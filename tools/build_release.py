#!/usr/bin/env python3
"""Build versioned desktop and web candidate packages and test the host-native artifact."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile
import zipfile
from verify import ROOT, run
from bootstrap_godot import VERSION

TARGET_PRESETS = {'windows': 'Windows Desktop', 'macos': 'macOS', 'web': 'Web'}
TARGET_LABELS = {'windows': 'windows-x64', 'macos': 'macos-universal', 'web': 'web'}
WEB_ENTRY = 'index.html'
# Godot 4.7.2 emits these for a threaded, non-GDExtension export named index.*
WEB_REQUIRED_MEMBERS = (
    'index.html',
    'index.js',
    'index.wasm',
    'index.pck',
    'index.audio.worklet.js',
    'index.audio.position.worklet.js',
)
# Members the exporter may add once PWA or worker options change; kept explicit for reviewers.
WEB_OPTIONAL_MEMBERS = (
    'index.png',
    'index.icon.png',
    'index.worker.js',
    'index.apple-touch-icon.png',
    'index.manifest.json',
    'index.service.worker.js',
    'index.offline.html',
)


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def runtime_fingerprint():
    config = (ROOT / 'export_presets.cfg').read_text()
    roots = re.search(r'export_files=PackedStringArray\(([^\n]+)\)', config).group(1)
    paths = re.findall(r'"(res://[^"]+)"', roots) + ['res://project.godot', 'res://export_presets.cfg']
    digest = hashlib.sha256()
    for resource in sorted(paths):
        digest.update((resource + '\n' + sha256(ROOT / resource[6:]) + '\n').encode())
    return digest.hexdigest()


def export_preset(target):
    return TARGET_PRESETS[target]


def target_label(target):
    return TARGET_LABELS[target]


def output_name(target):
    return {'windows': 'PokerGame.exe', 'macos': 'PokerGame.zip', 'web': WEB_ENTRY}[target]


def host_native(target):
    """A platform self-test only makes sense for desktop targets on their own OS."""
    if target == 'windows':
        return platform.system() == 'Windows'
    if target == 'macos':
        return platform.system() == 'Darwin'
    return False


def manifest_platform_fields(target):
    """Manifest fields that must describe the target honestly without overclaiming."""
    web = target == 'web'
    fields = {
        'target': target_label(target),
        'host_os': platform.platform(),
        'package_self_test_passed': host_native(target),
        'graphical_platform_validation': 'not established by this script',
        'macos_signing': 'ad-hoc; not notarized' if target == 'macos' else None,
    }
    if web:
        fields['web_native_self_test'] = 'not established by this script'
        fields['browser_validation'] = 'not established by this script'
    return fields


def web_export_members(directory):
    """Return exported web file names after checking the required set is present."""
    directory = Path(directory)
    if not directory.is_dir():
        raise RuntimeError(f'Web export directory is missing: {directory}')
    files = sorted(item.name for item in directory.iterdir() if item.is_file())
    missing = [name for name in WEB_REQUIRED_MEMBERS if name not in files]
    if missing:
        raise RuntimeError('Web export is missing required files: ' + ', '.join(missing))
    return files


def validate_web_export(directory):
    """Validate a Godot web export directory without applying desktop size gates to HTML."""
    directory = Path(directory)
    members = web_export_members(directory)
    if (directory / WEB_ENTRY).stat().st_size == 0:
        raise RuntimeError('Web export index.html is empty')
    if (directory / 'index.wasm').stat().st_size < 1024 * 1024:
        raise RuntimeError('Web export did not produce a complete WebAssembly payload')
    return members


def validate_web_archive(package):
    """Re-open the built ZIP and confirm the shipped members match the web contract."""
    required = set(WEB_REQUIRED_MEMBERS)
    license_names = {'licenses/NotoSansSC-OFL.txt'}
    license_names.update('licenses/' + item.name for item in (ROOT / 'assets/licenses').glob('*.txt'))
    expected_docs = {'README.md', 'THIRD_PARTY_NOTICES.md'}
    with zipfile.ZipFile(package) as archive:
        names = [item.filename for item in archive.infolist()]
        if len(names) != len(set(names)):
            raise RuntimeError('Web package contains duplicate archive members')
        for name in names:
            if name.startswith('/') or '..' in Path(name).parts:
                raise RuntimeError(f'Web package contains an unsafe archive member: {name}')
        flat = {name for name in names if '/' not in name}
        nested = {name for name in names if '/' in name}
        missing = (required | expected_docs) - flat
        if missing:
            raise RuntimeError('Web package is missing required members: ' + ', '.join(sorted(missing)))
        known_flat = required | expected_docs | set(WEB_OPTIONAL_MEMBERS)
        unknown_flat = flat - known_flat
        if unknown_flat:
            raise RuntimeError('Web package contains unexpected archive members: ' + ', '.join(sorted(unknown_flat)))
        missing_licenses = license_names - nested
        if missing_licenses:
            raise RuntimeError('Web package is missing license files: ' + ', '.join(sorted(missing_licenses)))
        unknown_nested = nested - license_names
        if unknown_nested:
            raise RuntimeError('Web package contains unexpected nested members: ' + ', '.join(sorted(unknown_nested)))
    return sorted(names)


def add_release_docs(archive):
    archive.write(ROOT / 'docs/player-guide.md', 'README.md')
    archive.write(ROOT / 'THIRD_PARTY_NOTICES.md', 'THIRD_PARTY_NOTICES.md')
    archive.write(ROOT / 'assets/fonts/OFL.txt', 'licenses/NotoSansSC-OFL.txt')
    for item in (ROOT / 'assets/licenses').glob('*.txt'):
        archive.write(item, 'licenses/' + item.name)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--target', choices=['windows', 'macos', 'web'], required=True)
    parser.add_argument('--candidate', action='store_true', help='Allow a dirty local candidate; record it in the manifest.')
    args = parser.parse_args()
    godot = str(Path(args.godot).resolve())
    engine = subprocess.check_output([godot, '--version'], text=True).strip()
    if not engine.startswith(VERSION + '.stable.'):
        raise RuntimeError(f'Expected Godot {VERSION} stable, got {engine}')
    dirty = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip())
    if dirty and not args.candidate:
        raise RuntimeError('Release build requires a clean checkout. Use --candidate for an explicitly unverified local build.')
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    source_sha256 = runtime_fingerprint()
    version = re.search(r'config/version="([^"]+)"', (ROOT / 'project.godot').read_text()).group(1)
    target = args.target
    web = target == 'web'
    export_root = ROOT / 'export'
    export_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=target + '-', dir=export_root) as temporary_export:
        raw = Path(temporary_export)
        output = raw / output_name(target)
        run([godot, '--headless', '--path', ROOT, '--import'], timeout=600, log_name='import-' + target)
        run([godot, '--headless', '--path', ROOT, '--export-release', export_preset(target), output], timeout=900, log_name='export-' + target)
        if runtime_fingerprint() != source_sha256:
            raise RuntimeError('Runtime sources changed during import/export; inspect and commit before rebuilding.')
        if not args.candidate and subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip():
            raise RuntimeError('Import/export changed the checkout; inspect and commit before rebuilding.')
        if web:
            exported = validate_web_export(raw)
        else:
            exported = None
            if not output.is_file() or output.stat().st_size < 1024 * 1024:
                raise RuntimeError('Export did not produce a complete binary package')
        if host_native(target):
            with tempfile.TemporaryDirectory(prefix='pokergame-package-check-') as temporary:
                sandbox = Path(temporary)
                if target == 'windows':
                    for item in raw.iterdir():
                        if item.is_file():
                            shutil.copy2(item, sandbox / item.name)
                    executable = sandbox / 'PokerGame.exe'
                else:
                    subprocess.run(['/usr/bin/ditto', '-x', '-k', str(output), temporary], check=True)
                    executable = sandbox / 'PokerGame.app/Contents/MacOS/PokerGame'
                result = run([executable, '--headless', '--', '--self-test'], 'Package self-test passed:',
                             timeout=600, log_name='package-self-test-' + target, cwd=sandbox)
                if 'template=true' not in result:
                    raise RuntimeError('Self-test did not execute the exported template')
        packages = ROOT / 'export/packages'
        packages.mkdir(parents=True, exist_ok=True)
        label = target_label(target)
        package = packages / f'PokerGame-{version}-{label}.zip'
        if web:
            with zipfile.ZipFile(package, 'w', zipfile.ZIP_DEFLATED) as archive:
                for name in exported:
                    archive.write(raw / name, name)
                add_release_docs(archive)
            validate_web_archive(package)
        elif target == 'windows':
            with zipfile.ZipFile(package, 'w', zipfile.ZIP_DEFLATED) as archive:
                for item in raw.iterdir():
                    if item.is_file():
                        archive.write(item, item.name)
                add_release_docs(archive)
        else:
            shutil.copy2(output, package)
            with zipfile.ZipFile(package, 'a', zipfile.ZIP_DEFLATED) as archive:
                add_release_docs(archive)
        manifest = {
            'version': version, 'commit': commit, 'dirty': dirty, 'engine': engine,
            'source_sha256': source_sha256,
            **manifest_platform_fields(target),
            'filename': package.name, 'sha256': sha256(package), 'bytes': package.stat().st_size,
            'public_release_ready': False,
        }
        (packages / f'{label}-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        (packages / f'{label}-SHA256SUMS.txt').write_text(f'{manifest["sha256"]}  {package.name}\n')
        print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
