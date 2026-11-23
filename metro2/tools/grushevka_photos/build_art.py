from pathlib import Path
import argparse,json,hashlib,shutil
import numpy as np
from PIL import Image,ImageOps,ImageFilter
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--photos',type=Path,required=True);args=p.parse_args()
OUT=ROOT/'modules/stations/grushevka/art';OUT.mkdir(parents=True,exist_ok=True)
records=[]
def image(stem):
    f=args.photos/('20261122_'+stem+'.jpg');im=ImageOps.exif_transpose(Image.open(f)).convert('RGB');im.thumbnail((1500,1200));return f,im
def rec(stem,name,coordinates):
    f,_=image(stem);records.append(dict(source=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),asset=name,coordinates_at_preview_1500x1200=coordinates))
def mat(stem,name,rect,tint):
    _,im=image(stem);im=im.crop(rect).resize((256,256),Image.Resampling.LANCZOS)
    a=np.array(im,dtype=float)-np.array(im.filter(ImageFilter.GaussianBlur(28)),dtype=float)+np.array(tint)
    im=Image.fromarray(np.uint8(np.clip(a,0,255)))
    out=Image.new('RGB',(512,512));out.paste(im,(0,0));out.paste(ImageOps.mirror(im),(256,0));out.paste(ImageOps.flip(im),(0,256));out.paste(ImageOps.flip(ImageOps.mirror(im)),(256,256));out.save(OUT/name,quality=92);rec(stem,name,rect)
def rectify(stem,name,corners,size):
    _,im=image(stem);a=[];b=[]
    for (u,v),(x,y) in zip([(0,0),(size[0]-1,0),(size[0]-1,size[1]-1),(0,size[1]-1)],corners):
        a.extend([[u,v,1,0,0,0,-x*u,-x*v],[0,0,0,u,v,1,-y*u,-y*v]]);b.extend([x,y])
    im=im.transform(size,Image.Transform.PERSPECTIVE,np.linalg.solve(np.array(a),np.array(b)),Image.Resampling.BICUBIC);im.save(OUT/name,quality=95);rec(stem,name,corners);return im
mat('171306','floor_light.jpg',(1030,415,1250,580),(172,174,167))
mat('171306','floor_dark.jpg',(602,706,737,762),(71,76,71))
mat('171205','plinth_green.jpg',(750,574,1040,683),(57,67,57))
mat('171147','stair_granite.jpg',(95,726,960,740),(145,146,136))
mat('171147','marble.jpg',(32,134,180,310),(185,187,175))
mat('171306','seat_wood.jpg',(542,376,656,413),(172,142,99))
mat('171333(1)','service_stone.jpg',(1057,62,1136,164),(95,93,83))
name=rectify('171205','nameplate.jpg',[(590,314),(1100,291),(1102,406),(598,424)],(1280,300))
small=name.resize((257,65),Image.Resampling.LANCZOS);a=np.array(small,dtype=float)
mask=np.uint8(((a[:,:,0]-a[:,:,2]>19)&(a[:,:,0]>95)&(a[:,:,1]>60))*255)
mask=np.asarray(Image.fromarray(mask).filter(ImageFilter.GaussianBlur(.48)),dtype=float)/255
(OUT/'name_relief.json').write_text(json.dumps(dict(width=257,height=65,depth_m=.030,values=[round(float(v),3) for v in mask.flatten()]),separators=(',',':'))+'\n')
src=ROOT/'modules/stations/institut_kultury/art'
for f in ['wall_route.svg','sos.svg','no_smoking.svg','advert.jpg']:
    shutil.copy(src/f,OUT/f)
for f in sorted(args.photos.glob('*.jpg')):records.append(dict(reference=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),reviewed=True))
records.append(dict(reused_artwork='advert.jpg / vector route and safety artwork',source_module='institut_kultury',notes='Owner-derived advertisement and reusable vector system copied locally; no runtime station-module dependency.'))
(OUT/'owner_sources.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
print('Created',len(list(OUT.iterdir())),'assets')
