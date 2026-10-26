#!/usr/bin/env python3
"""Generate iOS AppIcon PNGs from deterministic vector geometry; no external font."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'App/Assets.xcassets'
OUT=ASSETS/'AppIcon.appiconset'
OUT.mkdir(parents=True,exist_ok=True)
(ASSETS/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}},indent=2)+'\n')
S=1024
im=Image.new('RGB',(S,S),(2,8,6))
d=ImageDraw.Draw(im,'RGBA')
# restrained British racing green aperture, chrome accents and performance J silhouette
for radius in range(430,210,-2):
 t=(430-radius)/220
 a=int(16+14*t)
 d.ellipse((512-radius,512-radius,512+radius,512+radius),outline=(43,192,113,a),width=2)
d.ellipse((130,130,894,894),outline=(100,254,174,70),width=5)
d.ellipse((154,154,870,870),outline=(15,72,48,110),width=20)
d.polygon([(296,318),(756,318),(732,371),(453,371),(439,639),(408,713),(339,737),(272,707),(240,664),(297,623),(336,669),(382,660),(396,640),(413,371),(285,371)],fill=(235,248,240,255))
d.polygon([(645,214),(789,214),(685,281),(541,281)],fill=(80,255,157,235))
d.polygon([(677,748),(780,748),(717,785),(614,785)],fill=(31,220,112,160))
im=im.filter(ImageFilter.GaussianBlur(0.45))
targets=[
 ('icon-20@2x.png',40,'iphone','20x20','2x'),
 ('icon-20@3x.png',60,'iphone','20x20','3x'),
 ('icon-29@2x.png',58,'iphone','29x29','2x'),
 ('icon-29@3x.png',87,'iphone','29x29','3x'),
 ('icon-40@2x.png',80,'iphone','40x40','2x'),
 ('icon-40@3x.png',120,'iphone','40x40','3x'),
 ('icon-60@2x.png',120,'iphone','60x60','2x'),
 ('icon-60@3x.png',180,'iphone','60x60','3x'),
 ('icon-1024.png',1024,'ios-marketing','1024x1024','1x')
]
entries=[]
for filename,px,idiom,size,scale in targets:
 im.resize((px,px),Image.Resampling.LANCZOS).save(OUT/filename,format='PNG',optimize=True)
 entries.append({'filename':filename,'idiom':idiom,'size':size,'scale':scale})
(OUT/'Contents.json').write_text(json.dumps({'images':entries,'info':{'author':'xcode','version':1}},indent=2)+'\n')
print('AppIcon: generated',len(targets),'PNG assets')
