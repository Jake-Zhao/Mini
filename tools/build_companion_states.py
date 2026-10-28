#!/usr/bin/env python3
"""Two pixel-registered taillight states derived from a single car_body.png.

Only lamp pixels are allowed to differ; body, wheels, spoiler, angle,
plate, spray frame, crop, silhouette and alpha are identical.
"""
from pathlib import Path
import numpy as np
from PIL import Image

def build(art_dir):
    art=Path(art_dir)
    base=np.asarray(Image.open(art/'car_body.png').convert('RGBA'),dtype=np.uint8)
    emitter=np.asarray(Image.open(art/'brake_emission.png').convert('RGBA'),dtype=np.uint8)
    if base.shape!=emitter.shape:
        raise ValueError('brake mask not registered to exact car camera frame')
    mask=np.minimum(emitter[...,3:4].astype('float32')/255,
                    base[...,3:4].astype('float32')/255)
    if np.count_nonzero(mask>.05)<200:raise ValueError('empty tail lamp mask')
    rgb=base[...,:3].astype('float32')/255
    lin=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
    weight=np.clip(mask*1.2,0,1)
    cruise=lin.copy()
    brake=lin.copy()
    cruise[...,0:1]*=1-.34*weight
    cruise[...,1:2]*=1-.08*weight
    cruise[...,2:3]*=1-.08*weight
    brake[...,0:1]=np.clip(brake[...,0:1]*(1+.30*weight)+.14*weight,0,1)
    brake[...,1:2]*=1-.02*weight
    brake[...,2:3]*=1-.02*weight
    def to8(arr):
        a=np.clip(arr,0,1)
        srgb=np.where(a<=.0031308,12.92*a,1.055*a**(1/2.4)-.055)
        out=base.copy()
        out[...,:3]=np.uint8(np.clip(srgb*255+.5,0,255))
        out[mask[...,0]==0]=base[mask[...,0]==0]
        return out
    off,on=to8(cruise),to8(brake)
    if not np.array_equal(off[...,3],on[...,3]):
        raise ValueError('camera silhouette changed in brake variant')
    changed=np.any(off[...,:3]!=on[...,:3],axis=2)
    if np.count_nonzero(changed)<200 or np.any(changed & (mask[...,0]==0)):
        raise ValueError('non-lamp car pixels changed across brake states')
    Image.fromarray(off,'RGBA').save(art/'car_cruise.png',optimize=True)
    Image.fromarray(on,'RGBA').save(art/'car_brake.png',optimize=True)
    print('Matched companions; changed tail lamp pixels:',int(np.count_nonzero(changed)))

if __name__=='__main__':
    build(Path(__file__).resolve().parents[1]/'Resources/Art')
