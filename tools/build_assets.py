#!/usr/bin/env python3
"""Offline deterministic asset compiler. No network, AI inference or color-threshold body deletion.
Source PNGs remain straight sRGB. Runtime sprite payloads are linear-premultiplied float16.
"""
from pathlib import Path
import json, struct, math, shutil, io, re, base64
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter
import cv2, cairosvg
R=Path(__file__).resolve().parents[1]; A=R/'Resources/Art'; S=R/'Source'; A.mkdir(parents=True,exist_ok=True)

def linear(x): return np.where(x<=.04045,x/12.92,((x+.055)/1.055)**2.4)
def srgb(x): return np.where(x<=.0031308,x*12.92,1.055*np.maximum(x,0)**(1/2.4)-.055)
def resize_srgb_straight(a,size):
 alpha=np.clip(a[...,3:4],0,1);pm=np.concatenate([linear(np.clip(a[...,:3],0,1))*alpha,alpha],axis=2).astype(np.float32)
 q=cv2.resize(pm,size,interpolation=cv2.INTER_LANCZOS4)
 alpha=np.clip(q[...,3:4],0,1);rgb=np.minimum(np.maximum(q[...,:3],0),alpha)
 rgb=np.divide(rgb,alpha,out=np.zeros_like(rgb),where=alpha>1e-6)
 return np.concatenate([srgb(rgb),alpha],axis=2)

def mask(points,wh=(676,451),blur=.45):
 m=Image.new('L',(wh[0]*4,wh[1]*4));d=ImageDraw.Draw(m);d.polygon([(int(x*4),int(y*4))for x,y in points],fill=255)
 m=m.resize(wh,Image.Resampling.LANCZOS)
 return np.asarray(m.filter(ImageFilter.GaussianBlur(blur)),dtype=np.float32)/255

def save(name,x): Image.fromarray(np.uint8(np.clip(x,0,1)*255+.5),'RGBA' if x.shape[-1]==4 else 'RGB').save(A/(name+'.png'))
def procedural(seed,n=1024):
 rng=np.random.default_rng(seed);base=rng.random((n,n),dtype=np.float32)
 def field(s):
  a=gaussian_filter(base,s,mode='wrap');return (a-a.min())/(a.max()-a.min()+1e-10)
 fine=field(.7);med=field(3.4);macro=field(33);puddle=np.clip((field(24)-.48)*3.3,0,1)
 height=(.7*fine+.3*med)*.0008
 dx=(np.roll(height,-1,1)-np.roll(height,1,1))/(2*3.0/n);dz=(np.roll(height,-1,0)-np.roll(height,1,0))/(2*3.0/n)
 N=np.dstack([-dx,-dz,np.ones_like(dx)]);N/=np.linalg.norm(N,axis=-1,keepdims=True)
 rough=.62+.25*med
 surface=np.dstack([N[...,:2]*.5+.5,rough,puddle])
 albedo=.025+.055*fine+.012*macro
 rgb=np.dstack([albedo*.97,albedo,albedo*.98]);rgba=np.dstack([srgb(rgb),np.ones_like(albedo)])
 return rgba,surface

def build_materials():
 road,surf=procedural(9201);save('asphalt_color',road);save('asphalt_surface',surf)
 rng=np.random.default_rng(2901);n=1024;z=rng.random((n,n));m=gaussian_filter(z,7,mode='wrap');m=(m-m.min())/(m.max()-m.min())
 h=gaussian_filter(z,2,mode='wrap')*.001
 dx=(np.roll(h,-1,1)-np.roll(h,1,1))/(2*1.5/n);dy=(np.roll(h,-1,0)-np.roll(h,1,0))/(2*1.5/n)
 N=np.dstack([-dx,-dy,np.ones((n,n))]);N/=np.linalg.norm(N,axis=-1,keepdims=True)
 gray=.08+.09*m;wall=np.dstack([gray*.98,gray,gray*.99,np.ones_like(gray)]);wall[...,:3]=srgb(wall[...,:3]);save('concrete_color',wall)
 save('concrete_surface',np.dstack([N[...,:2]*.5+.5,.82+.12*m,np.ones_like(m)]))
 noise=[]
 for seed in [71,19,32]:
  a=np.random.default_rng(seed).random((512,512));a=gaussian_filter(a,5,mode='wrap');noise.append((a-a.min())/(a.max()-a.min()))
 save('flow_noise',np.dstack(noise+[np.ones_like(noise[0])]))
 (S/'Materials/recipe.json').write_text(json.dumps({'classification':'authored procedural source, NOT a measured PBR scan','road':{'seed':9201,'tileMetres':3,'heightMaxMetres':.0008,'dryRoughness':[.62,.87],'wetCoatIOR':1.333},'wall':{'seed':2901,'tileMetres':1.5},'noiseSeeds':[71,19,32]},indent=2))

def build_car():
 src=Image.open(S/'Vehicle/rear_original.png').convert('RGB');rgb=np.asarray(src,dtype=np.float32)/255
 regs=json.loads((S/'Vehicle/registration.json').read_text())
 alpha=mask(regs['silhouette'],blur=.22)
 for polygon in regs['cutouts']: alpha*=1-mask(polygon,blur=.20)
 body=np.maximum.reduce([mask(p,blur=1)for p in regs['paintPanels']])*alpha
 red=(rgb[...,0]>rgb[...,1]*1.35)&(rgb[...,0]>rgb[...,2]*1.35)
 body*=1-red.astype(np.float32)
 L=linear(rgb);lum=L@np.array([.2126,.7152,.0722])
 green=np.dstack([lum*.36,lum*.79,lum*.51]);mix=body[...,None]*.87
 out=L*(1-mix)+green*mix
 lamp=np.maximum.reduce([mask(p,blur=.15)for p in regs['brakeLenses']])*alpha
 out=out*(1-lamp[...,None]*.82)
 plate=Image.open(S/'Vehicle/plate.png').convert('RGBA');P=np.array(plate,dtype=np.float32)/255
 M=cv2.getPerspectiveTransform(np.float32([[0,0],[P.shape[1]-1,0],[P.shape[1]-1,P.shape[0]-1],[0,P.shape[0]-1]]),np.float32(regs['plateQuad']))
 P=np.dstack([linear(P[...,:3])*P[...,3:4],P[...,3]])
 warped=cv2.warpPerspective(P,M,(676,451),flags=cv2.INTER_LINEAR)
 out=out*(1-warped[...,3:4])+warped[...,:3]
 rgba=np.dstack([srgb(np.clip(out,0,1)),alpha]);em=np.zeros_like(rgba);em[...,0]=1;em[...,1]=.11;em[...,2]=.012;em[...,3]=lamp
 crop=tuple(regs["crop"])
 def crop_to_runtime(a):
  x0,y0,x1,y1=crop
  q=resize_srgb_straight(a[y0:y1,x0:x1],(992,542))
  return Image.fromarray(np.uint8(np.clip(q,0,1)*255+.5),'RGBA')
 crop_to_runtime(rgba).save(A/'car_body.png');crop_to_runtime(em).save(A/'brake_emission.png')
 glow=gaussian_filter(lamp,3.8);glow/=max(glow.max(),1e-6);em[...,3]=glow*.34;crop_to_runtime(em).save(A/'brake_halo.png')
 Image.fromarray(np.uint8(alpha*255)).save(S/'Vehicle/silhouette_mask.png')
 Image.fromarray(np.uint8(body*255)).save(S/'Vehicle/paint_mask.png')
 Image.fromarray(np.uint8(lamp*255)).save(S/'Vehicle/brake_mask.png')
 x,y=np.meshgrid(np.linspace(-1,1,512),np.linspace(-1,1,192));sh=np.exp(-(x*x*3+y*y*8))*.38
 save('contact_shadow',np.dstack([np.zeros_like(sh)]*3+[sh]))

def build_glyphs():
 source=S/'Typography';glyphs=list('0123456789DNPR')+['-'];atlas=Image.new('RGBA',(4096,2048));metrics={};metadata=[]
 for i,k in enumerate(glyphs):
  svg=source/('glyph_'+('dash'if k=='-'else k)+'.svg')
  b=cairosvg.svg2png(url=str(svg),output_height=480)
  im=Image.open(io.BytesIO(b)).convert('RGBA');bbox=im.getchannel('A').point(lambda v:255 if v>8 else 0).getbbox();im=im.crop(bbox)
  if im.width>1000: raise ValueError('glyph overflow')
  size=(round(im.width*480/im.height),480)
  im=Image.fromarray(np.uint8(np.clip(resize_srgb_straight(np.array(im,dtype=np.float32)/255,size),0,1)*255+.5),'RGBA')
  x=(i%4)*1024+12;y=(i//4)*512+12;atlas.alpha_composite(im,(x,y))
  wid=im.width*320/480
  metrics[k]={'index':i,'uv':[x/4096,y/2048,im.width/4096,480/2048],'width':wid,'height':320,'advance':wid+8}
  metadata.append({'glyph':k,'inkBounds':[0,0,im.width,480],'source':str(svg.relative_to(R))})
 atlas.save(A/'glyph_atlas.png');(R/'Resources/Config/glyphs.json').write_text(json.dumps(metrics,indent=2))
 (S/'Typography/metrics.json').write_text(json.dumps(metadata,indent=2))
 bit=Image.new('RGBA',(128,96));d=ImageDraw.Draw(bit)
 d.rounded_rectangle((13,14,49,80),radius=12,outline=(130,219,166,255),width=5)
 d.line([(82,30),(95,15),(95,79)],fill=(130,219,166,255),width=5);d.line((84,80,108,80),fill=(130,219,166,255),width=5)
 bit.save(A/'binary_glyphs.png')

def pack():
 sprites={'car_body','brake_emission','brake_halo','contact_shadow','glyph_atlas','binary_glyphs'}
 manifest=[]
 for p in sorted(A.glob('*.png')):
  name=p.stem;im=Image.open(p).convert('RGBA');a=np.array(im,dtype=np.float32)/255
  sprite=name in sprites;isdata=name.endswith('_surface')or name=='flow_noise'
  if sprite:
   a[...,:3]=linear(a[...,:3])*a[...,3:4];payload=a.astype('<f2').tobytes();magic=b'JTX2';enc='linear-premultiplied-f16';srg=False
  else:payload=np.uint8(a*255+.5).tobytes();magic=b'JTX1';enc='rgba8';srg=not isdata
  (A/(name+'.jtex')).write_bytes(magic+struct.pack('<II',*im.size)+payload)
  manifest.append({'name':name,'png':'Art/'+p.name,'runtime':'Art/'+name+'.jtex','size':list(im.size),'srgb':srg,'encoding':enc,'alpha':'linear-premultiplied'if sprite else'data'if isdata else'opaque','mipmaps':name!='glyph_atlas'and name!='binary_glyphs'})
 (R/'Resources/Config/assets.json').write_text(json.dumps(manifest,indent=2))
 print('Compiled',len(manifest),'textures; runtime sprites premultiplied in linear light BEFORE filtering.')
if __name__=='__main__':
 build_materials();build_car();build_glyphs();pack()
 shutil.copyfile(R/"Config/scene.json",R/"Resources/Config/scene.json")
