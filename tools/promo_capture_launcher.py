#!/usr/bin/env python3
"""Launch an isolated 1080p graphical MovieMaker project without changing game config."""
import argparse
from datetime import date
import re
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
source = Path(__file__).resolve().parents[1]
version = re.search(r'config/version="([^"]+)"', (source / 'project.godot').read_text()).group(1)
parser.add_argument('--output', type=Path, default=source / 'export' / 'promo' / f'v{version}' / f'production-{date.today().isoformat()}' / 'raw', help='Destination directory for AVI, PNG, records, and event logs.')
parser.add_argument('--lang', choices=['en', 'zh'], default='en')
parser.add_argument('--mode', choices=['test', 'practice', 'tutorial', 'replay', 'hard', 'config'], default='test')
args = parser.parse_args()
output = args.output.expanduser().resolve()
output_name = f'config-pickup-{args.lang}' if args.mode == 'config' else f'hard-ai-{args.lang}' if args.mode == 'hard' else ('zh-replay-pickup' if args.mode == 'replay' else f'{args.lang}-{args.mode}-take02')
existing = [path for path in (output / f'{output_name}.avi', output / f'{output_name}-timeline.jsonl') if path.exists()]
if existing:
    parser.error('Capture already exists; choose a fresh destination with --output: ' + ', '.join(path.name for path in existing))
output.mkdir(parents=True, exist_ok=True)
isolated = Path(tempfile.mkdtemp(prefix='poker-promo-v140-'))
for child in source.iterdir():
    if child.name not in {'project.godot', '.git', '.godot', 'export'}:
        (isolated / child.name).symlink_to(child, target_is_directory=child.is_dir())
config = (source / 'project.godot').read_text()
config = config.replace('viewport_width=1280', 'viewport_width=1920').replace('viewport_height=720', 'viewport_height=1080').replace('window/size/mode=2', 'window/size/mode=0')
(isolated / 'project.godot').write_text(config)
binary = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
subprocess.run([binary, '--headless', '--path', str(isolated), '--editor', '--import'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
print(f'ISOLATED_PROJECT={isolated}', flush=True)
subprocess.run([binary, '--path', str(isolated), '--resolution', '1920x1080', '--write-movie', str(output / f'{output_name}.avi'), '--fixed-fps', '30', '--disable-vsync', '-s', 'tools/promo_capture.gd', '--', f'--lang={args.lang}', f'--mode={args.mode}', f'--output={output}'], check=True)
