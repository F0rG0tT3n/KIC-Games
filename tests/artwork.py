"""Runtime-only artwork checks; Python standard library, no external packages."""
from pathlib import Path
import hashlib
import re
import struct

root = Path(__file__).resolve().parents[1]
addon = root / 'KIC-Games'
art = (addon / 'Artwork.lua').read_text(encoding='utf-8')
files = re.findall(r'file\s*=\s*base\s*\.\.\s*"([^"]+\.tga)"\s*,\s*width\s*=\s*(\d+)\s*,\s*height\s*=\s*(\d+)', art)
assert len(files) == 69, 'Expected 67 existing artworks and two supplied Blindshot assets'
for name, width, height in files:
    path = addon / 'Media' / 'KICUI' / name
    data = path.read_bytes()
    header = struct.unpack('<BBBHHBHHHHBB', data[:18])
    assert (header[8], header[9]) == (int(width), int(height)), f'Wrong dimensions: {name}'
    assert header[2] == 2 and header[10] in (24, 32), f'Unexpected WoW TGA encoding: {name}'
    assert all(n & (n - 1) == 0 for n in (header[8], header[9])), f'Non-power-of-two artwork: {name}'
    if name.startswith('Chess/Pieces/'):
        assert (int(width), int(height), header[10]) == (128, 128, 32), f'Wrong Chess piece format: {name}'
        alpha = data[18 + header[0] + 3:18 + header[0] + int(width) * int(height) * 4:4]
        assert min(alpha) == 0 and max(alpha) == 255, f'Chess piece transparency missing: {name}'
    if name.startswith('Chess/Squares/'):
        assert (int(width), int(height), header[10]) == (64, 64, 32), f'Wrong Chess square format: {name}'
    if name.startswith(('Navigation/', 'Icons/', 'Pieces/')):
        assert (int(width), int(height), header[10]) == (64, 64, 32), f'Wrong navigation format: {name}'
        alpha = data[18 + header[0] + 3:18 + header[0] + int(width) * int(height) * 4:4]
        assert min(alpha) == 0 and max(alpha) == 255 and any(0 < a < 255 for a in alpha), f'Missing antialiased transparency: {name}'
    supplied = root / 'Media' / 'KICUI' / name
    if supplied.exists():
        assert hashlib.sha256(data).digest() == hashlib.sha256(supplied.read_bytes()).digest(), f'Artwork changed: {name}'
assert not any('pug' in p.name for p in (addon / 'Media' / 'KICUI').iterdir()), 'Unused concept artwork copied to runtime'
assert not re.search(r'design[\\/]|references[\\/]|sources[\\/]', art), 'Runtime artwork points at design sources'
assert 'glyph =' not in art, 'Letter placeholders remain in the artwork registry'
assert {p.relative_to(addon / 'Media' / 'KICUI').as_posix() for p in (addon / 'Media' / 'KICUI').rglob('*.tga')} == {f[0] for f in files}, 'Unused runtime art or missing registry paths'
toc = (addon / 'KIC-Games.toc').read_text()
entries = [line.strip().replace('\\', '/') for line in toc.splitlines() if line.strip().endswith('.lua')]
assert all((addon / entry).is_file() for entry in entries), 'Missing TOC file'
actual_paths = {p.relative_to(addon).as_posix() for p in addon.rglob('*') if p.is_file()}
assert set(entries) <= actual_paths, 'Incorrectly cased TOC file path'
assert not (addon / 'tests').exists(), 'Development tests must stay outside the installable addon'
assert {p for p in actual_paths if p.endswith('.lua')} == set(entries), 'Unlisted runtime Lua file'
assert entries.index('Artwork.lua') < entries.index('Theme.lua') < entries.index('GameplayUI.lua') < entries.index('UI.lua') < entries.index('Launcher.lua') < entries.index('Options.lua')
print(f'PASS: {len(files)} runtime TGAs, headers, dimensions, optional source hashes, paths and TOC load order')

assert entries.index('ProfileData.lua') < entries.index('Profiles.lua') < entries.index('Settings.lua') < entries.index('Graphics.lua') < entries.index('Audio.lua') < entries.index('UI.lua')

# KIC Bejeweled uses the exact supplied artwork bytes, with left-side hero text.
import zipfile
archive = root / "KIC-Bejeweled-Assets.zip"
if archive.exists():
    with zipfile.ZipFile(archive) as z:
        for name in ("kic-bejeweled-hero.tga", "kic-bejeweled-card.tga"):
            assert (addon / "Media/KICUI" / name).read_bytes() == z.read(name)
assert re.search(r'\["kic-bejeweled-hero"\].*?textSide = "left"', art, re.S)
