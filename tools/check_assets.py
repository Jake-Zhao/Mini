#!/usr/bin/env python3
"""Verify asset masters and compiled JTX payloads without Xcode or GPU."""
import argparse, hashlib, json, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MASTERS={
 'Source/Vehicle/car_master.png':('ca8006f4efe1ab3a0f40a4a72a7161eb0ef1744374dc2589756f6dc32aabc9ee',(2172,724)),
 'Source/Vehicle/rear_original.png':('0377d987c9a3c66ed1b040e5b60ed96affcc4edaf8c650303698aa1c59e723d5',(676,451)),
 'Reference/APPROVED.png':('da8498daf0c5effce4c5654e34cec7de95c4b85af62f8a7eb25af608c276deed',(1774,887))
}
NAMES={'asphalt_color','asphalt_surface','binary_glyphs','brake_emission','brake_halo','car_body','concrete_color','concrete_surface','contact_shadow','flow_noise','glyph_atlas'}
GLYPHS=set('0123456789DNPR-')
def check_sources():
 from PIL import Image
 for name,(sha,dimensions) in MASTERS.items():
  p=ROOT/name
  assert p.is_file(),f'Missing master {name} — see Source/Vehicle/README.md'
  assert hashlib.sha256(p.read_bytes()).hexdigest()==sha,f'Unexpected master contents {name}'
  with Image.open(p) as im:
   assert im.size==dimensions,f'Wrong source dimensions {name}'
   if name.endswith('car_master.png'):
    assert im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255),'No car transparency'
  print('SOURCE OK',name)
def check_runtime():
 from PIL import Image
 import numpy as np
 m=json.loads((ROOT/'Resources/Config/assets.json').read_text())
 assert {a['name'] for a in m}==NAMES,'Missing/extra texture names'
 for a in m:
  name=a['name'];p=ROOT/'Resources'/a['runtime']
  assert p.is_file(),f'Missing JTX: {p}'
  data=p.read_bytes()
  assert len(data)>=12,name
  magic,w,h=struct.unpack('<4sII',data[:12])
  assert magic in (b'JTX1',b'JTX2'),name
  assert [w,h]==a['size'],name
  assert len(data)==12+w*h*(8 if magic==b'JTX2' else 4),name
  if magic==b'JTX2':
   rgba=np.frombuffer(data,offset=12,dtype='<f2').astype('float32').reshape(h,w,4)
   assert np.isfinite(rgba).all() and rgba.min()>=-.001 and rgba.max()<=1.01,name
   assert np.all(rgba[:,:,:3]<=rgba[:,:,3:4]+.003),f'Unpremultiplied RGB: {name}'
  png=ROOT/'Resources'/a['png']
  with Image.open(png) as im: assert list(im.size)==a['size'],name
  print('RUNTIME OK',name,w,h)
 g=json.loads((ROOT/'Resources/Config/glyphs.json').read_text())
 assert set(g)==GLYPHS,'Glyph count mismatch'
 for key,v in g.items():
  u,y,w,h=v['uv']
  assert u>=0 and y>=0 and w>0 and h>0 and u+w<=1.00001 and y+h<=1.00001,key
  assert v['width']>0 and v['advance']>0,key
 print('GLYPHS OK',len(g))
if __name__=='__main__':
 parser=argparse.ArgumentParser()
 parser.add_argument('--sources-only',action='store_true')
 args=parser.parse_args()
 check_sources()
 if not args.sources_only:check_runtime()
 print('ALL CHECKS PASSED')
