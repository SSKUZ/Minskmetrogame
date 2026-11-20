"""Owner archive texture/relief extraction. Coordinates use a 400px-wide authoring reference."""
from pathlib import Path
import argparse,json,hashlib
import numpy as np
from PIL import Image,ImageOps,ImageFilter
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'modules/stations/yakuba_kolasa/art'
p=argparse.ArgumentParser();p.add_argument('--photos',type=Path,required=True);ns=p.parse_args();records=[]
def source(t):return ns.photos/('20261120_'+t+'.jpg')
def picture(t):return ImageOps.exif_transpose(Image.open(source(t))).convert('RGB')
def rectify(t,name,points,size):
 im=picture(t);scale=im.width/400.0;corners=[(x*scale,y*scale) for x,y in points];A=[];B=[]
 for (u,v),(x,y) in zip([(0,0),(size[0]-1,0),(size[0]-1,size[1]-1),(0,size[1]-1)],corners):
  A.extend([[u,v,1,0,0,0,-x*u,-x*v],[0,0,0,u,v,1,-y*u,-y*v]]);B.extend([x,y])
 h=np.linalg.solve(np.array(A),np.array(B));out=im.transform(size,Image.Transform.PERSPECTIVE,h,Image.Resampling.BICUBIC)
 out.save(OUT/name,quality=92);records.append(dict(source=source(t).name,asset=name,reference_width=400,source_quad=points));return out
# One distinct front-facing composition per longitudinal pair. 133955 is a closer
# duplicate of 133946, not a fourteenth column motif. 133649/133807 are adjacent faces.
MOTIFS=[
 ('133623',[(138,194),(253,198),(257,308),(143,313)]),
 ('133756',[(103,214),(233,181),(234,376),(103,378)]),
 ('133804',[(127,223),(253,190),(256,362),(128,363)]),
 ('133833',[(104,179),(250,177),(252,333),(105,334)]),
 ('133849',[(137,203),(255,193),(262,312),(142,316)]),
 ('133854',[(137,171),(294,193),(309,377),(146,378)]),
 ('133905',[(116,168),(212,166),(220,277),(117,279)]),
 ('133913',[(101,171),(212,150),(216,301),(103,303)]),
 ('133924',[(113,200),(235,179),(241,330),(114,327)]),
 ('133932',[(168,154),(273,181),(274,301),(173,304)]),
 ('133946',[(112,104),(203,101),(204,220),(113,221)]),
 ('134007',[(120,129),(247,93),(245,299),(117,297)]),
 ('134014',[(144,245),(238,247),(237,363),(146,365)]),
]
height_data={};motif_records=[]
def relief(im,name):
 # Conservative height derived from local photographic relief contrast. This is
 # reconstructed depth, not a claim that photography supplies measured 3D scans.
 g=im.convert('L');a=np.asarray(g,dtype=float)/255.;smooth=np.asarray(g.filter(ImageFilter.GaussianBlur(11)),dtype=float)/255.
 height=np.clip(.5+(a-smooth)*2.4,.04,.96)
 small=Image.fromarray((height*255).astype('uint8')).resize((41,49),Image.Resampling.LANCZOS)
 height_data[name]=[round(float(x)/255.,3) for x in np.asarray(small).flatten()]
 dy,dx=np.gradient(height);v=np.stack([-dx*4,-dy*4,np.ones_like(dx)],axis=2);v/=np.linalg.norm(v,axis=2,keepdims=True)
 Image.fromarray(((v*.5+.5)*255).astype('uint8')).quantize(colors=256,method=Image.Quantize.FASTOCTREE).save(OUT/(name+'_normal.png'))
for i,(t,quad) in enumerate(MOTIFS):
 name=f'relief_{i+1:02d}';im=rectify(t,name+'.jpg',quad,(512,576));relief(im,name)
 motif_records.append(dict(pair=i+1,source=source(t).name,front_asset=name+'.jpg',opposite_pair_same=True))
# Shared lower ornament and the short upper ornament, free from pedestrians.
im=rectify('133833','lower_ornament.jpg',[(105,334),(252,333),(257,661),(108,662)],(512,1152));relief(im,'lower_ornament')
im=rectify('133833','upper_ornament.jpg',[(104,101),(248,101),(250,178),(104,179)],(512,256));relief(im,'upper_ornament')
# All whole-surface samples avoid station names, maps and passengers.
rectify('133812','wall_marble.jpg',[(6,43),(40,43),(40,69),(6,69)],(768,512))
rectify('133815','wall_marble_alt.jpg',[(286,61),(320,63),(320,80),(286,79)],(768,512))
rectify('133812','wall_plinth.jpg',[(95,167),(220,172),(220,190),(95,185)],(768,192))
rectify('133833','base_marble.jpg',[(137,669),(239,666),(239,692),(137,693)],(512,128))
rectify('133827','floor_red.jpg',[(160,550),(182,550),(202,691),(164,691)],(512,768))
rectify('133827','floor_tan.jpg',[(97,565),(112,565),(96,692),(74,692)],(384,768))
rectify('133708','escalator_wood.jpg',[(150,24),(158,24),(148,40),(140,40)],(512,512))
rectify('134027','stair_granite.jpg',[(88,157),(181,157),(181,162),(88,162)],(768,128))
# Printed faces are isolated from stainless frames, hangers and surrounding people.
rectify('133739','platform_track1.jpg',[(23,52),(377,63),(378,100),(23,92)],(2048,300))
rectify('133735','platform_track2.jpg',[(88,84),(314,67),(315,92),(88,109)],(2048,300))
rectify('133704','exit_escalators.jpg',[(81,74),(240,56),(242,78),(83,95)],(1792,260))
rectify('134027','exit_stairs.jpg',[(105,58),(238,59),(238,77),(105,76)],(1792,260))
rectify('133628','platform_cctv.jpg',[(161,60),(177,61),(177,70),(161,69)],(384,216))
# Neutral plaster grain: remove broad photographed illumination before tiling.
im=picture('133825');s=im.width/400;im=im.crop(tuple(int(v*s) for v in (120,89,145,113))).resize((512,256),Image.Resampling.LANCZOS)
a=np.asarray(im,dtype=float);blur=np.asarray(im.filter(ImageFilter.GaussianBlur(15)),dtype=float);Image.fromarray(np.clip(231+(a-blur)*.55,0,255).astype('uint8')).save(OUT/'ceiling_paint.jpg',quality=94)
# Original outlined station route artwork. Current stop is 118.
text=(ROOT/'tools/moskovskaya_photo_v60/build_art.py').read_text();text=text[text.index('from fontTools'):text.index('# Longitudinal side-hung boards.')]
text=text.replace("OUT=ROOT/'modules/stations/moskovskaya/art'","OUT=ROOT/'modules/stations/yakuba_kolasa/art'").replace('n==11','n==8').replace('n>11','n>8').replace('n<11','n<8')
exec(text,globals())
(OUT/'relief_heights.json').write_text(json.dumps(dict(columns=41,rows=49,depths=height_data),separators=(',',':'))+'\n')
(OUT/'motif_pairs.json').write_text(json.dumps(dict(pair_count=len(MOTIFS),column_count=2*len(MOTIFS),pairs=motif_records,duplicates=['133649 adjacent face of first motif','133807 adjacent face of dance motif','133955 same harvest composition as 133946']),ensure_ascii=False,indent=2)+'\n')
(OUT/'owner_sources.json').write_text(json.dumps(dict(references=[dict(file=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest()) for f in sorted(ns.photos.glob('*.jpg'))],crops=records),ensure_ascii=False,indent=2)+'\n')
