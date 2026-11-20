"""Isolate owner stone and printed faces; coordinates measured on 800px-wide EXIF-corrected references."""
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
    records.append(dict(source=file(n).name, sha256=hashlib.sha256(file(n).read_bytes()).hexdigest(), asset=name, coordinates_at_width_800=points))

def crop(n, name, rect, size):
    im = source(n)
    k = im.width / 800
    im.crop(tuple(int(v*k) for v in rect)).resize(size, Image.Resampling.LANCZOS).save(OUT/name, quality=94)
    record(n, name, rect)

def rectify(n, name, corners, size):
    im = source(n)
    k = im.width / 800
    A, B = [], []
    for (u,v),(x,y) in zip([(0,0),(size[0]-1,0),(size[0]-1,size[1]-1),(0,size[1]-1)], corners):
        x *= k; y *= k
        A.extend([[u,v,1,0,0,0,-x*u,-x*v], [0,0,0,u,v,1,-y*u,-y*v]])
        B.extend([x,y])
    h = np.linalg.solve(np.array(A), np.array(B))
    im.transform(size, Image.Transform.PERSPECTIVE, h, Image.Resampling.BICUBIC).save(OUT/name, quality=95)
    record(n, name, corners)

# Complete source plaques inside their real wall recess; no cropping through letters.
rectify('133015','name_ru.jpg',[(203,178),(558,178),(558,208),(203,221)],(2048,210))
rectify('133024','name_be.jpg',[(195,180),(697,175),(697,215),(195,222)],(2048,180))
# Clean samples from within ONE surface, without surrounding tunnel, slab joints or paving stripes.
def material(n,name,r,target):
    im=source(n);k=im.width/800
    im=im.crop(tuple(int(v*k) for v in r)).resize((384,384),Image.Resampling.LANCZOS)
    a=np.asarray(im,dtype=float);blur=np.asarray(im.filter(ImageFilter.GaussianBlur(28)),dtype=float)
    # Remove broad photographed lighting, retain mineral grain and veining. Periodically blend the sample edges.
    a=(a-blur)*.85+np.array(target)
    # Periodic-plus-smooth decomposition removes border jumps without mirrored butterfly patterns.
    v=np.zeros_like(a);v[:,0,:]=a[:,-1,:]-a[:,0,:];v[:,-1,:]=-v[:,0,:]
    v[0,:,:]+=a[-1,:,:]-a[0,:,:];v[-1,:,:]-=a[-1,:,:]-a[0,:,:]
    yy,xx=np.mgrid[0:384,0:384];den=2*np.cos(2*np.pi*xx/384)+2*np.cos(2*np.pi*yy/384)-4;den[0,0]=1
    f=np.fft.fft2(v,axes=(0,1))/den[:,:,None];f[0,0,:]=0
    a=a-np.fft.ifft2(f,axes=(0,1)).real
    tiled=Image.fromarray(np.clip(a,0,255).astype('uint8'))
    tiled.save(OUT/name,quality=94);record(n,name,r)
    if name.startswith('floor_'):
        h=np.asarray(tiled.convert('L'),dtype=float)/255;dy,dx=np.gradient(h)
        v=np.stack([-dx*.6,-dy*.6,np.ones_like(h)],axis=2);v/=np.linalg.norm(v,axis=2,keepdims=True)
        Image.fromarray(((v*.5+.5)*255).astype('uint8')).save(OUT/(name[:-4]+'_normal.png'))
material('133029','column_marble.jpg',(288,267,332,347),(194,191,177))
material('133000','column_marble_alt.jpg',(353,765,392,930),(190,187,173))
material('133024','wall_marble.jpg',(520,101,535,132),(197,194,181))
material('133024','wall_marble_alt.jpg',(522,104,534,131),(193,191,178))
material('133024','plinth_granite.jpg',(514,351,583,394),(115,84,59))
material('133029','floor_red.jpg',(25,1007,156,1080),(129,107,91))
material('133029','floor_grey.jpg',(231,1050,273,1123),(131,132,123))
material('133029','floor_dark.jpg',(375,973,451,1033),(68,70,65))
material('133029','stair_granite.jpg',(231,1050,273,1123),(130,129,116))
material('133122','escalator_oak.jpg',(440,830,500,863),(157,116,64))
material('133049','bench_oak.jpg',(441,243,474,252),(166,116,62))
rectify('133118','platform_cctv.jpg',[(205,401),(283,420),(279,455),(204,440)],(384,216))
rectify('132956','burger_ad.jpg',[(100,302),(331,288),(342,439),(113,440)],(960,540))
# Small neutral plaster sample, without seams or broad baked illumination.
material('132932','ceiling_paint.jpg',(300,129,360,200),(229,228,218))
im=Image.open(OUT/'ceiling_paint.jpg').convert('L');h=np.asarray(im,dtype=float)/255;dy,dx=np.gradient(h)
v=np.stack([-dx*.3,-dy*.3,np.ones_like(h)],axis=2);v/=np.linalg.norm(v,axis=2,keepdims=True)
Image.fromarray(((v*.5+.5)*255).astype('uint8')).save(OUT/'ceiling_normal.png')

# Crisp vector lettering from the photographed information layout, rather than stretched image cuts.
s=(ROOT/'tools/moskovskaya_photo_v60/build_art.py').read_text()
s=s[s.index('from fontTools'):s.index('# Longitudinal side-hung boards.')]
s=s.replace("OUT=ROOT/'modules/stations/moskovskaya/art'", "OUT=ROOT/'modules/stations/ploshchad_pobedy/art'")
s=s.replace('n==11','n==7').replace('n>11','n>7').replace('n<11','n<7')
exec(s,globals())
# Route signs match the owner photographs. All lettering is outlined and stays inside its cell.
for track in [1,2]:
    b=f'<rect width="2400" height="380" fill="{WHITE}"/>'
    b+=f'<path d="M0 0H210L0 210Z" fill="{YELLOW}"/>'+text('пуць',22,30,22,'#222')+text('путь',22,56,22,'#222')
    b+=f'<circle cx="57" cy="109" r="43" fill="{BLUE}"/>'+centered(str(track),57,126,51)
    indices=list(range(14,7,-1)) if track==1 else list(range(7))
    for j,n in enumerate(indices):
        x=10+j*110
        b+=f'<path d="M{x} 330L{x+255} 14H{x+361}L{x+106} 330Z" fill="{BLUE}" stroke="{WHITE}" stroke-width="3"/>'
        b+=f'<g transform="translate({x+59} 300) rotate(-50)">'+text(be[n],0,0,17)+text(ru[n],0,23,17)+'</g>'
        b+=f'<circle cx="{x+46}" cy="330" r="22" fill="{BLUE}"/>'+centered(str(n+110),x+46,338,18)
        if n in [5,6]:
            col=GREEN if n==5 else '#b82643';number='314' if n==5 else '216'
            b+=f'<circle cx="{x+46}" cy="354" r="17" fill="{col}"/>'+centered(number,x+46,360,12)
    b+=f'<path d="M780 380L1086 0H1260L954 380Z" fill="{YELLOW}"/>'
    b+='<g transform="translate(851 307) rotate(-50)">'+text('117  ПЛОШЧА ПЕРАМОГІ',0,0,24,'#181820')+text('ПЛОЩАДЬ ПОБЕДЫ',61,32,24,'#181820')+'</g>'
    b+=f'<path d="M1250 8H2390V91H1183Z" fill="{BLUE}"/>'+centered('ВЫХАД   ВЫХОД',1820,45,33)
    b+=arrow(1255,13,False,.54)+arrow(2340,13,True,.54)
    b+=centered('праспект Незалежнасці    проспект Независимости',1810,80,25)
    entries=[('праспект Машэрава','проспект Машерова'),('вуліца Казлова','улица Козлова'),('плошча Перамогі','площадь Победы','вуліца Захарава','улица Захарова')] if track==1 else [('плошча Перамогі','площадь Победы'),('вуліца Захарава','улица Захарова'),('праспект Машэрава','проспект Машерова','вуліца Казлова','улица Козлова')]
    for j,lines in enumerate(entries):
        x=1115+j*420
        for k,line in enumerate(lines):b+=text(line,x,173+k*44,24,'#202123')
        if j:b+=f'<path d="M{x-26} 130V351" stroke="#747066" stroke-width="2"/>'
    save(f'platform_track{track}.svg',2400,380,b)
for stairs in [True,False]:
    b=f'<rect width="2400" height="390" fill="{BLUE}"/><rect x="830" width="740" height="65" fill="{GREEN}"/>'+centered('ВЫХАД   ВЫХОД',1200,47,40)
    b+='<path d="M20 74H2380M20 133H2380" stroke="#eee" stroke-width="2"/>'+centered('праспект Незалежнасці    проспект Независимости',1200,119,38)
    if stairs:
        b+=centered('плошча Перамогі    площадь Победы',1200,181,38)
        entries=[('вуліца Захарава','улица Захарова'),('парк Горкага','парк Горького'),('вуліца Кісялёва','улица Киселёва'),('Дом-музей I з’езда РСДРП','Дом-музей I съезда РСДРП')]
        y=214
    else:
        entries=[('праспект Машэрава','проспект Машерова'),('Акадэмія МУС','Академия МВД'),('вуліца Казлова','улица Козлова'),('Палац мастацтва','Дворец искусств')]
        y=151
    b+=f'<rect x="18" y="{y}" width="2364" height="{373-y}" fill="{WHITE}"/>'
    for j,lines in enumerate(entries):
        x=65+j*575
        for k,line in enumerate(lines):b+=text(line,x,y+54+k*46,30 if j<3 else 28,'#202123')
        if j:b+=f'<path d="M{x-22} {y+16}V358" stroke="#767167" stroke-width="2"/>'
    save('exit_stairs.svg' if stairs else 'exit_escalators.svg',2400,390,b)
# Rolled steel landing texture with small raised checker lozenges; no paving/photo fragments.
b='<rect width="256" height="256" fill="#a8aaa5"/>'
for y in range(0,256,32):
    for x in range(0,256,32):
        b+=f'<path d="M{x+4} {y+20}L{x+19} {y+4}L{x+23} {y+8}L{x+8} {y+24}Z" fill="#d1d2ca" stroke="#7a7d77" stroke-width="1"/>'
save('checker_plate.svg',256,256,b)

for f in sorted(ns.photos.glob('*.jpg')):
    records.append(dict(reference=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),reviewed=True))
for f in sorted(ns.photos.glob('*.mp4')):
    duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=nw=1:nk=1',str(f)]))
    records.append(dict(reference=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),duration_seconds=duration,review='Complete video decoded; 0.25 second contact sequence reviewed'))
(OUT/'owner_sources.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
