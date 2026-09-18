#!/usr/bin/env python3
"""Upload the owner's private file value to the deployed Worker's Secret binding."""
import argparse
import os
from pathlib import Path
import subprocess

from coach_service import read_key

ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / 'services/coach-worker'


def upload_secret(env_file, worker_dir=WORKER, runner=subprocess.run):
    key = read_key(env_file)
    if not key:
        raise ValueError('A valid DEEPSEEK_API_KEY is required in the private configuration file.')
    wrangler = worker_dir / 'node_modules/wrangler/bin/wrangler.js'
    if not wrangler.is_file():
        raise ValueError('Install the Worker dependencies with npm ci before configuring its Secret.')
    environment = os.environ.copy()
    environment['CLOUDFLARE_SEND_METRICS'] = 'false'
    # A pipe keeps the credential out of shell commands, process arguments and
    # terminal echo. Never forward Wrangler output: upstream errors may contain
    # sensitive request data. The account remains owned by Wrangler's login.
    result = runner(
        ['node', str(wrangler), 'secret', 'put', 'DEEPSEEK_API_KEY'],
        cwd=worker_dir, input=key + '\n', capture_output=True, text=True,
        env=environment, timeout=120, check=False,
    )
    if result.returncode != 0:
        raise RuntimeError('Worker Secret upload failed (exit %d). Check Wrangler login and Worker deployment.' % result.returncode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--env-file', type=Path, default=ROOT / '.env.local')
    args = parser.parse_args()
    try:
        upload_secret(args.env_file)
    except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        # TimeoutExpired may contain captured process output, so omit it.
        message = str(error) if isinstance(error, (ValueError, RuntimeError)) else 'Worker Secret configuration could not complete.'
        parser.exit(1, message + '\n')
    print('Cloudflare Secret DEEPSEEK_API_KEY configured; the key was not printed.')


if __name__ == '__main__':
    main()
