#!/usr/bin/env python3
"""Install the pinned official GDScript editor/templates into a build cache."""
import argparse
import hashlib
import os
from pathlib import Path
import platform
import shutil
import urllib.request
import zipfile

VERSION = '4.7.2'
BASE = f'https://github.com/godotengine/godot/releases/download/{VERSION}-stable/'
# The Web preset enables thread support and disables GDExtension, so the matching
# official templates are the plain (non-dlink) threaded pair.
WEB_TEMPLATES = ('web_debug.zip', 'web_release.zip')


def is_template_file(base):
    """Return True for export templates the project's desktop and web presets need."""
    if base in ('macos.zip', 'version.txt'):
        return True
    if base.startswith('windows_') and 'x86_64' in base:
        return True
    return base in WEB_TEMPLATES


def fetch(name, cache, sums):
    path = cache / name
    if not path.exists():
        temporary = cache / (name + '.download')
        urllib.request.urlretrieve(BASE + name, temporary)
        temporary.replace(path)
    digest = hashlib.sha512()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    if digest.hexdigest() != sums[name]:
        raise RuntimeError(f'Official SHA-512 mismatch: {path}')
    return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cache', type=Path, default=Path.home() / '.cache/pokergame/godot' / VERSION)
    parser.add_argument('--templates', action='store_true')
    args = parser.parse_args()
    cache = args.cache.resolve()
    cache.mkdir(parents=True, exist_ok=True)
    checksum = cache / 'SHA512-SUMS.txt'
    if not checksum.exists():
        urllib.request.urlretrieve(BASE + checksum.name, checksum)
    sums = {line.split()[-1]: line.split()[0] for line in checksum.read_text().splitlines() if line.strip()}
    system = platform.system()
    suffix, executable = {
        'Darwin': ('macos.universal.zip', 'Godot.app/Contents/MacOS/Godot'),
        'Windows': ('win64.exe.zip', f'Godot_v{VERSION}-stable_win64.exe'),
        'Linux': ('linux.x86_64.zip', f'Godot_v{VERSION}-stable_linux.x86_64'),
    }[system]
    archive = fetch(f'Godot_v{VERSION}-stable_{suffix}', cache, sums)
    editor = cache / 'editor'
    if not (editor / executable).exists():
        with zipfile.ZipFile(archive) as source:
            source.extractall(editor)
    godot = editor / executable
    godot.chmod(0o755)
    if args.templates:
        templates = fetch(f'Godot_v{VERSION}-stable_export_templates.tpz', cache, sums)
        if system == 'Darwin':
            target = Path.home() / 'Library/Application Support/Godot/export_templates'
        elif system == 'Windows':
            target = Path(os.environ['APPDATA']) / 'Godot/export_templates'
        else:
            target = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'godot/export_templates'
        target = target / f'{VERSION}.stable'
        target.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(templates) as source:
            for name in source.namelist():
                base = Path(name).name
                if is_template_file(base):
                    with source.open(name) as src, (target / base).open('wb') as dst:
                        shutil.copyfileobj(src, dst)
    print(godot)
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            output.write(f'godot={godot}\n')


if __name__ == '__main__':
    main()
