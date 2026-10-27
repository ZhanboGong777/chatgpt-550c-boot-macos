#!/usr/bin/env python3
"""Check real macOS process replacement and bounded failure using a local fixture.

Runs on an unlocked macOS desktop. No ChatGPT process is opened, closed, or
resized. Each fixture app uses a private temporary directory and exits after
the test, with an additional 20-second self-termination guard.
"""
import argparse
import json
import plistlib
import platform
import subprocess
import tempfile
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def events(directory):
    return [json.loads(path.read_text(encoding='utf-8')) for path in directory.glob('*.json')]


def stop_fixture(directory):
    (directory / 'stop').touch()
    deadline = time.monotonic() + 3
    while time.monotonic() < deadline:
        recorded = events(directory)
        started = {event['pid'] for event in recorded if event['event'].endswith('-started')}
        exited = {event['pid'] for event in recorded if event['event'] == 'exited'}
        if started <= exited:
            return
        time.sleep(0.1)
    raise AssertionError(f'Fixture did not stop on request: {directory}')


def run_case(app, binary, output, scenario):
    directory = output / scenario
    directory.mkdir()
    event_directory = directory / 'events'
    event_directory.mkdir()
    fixture = directory / 'Lifecycle Fixture.app'
    contents = fixture / 'Contents'
    executable = contents / 'MacOS' / 'LifecycleFixture'
    executable.parent.mkdir(parents=True)
    executable.write_bytes(binary.read_bytes())
    executable.chmod(0o755)
    resources = contents / 'Resources'
    resources.mkdir()
    (resources / 'FixtureConfig.json').write_text(json.dumps({
        'scenario': scenario, 'events': str(event_directory),
    }), encoding='utf-8')
    with (contents / 'Info.plist').open('wb') as stream:
        plistlib.dump({
            'CFBundleIdentifier': f'io.github.chatgpt550c.lifecyclefixture.{uuid.uuid4().hex}',
            'CFBundleExecutable': 'LifecycleFixture',
            'CFBundleName': '550C Lifecycle Fixture',
            'CFBundlePackageType': 'APPL',
            'LSMinimumSystemVersion': '13.0',
            'NSSupportsAutomaticTermination': False,
        }, stream)
    subprocess.run(['codesign', '--force', '--sign', '-', str(fixture)], check=True)
    report = directory / 'handoff.json'
    started = time.monotonic()
    try:
        mode = 'simple' if scenario == 'ready-replacement' else 'off'
        subprocess.run(['open', '-n', '-W', str(app), '--args', '--mode', mode,
                        '--verify', str(report), '--verify-handoff', '--verify-target', str(fixture)],
                       check=True, timeout=18)
        duration = time.monotonic() - started
        result = json.loads(report.read_text(encoding='utf-8'))
        handoff = result['handoff']
        recorded = events(event_directory)
        initial = {event['pid'] for event in recorded if event['event'] == 'initial-started'}
        assert len(initial) == 1, recorded
        if scenario == 'exit':
            assert result['handoffPhase'] == 'failed', result
            assert 7.5 <= duration < 13, (duration, result)
            assert not handoff.get('processReplacementCount'), result
            assert 'fadeStartedAt' not in handoff, result
        else:
            assert result['handoffPhase'] == 'done', result
            assert 'targetVisibleAt' in handoff and 'fadeStartedAt' in handoff, result
            if scenario in {'replacement', 'ready-replacement'}:
                successor = {event['pid'] for event in recorded if event['event'] == 'successor-started'}
                assert len(successor) == 1 and not initial & successor, recorded
                assert handoff['targetPID'] in successor, (result, recorded)
                assert handoff.get('processReplacementCount', 0) >= 1, result
            else:
                assert handoff['targetPID'] in initial, result
        print(f'PASS {scenario}: {duration:.2f}s, {result["handoffPhase"]}', flush=True)
    finally:
        stop_fixture(event_directory)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True, type=Path, help='Built ChatGPT 550C.app to verify.')
    parser.add_argument('--output', type=Path, help='Optional directory for local reports and fixtures.')
    args = parser.parse_args()
    app = args.app.expanduser().resolve()
    if not (app / 'Contents' / 'MacOS' / 'ChatGPT550C').is_file():
        parser.error('The supplied launcher app does not exist.')
    output = args.output.expanduser().resolve() if args.output else Path(tempfile.mkdtemp(prefix='chatgpt550c-lifecycle-'))
    output.mkdir(parents=True, exist_ok=True)
    binary = output / 'LifecycleFixture'
    cache = output / 'module-cache'
    cache.mkdir(exist_ok=True)
    # The fixture only needs the current host architecture.
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library',
                    '-target', f'{platform.machine()}-apple-macosx13.0',
                    '-module-cache-path', str(cache), '-framework', 'AppKit',
                    str(ROOT / 'macos' / 'tests' / 'LifecycleFixture.swift'), '-o', str(binary)], check=True)
    for scenario in ('stable', 'replacement', 'ready-replacement', 'exit'):
        run_case(app, binary, output, scenario)
    print(f'Reports: {output}')


if __name__ == '__main__':
    main()
