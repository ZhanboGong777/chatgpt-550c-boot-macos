#!/usr/bin/env python3
"""Create a source-only archive for a GitHub repository upload."""
import argparse
import hashlib
import os
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'dist')
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    version = (ROOT / 'VERSION').read_text(encoding='utf-8').strip()
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        parser.error('Invalid VERSION')
    archive = output / f'chatgpt-550c-boot-macos-v{version}-source.zip'
    excluded = {'.git', '.build', 'dist', '__pycache__', '.DS_Store', '__MACOSX'}
    paths = []
    for current, directories, files in os.walk(ROOT):
        directories[:] = sorted(d for d in directories if d not in excluded and not d.endswith('.app'))
        for name in sorted(files):
            path = Path(current) / name
            if name in excluded or path.suffix in {'.pyc', '.zip', '.sha256'} or path.is_symlink():
                continue
            paths.append(path)
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as stream:
        for path in paths:
            stream.write(path, (Path('chatgpt-550c-boot-macos') / path.relative_to(ROOT)).as_posix())
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / f'{archive.name}.sha256').write_text(f'{digest}  {archive.name}\n', encoding='utf-8')
    lines = [f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}' for path in sorted(output.glob('*.zip'))]
    (output / 'SHA256SUMS').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'Source archive: {archive}\nFiles: {len(paths)}\nSHA-256: {digest}')


if __name__ == '__main__':
    main()
