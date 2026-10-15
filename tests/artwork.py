"""Runtime-only artwork checks; Python standard library, no external packages."""
from pathlib import Path
import hashlib
import re
import struct

root = Path(__file__).resolve().parents[1]
addon = root / 'KIC-Games'
art = (addon / 'Artwork.lua').read_text(encoding='utf-8')
files = re.findall(r'file\s*=\s*base\s*\.\.\s*"([^"]+\.tga)"\s*,\s*width\s*=\s*(\d+)\s*,\s*height\s*=\s*(\d+)', art)
assert len(files) == 8, 'Expected only the eight required supplied runtime artworks'
for name, width, height in files:
    path = addon / 'Media' / 'KICUI' / name
    data = path.read_bytes()
    header = struct.unpack('<BBBHHBHHHHBB', data[:18])
    assert (header[8], header[9]) == (int(width), int(height)), f'Wrong dimensions: {name}'
    assert header[2] == 2 and header[10] in (24, 32), f'Unexpected WoW TGA encoding: {name}'
    assert all(n & (n - 1) == 0 for n in (header[8], header[9])), f'Non-power-of-two artwork: {name}'
    supplied = root / 'Media' / 'KICUI' / name
    if supplied.exists():
        assert hashlib.sha256(data).digest() == hashlib.sha256(supplied.read_bytes()).digest(), f'Artwork changed: {name}'
assert not any('pug' in p.name for p in (addon / 'Media' / 'KICUI').iterdir()), 'Unused concept artwork copied to runtime'
assert not re.search(r'design[\\/]|references[\\/]|sources[\\/]', art), 'Runtime artwork points at design sources'
toc = (addon / 'KIC-Games.toc').read_text()
entries = [line.strip().replace('\\', '/') for line in toc.splitlines() if line.strip().endswith('.lua')]
assert all((addon / entry).is_file() for entry in entries), 'Missing TOC file'
assert entries.index('Artwork.lua') < entries.index('Theme.lua') < entries.index('UI.lua') < entries.index('Launcher.lua') < entries.index('Options.lua')
print(f'PASS: {len(files)} runtime TGAs, headers, dimensions, optional source hashes, paths and TOC load order')
