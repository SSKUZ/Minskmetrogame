"""Recreate only corrected Grushevka material crops from the owner's ZIP."""
from pathlib import Path
from zipfile import ZipFile
from io import BytesIO
import argparse,hashlib,json
import numpy as np
from PIL import Image,ImageOps,ImageFilter
p=argparse.ArgumentParser();p.add_argument('--archive',type=Path,required=True);args=p.parse_args()
out=Path(__file__).resolve().parents[2]/'modules/stations/grushevka/art'
records=json.loads((out/'owner_sources.json').read_text())
with ZipFile(args.archive) as z:
 for stem,asset,rect,target in [
  ('171306','floor_light.jpg',(1120,400,1300,520),(163,163,155)),
  ('171147','marble.jpg',(35,220,210,320),(192,192,181)),
  ('171147','stair_granite.jpg',(600,938,1200,950),(147,146,137))]:
  name=next(n for n in z.namelist() if n.endswith('20261122_'+stem+'.jpg'))
  raw=z.read(name);im=ImageOps.exif_transpose(Image.open(BytesIO(raw))).convert('RGB');im.thumbnail((1800,1500))
  im=im.crop(rect).resize((512,512),Image.Resampling.LANCZOS)
  grain=np.asarray(im,dtype=float)-np.asarray(im.filter(ImageFilter.GaussianBlur(26)),dtype=float)
  y,x=np.mgrid[:512,:512];weights=(np.sin(np.pi*x/512)**2*np.sin(np.pi*y/512)**2)[...,None]
  pixels=np.zeros_like(grain);total=np.zeros_like(weights)
  for dy,dx in [(0,0),(256,0),(0,256),(256,256)]:
   w=np.roll(weights,(dy,dx),(0,1));pixels+=np.roll(grain,(dy,dx),(0,1))*w;total+=w
  Image.fromarray(np.uint8(np.clip(pixels/total+np.array(target),0,255))).save(out/asset,quality=93)
  records=[r for r in records if r.get('asset')!=asset]
  records.append(dict(source=Path(name).name,sha256=hashlib.sha256(raw).hexdigest(),asset=asset,coordinates_at_preview_1800x1500=rect,treatment='Local stone grain; broad light removed; periodic overlap without mirrored photographic patterns'))
(out/'owner_sources.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
