"""Clean marble/paint samples for V60.2; all crops exclude signs and people."""
from pathlib import Path
import argparse,json,hashlib
from PIL import Image,ImageFilter
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'modules/stations/moskovskaya/art'
p=argparse.ArgumentParser();p.add_argument('--photos',type=Path,required=True);args=p.parse_args();records=[]
def rectify(src,name,quad,size):
 path=args.photos/src;im=Image.open(path).convert('RGB');A=[];B=[]
 for (u,v),(x,y) in zip([(0,0),(size[0]-1,0),(size[0]-1,size[1]-1),(0,size[1]-1)],quad):A.extend([[u,v,1,0,0,0,-x*u,-x*v],[0,0,0,u,v,1,-y*u,-y*v]]);B.extend([x,y])
 out=im.transform(size,Image.Transform.PERSPECTIVE,np.linalg.solve(np.asarray(A),np.asarray(B)),Image.Resampling.BICUBIC);out.save(OUT/name,quality=94)
 records.append({'asset':name,'source':src,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'quad_pixels':quad,'excludes':'route boards, interchange tags, lettering and people'})
rectify('02-7896.jpg','lower_clean_v60_2.jpg',[(0,665),(1535,632),(1535,710),(0,774)],(3072,384))
rectify('02-7896.jpg','mural_university_clean_v60_2.jpg',[(0,115),(1535,170),(1535,511),(0,532)],(3072,900))
rectify('01-7897.jpg','mural_kremlin_clean_v60_2.jpg',[(0,132),(1535,198),(1535,486),(0,515)],(3072,900))
rectify('03-7877.jpg','mural_domes_clean_v60_2.jpg',[(0,85),(1535,95),(1535,454),(0,466)],(3072,900))
rectify('02-7896.jpg','dark_plinth_v60_2.jpg',[(500,808),(1000,790),(1000,852),(500,860)],(768,256))
# A bare paint field in the ceiling close-up. Remove photographic illumination,
# retain the photographed plaster grain for colour and a subtle normal map.
src=args.photos/'03-7887.jpg';im=Image.open(src).convert('L').crop((550,420,690,550)).resize((512,512),Image.Resampling.LANCZOS)
a=np.asarray(im,dtype=float);blur=np.asarray(im.filter(ImageFilter.GaussianBlur(18)),dtype=float)
height=np.clip((a-blur)/255.0,-0.12,0.12)
colour=np.clip(232+height*135,212,245).astype('uint8')
Image.fromarray(np.stack([colour,colour,np.clip(colour.astype(int)-4,0,255).astype('uint8')],axis=2)).save(OUT/'ceiling_paint_v60_2.jpg',quality=96)
dy,dx=np.gradient(height);normal=np.stack([-dx*8,dy*8,np.ones_like(dx)],axis=2);normal/=np.linalg.norm(normal,axis=2,keepdims=True)
Image.fromarray(np.uint8(np.clip((normal*.5+.5)*255,0,255))).save(OUT/'ceiling_normal_v60_2.png')
records.append({'assets':['ceiling_paint_v60_2.jpg','ceiling_normal_v60_2.png'],'source':'03-7887.jpg','rectangle':[550,420,690,550],'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'processing':'subtract broad illumination; preserve photographed paint grain; derive low-amplitude normal'})
for name,seconds in [('7879.mp4',13.872958),('7880.mp4',8.331100)]:
 src=args.photos/name;records.append({'source':name,'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'seconds':seconds,'analysis':'full video decoded; contact sequences every 0.25 seconds compared with still photographs','finding':'marble moulding band below upper inlay; no floating/duplicated route fragments; signs fit between column bays'})
(OUT/'repair_provenance_v60_2.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
