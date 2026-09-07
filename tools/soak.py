#!/usr/bin/env python3
"""Run the full window soak with commit/source identity and retained evidence."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
from verify import ROOT


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    environment = os.environ.copy()
    environment['POKER_TEST_COMMIT'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip())
    environment['POKER_TEST_DIRTY'] = str(dirty).lower()
    evidence = ROOT / 'export/evidence'
    evidence.mkdir(parents=True, exist_ok=True)
    log = evidence / 'ui-stability.log'
    print(f'Starting 30-minute window soak; live log: {log}', flush=True)
    with log.open('w', encoding='utf-8') as output:
        process = subprocess.Popen([args.godot, '--path', str(ROOT), '-s', 'tests/ui_stability_probe.gd'],
                                   cwd=ROOT, env=environment, stdout=output, stderr=subprocess.STDOUT)
        try:
            code = process.wait(timeout=2100)
        except subprocess.TimeoutExpired:
            process.terminate()
            process.wait(timeout=20)
            raise RuntimeError('Window soak exceeded 35 minutes; inspect its retained log')
    text = log.read_text(encoding='utf-8', errors='replace')
    report = None
    for line in text.splitlines():
        if line.startswith('{') and 'source_sha256' in line:
            report = json.loads(line)
    if report is not None:
        (evidence / 'ui-stability.json').write_text(json.dumps(report, indent=2) + '\n')
    if code or re.search(r'(^|\n)(?:SCRIPT )?ERROR:', text) or 'UI stability probe passed.' not in text or report is None:
        raise RuntimeError(f'Window soak failed; see {log}')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
