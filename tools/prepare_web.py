"""Prepare smaller Web-only assets in an isolated export project.

The original font/music and desktop exports remain unchanged. No glyphs are
subsetted: cloud feedback and player names can contain characters outside the UI.
"""
from pathlib import Path
import shutil
import subprocess

FONT = Path('assets/fonts/NotoSansSC.ttf')
MUSIC = Path('assets/audio/airport-lounge.mp3')


def stage_project(source, destination):
    source, destination = Path(source), Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    for directory in ('assets', 'scenes', 'scripts'):
        shutil.copytree(source / directory, destination / directory)
    for name in ('project.godot', 'export_presets.cfg', 'THIRD_PARTY_NOTICES.md'):
        shutil.copy2(source / name, destination / name)
    (destination / 'tools').mkdir()
    shutil.copy2(source / 'tools/web_shell.html', destination / 'tools/web_shell.html')


def optimize_assets(project, ffmpeg='ffmpeg'):
    try:
        from fontTools.ttLib import TTFont
        from fontTools.varLib.instancer import instantiateVariableFont
    except ImportError as error:
        raise RuntimeError('Web builds require: pip install -r tools/requirements-web.txt') from error
    encoder = shutil.which(ffmpeg)
    if not encoder:
        raise RuntimeError('Web builds require ffmpeg (or pass --ffmpeg /path/to/ffmpeg).')
    project = Path(project)
    font_path, music_path = project / FONT, project / MUSIC
    before = {str(path): (project / path).stat().st_size for path in (FONT, MUSIC)}
    # UI-Regular.tres uses weight 400 exclusively. Retain the entire cmap and all
    # shaping tables; only unused variable-weight data is removed.
    with TTFont(font_path, recalcTimestamp=False) as font:
        original_cmap = font.getBestCmap().copy()
        instantiateVariableFont(font, {'wght': 400}, inplace=True)
        font.save(font_path)
    with TTFont(font_path) as font:
        if font.getBestCmap() != original_cmap or 'fvar' in font:
            raise RuntimeError('Web font optimization changed character coverage or retained variable axes')
    temporary = music_path.with_name('airport-lounge-encoded.mp3')
    subprocess.run([encoder, '-nostdin', '-v', 'error', '-i', str(music_path),
                    '-map_metadata', '-1', '-c:a', 'libmp3lame', '-b:a', '96k',
                    '-ar', '44100', str(temporary)], check=True, timeout=120)
    temporary.replace(music_path)
    after = {str(path): (project / path).stat().st_size for path in (FONT, MUSIC)}
    if any(after[path] >= before[path] or after[path] == 0 for path in before):
        raise RuntimeError('Web asset optimization did not reduce both resources')
    return {'before_bytes': before, 'after_bytes': after,
            'font_characters': len(original_cmap), 'music_bitrate_kbps': 96}
