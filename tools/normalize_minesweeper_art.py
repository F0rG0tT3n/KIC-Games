"""Encode the supplied PNGs as uncompressed, power-of-two WoW textures.

The wide hero is center-cropped to the launcher's banner shape, preserving its
title and board without stretching. Original PNGs are kept beside the TGAs.
"""
from pathlib import Path
from PIL import Image, ImageOps

folder = Path(__file__).resolve().parents[1] / 'KIC-Games/Media/KICUI/Minesweeper'
for name, size in [('minesweeper-hero', (2048, 512)), ('minesweeper-card', (256, 256))]:
    with Image.open(folder / (name + '.png')) as source:
        image = ImageOps.fit(source.convert('RGBA'), size, method=Image.Resampling.LANCZOS)
        image.save(folder / (name + '.tga'), format='TGA', compression=None)
    print(f'{name}: {size[0]}x{size[1]} uncompressed RGBA TGA')
