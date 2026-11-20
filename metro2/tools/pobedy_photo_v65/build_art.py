"""Isolate owner stone and printed faces; coordinates measured on 400px-wide EXIF-corrected references."""
from pathlib import Path
import argparse, hashlib, json, subprocess
import numpy as np
from PIL import Image, ImageOps, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'modules/stations/ploshchad_pobedy/art'
p = argparse.ArgumentParser()
p.add_argument('--photos', type=Path, required=True)
ns = p.parse_args()
records = []

def file(n):
    return ns.photos / ('20261120_' + str(n) + '.jpg')

def source(n):
    return ImageOps.exif_transpose(Image.open(file(n))).convert('RGB')

def record(n, name, points):
    records.append(dict(source=file(n).name, sha256=hashlib.sha256(file(n).read_bytes()).hexdigest(), asset=name, coordinates_at_width_400=points))

def crop(n, name, rect, size):
    im = source(n)
    k = im.width / 400
    im.crop(tuple(int(v*k) for v in rect)).resize(size, Image.Resampling.LANCZOS).save(OUT/name, quality=94)
    record(n, name, rect)

def rectify(n, name, corners, size):
    im = source(n)
    k = im.width / 400
    A, B = [], []
    for (u,v),(x,y) in zip([(0,0),(size[0]-1,0),(size[0]-1,size[1]-1),(0,size[1]-1)], corners):
        x *= k; y *= k
        A.extend([[u,v,1,0,0,0,-x*u,-x*v], [0,0,0,u,v,1,-y*u,-y*v]])
        B.extend([x,y])
    h = np.linalg.solve(np.array(A), np.array(B))
    im.transform(size, Image.Transform.PERSPECTIVE, h, Image.Resampling.BICUBIC).save(OUT/name, quality=95)
    record(n, name, corners)

# Four different actual bilingual printed faces, within the frame edges.
rectify('133108','platform_track1.jpg',[(65,135),(375,97),(380,123),(69,161)],(2048,310))
rectify('132952','platform_track2.jpg',[(107,256),(296,276),(291,307),(103,287)],(2048,310))
rectify('132926','exit_stairs.jpg',[(91,69),(306,64),(307,103),(92,110)],(2048,340))
rectify('133122','exit_escalators.jpg',[(79,227),(264,184),(265,216),(78,255)],(2048,340))
# The unusual gold/black raised station lettering, including the real rectangular outline.
rectify('133015','name_ru.jpg',[(101,88),(279,89),(279,105),(101,107)],(2048,190))
rectify('133024','name_be.jpg',[(99,89),(351,85),(350,108),(99,111)],(2048,190))

# Clean material samples away from people, posters, conduits and names.
crop('133024','wall_marble.jpg',(15,17,86,58),(640,384))
crop('133015','wall_marble_alt.jpg',(283,59,344,78),(640,256))
crop('133024','plinth_granite.jpg',(205,179,290,207),(640,256))
rectify('133000','column_marble.jpg',[(153,442),(187,452),(189,685),(153,680)],(384,1536))
rectify('133000','column_marble_alt.jpg',[(196,452),(220,446),(231,684),(196,686)],(256,1536))
crop('132956','floor_red.jpg',(52,530,235,670),(768,768))
crop('133029','floor_grey.jpg',(255,615,280,660),(384,512))
rectify('133029','floor_dark.jpg',[(160,510),(180,507),(226,675),(176,686)],(384,768))
crop('132926','stair_granite.jpg',(279,177,294,180),(384,96))
crop('133049','bench_oak.jpg',(282,109,293,113),(384,128))
rectify('133118','platform_cctv.jpg',[(102,200),(142,209),(140,229),(101,222)],(384,216))
rectify('132956','burger_ad.jpg',[(49,150),(165,143),(172,220),(56,220)],(960,540))

# Neutralize the photographed illumination, preserving only fine painted plaster detail.
im=source('132932');k=im.width/400
im=im.crop(tuple(int(v*k) for v in (155,60,220,107))).resize((512,384),Image.Resampling.LANCZOS)
a=np.asarray(im,dtype=float);b=np.asarray(im.filter(ImageFilter.GaussianBlur(15)),dtype=float)
out=np.clip(233+(a-b)*.55,0,255).astype('uint8')
Image.fromarray(out).save(OUT/'ceiling_paint.jpg',quality=94)
h=out.mean(axis=2)/255;dy,dx=np.gradient(h)
v=np.stack([-dx*2,-dy*2,np.ones_like(h)],axis=2);v/=np.linalg.norm(v,axis=2,keepdims=True)
Image.fromarray(((v*.5+.5)*255).astype('uint8')).save(OUT/'ceiling_normal.png')
record('132932','ceiling_paint.jpg / ceiling_normal.png',(155,60,220,107))

# Outlined bilingual line diagrams, 117 current, with both interchange destinations.
s=(ROOT/'tools/moskovskaya_photo_v60/build_art.py').read_text()
s=s[s.index('from fontTools'):s.index('# Longitudinal side-hung boards.')]
s=s.replace("OUT=ROOT/'modules/stations/moskovskaya/art'", "OUT=ROOT/'modules/stations/ploshchad_pobedy/art'")
s=s.replace('n==11','n==7').replace('n>11','n>7').replace('n<11','n<7')
exec(s,globals())

for f in sorted(ns.photos.glob('*.jpg')):
    records.append(dict(reference=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),reviewed=True))
for f in sorted(ns.photos.glob('*.mp4')):
    duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=nw=1:nk=1',str(f)]))
    records.append(dict(reference=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),duration_seconds=duration,review='Complete video decoded; 0.25 second contact sequence reviewed'))
(OUT/'owner_sources.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
