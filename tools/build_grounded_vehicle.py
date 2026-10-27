#!/usr/bin/env python3
"""Rebuild the ONE road-registered MINI from the APPROVED shot.

The user-approved scene is the source of camera pose, body color, lamp coverage,
wheel contacts and photographed water. No separately generated second car.
This is a photographed impostor, not a physically simulated 3-D vehicle.
"""
from pathlib import Path
import json
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter

CROP = (1330, 470, 1740, 730)
RUNTIME = (1230, 780)
SILHOUETTE = [
    (1368,609),(1371,596),(1381,575),(1402,559),(1420,550),(1443,541),
    (1462,530),(1486,519),(1523,512),(1557,505),(1582,504),(1597,499),
    (1616,498),(1640,501),(1665,505),(1677,514),(1675,525),(1670,532),
    (1680,540),(1692,553),(1700,572),(1705,602),(1704,620),(1703,642),
    (1690,652),(1663,658),(1635,654),(1620,654),(1597,655),(1578,663),
    (1567,668),(1534,674),(1512,668),(1503,655),(1460,648),(1432,654),
    (1420,662),(1400,663),(1384,659),(1371,648)]
WHEEL_CONTACTS = ((1398,659),(1532,675))
BRAKE_LAMPS = ((1547,572,15,29),(1695,592,12,30))
PHOTO_SPLASH_REGIONS = ((1398,659,38,22),(1532,675,55,26),(1683,659,36,22))

def srgb_to_linear(a):
    return np.where(a<=0.04045,a/12.92,((a+0.055)/1.055)**2.4)

def linear_to_srgb(a):
    return np.where(a<=0.0031308,a*12.92,1.055*np.maximum(a,0)**(1/2.4)-0.055)

def resize_rgba_straight(a):
    alpha=np.clip(a[...,3:4],0,1)
    pm=np.concatenate([srgb_to_linear(np.clip(a[...,:3],0,1))*alpha,alpha],axis=2).astype('float32')
    small=cv2.resize(pm,RUNTIME,interpolation=cv2.INTER_LANCZOS4)
    aa=np.clip(small[...,3:4],0,1)
    rgb=np.divide(np.clip(small[...,:3],0,1),aa,out=np.zeros_like(small[...,:3]),where=aa>1e-5)
    return np.concatenate([np.clip(linear_to_srgb(rgb),0,1),aa],axis=2)

def save_rgba(a,path):
    Image.fromarray(np.uint8(np.clip(a,0,1)*255+.5),'RGBA').save(path,optimize=True)

def build(art_dir, approved_path, registration_path):
    art=Path(art_dir);art.mkdir(parents=True,exist_ok=True)
    ref=Image.open(approved_path).convert('RGB')
    if ref.size!=(1774,887):
        raise ValueError('Use the exact approved 1774x887 image to preserve lens perspective.')
    x0,y0,x1,y1=CROP
    w,h=x1-x0,y1-y0
    image=np.asarray(ref.crop(CROP),dtype='float32')/255.0
    matte=Image.new('L',(w,h),0)
    ImageDraw.Draw(matte).polygon([(x-x0,y-y0) for x,y in SILHOUETTE],fill=255)
    alpha=np.asarray(matte.filter(ImageFilter.GaussianBlur(.85)),dtype='float32')/255.0
    if not .1<alpha.mean()<.8:
        raise ValueError('Corrupt body silhouette')
    body=resize_rgba_straight(np.dstack([image,alpha]))
    save_rgba(body,art/'car_body.png')
    xx,yy=np.meshgrid(np.arange(x0,x1,dtype='float32'),np.arange(y0,y1,dtype='float32'))
    lamps=np.zeros((h,w),dtype='float32')
    for cx,cy,rx,ry in BRAKE_LAMPS:
        lamps=np.maximum(lamps,np.exp(-2.2*((xx-cx)/rx)**2-2.2*((yy-cy)/ry)**2))
    lamps=np.minimum(alpha,lamps*alpha)
    emission=np.dstack([np.ones((h,w))*.96,np.ones((h,w))*.055,np.ones((h,w))*.02,lamps])
    save_rgba(resize_rgba_straight(emission),art/'brake_emission.png')
    glow=np.clip(gaussian_filter(lamps,5.8)*.6,0,.40)
    halo=np.dstack([np.ones((h,w))*.95,np.ones((h,w))*.045,np.ones((h,w))*.015,glow])
    save_rgba(resize_rgba_straight(halo),art/'brake_halo.png')

    # Extract photographed water near *registered* tyre contacts. This is only
    # a wake/light layer, NOT a second copy of the car or a static road bitmap.
    light=image[...,0]*.2126+image[...,1]*.7152+image[...,2]*.0722
    envelope=np.zeros((h,w),dtype='float32')
    for cx,cy,rx,ry in PHOTO_SPLASH_REGIONS:
        envelope=np.maximum(envelope,np.exp(-2.1*((xx-cx)/rx)**2-2.1*((yy-cy)/ry)**2))
    a=np.clip((light-.19)*2.3,0,1)*envelope*np.clip((yy-637)/20,0,1)*1.25
    a=gaussian_filter(np.clip(a,0,.8),.4)
    wake=resize_rgba_straight(np.dstack([np.clip(image*1.28+.075,0,1),a]))
    if np.count_nonzero(wake[...,3]>.012)<1500:
        raise ValueError('Water extraction empty; no placeholder green streak is allowed.')
    save_rgba(wake,art/'car_wake.png')

    # Wheel-ground shadow is generated from the two photographed contact points.
    sw,sh=512,192
    px,py=np.meshgrid(np.linspace(0,1,sw),np.linspace(0,1,sh))
    shadow=np.zeros((sh,sw),dtype='float32')
    for (cx,cy),rx,ry in zip(WHEEL_CONTACTS,(.07,.08),(.10,.11)):
        cx=(cx-x0)/w;cy=(cy-y0)/h
        shadow=np.maximum(shadow,np.exp(-3*((px-cx)/rx)**2-3*((py-cy)/ry)**2))
    shade=np.clip(shadow*.29,0,.32)
    save_rgba(np.dstack([np.zeros_like(shade)]*3+[shade]),art/'contact_shadow.png')

    registration={
        'source':'Reference/APPROVED.png',
        'method':'same-camera photographed car silhouette and wheel-contact water extraction',
        'cropPixels':list(CROP),'runtimeSize':list(RUNTIME),
        'wheelContactsSource':[list(p) for p in WHEEL_CONTACTS],
        'wheelContactsUV':[[(p[0]-x0)/w,(p[1]-y0)/h] for p in WHEEL_CONTACTS],
        'camera':{'tanHalfVerticalFOV':.30,'eyeHeightMetres':1.22,'horizonY':.61,
                  'carPositionXMetres':5.77,'carPositionZMetres':13.0,
                  'proxyWidthMetres':3.61,'contactY':.806},
        'authenticity':'approved image based photographic impostor + speed-driven particle cues; NOT CFD/3-D wheel simulation'
    }
    Path(registration_path).write_text(json.dumps(registration,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print('Grounded companion extracted',RUNTIME,
          'active spray pixels',int(np.count_nonzero(wake[...,3]>.012)))

if __name__=='__main__':
    root=Path(__file__).resolve().parents[1]
    build(root/'Resources/Art',root/'Reference/APPROVED.png',root/'Source/Vehicle/runtime_registration.json')
