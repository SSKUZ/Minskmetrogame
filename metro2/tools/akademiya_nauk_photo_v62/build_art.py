"""Owner-only texture samples and rectified signs; no complete photos or people redistributed."""
from pathlib import Path
import argparse,hashlib,json
import numpy as np
from PIL import Image,ImageFilter
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'modules/stations/akademiya_nauk/art'
p=argparse.ArgumentParser();p.add_argument('--photos',type=Path,required=True);ns=p.parse_args();records=[]
def file(n):return next(ns.photos.glob('*-'+str(n)+'.jpg'))
def record(n,name,region):
 s=file(n);records.append(dict(source=s.name,sha256=hashlib.sha256(s.read_bytes()).hexdigest(),asset=name,region_pixels=region))
def crop(n,name,r,size):
 Image.open(file(n)).crop(r).resize(size,Image.Resampling.LANCZOS).save(OUT/name,quality=94);record(n,name,r)
def rectify(n,name,corners,size):
 A=[];B=[]
 for (u,v),(x,y) in zip([(0,0),(size[0]-1,0),(size[0]-1,size[1]-1),(0,size[1]-1)],corners):
  A.extend([[u,v,1,0,0,0,-x*u,-x*v],[0,0,0,u,v,1,-y*u,-y*v]]);B.extend([x,y])
 h=np.linalg.solve(np.array(A),np.array(B));Image.open(file(n)).transform(size,Image.Transform.PERSPECTIVE,h,Image.Resampling.BICUBIC).save(OUT/name,quality=95);record(n,name,corners)
# Actual printed faces, clipped inside the metal cases; no structural columns baked in.
rectify(7749,'platform_track2.jpg',[(87,574),(775,578),(779,669),(85,671)],(1792,250))
rectify(7748,'platform_track1.jpg',[(123,625),(822,599),(829,708),(123,732)],(1792,280))
rectify(7762,'exit_stairs.jpg',[(505,208),(1122,198),(1125,283),(505,296)],(1792,260))
rectify(7744,'exit_escalators.jpg',[(246,520),(663,520),(665,578),(247,581)],(1792,260))
# Clean marble well away from the letters and route board.
crop(7750,'wall_marble.jpg',(390,185,600,260),(768,384))
crop(7757,'wall_marble_alt.jpg',(920,556,1160,605),(768,384))
crop(7750,'plinth_granite.jpg',(450,696,820,794),(768,256))
rectify(7766,'column_marble.jpg',[(185,642),(322,650),(320,1430),(166,1450)],(384,1536))
rectify(7766,'column_marble_alt.jpg',[(360,634),(542,615),(568,1399),(363,1431)],(384,1536))
crop(7749,'floor_grey.jpg',(410,1370,545,1510),(512,512))
crop(7746,'floor_dark.jpg',(557,1225,662,1245),(512,128))
crop(7762,'stair_granite.jpg',(1100,722,1250,735),(768,128))
rectify(7769,'platform_cctv.jpg',[(371,371),(456,378),(451,437),(370,434)],(384,216))
# The actual event poster is isolated from its hanging frame and supporting column.
rectify(7756,'student_event.jpg',[(584,318),(783,264),(815,409),(607,450)],(640,420))
# Small paint sample: remove photographed lighting, preserve only fine plaster relief.
im=Image.open(file(7767)).crop((400,210,565,280)).resize((512,256),Image.Resampling.LANCZOS).convert('RGB')
a=np.asarray(im,dtype=float);b=np.asarray(im.filter(ImageFilter.GaussianBlur(15)),dtype=float)
out=np.clip(231+(a-b)*.7,0,255).astype('uint8');Image.fromarray(out).save(OUT/'ceiling_paint.jpg',quality=95)
h=out.mean(axis=2)/255.;dy,dx=np.gradient(h);v=np.stack([-dx*2,-dy*2,np.ones_like(h)],axis=2);v/=np.linalg.norm(v,axis=2,keepdims=True);Image.fromarray(((v*.5+.5)*255).astype('uint8')).save(OUT/'ceiling_normal.png');record(7767,'ceiling_paint.jpg / ceiling_normal.png',(400,210,565,280))
# Route artwork uses outlined bilingual type, station 119 and correct directional progress.
source=(ROOT/'tools/moskovskaya_photo_v60/build_art.py').read_text();start=source.index('from fontTools');end=source.index('# Longitudinal side-hung boards.')
t=source[start:end];t=t.replace("OUT/name","OUT/name").replace('n==11','n==9').replace('n>11','n>9').replace('n<11','n<9')
t=t.replace("OUT=ROOT/'modules/stations/moskovskaya/art'", "OUT=ROOT/'modules/stations/akademiya_nauk/art'")
exec(t,globals())
# Font helper also supplies a small safety pictogram without external font dependencies.
save('escalator_warning.svg',160,180,'<rect width="160" height="180" fill="#ebc43b"/><path d="M80 13L147 123H13Z" fill="none" stroke="#21241e" stroke-width="8"/><path d="M40 105H62V85H83V65H106" fill="none" stroke="#21241e" stroke-width="7"/>'+centered('АСЦЯРОЖНА',80,153,18,'#21241e'))
for s in sorted(ns.photos.glob('*.jpg')):
 if 7744<=int(s.stem.split('-')[-1])<=7770:records.append(dict(reference=s.name,sha256=hashlib.sha256(s.read_bytes()).hexdigest(),reviewed=True))
v=ns.photos/'7761.mp4';records.append(dict(reference=v.name,sha256=hashlib.sha256(v.read_bytes()).hexdigest(),duration_seconds=2.715989,review='Full duration decoded; contact sequence at 0.25-second intervals'))
(OUT/'owner_sources.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
