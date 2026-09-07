#!/usr/bin/env python3
"""Build versioned desktop candidate packages and test the host-native artifact."""
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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--target', choices=['windows', 'macos'], required=True)
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
    export_root = ROOT / 'export'
    export_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=args.target + '-', dir=export_root) as temporary_export:
        raw = Path(temporary_export)
        windows = args.target == 'windows'
        preset = 'Windows Desktop' if windows else 'macOS'
        output = raw / ('PokerGame.exe' if windows else 'PokerGame.zip')
        run([godot, '--headless', '--path', ROOT, '--import'], timeout=600, log_name='import-' + args.target)
        run([godot, '--headless', '--path', ROOT, '--export-release', preset, output], timeout=900, log_name='export-' + args.target)
        if runtime_fingerprint() != source_sha256:
            raise RuntimeError('Runtime sources changed during import/export; inspect and commit before rebuilding.')
        if not args.candidate and subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip():
            raise RuntimeError('Import/export changed the checkout; inspect and commit before rebuilding.')
        if not output.is_file() or output.stat().st_size < 1024 * 1024:
            raise RuntimeError('Export did not produce a complete binary package')
        native = (windows and platform.system() == 'Windows') or (not windows and platform.system() == 'Darwin')
        with tempfile.TemporaryDirectory(prefix='pokergame-package-check-') as temporary:
            sandbox = Path(temporary)
            if windows:
                for item in raw.iterdir():
                    if item.is_file():
                        shutil.copy2(item, sandbox / item.name)
                executable = sandbox / 'PokerGame.exe'
            elif platform.system() == 'Darwin':
                subprocess.run(['/usr/bin/ditto', '-x', '-k', str(output), temporary], check=True)
                executable = sandbox / 'PokerGame.app/Contents/MacOS/PokerGame'
            else:
                executable = None
            if native:
                result = run([executable, '--headless', '--', '--self-test'], 'Package self-test passed:',
                             timeout=600, log_name='package-self-test-' + args.target, cwd=sandbox)
                if 'template=true' not in result:
                    raise RuntimeError('Self-test did not execute the exported template')
        packages = ROOT / 'export/packages'
        packages.mkdir(parents=True, exist_ok=True)
        target_label = 'windows-x64' if windows else 'macos-universal'
        package = packages / f'PokerGame-{version}-{target_label}.zip'
        if windows:
            with zipfile.ZipFile(package, 'w', zipfile.ZIP_DEFLATED) as archive:
                for item in raw.iterdir():
                    if item.is_file():
                        archive.write(item, item.name)
        else:
            shutil.copy2(output, package)
        with zipfile.ZipFile(package, 'a', zipfile.ZIP_DEFLATED) as archive:
            archive.write(ROOT / 'docs/player-guide.md', 'README.md')
            archive.write(ROOT / 'THIRD_PARTY_NOTICES.md', 'THIRD_PARTY_NOTICES.md')
            archive.write(ROOT / 'assets/fonts/OFL.txt', 'licenses/NotoSansSC-OFL.txt')
            for item in (ROOT / 'assets/licenses').glob('*.txt'):
                archive.write(item, 'licenses/' + item.name)
        manifest = {
            'version': version, 'commit': commit, 'dirty': dirty, 'engine': engine,
            'source_sha256': source_sha256,
            'target': target_label, 'host_os': platform.platform(),
            'package_self_test_passed': native, 'graphical_platform_validation': 'not established by this script',
            'macos_signing': 'ad-hoc; not notarized' if not windows else None,
            'filename': package.name, 'sha256': sha256(package), 'bytes': package.stat().st_size,
            'public_release_ready': False,
        }
        (packages / f'{target_label}-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        (packages / f'{target_label}-SHA256SUMS.txt').write_text(f'{manifest["sha256"]}  {package.name}\n')
        print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
