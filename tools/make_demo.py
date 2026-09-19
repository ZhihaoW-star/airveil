"""Build the illustrative launch film. macOS + Pillow + NumPy; no screen capture.

python3 tools/make_demo.py --preview   # poster and storyboard only
python3 tools/make_demo.py             # 1080p/30 fps MP4 and compact looping GIF
"""
from pathlib import Path
import math
import subprocess
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/media'
W, H, FPS, SECONDS = 1920, 1080, 30, 28
NAVY, GRAY, GREEN = '#172F3B', '#677B84', '#227B72'
FONT = '/System/Library/Fonts/Supplemental/Arial.ttf'
BOLD = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'
FONTS = {}

def text(d, xy, value, size=24, color=NAVY, bold=False, anchor=None):
    key = size, bold
    if key not in FONTS:
        FONTS[key] = ImageFont.truetype(BOLD if bold else FONT, size)
    d.text(xy, value, font=FONTS[key], fill=color, anchor=anchor)

def ease(x):
    x = max(0, min(1, x))
    return x*x*(3-2*x)

def interp(t, keys):
    for (a, x), (b, y) in zip(keys, keys[1:]):
        if a <= t <= b:
            return x+(y-x)*ease((t-a)/(b-a))
    return keys[-1][1]

def rounded_paste(target, source, xy, radius):
    mask = Image.new('L', source.size)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,source.width-1,source.height-1),radius,fill=255)
    target.paste(source, xy, mask)

def make_background():
    y, x = np.mgrid[0:H, 0:W]
    a = np.exp(-((x-1700)**2/(750**2)+(y-120)**2/(600**2)))
    b = np.exp(-((x-100)**2/(750**2)+(y-1000)**2/(480**2)))
    arr = np.empty((H,W,3),dtype=np.uint8)
    for ch, base in enumerate((247,249,250)):
        arr[:,:,ch] = np.clip(base-a*(18,8,0)[ch]-b*(12,2,8)[ch],0,255)
    im = Image.fromarray(arr)
    d = ImageDraw.Draw(im)
    # Quiet, consistent cards and monitor silhouette.
    d.rounded_rectangle((64,292,1290,906),42,fill='#E3E9EB')
    d.rounded_rectangle((72,280,1282,882),34,fill='#203540')
    d.rounded_rectangle((588,882,766,920),8,fill='#BCC9CD')
    d.rounded_rectangle((505,916,849,930),7,fill='#CBD6DA')
    d.rounded_rectangle((1340,280,1848,934),34,fill='white',outline='#E3EAEC',width=2)
    icon = Image.open(ROOT/'Source/Assets/AirVeilIcon.png').convert('RGBA').resize((66,66),Image.Resampling.LANCZOS)
    im.paste(icon,(65,42),icon)
    text(d,(147,55),'AirVeil',34,bold=True)
    text(d,(1844,68),'AIRPODS + MAC',21,GRAY,True,'ra')
    text(d,(76,1020),'Illustrative animation · Simulated screen',20,GRAY)
    text(d,(1842,1020),'macOS 14+ · Compatible AirPods required',20,GRAY,anchor='ra')
    return im

def make_screen():
    im = Image.new('RGB',(1178,570),'#EFF3F5'); d=ImageDraw.Draw(im)
    d.rectangle((0,0,1178,46),fill='#FFFFFF')
    for i,c in enumerate(('#EEA8A6','#ECD6A1','#A2CBB4')):
        d.ellipse((20+i*24,17,31+i*24,28),fill=c)
    text(d,(589,23),'Focus space',17,GRAY,anchor='mm')
    d.rounded_rectangle((26,72,250,546),18,fill='#E3EBEE')
    text(d,(51,103),'Your space',22,bold=True)
    for i,s in enumerate(('Today','Your ideas','Projects','Highlights')):
        yy=163+i*58
        if i==0: d.rounded_rectangle((40,yy-8,234,yy+36),10,fill='white')
        text(d,(60,yy),s,19,GREEN if i==0 else GRAY,i==0)
    text(d,(286,88),'Make room for great ideas.',36,bold=True)
    text(d,(286,141),'Build something you love.',20,GRAY)
    d.rounded_rectangle((283,191,1148,346),18,fill='white')
    text(d,(309,215),'Today’s inspiration',23,bold=True)
    text(d,(309,258),'Bring your next idea to life.',21,GRAY)
    text(d,(309,293),'Explore. Create. Make progress.',21,GRAY)
    for i,(label,c) in enumerate((('Ideas','#C8E9E0'),('In progress','#D6E4F5'),('A fresh start','#EAE0D1'))):
        xx=283+i*296
        d.rounded_rectangle((xx,369,xx+273,541),18,fill='white')
        d.ellipse((xx+23,393,xx+57,427),fill=c)
        text(d,(xx+23,449),label,22,bold=True)
        d.rounded_rectangle((xx+23,493,xx+211,500),3,fill='#E2E9EB')
        d.rounded_rectangle((xx+23,515,xx+154,522),3,fill='#EDF1F2')
    return im

BG = make_background()
SCREEN = make_screen()
SPRITES = Image.open(ROOT/'tools/media/character-poses.png').convert('RGBA')
POSES = [SPRITES.crop((i*512,105,(i+1)*512,885)).resize((294,448),Image.Resampling.LANCZOS) for i in range(3)]
BLURS = [SCREEN.filter(ImageFilter.GaussianBlur(i*0.5)) for i in range(65)]

def frame(t):
    angle = interp(t,[(0,0),(1,0),(2.5,-70),(3.3,-70),(4.8,0),(6,0),(7.5,70),(8.3,70),(10,0),(12,0),(13,18),(14,-18),(15.3,0),(28,0)])
    amount = ease((abs(angle)-28)/42)
    section = 0 if t<6 else 1 if t<12 else 2 if t<16 else 3 if t<21 else 4 if t<25 else 5
    titles = ['Move naturally. Enjoy more privacy.','Face your Mac. Enjoy a clear view.','Make room for natural movement.','Pick up where you left off.','Choose when to pause.','Your focus. Your space. Your control.']
    subs = ['A soft blur that grows as you turn your head.','Left or right. AirVeil follows your head motion.','Adjust your comfort zone to match how you sit.','Automatic reconnect attempts help you get back to your flow.','One click or a keyboard shortcut. You stay in control.','Powered by your AirPods. Screen images stay on your Mac.']
    status = 'Facing forward' if abs(angle)<28 else ('Looking left' if angle<0 else 'Looking right')
    detail = 'Screen is clear' if amount<.01 else 'Whole-screen blur'
    if section==2: status,detail = 'Within comfort zone','Small movements stay clear'
    if section==3:
        amount = interp(t,[(16,0),(16.5,1),(18.7,1),(19.8,0),(21,0)])
        status = 'Reconnecting…' if t<19 else 'Motion restored'
        detail = 'Retrying automatically' if t<19 else 'Protection can continue'
    if section==4:
        amount = interp(t,[(21,0),(21.5,.7),(22,.7),(22.6,0),(25,0)])
        status,detail = ('Protection on','Ready to pause') if t<22.2 else ('Paused','Screen capture stopped')
    if section==5: amount=0; status,detail='Ready when you are','Free to use at home and work'
    im = BG.copy(); d=ImageDraw.Draw(im)
    text(d,(76,140),titles[section],58,bold=True)
    text(d,(78,220),subs[section],27,GRAY)
    rounded_paste(im,BLURS[round(amount*64)],(88,296),20)
    d=ImageDraw.Draw(im)
    text(d,(1594,320),'GUIDED BY YOUR AIRPODS',18,GRAY,True,'mm')
    # Short pose crossfade illustrates orientation, not measured tracking latency.
    weight=ease((abs(angle)-30)/3)
    side=0 if angle<0 else 2
    person=Image.blend(POSES[1],POSES[side],weight)
    if section==3 and t<19:
        person=person.copy(); person.putalpha(person.getchannel('A').point(lambda a: round(a*.45)))
    im.paste(person,(1447,351),person)
    d=ImageDraw.Draw(im)
    text(d,(1594,808),status,30,GREEN,True,'mm')
    text(d,(1594,851),detail,20,GRAY,anchor='mm')
    # One contextual control, without a wall of labels.
    if section in (0,1):
        d.rounded_rectangle((1443,890,1745,896),3,fill='#E7EFF0')
        if amount>.01: d.rounded_rectangle((1443,890,1443+max(6,302*amount),896),3,fill='#62B7A9')
    elif section==2:
        text(d,(1594,897),'COMFORT ZONE   ±28°',20,GREEN,True,'mm')
    elif section==3:
        text(d,(1594,897),'Restore screen is also available',17,GRAY,anchor='mm')
    elif section==4:
        text(d,(1594,897),'Ctrl + Option + Shift + Cmd + P',17,GREEN,True,'mm')
    else:
        text(d,(1594,897),'PUBLIC BETA · SOURCE AVAILABLE',17,GREEN,True,'mm')
    if section==3:
        text(d,(681,968),'After iPhone use, reconnect AirPods in macOS Bluetooth.',21,GRAY,anchor='mm')
    elif section==4:
        text(d,(681,968),'Pause for clear screenshots and screen sharing.',21,GRAY,anchor='mm')
    elif section==5:
        text(d,(681,968),'github.com/ZhihaoW-star/airveil',26,GREEN,True,'mm')
    else:
        labels=['Whole-screen blur','Automatic clarity','Room to move','Reconnect','Quick pause','Try AirVeil']
        for j in range(6):
            xx=90+j*198
            d.rounded_rectangle((xx,960,xx+172,964),2,fill=GREEN if j==section else '#DAE3E7')
            text(d,(xx+86,984),labels[j],16,GREEN if j==section else GRAY,j==section,'mm')
    return im

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    frame(0).save(OUT/'demo-poster.png')
    times=[0,3,5,8,13,17.5,20,23,26]
    sheet=Image.new('RGB',(1440,810),'white')
    for i,t in enumerate(times): sheet.paste(frame(t).resize((480,270),Image.Resampling.LANCZOS),((i%3)*480,(i//3)*270))
    # Review contact sheet stays outside the public media directory.
    build=ROOT/'.build'; build.mkdir(exist_ok=True)
    sheet.save(build/'demo-storyboard.jpg',quality=95)
    if '--preview' in sys.argv: return
    encoder=build/'media-encode'
    subprocess.run(['clang','-fobjc-arc','-Wno-incompatible-pointer-types','-framework','Foundation','-framework','AVFoundation','-framework','CoreVideo','-framework','CoreMedia',str(ROOT/'tools/media/encode.m'),'-o',str(encoder)],check=True)
    process=subprocess.Popen([str(encoder),str(OUT/'airveil-demo-1080p.mp4'),str(W),str(H),str(FPS)],stdin=subprocess.PIPE)
    gifs=[]
    # A single palette avoids changing colors between GIF frames.
    palette=sheet.quantize(colors=160,method=Image.Quantize.MEDIANCUT)
    for i in range(FPS*SECONDS):
        im=frame(i/FPS)
        process.stdin.write(im.convert('RGBA').tobytes('raw','BGRA'))
        if i%3==0:
            gifs.append(im.resize((960,540),Image.Resampling.LANCZOS).quantize(palette=palette,dither=Image.Dither.NONE))
        if i%(FPS*4)==0: print(f'Rendered {i//FPS}/{SECONDS}s',flush=True)
    process.stdin.close()
    if process.wait()!=0: raise RuntimeError('Video encoding failed')
    gifs[0].save(OUT/'airveil-demo.gif',save_all=True,append_images=gifs[1:],duration=100,loop=0,optimize=True,disposal=1)
    print('Saved 1080p MP4, lightweight GIF, and poster.',flush=True)

if __name__=='__main__': main()
