#!/usr/bin/env python3
"""Build the macOS port using Apple's installed command-line tools only."""
import argparse
import hashlib
import json
import platform
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_NAME = 'ChatGPT 550C.app'
EXECUTABLE = 'ChatGPT550C'


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--arch', choices=['arm64', 'x86_64', 'universal'], default='universal')
    parser.add_argument('--output', type=Path, default=ROOT / 'dist')
    args = parser.parse_args()
    if platform.system() != 'Darwin':
        parser.error('Build on macOS with Xcode Command Line Tools installed.')
    version = (ROOT / 'VERSION').read_text(encoding='utf-8').strip()
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        parser.error('VERSION must contain a numeric major.minor.patch version.')
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    cache = ROOT / '.build' / 'module-cache'
    cache.mkdir(parents=True, exist_ok=True)
    # Build the .app outside synced folders: Finder metadata can invalidate signing.
    stage = Path(tempfile.mkdtemp(prefix='chatgpt550c-macos-'))
    package = stage / 'release'
    app = package / APP_NAME
    contents = app / 'Contents'
    resources = contents / 'Resources'
    binary_dir = contents / 'MacOS'
    resources.mkdir(parents=True)
    binary_dir.mkdir()
    for name in ['550c-overlay.html', 'LICENSE', 'NOTICE.md', 'TRADEMARKS.md', 'UPSTREAM.json']:
        shutil.copyfile(ROOT / name, resources / name)

    architectures = ['arm64', 'x86_64'] if args.arch == 'universal' else [args.arch]
    slices = []
    for arch in architectures:
        binary = stage / f'{EXECUTABLE}-{arch}'
        print(f'Building {arch}...', flush=True)
        run('xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library', '-O', '-target', f'{arch}-apple-macosx13.0',
            '-module-name', EXECUTABLE, '-module-cache-path', cache,
            '-framework', 'AppKit', '-framework', 'WebKit', '-framework', 'ApplicationServices',
            ROOT / 'macos' / 'Launcher.swift', ROOT / 'macos' / 'HandoffState.swift',
            ROOT / 'macos' / 'TargetWindowManager.swift', '-o', binary)
        slices.append(binary)
    destination = binary_dir / EXECUTABLE
    if len(slices) == 2:
        run('xcrun', 'lipo', '-create', *slices, '-output', destination)
    else:
        shutil.copyfile(slices[0], destination)
    destination.chmod(0o755)

    icon_generator = stage / 'generate-icon'
    run('xcrun', 'swiftc', '-swift-version', '5', '-O', '-module-cache-path', cache,
        '-framework', 'AppKit', ROOT / 'macos' / 'generate-icon.swift', '-o', icon_generator)
    iconset = stage / 'Boot.iconset'
    run(icon_generator, iconset)
    run('xcrun', 'iconutil', '-c', 'icns', iconset, '-o', resources / 'AppIcon.icns')

    info = {
        'CFBundleIdentifier': 'io.github.chatgpt550c.macos',
        'CFBundleName': 'ChatGPT 550C', 'CFBundleDisplayName': 'ChatGPT 550C',
        'CFBundleExecutable': EXECUTABLE, 'CFBundlePackageType': 'APPL',
        'CFBundleShortVersionString': version, 'CFBundleVersion': version,
        'CFBundleIconFile': 'AppIcon.icns', 'LSMinimumSystemVersion': '13.0',
        'NSHighResolutionCapable': True, 'NSSupportsAutomaticTermination': False,
        'NSHumanReadableCopyright': 'macOS port of Chenchu0o0/chatgpt-550c-boot; animation credits in NOTICE.md.',
    }
    with (contents / 'Info.plist').open('wb') as stream:
        plistlib.dump(info, stream)
    # This is an ad-hoc signature for integrity, not a Developer ID/notarized release.
    run('codesign', '--force', '--sign', '-', app)
    run('codesign', '--verify', '--deep', '--strict', app)
    run('xcrun', 'lipo', '-info', destination)

    for name in ['LICENSE', 'NOTICE.md', 'TRADEMARKS.md', 'UPSTREAM.json']:
        shutil.copyfile(ROOT / name, package / name)
    usage = (ROOT / 'docs' / 'macOS使用说明.md').read_text(encoding='utf-8')
    for name in ['NOTICE.md', 'LICENSE', 'TRADEMARKS.md']:
        usage = usage.replace(f'](../{name})', f']({name})')
    (package / '使用说明.md').write_text(usage, encoding='utf-8')
    archive = output / f'ChatGPT-550C-macOS-v{version}-{args.arch}.zip'
    run('ditto', '--norsrc', '-c', '-k', '--keepParent', app, archive)
    # Keep the .app as the archive's first-level entry, alongside its notices.
    import zipfile
    with zipfile.ZipFile(archive, 'a', compression=zipfile.ZIP_DEFLATED) as zip_file:
        for path in sorted(package.iterdir()):
            if path.is_file():
                zip_file.write(path, path.name)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / f'{archive.name}.sha256').write_text(f'{digest}  {archive.name}\n', encoding='utf-8')
    checksum_lines = []
    for path in sorted(output.glob('*.zip')):
        checksum_lines.append(f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}')
    (output / 'SHA256SUMS').write_text('\n'.join(checksum_lines) + '\n', encoding='utf-8')
    (ROOT / '.build' / 'last-app-path.txt').write_text(str(app), encoding='utf-8')
    (ROOT / '.build' / 'last-build.json').write_text(json.dumps({
        'app': str(app), 'archive': str(archive), 'architectures': architectures,
        'version': version, 'sha256': digest,
    }, indent=2), encoding='utf-8')
    print(f'Release: {archive}\nSHA-256: {digest}\nLocal app: {app}', flush=True)


if __name__ == '__main__':
    main()
