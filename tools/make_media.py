"""Draw original, synthetic demo assets. No screenshots or device data.

Run: python3 -m pip install Pillow && python3 tools/make_media.py
Pillow is a development-only dependency, not part of the Mac app.
"""
from pathlib import Path
import math
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

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

def screen():
    im = Image.new('RGB', (548, 296), '#E7EDEB')
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 548, 28), fill='#F6F9F8')
    for i, c in enumerate(('#E4A19D', '#E8D29F', '#AACDB9')):
        d.ellipse((13+i*16, 10, 20+i*16, 17), fill=c)
    d.rounded_rectangle((24, 48, 524, 277), radius=12, fill='white')
    text(d, (46, 68), 'A little room to focus.', 23, bold=True)
    text(d, (46, 108), 'Notes for a calmer workday', 13, '#7C878B')
    for i, w in enumerate((246, 218, 265, 197)):
        d.rounded_rectangle((46, 148+i*22, 46+w, 154+i*22), 3, '#C6D2CE')
    for i, c in enumerate(('#89CBB4', '#A0BACC', '#D6C2AA')):
        d.ellipse((356, 146+i*30, 375, 165+i*30), fill=c)
        d.rounded_rectangle((390, 150+i*30, 478, 156+i*30), 3, '#D5DDD9')
    return im

def smooth(t):
    return t*t*(3-2*t)

def angle_at(t):
    keys = [(0,0),(1.1,0),(2.7,-76),(3.8,-76),(5.2,0),(6.4,0),(8.0,76),(9.1,76),(10.5,0),(12,0)]
    for (a,x),(b,y) in zip(keys,keys[1:]):
        if a <= t <= b:
            return x+(y-x)*smooth((t-a)/(b-a))
    return 0

def demo():
    MEDIA.mkdir(parents=True, exist_ok=True)
    source = screen()
    frames = []
    for i in range(192):
        a = angle_at(i/16)
        p = smooth(max(0,min(1,(abs(a)-28)/(78-28))))
        im = Image.new('RGB', (960,600), '#F6F8F6')
        d = ImageDraw.Draw(im)
        text(d, (56,35), 'AirVeil', 23, '#245D51', True)
        text(d, (56,85), 'Look away. Blur the screen.', 38, bold=True)
        text(d, (56,139), 'A soft privacy layer for your Mac, guided by your AirPods.', 18, '#718079')
        d.rounded_rectangle((49,202,615,516), 17, '#24342F')
        blurred = source.filter(ImageFilter.GaussianBlur(25*p)) if p > 0 else source
        im.paste(blurred,(58,211))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle((291,516,373,530), 4, '#CAD4CE')
        d.rounded_rectangle((255,528,409,535), 4, '#CAD4CE')
        # Head and shoulders: eye and nose positions move with yaw.
        cx, cy = 786, 320
        d.arc((cx-67,cy+65,cx+67,cy+154),180,360,fill='#3C6559',width=5)
        d.line((cx-22,cy+49,cx-22,cy+83), fill='#3C6559',width=4)
        d.line((cx+22,cy+49,cx+22,cy+83), fill='#3C6559',width=4)
        d.ellipse((cx-48,cy-62,cx+48,cy+57),outline='#3C6559',width=4)
        shift=31*a/76
        for ex in (-14,14):
            xx=cx+shift+ex*(1-abs(a)/145)
            d.ellipse((xx-3,cy-12,xx+3,cy-6),fill='#3C6559')
        d.line((cx+shift,cy-1,cx+shift+8*a/76,cy+13,cx+shift-2,cy+15),fill='#3C6559',width=3)
        d.arc((cx+shift-11,cy+19,cx+shift+11,cy+30),0,180,fill='#3C6559',width=2)
        for side in (-1,1):
            x=cx+side*46
            d.rounded_rectangle((x-6,cy-5,x+6,cy+18),5,fill='#71BBA3')
            d.line((x,cy+10,x,cy+33),fill='#71BBA3',width=7)
        label = 'Looking ahead' if abs(a)<28 else ('Turning left' if a<0 else 'Turning right')
        text(d,(786,235),label,18,'#45695C',True,'mm')
        status = 'Clear' if p < .001 else 'Whole-screen blur'
        text(d,(786,476),status,18,'#263444',True,'mm')
        d.rounded_rectangle((686,504,886,510),3,fill='#DCE5DF')
        if p>0:
            d.rounded_rectangle((686,504,686+max(6,200*p),510),3,fill='#70AF99')
        text(d,(56,565),'Illustration · Not a screen recording',13,'#7A8981')
        text(d,(904,565),'macOS beta',13,'#7A8981',anchor='ra')
        if i == 0: im.save(MEDIA/'demo-poster.png')
        frames.append(im.quantize(colors=128, method=Image.Quantize.MEDIANCUT))
    # GIF timing is in 10 ms units: 60/60/60/70 keeps a mean of 16 fps.
    frames[0].save(MEDIA/'airveil-demo.gif',save_all=True,append_images=frames[1:],duration=[60,60,60,70]*48,loop=0,optimize=False,disposal=2)

if __name__ == '__main__':
    icon()
    demo()
    print('Generated original icon and illustrative demo (no real screen content).')
