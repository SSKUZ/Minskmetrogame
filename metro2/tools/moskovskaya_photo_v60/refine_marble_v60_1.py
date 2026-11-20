"""Re-sample the owner's lower marble wall and a flat column face. No generated images."""
from pathlib import Path
import argparse,json,hashlib
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'modules/stations/moskovskaya/art'
p=argparse.ArgumentParser();p.add_argument('--photos',type=Path,required=True);args=p.parse_args()
records=[]
def rectify(src,name,quad,size):
 path=args.photos/src;im=Image.open(path).convert('RGB');A=[];B=[]
 dest=[(0,0),(size[0]-1,0),(size[0]-1,size[1]-1),(0,size[1]-1)]
 for (u,v),(x,y) in zip(dest,quad):A.extend([[u,v,1,0,0,0,-x*u,-x*v],[0,0,0,u,v,1,-y*u,-y*v]]);B.extend([x,y])
 h=np.linalg.solve(np.asarray(A),np.asarray(B));im.transform(size,Image.Transform.PERSPECTIVE,h,Image.Resampling.BICUBIC).save(OUT/name,quality=95)
 records.append({'asset':name,'source':src,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'quad_pixels':quad})
rectify('01-7897.jpg','owner_lower_marble.jpg',[(0,650),(1535,615),(1535,699),(0,792)],(3072,384))
# Large quiet marble field, with actual plate joints and veins; no lettering/people.
rectify('05-7869.jpg','wall_marble_v60_1.jpg',[(7,13),(558,85),(558,384),(7,421)],(1024,768))
# Preserve the tall grain of the real flat column slab, rather than stretching a 40px strip.
rectify('01-7875.jpg','column_marble_v60_1.jpg',[(250,551),(316,541),(316,700),(250,714)],(384,896))
(OUT/'marble_refinement_v60_1.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
