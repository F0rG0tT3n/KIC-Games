"""Re-encode the supplied artwork for WoW; no generation or visual replacement.

Run from any directory with Python and Pillow installed. Original inputs remain
in KIC-Blindshot-Artwork/Sources, outside the installable addon.
"""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = root / 'KIC-Blindshot-Artwork' / 'Sources'
runtime = root / 'KIC-Games' / 'Media' / 'KICUI' / 'Blindshot'
for name, size in [('blindshot-hero', (1024, 512)), ('blindshot-card', (256, 256))]:
    original = source / (name + '.tga')
    if not original.is_file():
        raise FileNotFoundError(f'Supplied original missing: {original}')
    with Image.open(original) as image:
        image.convert('RGBA').resize(size, Image.Resampling.LANCZOS).save(
            runtime / original.name, format='TGA', compression=None)
    print(f'{name}: {size[0]}x{size[1]} uncompressed RGBA TGA')
