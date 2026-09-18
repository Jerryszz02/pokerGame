#!/usr/bin/env python3
"""Validate release packages, then push them to itch.io with Butler.

`tools/build_release.py` produces the manifests and ZIPs. This script reads those
manifests, re-checks every selected package (including the real Web archive
validator), and only then either prints the exact Butler argv (``--dry-run``) or
runs it. Updates to existing channels may become live immediately. Butler
authenticates through its normal local login or ``BUTLER_API_KEY``.
"""
import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys
import zipfile

from verify import ROOT
import build_release

TARGETS = ('web', 'windows', 'macos')
VERSION_RE = re.compile(r'\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?')
COMMIT_RE = re.compile(r'^[0-9a-fA-F]{40}$')
SHA256_RE = re.compile(r'^[0-9a-f]{64}$')
PROJECT_RE = re.compile(r'^[^\s:/]+/[^\s:]+$')


class PreflightError(RuntimeError):
    """A package or manifest failed local validation before any upload."""


def channel_for(target):
    """The itch.io channel name for a build target (matches its target label)."""
    return build_release.target_label(target)


def expected_filename(target, version):
    return f'PokerGame-{version}-{channel_for(target)}.zip'


def within(parent, child):
    """True when ``child`` resolves inside ``parent`` (symlink-safe)."""
    try:
        parent = Path(parent).resolve(strict=True)
        child = Path(child).resolve(strict=True)
    except OSError:
        return False
    return child == parent or parent in child.parents


def load_manifest(target, packages_dir):
    path = Path(packages_dir) / f'{channel_for(target)}-manifest.json'
    if not path.is_file():
        raise PreflightError(f'{target}: missing manifest {path}')
    try:
        manifest = json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError) as exc:
        raise PreflightError(f'{target}: cannot read {path}: {exc}')
    if not isinstance(manifest, dict):
        raise PreflightError(f'{target}: {path} must contain a JSON object')
    return manifest


def preflight_target(target, packages_dir, expected_commit=None):
    """Validate one manifest and its package; return the upload details."""
    label = channel_for(target)
    source = f'{label}-manifest.json'
    manifest = load_manifest(target, packages_dir)

    if manifest.get('target') != label:
        raise PreflightError(f"{target}: manifest target {manifest.get('target')!r} != {label!r} in {source}")
    if manifest.get('dirty') is not False:
        raise PreflightError(f'{target}: manifest dirty must be exactly false in {source} (rebuild clean)')

    version = manifest.get('version')
    if not isinstance(version, str) or not VERSION_RE.fullmatch(version):
        raise PreflightError(f'{target}: manifest version is not sensible: {version!r}')
    commit = manifest.get('commit')
    if not isinstance(commit, str) or not COMMIT_RE.fullmatch(commit):
        raise PreflightError(f'{target}: manifest commit is not a full Git SHA: {commit!r}')
    commit = commit.lower()
    if expected_commit is not None and commit != expected_commit.lower():
        raise PreflightError(f'{target}: manifest commit {commit} != --expected-commit {expected_commit.lower()}')

    name = expected_filename(target, version)
    if manifest.get('filename') != name:
        raise PreflightError(f"{target}: manifest filename {manifest.get('filename')!r} != expected {name!r}")

    sha = manifest.get('sha256')
    if not isinstance(sha, str) or not SHA256_RE.fullmatch(sha):
        raise PreflightError(f'{target}: manifest sha256 is malformed: {sha!r}')
    size = manifest.get('bytes')
    if isinstance(size, bool) or not isinstance(size, int) or size < 0:
        raise PreflightError(f'{target}: manifest bytes must be a non-negative integer: {size!r}')

    packages_dir = Path(packages_dir)
    package = packages_dir / name
    if not package.is_file():
        raise PreflightError(f'{target}: package is missing: {package}')
    if not within(packages_dir, package):
        raise PreflightError(f'{target}: package path escapes the packages directory: {package}')
    actual_size = package.stat().st_size
    if actual_size != size:
        raise PreflightError(f'{target}: package size {actual_size} != manifest {size}')
    actual_sha = build_release.sha256(package)
    if actual_sha != sha:
        raise PreflightError(f'{target}: package sha256 {actual_sha} != manifest {sha}')

    if target == 'web':
        try:
            build_release.validate_web_archive(package)
        except (RuntimeError, OSError, zipfile.BadZipFile) as exc:
            raise PreflightError(f'{target}: web archive validation failed: {exc}')

    return {'target': target, 'version': version, 'commit': commit, 'package': package}


def preflight_all(targets, packages_dir, expected_commit=None):
    """Preflight every selected target before any push may run."""
    entries = [preflight_target(target, packages_dir, expected_commit) for target in targets]
    if len(entries) > 1:
        versions = sorted({entry['version'] for entry in entries})
        commits = sorted({entry['commit'] for entry in entries})
        if len(versions) > 1:
            raise PreflightError('selected targets have mixed versions: ' + ', '.join(versions))
        if len(commits) > 1:
            raise PreflightError('selected targets have mixed source commits: ' + ', '.join(commits))
    return entries


def butler_command(butler, project, entry, hidden=False):
    """Build the list argv for one official `butler push` invocation."""
    command = [
        butler,
        'push',
        str(entry['package']),
        f"{project}:{channel_for(entry['target'])}",
        '--userversion',
        entry['version'],
    ]
    if hidden:
        command.append('--hidden')
    return command


def build_parser():
    parser = argparse.ArgumentParser(
        description='Validate export/packages candidates and upload them to itch.io with Butler.')
    parser.add_argument('--target', choices=TARGETS + ('all',), default='all',
                        help='which candidate(s) to upload (default: all)')
    parser.add_argument('--packages-dir', type=Path, default=ROOT / 'export/packages',
                        help='directory holding the manifests and ZIPs')
    parser.add_argument('--project', default='jerryszz02/poker-game',
                        help='itch.io project as user/game')
    parser.add_argument('--butler', default='butler', help='Butler executable to invoke')
    parser.add_argument('--dry-run', action='store_true',
                        help='validate fully and print the commands without invoking Butler')
    parser.add_argument('--hidden', action='store_true',
                        help="forward Butler's --hidden (new channels only; errors on existing ones)")
    parser.add_argument('--expected-commit', default=None,
                        help='require every selected manifest to match this full Git SHA')
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    if not PROJECT_RE.fullmatch(args.project):
        print(f'error: --project must look like user/game, got {args.project!r}', file=sys.stderr)
        return 2

    targets = TARGETS if args.target == 'all' else (args.target,)
    try:
        entries = preflight_all(targets, args.packages_dir, args.expected_commit)
    except (PreflightError, OSError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 2

    commands = [butler_command(args.butler, args.project, entry, args.hidden) for entry in entries]
    if args.dry_run:
        print(f'Dry run: validated {len(entries)} package(s); Butler, network and authentication untouched.')
        for command in commands:
            print(shlex.join(command))
        return 0

    for command in commands:
        print('+ ' + shlex.join(command), flush=True)
        try:
            result = subprocess.run(command)
        except OSError as exc:
            print(f'error: cannot run Butler ({args.butler}): {exc}. Check butler version or --butler.',
                  file=sys.stderr)
            return 2
        if result.returncode != 0:
            print(f'error: Butler exited {result.returncode}; stopping', file=sys.stderr)
            return result.returncode
    return 0


if __name__ == '__main__':
    sys.exit(main())
