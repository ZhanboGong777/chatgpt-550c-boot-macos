#!/usr/bin/env python3
"""Run visible playback checks on a macOS desktop without launching ChatGPT."""
import argparse
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path)
    args = parser.parse_args()
    app = args.app or Path((ROOT / '.build' / 'last-app-path.txt').read_text(encoding='utf-8').strip())
    reports = Path(tempfile.mkdtemp(prefix='chatgpt550c-verification-'))
    for name, mode, action, reason in [
        ('full', 'full', None, 'animation-complete'),
        ('simple', 'simple', None, 'animation-complete'),
        ('skip', 'full', 'skip', 'animation-complete'),
        ('timeout', 'full', 'timeout', 'timeout'),
        ('off', 'off', None, 'off'),
    ]:
        report = reports / f'{name}.json'
        command = ['open', '-n', '-W', str(app.resolve()), '--args', '--windowed', '--mode', mode, '--verify', str(report)]
        if action:
            command += ['--test-action', action]
        subprocess.run(command, check=True, timeout=160)
        result = json.loads(report.read_text(encoding='utf-8'))
        assert result['reason'] == reason and not result['scriptErrors'], result
        if mode != 'off':
            assert result['page']['mode'] == mode and result['page']['skipOnTop'], result
        if name == 'full':
            assert result['page']['nodes'] == result['page']['completedNodes'] == 47, result
            assert result['page']['progress'] == '100%' and result['page']['finalVisible'], result
        if name == 'simple':
            assert result['page']['nodes'] == 0 and not result['page']['finalVisible'], result
        if name == 'skip':
            assert result['page']['nodes'] == 0, result
        print(f"PASS {name}: {result['seconds']:.2f}s, {reason}", flush=True)
    print(f'Reports: {reports}')


if __name__ == '__main__':
    main()
