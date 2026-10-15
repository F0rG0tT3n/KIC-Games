"""Original geometric RGBA masks, matching the existing navigation icon set."""
from pathlib import Path
from math import sin, cos, pi
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / 'KIC-Games/Media/KICUI/Icons'
OUT.mkdir(parents=True, exist_ok=True)
S = 4


def make(name, paint):
    im = Image.new('RGBA', (64*S, 64*S))
    d = ImageDraw.Draw(im)
    def line(points, width=4):
        d.line([(round(x*S), round(y*S)) for x, y in points], fill='white', width=width*S, joint='curve')
    def circle(x, y, r, fill=True):
        box = tuple(round(v*S) for v in (x-r, y-r, x+r, y+r))
        d.ellipse(box, fill='white' if fill else None, outline='white', width=4*S)
    paint(line, circle)
    im.resize((64, 64), Image.Resampling.LANCZOS).save(OUT / f'{name}.tga', compression=None)


def gem(l, c):
    l([(8, 23), (19, 11), (45, 11), (56, 23), (32, 55), (8, 23), (56, 23)])
    l([(19, 11), (24, 23), (32, 55), (40, 23), (45, 11)], 3)


def crown(l, c):
    l([(10, 46), (7, 20), (22, 31), (32, 12), (42, 31), (57, 20), (54, 46), (10, 46)])
    l([(12, 53), (52, 53)])
    for x, y in [(7, 16), (32, 8), (57, 16)]: c(x, y, 3)


def hint(l, c):
    c(32, 25, 17, False)
    l([(19, 35), (24, 43), (40, 43), (45, 35)])
    l([(24, 49), (40, 49)])
    l([(27, 56), (37, 56)])


def share(l, c):
    l([(16, 32), (46, 15)]); l([(16, 32), (46, 49)])
    for x, y in [(12, 32), (50, 12), (50, 52)]: c(x, y, 7)


def swap(l, c):
    l([(9, 20), (54, 20), (43, 9)]); l([(54, 20), (43, 31)])
    l([(55, 44), (10, 44), (21, 33)]); l([(10, 44), (21, 55)])


def clock(l, c):
    c(32, 32, 23, False); l([(32, 16), (32, 32), (43, 39)])


def infinity(l, c):
    points = [(32+25*cos(t), 32+14*sin(2*t)) for t in [i*2*pi/100 for i in range(101)]]
    l(points)


def cascade(l, c):
    for x, y in [(32, 13), (14, 42), (50, 42)]:
        l([(x, y-9), (x+8, y), (x, y+10), (x-8, y), (x, y-9)])


for name, paint in [
    ('gem', gem), ('crown', crown), ('hint', hint), ('share', share), ('swap', swap),
    ('clock', clock), ('infinity', infinity), ('cascade', cascade),
    ('pause', lambda l,c: (l([(23, 12), (23, 52)], 9), l([(41, 12), (41, 52)], 9))),
    ('back', lambda l,c: l([(29, 12), (10, 32), (29, 52), (10, 32), (55, 32)])),
    ('diamond', lambda l,c: l([(32, 6), (58, 32), (32, 58), (6, 32), (32, 6)])),
]:
    make(name, paint)
