"""Draw original, synthetic demo assets. No screenshots or device data.

Run: python3 -m pip install Pillow && python3 tools/make_media.py
Pillow is a development-only dependency, not part of the Mac app.
"""
from pathlib import Path
import math
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / 'docs' / 'media'
ASSETS = ROOT / 'Source' / 'Assets'

def font(size, bold=False):
    names = ([f'/System/Library/Fonts/Supplemental/Arial{" Bold" if bold else ""}.ttf',
              f'DejaVuSans{"-Bold" if bold else ""}.ttf'])
    for name in names:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default(size=size)

def text(draw, xy, value, size=18, color='#263444', bold=False, anchor=None):
    draw.text(xy, value, font=font(size, bold), fill=color, anchor=anchor)

def icon():
    im = Image.new('RGBA', (1024, 1024))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((52, 52, 972, 972), radius=208, fill='#102D39')
    # A folded V made of three soft ribbons. Original procedural artwork.
    for offset, color in [(0, '#D7FAED'), (96, '#80D9C5'), (192, '#4FA6B7')]:
        pts = []
        for i in range(201):
            x = 237 + i * 2.75
            y = 290 + offset + 200 * math.sin(i / 200 * math.pi)
            pts.append((x, y))
        d.polygon([(x,y-26) for x,y in pts]+[(x,y+26) for x,y in reversed(pts)], fill=color)
        for x, y in (pts[0], pts[-1]):
            d.ellipse((x-26, y-26, x+26, y+26), fill=color)
    ASSETS.mkdir(parents=True, exist_ok=True)
    im.save(ASSETS / 'AirVeilIcon.png')
    if sys.platform == 'darwin':
        # iconutil reads a directory of standard-size PNGs.
        import tempfile
        with tempfile.TemporaryDirectory(prefix='airveil-icon-') as temp:
            folder = Path(temp) / 'AirVeil.iconset'
            folder.mkdir()
            for size in (16, 32, 128, 256, 512):
                for scale in (1, 2):
                    suffix = '@2x' if scale == 2 else ''
                    im.resize((size*scale, size*scale), Image.Resampling.LANCZOS).save(folder / f'icon_{size}x{size}{suffix}.png')
            subprocess.run(['iconutil', '-c', 'icns', str(folder), '-o', str(ASSETS/'AirVeil.icns')], check=True)
    return im

if __name__ == '__main__':
    icon()
    from make_demo import main
    main()
