#!/usr/bin/env python3
"""Produce auditable photo-registration and paired-brake contact sheet.

This is NOT an iPhone drawable capture and is labelled as an asset/pose check.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

R=Path(__file__).resolve().parents[1]
A=R/'Resources/Art'
OUT=R/'Review'
OUT.mkdir(parents=True,exist_ok=True)
reg=json.loads((R/'Source/Vehicle/runtime_registration.json').read_text())
shot=Image.open(R/'Reference/APPROVED.png').convert('RGBA')
body=Image.open(A/'car_cruise.png').convert('RGBA')
brake=Image.open(A/'car_brake.png').convert('RGBA')
wake=Image.open(A/'car_wake.png').convert('RGBA')
assert body.size==brake.size==wake.size
canvas=Image.new('RGB',(1680,1110),(15,22,22));d=ImageDraw.Draw(canvas)
try: font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',23)
except OSError:font=ImageFont.load_default()

def panel_rgba(img,x,y,w,h):
    im=img.resize((w,h),Image.Resampling.LANCZOS)
    canvas.paste(im,(x,y),im.getchannel('A'))
def checker(x,y,w,h,step=24):
    dr=ImageDraw.Draw(canvas)
    for yy in range(y,y+h,step):
        for xx in range(x,x+w,step):
            color=(29,37,39) if ((xx-x)//step+(yy-y)//step)%2 else (62,68,71)
            dr.rectangle((xx,yy,min(x+w,xx+step),min(y+h,yy+step)),fill=color)

d.text((35,18),'JAKE DRIVE — VERIFIED SINGLE-CAMERA COMPANION  |  ASSET CHECK, NOT iOS RENDER',font=font,fill=(200,230,218))
crop=shot.crop((1070,370,1774,800)).resize((790,480),Image.Resampling.LANCZOS)
canvas.paste(crop.convert('RGB'),(35,70))
x0,y0,x1,y1=reg['cropPixels']
d.rectangle((35+(x0-1070)*790/704,70+(y0-370)*480/430,
             35+(x1-1070)*790/704,70+(y1-370)*480/430),outline=(114,255,162),width=2)
for i,(x,y) in enumerate(reg['wheelContactsSource']):
    cx=int(35+(x-1070)*790/704);cy=int(70+(y-370)*480/430)
    d.ellipse((cx-6,cy-6,cx+6,cy+6),outline=(255,222,120),width=3)
    d.text((cx+9,cy-18),'tyre '+str(i+1),fill=(245,242,205))
d.text((36,556),'Approved-shot registration; green rectangle is the shared sprite frame',font=font,fill=(168,191,177))

checker(860,70,785,480)
panel_rgba(body,860,70,785,480)
for px,py in reg['wheelContactsUV']:
    cx=int(860+px*785);cy=int(70+py*480)
    d.ellipse((cx-5,cy-5,cx+5,cy+5),outline=(255,218,114),width=3)
d.text((865,556),'Exact car alpha / two photographed wheel contacts',font=font,fill=(168,191,177))

for x,label,layer in [(35,'Cruise (not braking)',body),(860,'Braking (same pose)',brake)]:
    checker(x,610,785,465)
    panel_rgba(layer,x,610,785,465)
    d.text((x+6,1080-30),label,font=font,fill=(228,242,227))
canvas.save(OUT/'companion_alignment.jpg',quality=90,subsampling=0,optimize=True)

# A separate alpha-debug for the spray to catch accidentally invisible layers.
white=Image.new('RGB',(900,600),(12,18,23))
w=wake.resize((870,550),Image.Resampling.LANCZOS)
white.paste(w,(15,15),w.getchannel('A'))
ImageDraw.Draw(white).text((22,576),'Photographed tyre spray — transparent and velocity-gated at runtime',fill=(205,235,219))
white.save(OUT/'wheel_wake_check.jpg',quality=92,optimize=True)
print('Review generated:',OUT/'companion_alignment.jpg',OUT/'wheel_wake_check.jpg')
