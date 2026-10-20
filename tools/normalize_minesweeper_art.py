"""Encode the supplied PNGs as uncompressed, power-of-two WoW textures.

The wide hero is center-cropped to the launcher's banner shape, preserving its
title and board without stretching. Originals live outside the installable addon.
"""
from pathlib import Path
from PIL import Image, ImageOps

root = Path(__file__).resolve().parents[1]
source_folder = root / 'Media/Minesweeper'
folder = root / 'KIC-Games/Media/Minesweeper'
folder.mkdir(parents=True, exist_ok=True)
for name, size in [('minesweeper-hero', (2048, 512)), ('minesweeper-card', (256, 256))]:
    with Image.open(source_folder / (name + '.png')) as source:
        image = ImageOps.fit(source.convert('RGBA'), size, method=Image.Resampling.LANCZOS)
        image.save(folder / (name + '.tga'), format='TGA', compression=None)
    print(f'{name}: {size[0]}x{size[1]} uncompressed RGBA TGA')
