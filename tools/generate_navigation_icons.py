"""Rebuild the original vector-like navigation silhouettes as WoW RGBA TGAs.

Development-only source. White masks are tinted by Theme:NavigationButton.
64px textures are supersampled for crisp 24 UI-pixel icons at 75-200% scale.
"""
from pathlib import Path
from math import cos, sin, pi
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'KIC-Games/Media/KICUI/Navigation'
OUT.mkdir(parents=True, exist_ok=True)
S = 4


def icon(name, draw_icon):
    image = Image.new('RGBA', (64*S, 64*S))
    draw = ImageDraw.Draw(image)

    def line(points, width=5):
        draw.line([(round(x*S), round(y*S)) for x, y in points],
                  fill='white', width=width*S, joint='curve')

    def ellipse(box, fill='white'):
        draw.ellipse(tuple(round(v*S) for v in box), fill=fill)

    draw_icon(line, ellipse)
    image.resize((64, 64), Image.Resampling.LANCZOS).save(OUT / f'nav-{name}.tga', compression=None)


def home(line, ellipse):
    line([(7, 29), (32, 9), (57, 29)])
    line([(15, 26), (15, 53), (27, 53), (27, 37), (37, 37), (37, 53), (49, 53), (49, 26)])


def person(line, ellipse):
    ellipse((24, 9, 40, 25))
    line([(13, 53), (13, 46), (17, 36), (25, 32), (39, 32), (47, 36), (51, 46), (51, 53), (13, 53)])


def group(line, ellipse):
    ellipse((7, 20, 19, 32))
    ellipse((45, 20, 57, 32))
    line([(4, 50), (4, 44), (7, 38), (14, 36), (20, 38)], 4)
    line([(44, 38), (50, 36), (57, 38), (60, 44), (60, 50)], 4)
    ellipse((24, 9, 40, 25))
    line([(18, 54), (18, 44), (22, 35), (28, 32), (36, 32), (42, 35), (46, 44), (46, 54), (18, 54)])


def trophy(line, ellipse):
    line([(20, 13), (44, 13), (43, 29), (39, 37), (32, 41), (25, 37), (21, 29), (20, 13)])
    line([(20, 17), (10, 17), (10, 25), (14, 32), (23, 34)], 4)
    line([(44, 17), (54, 17), (54, 25), (50, 32), (41, 34)], 4)
    line([(32, 41), (32, 52)])
    line([(20, 54), (44, 54)])


def gear(line, ellipse):
    points = []
    for tooth in range(8):
        for offset, radius in [(-.5, 21), (-.3, 21), (-.3, 27), (.3, 27), (.3, 21), (.5, 21)]:
            angle = (tooth + offset) * pi / 4
            points.append((32 + cos(angle)*radius, 32 + sin(angle)*radius))
    line(points + points[:1], 4)
    ellipse((23, 23, 41, 41))
    ellipse((28, 28, 36, 36), (0, 0, 0, 0))


for name, drawing in [('home', home), ('singleplayer', person), ('multiplayer', group), ('results', trophy), ('options', gear)]:
    icon(name, drawing)
