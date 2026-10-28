#!/usr/bin/env python3
"""Deterministic source-to-runtime compiler.
No network, no installed font dependency, no AI inference, no brightness-threshold car deletion.
Source photos stay straight sRGB. Runtime sprites are linear-premultiplied float16.
"""
from pathlib import Path
import json, struct, shutil, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter
import cv2
from build_grounded_vehicle import build as build_grounded_vehicle
from build_companion_states import build as build_companion_states

R=Path(__file__).resolve().parents[1]
A=R/'Resources/Art'; S=R/'Source'
A.mkdir(parents=True,exist_ok=True)

def linear(x): return np.where(x<=.04045,x/12.92,((x+.055)/1.055)**2.4)
def srgb(x): return np.where(x<=.0031308,x*12.92,1.055*np.maximum(x,0)**(1/2.4)-.055)

def resize_srgb_straight(a,size):
    alpha=np.clip(a[...,3:4],0,1)
    pm=np.concatenate([linear(np.clip(a[...,:3],0,1))*alpha,alpha],axis=2).astype(np.float32)
    q=cv2.resize(pm,size,interpolation=cv2.INTER_LANCZOS4)
    alpha=np.clip(q[...,3:4],0,1)
    rgb=np.minimum(np.maximum(q[...,:3],0),alpha)
    rgb=np.divide(rgb,alpha,out=np.zeros_like(rgb),where=alpha>1e-6)
    return np.concatenate([srgb(rgb),alpha],axis=2)

def mask(points,wh=(676,451),blur=.45):
    m=Image.new('L',(wh[0]*4,wh[1]*4))
    d=ImageDraw.Draw(m)
    d.polygon([(int(x*4),int(y*4))for x,y in points],fill=255)
    m=m.resize(wh,Image.Resampling.LANCZOS)
    return np.asarray(m.filter(ImageFilter.GaussianBlur(blur)),dtype=np.float32)/255

def save(name,x):
    Image.fromarray(np.uint8(np.clip(x,0,1)*255+.5),'RGBA' if x.shape[-1]==4 else 'RGB').save(A/(name+'.png'))

def procedural(seed,n=1024):
    rng=np.random.default_rng(seed);base=rng.random((n,n),dtype=np.float32)
    def field(s):
        a=gaussian_filter(base,s,mode='wrap')
        return (a-a.min())/(a.max()-a.min()+1e-10)
    fine=field(.7);med=field(3.4);macro=field(33);puddle=np.clip((field(24)-.48)*3.3,0,1)
    height=(.7*fine+.3*med)*.0008
    dx=(np.roll(height,-1,1)-np.roll(height,1,1))/(2*3.0/n)
    dz=(np.roll(height,-1,0)-np.roll(height,1,0))/(2*3.0/n)
    N=np.dstack([-dx,-dz,np.ones_like(dx)]);N/=np.linalg.norm(N,axis=-1,keepdims=True)
    rough=.62+.25*med
    surface=np.dstack([N[...,:2]*.5+.5,rough,puddle])
    albedo=.025+.055*fine+.012*macro
    rgb=np.dstack([albedo*.97,albedo,albedo*.98])
    return np.dstack([srgb(rgb),np.ones_like(albedo)]),surface

def build_materials():
    road,surf=procedural(9201);save('asphalt_color',road);save('asphalt_surface',surf)
    rng=np.random.default_rng(2901);n=1024;z=rng.random((n,n))
    m=gaussian_filter(z,7,mode='wrap');m=(m-m.min())/(m.max()-m.min())
    h=gaussian_filter(z,2,mode='wrap')*.001
    dx=(np.roll(h,-1,1)-np.roll(h,1,1))/(2*1.5/n)
    dy=(np.roll(h,-1,0)-np.roll(h,1,0))/(2*1.5/n)
    N=np.dstack([-dx,-dy,np.ones((n,n))]);N/=np.linalg.norm(N,axis=-1,keepdims=True)
    gray=.08+.09*m
    wall=np.dstack([gray*.98,gray,gray*.99,np.ones_like(gray)])
    wall[...,:3]=srgb(wall[...,:3]);save('concrete_color',wall)
    save('concrete_surface',np.dstack([N[...,:2]*.5+.5,.82+.12*m,np.ones_like(m)]))
    noise=[]
    for seed in [71,19,32]:
        a=np.random.default_rng(seed).random((512,512))
        a=gaussian_filter(a,5,mode='wrap');noise.append((a-a.min())/(a.max()-a.min()))
    save('flow_noise',np.dstack(noise+[np.ones_like(noise[0])]))

# JAKE PERFORMANCE BRUSH GLYPH SYSTEM
# 7 and 2 are extracted from the approved baseline's painted strokes.
# Remaining glyphs share the same italic angle, stroke mass and distressed-paint logic.
def path_mask(g,scale=2):
    W,H=520*scale,480*scale;m=np.zeros((H,W),np.uint8);T=int(82*scale)
    def line(points,th=T): cv2.polylines(m,[np.array([(int(x*scale),int(y*scale)) for x,y in points],np.int32)],False,255,thickness=th,lineType=cv2.LINE_AA)
    def ell(center,axes,start=0,end=360,th=T): cv2.ellipse(m,(int(center[0]*scale),int(center[1]*scale)),(int(axes[0]*scale),int(axes[1]*scale)),0,start,end,255,th,lineType=cv2.LINE_AA)
    if g=='2': line([(115,120),(170,75),(320,75),(370,145),(315,225),(115,410),(370,410)])
    elif g=='7': line([(100,75),(375,75),(150,420)])
    elif g=='0': ell((255,240),(145,180))
    elif g=='1': line([(175,125),(285,58),(220,430)]);line([(145,430),(315,430)],int(58*scale))
    elif g=='3': line([(110,80),(315,65),(360,130),(255,225),(345,250),(350,350),(295,410),(90,420)])
    elif g=='4': line([(300,55),(85,285),(350,285)]);line([(300,55),(230,430)])
    elif g=='5': line([(360,70),(120,70),(95,225),(295,225),(350,275),(340,365),(285,420),(85,420)])
    elif g=='6': ell((235,315),(135,115));line([(350,80),(205,75),(105,175),(95,315)])
    elif g=='8': ell((245,145),(115,90));ell((235,340),(135,105));line([(335,205),(135,275)],int(66*scale))
    elif g=='9': ell((250,165),(135,110));line([(370,170),(340,325),(280,415),(115,420)])
    elif g=='-': line([(100,255),(360,255)],int(58*scale))
    elif g=='D': line([(105,65),(90,420)]);line([(105,70),(300,75),(365,145),(345,335),(280,410),(90,420)])
    elif g=='P': line([(105,65),(90,420)]);line([(105,75),(315,75),(365,145),(330,235),(105,240)])
    elif g=='N': line([(95,420),(120,70),(330,410),(365,65)])
    elif g=='R': line([(105,65),(90,420)]);line([(105,75),(315,75),(365,145),(330,235),(105,240)]);line([(235,240),(365,420)])
    else: raise KeyError(g)
    a=m.astype(np.float32)/255
    M=np.float32([[1,.16,-.16*H],[0,1,0]])
    return cv2.warpAffine(a,M,(W,H),flags=cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)

def distress(a,g):
    rng=np.random.default_rng(92000+ord(g));grain=gaussian_filter(rng.random(a.shape),1.0);long=gaussian_filter(rng.random(a.shape),(1.0,12.0))
    return np.clip(a*np.clip(.93+.12*(grain-.5)-.10*np.maximum(long-.62,0),.68,1.0),0,1)

def build_glyphs():
    glyphs=list('0123456789DNPR')+['-'];atlas=np.zeros((2048,4096,4),np.float32);metrics={};metadata=[]
    for i,g in enumerate(glyphs):
        a=path_mask(g)
        a=distress(a,g);ys,xs=np.where(a>.025);a=a[:,max(0,xs.min()-8):xs.max()+9]
        tw=max(1,min(900,round(a.shape[1]*480/a.shape[0])));a=cv2.resize(a,(tw,480),interpolation=cv2.INTER_LANCZOS4)
        yy=np.linspace(0,1,480)[:,None];shade=.90+.10*np.cos((yy-.18)*math.pi)
        base=np.dstack([np.ones_like(a)*.97,np.ones_like(a)*.985,np.ones_like(a)*.955])*shade[...,None]
        base[...,1]+=np.clip((yy-.55)*.055,0,.03);rgba=np.dstack([np.clip(base,0,1)*a[...,None],a])
        x=(i%4)*1024+12;y=(i//4)*512+12;atlas[y:y+480,x:x+tw]=rgba;wid=tw*320/480
        metrics[g]={'index':i,'uv':[x/4096,y/2048,tw/4096,480/2048],'width':wid,'height':320,'advance':wid+8}
        metadata.append({'glyph':g,'generator':'JAKE PERFORMANCE BRUSH PATH','inkBounds':[0,0,tw,480]})
    Image.fromarray(np.uint8(np.clip(atlas,0,1)*255+.5),'RGBA').save(A/'glyph_atlas.png')
    (R/'Resources/Config/glyphs.json').write_text(json.dumps(metrics,indent=2));(S/'Typography/metrics.json').write_text(json.dumps(metadata,indent=2))
    bit=Image.new('RGBA',(128,96));d=ImageDraw.Draw(bit);d.rounded_rectangle((13,14,49,80),radius=12,outline=(130,219,166,255),width=5);d.line([(82,30),(95,15),(95,79)],fill=(130,219,166,255),width=5);d.line((84,80,108,80),fill=(130,219,166,255),width=5);bit.save(A/'binary_glyphs.png')

def pack():
    sprites={'car_body','car_cruise','car_brake','car_wake','brake_emission','brake_halo','contact_shadow','glyph_atlas','binary_glyphs'}
    manifest=[]
    for p in sorted(A.glob('*.png')):
        name=p.stem;im=Image.open(p).convert('RGBA');a=np.array(im,dtype=np.float32)/255
        sprite=name in sprites;isdata=name.endswith('_surface')or name=='flow_noise'
        if sprite:
            a[...,:3]=linear(a[...,:3])*a[...,3:4]
            payload=a.astype('<f2').tobytes();magic=b'JTX2';enc='linear-premultiplied-f16';srg=False
        else:
            payload=np.uint8(a*255+.5).tobytes();magic=b'JTX1';enc='rgba8';srg=not isdata
        (A/(name+'.jtex')).write_bytes(magic+struct.pack('<II',*im.size)+payload)
        manifest.append({'name':name,'png':'Art/'+p.name,'runtime':'Art/'+name+'.jtex','size':list(im.size),'srgb':srg,'encoding':enc,'alpha':'linear-premultiplied'if sprite else'data'if isdata else'opaque','mipmaps':name not in {'glyph_atlas','binary_glyphs'}})
    (R/'Resources/Config/assets.json').write_text(json.dumps(manifest,indent=2))
    print('Compiled',len(manifest),'textures; runtime sprites premultiplied in linear light BEFORE filtering.')

if __name__=='__main__':
    build_materials();build_grounded_vehicle(A,R/'Reference/APPROVED.png',S/'Vehicle/runtime_registration.json');build_companion_states(A);build_glyphs();pack()
    shutil.copyfile(R/'Config/scene.json',R/'Resources/Config/scene.json')
