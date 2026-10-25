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

def build_car():
    src=Image.open(S/'Vehicle/rear_original.png').convert('RGB')
    rgb=np.asarray(src,dtype=np.float32)/255
    regs=json.loads((S/'Vehicle/registration.json').read_text())
    alpha=mask(regs['silhouette'],blur=.22)
    for polygon in regs['cutouts']: alpha*=1-mask(polygon,blur=.20)
    body=np.maximum.reduce([mask(p,blur=1)for p in regs['paintPanels']])*alpha
    red=(rgb[...,0]>rgb[...,1]*1.35)&(rgb[...,0]>rgb[...,2]*1.35)
    body*=1-red.astype(np.float32)
    L=linear(rgb);lum=L@np.array([.2126,.7152,.0722])
    green=np.dstack([lum*.36,lum*.79,lum*.51])
    mix=body[...,None]*.87
    out=L*(1-mix)+green*mix
    lamp=np.maximum.reduce([mask(p,blur=.15)for p in regs['brakeLenses']])*alpha
    out=out*(1-lamp[...,None]*.82)

    plate=Image.open(S/'Vehicle/plate.png').convert('RGBA')
    P=np.array(plate,dtype=np.float32)/255
    M=cv2.getPerspectiveTransform(
        np.float32([[0,0],[P.shape[1]-1,0],[P.shape[1]-1,P.shape[0]-1],[0,P.shape[0]-1]]),
        np.float32(regs['plateQuad']))
    P=np.dstack([linear(P[...,:3])*P[...,3:4],P[...,3]])
    warped=cv2.warpPerspective(P,M,(676,451),flags=cv2.INTER_LINEAR)
    out=out*(1-warped[...,3:4])+warped[...,:3]

    rgba=np.dstack([srgb(np.clip(out,0,1)),alpha])
    em=np.zeros_like(rgba);em[...,0]=1;em[...,1]=.11;em[...,2]=.012;em[...,3]=lamp
    crop=tuple(regs["crop"])
    def crop_runtime(a):
        x0,y0,x1,y1=crop
        q=resize_srgb_straight(a[y0:y1,x0:x1],(992,542))
        return Image.fromarray(np.uint8(np.clip(q,0,1)*255+.5),'RGBA')
    crop_runtime(rgba).save(A/'car_body.png')
    crop_runtime(em).save(A/'brake_emission.png')
    glow=gaussian_filter(lamp,3.8);glow/=max(glow.max(),1e-6)
    em[...,3]=glow*.34;crop_runtime(em).save(A/'brake_halo.png')
    Image.fromarray(np.uint8(alpha*255)).save(S/'Vehicle/silhouette_mask.png')
    Image.fromarray(np.uint8(body*255)).save(S/'Vehicle/paint_mask.png')
    Image.fromarray(np.uint8(lamp*255)).save(S/'Vehicle/brake_mask.png')
    x,y=np.meshgrid(np.linspace(-1,1,512),np.linspace(-1,1,192))
    sh=np.exp(-(x*x*3+y*y*8))*.38
    save('contact_shadow',np.dstack([np.zeros_like(sh)]*3+[sh]))

# JAKE PERFORMANCE GLYPH SYSTEM
# The shapes are authored vector recipes, not an installed font. All digits share one stroke language.
SEGMENTS={
 'a':[(95,40),(390,40),(355,95),(115,95)],
 'g':[(85,220),(350,220),(315,275),(105,275)],
 'd':[(60,400),(325,400),(285,458),(80,458)],
 'f':[(90,65),(145,90),(115,225),(62,250)],
 'b':[(350,70),(405,55),(365,220),(315,245)],
 'e':[(62,250),(112,225),(80,410),(30,435)],
 'c':[(315,245),(365,220),(325,410),(275,435)]
}
DIGIT_SEGMENTS={
 '0':'ab cdef'.replace(' ',''),'1':'bc','2':'abged'.replace(' ',''),'3':'abgcd',
 '4':'fgbc','5':'afgcd','6':'afgecd','7':'abc','8':'abcdefg','9':'abfgcd'
}
def slant(poly,amount=.13):
    return [(x+amount*(480-y),y) for x,y in poly]
def performance_mask(glyph,scale=2):
    W,H=560*scale,480*scale
    m=Image.new('L',(W,H),0);d=ImageDraw.Draw(m)
    if glyph in DIGIT_SEGMENTS:
        for s in DIGIT_SEGMENTS[glyph]:
            d.polygon([(int(x*scale),int(y*scale)) for x,y in slant(SEGMENTS[s])],fill=255)
    elif glyph=='-':
        d.polygon([(int(x*scale),int(y*scale)) for x,y in slant(SEGMENTS['g'])],fill=255)
    else:
        # Letters share the same chamfered stroke construction.
        strokes={
          'D': ['f','e','a','b','c','d'],
          'P': ['f','e','a','b','g'],
          'N': ['f','e','b','c'],
          'R': ['f','e','a','b','g']
        }[glyph]
        for s in strokes:
            d.polygon([(int(x*scale),int(y*scale)) for x,y in slant(SEGMENTS[s])],fill=255)
        if glyph in ('N','R'):
            if glyph=='N': pts=[(115,90),(165,80),(345,405),(290,430)]
            else: pts=[(220,250),(275,235),(385,430),(325,440)]
            d.polygon([(int(x*scale),int(y*scale)) for x,y in slant(pts)],fill=255)
    # deterministic chipped brush edges
    a=np.asarray(m,dtype=np.float32)/255
    rng=np.random.default_rng(7000+ord(glyph))
    grain=gaussian_filter(rng.random(a.shape),1.2)
    scratches=gaussian_filter(rng.random(a.shape),(.7,8.0))
    texture=np.clip(.90+.18*grain-.14*(scratches>.57),.55,1)
    a=np.clip(a*texture,0,1)
    return a

def build_glyphs():
    glyphs=list('0123456789DNPR')+['-']
    atlas=np.zeros((2048,4096,4),dtype=np.float32)
    metrics={};metadata=[]
    for i,k in enumerate(glyphs):
        a=performance_mask(k,2)
        ys,xs=np.where(a>.025)
        if len(xs)==0: raise ValueError('empty glyph '+k)
        x0,x1=max(0,xs.min()-8),min(a.shape[1],xs.max()+9)
        y0,y1=max(0,ys.min()-8),min(a.shape[0],ys.max()+9)
        a=a[y0:y1,x0:x1]
        targetH=480
        targetW=max(1,round(a.shape[1]*targetH/a.shape[0]))
        a=cv2.resize(a,(targetW,targetH),interpolation=cv2.INTER_LANCZOS4)
        # ivory metal/paint treatment in sRGB authoring space; no font dependency
        yy=np.linspace(0,1,targetH)[:,None]
        shade=.92+.08*np.cos((yy-.18)*math.pi)
        rgb=np.dstack([np.ones_like(a)*.97,np.ones_like(a)*.985,np.ones_like(a)*.96])*shade[...,None]
        rgba=np.dstack([rgb*a[...,None],a])
        x=(i%4)*1024+12;y=(i//4)*512+12
        atlas[y:y+targetH,x:x+targetW]=rgba
        wid=targetW*320/480
        metrics[k]={'index':i,'uv':[x/4096,y/2048,targetW/4096,480/2048],'width':wid,'height':320,'advance':wid+8}
        metadata.append({'glyph':k,'generator':'tools/build_assets.py:performance_mask','inkBounds':[0,0,targetW,480]})
    Image.fromarray(np.uint8(np.clip(atlas,0,1)*255+.5),'RGBA').save(A/'glyph_atlas.png')
    (R/'Resources/Config/glyphs.json').write_text(json.dumps(metrics,indent=2))
    (S/'Typography/metrics.json').write_text(json.dumps(metadata,indent=2))
    bit=Image.new('RGBA',(128,96));d=ImageDraw.Draw(bit)
    d.rounded_rectangle((13,14,49,80),radius=12,outline=(130,219,166,255),width=5)
    d.line([(82,30),(95,15),(95,79)],fill=(130,219,166,255),width=5)
    d.line((84,80,108,80),fill=(130,219,166,255),width=5)
    bit.save(A/'binary_glyphs.png')

def pack():
    sprites={'car_body','brake_emission','brake_halo','contact_shadow','glyph_atlas','binary_glyphs'}
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
    build_materials();build_car();build_glyphs();pack()
    shutil.copyfile(R/'Config/scene.json',R/'Resources/Config/scene.json')
