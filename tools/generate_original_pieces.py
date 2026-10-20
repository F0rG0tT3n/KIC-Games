"""Original geometric arcade piece placeholders, extending the native icon set."""
from pathlib import Path
from math import cos, sin, pi
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / 'KIC-Games/Media'
GEMS = ROOT / 'Bejeweled/Pieces'
BLOCKS = ROOT / 'Tetris/Pieces'
for folder in (GEMS, BLOCKS):
    folder.mkdir(parents=True, exist_ok=True)
COLORS = [(26, 230, 255), (51, 102, 255), (255, 140, 26), (255, 230, 38),
          (51, 242, 89), (204, 77, 255), (255, 51, 77)]
for index, color in enumerate(COLORS, 1):
    image = Image.new('RGBA', (256, 256))
    draw = ImageDraw.Draw(image)
    sides = [6, 4, 8, 3, 4, 10, 5][index - 1]
    angle = -pi / 2 if index != 5 else -pi / 4
    points = [(128 + cos(angle + n * 2*pi/sides) * (95 if index != 6 or n % 2 == 0 else 62),
               128 + sin(angle + n * 2*pi/sides) * (95 if index != 6 or n % 2 == 0 else 62)) for n in range(sides)]
    draw.polygon(points, fill=tuple(round(c*.48) for c in color)+(255,))
    inner = [(128+(x-128)*.7, 128+(y-128)*.7) for x, y in points]
    for n, point in enumerate(points):
        factor = .55 + .45 * (1 - n / sides)
        draw.polygon([point, points[(n+1)%sides], inner[(n+1)%sides], inner[n]],
                     fill=tuple(round(c*factor) for c in color)+(255,))
    draw.polygon(inner, fill=color+(255,))
    draw.line(points+[points[0]], fill=(200, 240, 255, 255), width=5)
    draw.line([inner[-1], inner[0], inner[1]], fill=(255, 255, 255, 210), width=5)
    image.resize((64, 64), Image.Resampling.LANCZOS).save(GEMS/f'gem-{index}.tga', compression=None)

image = Image.new('RGBA', (256, 256))
draw = ImageDraw.Draw(image)
draw.rectangle((9, 9, 246, 246), fill=(110, 110, 110, 255), outline='white', width=5)
draw.polygon([(14,14),(241,14),(211,44),(44,44),(44,211),(14,241)],fill=(235,235,235,255))
draw.polygon([(241,14),(241,241),(14,241),(44,211),(211,211),(211,44)],fill=(70,70,70,255))
draw.rectangle((44,44,211,211),fill=(180,180,180,255))
image.resize((64,64), Image.Resampling.LANCZOS).save(BLOCKS/'block.tga', compression=None)
