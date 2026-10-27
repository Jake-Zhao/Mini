#!/usr/bin/env python3
"""Camera-matched single companion vehicle extracted from the approved road shot.

Source: Reference/APPROVED.png (1774 x 887). All vehicle states have the exact
same pixels except the registered tail lamps. Splash and shadow are independent,
speed-controlled layers. Never composite two different-angle photographs.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter

CROP = (1300, 480, 1725, 745)
SIZE = (1050, 655)
SILHOUETTE = [
 (1378,658),(1377,630),(1383,608),(1395,589),(1404,578),(1415,569),
 (1422,554),(1438,548),(1439,531),(1453,523),(1477,515),(1497,514),
 (1520,508),(1536,504),(1560,500),(1596,501),(1640,500),(1674,504),
 (1684,511),(1690,525),(1682,533),(1688,544),(1700,556),(1707,578),
 (1714,610),(1715,642),(1712,672),(1704,688),(1689,693),(1672,698),
 (1642,697),(1620,690),(1572,696),(1541,704),(1502,704),(1479,695),
 (1446,696),(1410,694),(1390,682),(1380,670)
]
TAIL_LIGHTS = [
 [(1530,562),(1559,562),(1566,582),(1565,608),(1537,611),(1531,601)],
 [(1687,564),(1709,579),(1714,605),(1711,618),(1699,616),(1691,604)]
]
CONTACTS = [(1399,672),(1501,697),(1701,693)]


def mask_from_polygons(polygons, sigma):
    w,h=CROP[2]-CROP[0],CROP[3]-CROP[1]
    canvas=Image.new("L",(w*3,h*3),0)
    painter=ImageDraw.Draw(canvas)
    for poly in polygons:
        painter.polygon([((x-CROP[0])*3,(y-CROP[1])*3) for x,y in poly],fill=255)
    return canvas.resize((w,h),Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(sigma))


def s2l(x):
    return np.where(x<=.04045,x/12.92,((x+.055)/1.055)**2.4)


def l2s(x):
    return np.where(x<=.0031308,x*12.92,1.055*np.maximum(x,0)**(1/2.4)-.055)


def build(reference, art):
    reference=Path(reference);art=Path(art);art.mkdir(parents=True,exist_ok=True)
    scene=Image.open(reference).convert("RGB")
    if scene.size!=(1774,887):
        raise ValueError("Approved reference must be exactly 1774x887")
    crop=scene.crop(CROP)
    w,h=crop.size
    silhouette=mask_from_polygons([SILHOUETTE],0.85)
    straight=Image.merge("RGBA",(*crop.split(),silhouette))
    master=straight.resize(SIZE,Image.Resampling.LANCZOS)
    master.save(art/"car_body.png",optimize=True)
    original=np.asarray(master).copy()
    # Brake on/off differ in lens pixels only, not view, silhouette, spoiler,
    # wheelbase, license plate or any background/wake pixels.
    raw_mask=mask_from_polygons(TAIL_LIGHTS,0.8).resize(SIZE,Image.Resampling.LANCZOS)
    lens=np.minimum(np.asarray(raw_mask,dtype=np.float32)/255,
                    original[...,3].astype(np.float32)/255)
    rgb=original[...,:3].astype(np.float32)/255
    linear=s2l(rgb)
    weight=np.clip(lens*1.3,0,1)[...,None]
    cruise=linear.copy();brake=linear.copy()
    cruise[...,0:1]*=1-.48*weight
    cruise[...,1:2]*=1-.16*weight
    cruise[...,2:3]*=1-.12*weight
    brake[...,0:1]=np.clip(brake[...,0:1]*(1+.38*weight)+.12*weight,0,1)
    brake[...,1:2]*=1-.06*weight
    brake[...,2:3]*=1-.06*weight
    def finish(light):
        pixels=original.copy()
        pixels[...,:3]=np.uint8(np.clip(l2s(np.clip(light,0,1))*255+.5,0,255))
        pixels[lens==0]=original[lens==0]
        return pixels
    off,on=finish(cruise),finish(brake)
    changed=np.any(off[...,:3]!=on[...,:3],axis=2)
    assert np.array_equal(off[...,3],on[...,3])
    assert np.any(changed) and np.all(lens[changed]>0)
    Image.fromarray(off,"RGBA").save(art/"car_cruise.png",optimize=True)
    Image.fromarray(on,"RGBA").save(art/"car_brake.png",optimize=True)
    emission=np.zeros_like(original)
    emission[...,:3]=(255,30,14)
    emission[...,3]=np.uint8(lens*255)
    Image.fromarray(emission,"RGBA").save(art/"brake_emission.png",optimize=True)
    blurred=gaussian_filter(lens,12)
    blurred=blurred/max(float(blurred.max()),1e-6)
    halo=np.zeros_like(original);halo[...,:3]=(255,35,16)
    halo[...,3]=np.uint8(np.clip(blurred*.28*255,0,255))
    Image.fromarray(halo,"RGBA").save(art/"brake_halo.png",optimize=True)
    # The water texture is taken from the same actual wet-road photo, bounded
    # by wheel/tire locations and smoothly decaying into the real road image.
    yy,xx=np.mgrid[:h,:w]
    wake=np.zeros((h,w),dtype=np.float32)
    for px,py,rx,ry,amp in [
        (CONTACTS[0][0],CONTACTS[0][1],53,18,.32),
        (CONTACTS[1][0],CONTACTS[1][1],75,17,.55),
        (CONTACTS[2][0],CONTACTS[2][1],48,13,.19)]:
        x0,y0=px-CROP[0],py-CROP[1]
        wake=np.maximum(wake,amp*np.exp(-.5*((xx-x0)/rx)**2-.5*((yy-y0-8)/ry)**2))
    wake*=np.clip((yy-170)/65,0,1)*np.clip((h-14-yy)/23,0,1)
    wakealpha=np.asarray(Image.fromarray(wake.astype(np.float32),"F").resize(SIZE,Image.Resampling.LANCZOS))
    spr=np.zeros_like(original)
    spr[...,:3]=np.asarray(crop.resize(SIZE,Image.Resampling.LANCZOS).convert("RGB"))
    spr[...,3]=np.uint8(np.clip(wakealpha*255*1.8,0,190))
    Image.fromarray(spr,"RGBA").save(art/"car_wake.png",optimize=True)
    # Footprint contact occlusion, keyed by the same wheel locations. Used
    # as a mask on the road, never as a dark overlay on the vehicle silhouette.
    sy,sx=np.indices((192,512),dtype=np.float32)
    shadow=np.zeros((192,512),dtype=np.float32)
    for u,strength in ((.233,.34),(.473,.43),(.94,.24)):
        shadow=np.maximum(shadow,strength*np.exp(
            -.5*((sx-u*512)/(512*.11))**2-.5*((sy-96)/14)**2))
    shadow=np.maximum(shadow,.12*np.exp(
        -.5*((sx-300)/(512*.36))**2-.5*((sy-96)/28)**2))
    contact=np.zeros((192,512,4),dtype=np.uint8)
    contact[...,3]=np.uint8(np.clip(shadow*255,0,255))
    Image.fromarray(contact,"RGBA").save(art/"contact_shadow.png",optimize=True)
    return dict(source="Reference/APPROVED.png",sourceCrop=list(CROP),
                sourceCanvas=list(scene.size),runtimeCanvas=list(SIZE),
                actualTireContacts=[list(v) for v in CONTACTS],
                brakeChangedPixels=int(changed.sum()),
                pose="same approved roadway camera; one master for both states")

if __name__=="__main__":
    import argparse
    cli=argparse.ArgumentParser()
    cli.add_argument("--reference",type=Path,default=Path(__file__).resolve().parents[1]/"Reference/APPROVED.png")
    cli.add_argument("--art",type=Path,default=Path(__file__).resolve().parents[1]/"Resources/Art")
    a=cli.parse_args()
    print(json.dumps(build(a.reference,a.art),ensure_ascii=False,indent=2))
