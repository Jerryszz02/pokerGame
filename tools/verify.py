#!/usr/bin/env python3
"""Run release checks; fail on Godot script errors even if the process exits 0."""
import argparse
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def run(command, marker=None, timeout=300, log_name='check', cwd=ROOT):
    result = subprocess.run([str(x) for x in command], cwd=cwd, capture_output=True,
                            text=True, encoding="utf-8", errors="replace", timeout=timeout)
    output = re.sub(r'\x1b\[[0-9;]*m', '', result.stdout + result.stderr)
    logs = ROOT / 'export/logs'
    logs.mkdir(parents=True, exist_ok=True)
    (logs / (log_name + '.log')).write_text(output, encoding="utf-8")
    if result.returncode or re.search(r'(^|\n)(?:SCRIPT )?ERROR:', output) or (marker and marker not in output):
        raise RuntimeError(f'{log_name} failed (exit {result.returncode}):\n{output[-12000:]}')
    print(f'PASS {log_name}', flush=True)
    return output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--windowed', action='store_true')
    args = parser.parse_args()
    run([args.godot, '--headless', '--path', ROOT, '--import'], timeout=600, log_name='import')
    checks = [
        ('localization_test.gd', 'Localization tests passed.'),
        ('localization_ui_probe.gd', 'Localization UI probes passed.'),
        ('audio_test.gd', 'Audio tests passed.'),
        ('test_runner.gd', 'All poker tests passed.'),
        ('practice_data_test.gd', 'Practice data tests passed.'),
        ('practice_save_retry_test.gd', 'Practice save retry tests passed.'),
        ('tutorial_test.gd', 'Tutorial tests passed.'),
        ('practice_ui_probe.gd', 'Practice UI probes passed.'),
        ('test_ai_strategy.gd', 'AI strategy tests passed.'),
        ('test_ai_observations.gd', 'AI observation tests passed.'),
        ('rules_soak.gd', 'Rules soak passed:'),
        ('ai_runtime_probe.gd', 'AI runtime probe passed:'),
        ('ui_lifecycle_probe.gd', 'UI lifecycle probe passed.'),
        ('ui_layout_probe.gd', 'All UI layout probes passed.'),
    ]
    for script, marker in checks:
        run([args.godot, '--headless', '--path', ROOT, '-s', 'tests/' + script],
            marker, log_name=script[:-3])
    if args.windowed:
        run([args.godot, '--path', ROOT, '-s', 'tests/ui_playthrough_probe.gd'],
            'UI playthrough probe passed.', timeout=600, log_name='ui_playthrough_probe')
        run([args.godot, '--path', ROOT, '-s', 'tests/practice_ui_probe.gd'],
            'Practice UI probes passed.', timeout=600, log_name='practice_ui_windowed')
    print('Verification passed. Long-window and target-platform gates remain separate.')


if __name__ == '__main__':
    main()
