"""Isolate owner stone and printed faces; coordinates measured on 800px-wide EXIF-corrected references."""
from pathlib import Path
import argparse, hashlib, json, subprocess
import numpy as np
from PIL import Image, ImageOps, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'modules/stations/oktyabrskaya/art'
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
# All coordinates refer to the 800px-wide, EXIF-corrected source, and stay within one clean surface.
material('132153','column_marble.jpg',(480,716,526,780),(191,188,170))
material('132153','column_marble_alt.jpg',(365,821,401,886),(194,190,173))
material('132153','wall_marble.jpg',(54,845,116,879),(198,194,176))
material('132153','wall_marble_alt.jpg',(221,839,278,875),(192,188,171))
material('132200','plinth_granite.jpg',(640,214,718,246),(93,68,46))
material('132438','floor_red.jpg',(260,1080,440,1320),(126,105,91))
material('132523','floor_grey.jpg',(364,291,412,317),(147,142,129))
material('132523','stair_granite.jpg',(364,291,412,317),(139,137,120))
material('132200','bench_oak.jpg',(374,213,399,219),(188,154,100))
material('132409','amber_glass.jpg',(331,159,346,181),(206,144,43))
material('132153','ceiling_paint.jpg',(60,83,142,147),(216,210,190))
# End-frieze sections isolate the photographed bas-relief, without people or exit equipment.
rectify('132144','frieze_north_center.jpg',[(111,148),(677,136),(694,285),(106,286)],(2048,512))
rectify('132148','frieze_north_left.jpg',[(175,204),(295,161),(299,276),(173,286)],(768,512))
rectify('132149','frieze_north_right.jpg',[(462,98),(598,119),(633,265),(464,258)],(768,512))
rectify('132404','frieze_south_center.jpg',[(4,99),(795,111),(795,307),(4,305)],(2048,512))
rectify('132403','frieze_south_left.jpg',[(188,191),(337,157),(341,329),(180,341)],(768,512))
rectify('132354','frieze_south_right.jpg',[(200,430),(725,330),(745,640),(205,655)],(768,512))
for name in ['north_center','north_left','north_right','south_center','south_left','south_right']:
    im=Image.open(OUT/('frieze_'+name+'.jpg')).convert('RGB')
    # Relief is estimated from local tonal structure; photographed sculptural artwork remains authoritative.
    small=im.convert('L').resize((193,41),Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(.55))
    a=np.asarray(small,dtype=float);a=(a-np.asarray(small.filter(ImageFilter.GaussianBlur(2.0)),dtype=float))*1.8+128
    (OUT/('frieze_'+name+'.json')).write_text(json.dumps(dict(width=193,height=41,values=np.clip(a,0,255).astype('uint8').ravel().tolist()),separators=(',',':')))
# Preserve the actual distinctive lettering as isolated, lit gold/black letter shapes.
rectify('132315','name_ru_sample.jpg',[(120,157),(597,185),(597,224),(120,205)],(2048,160))
rectify('132336','name_be_sample.jpg',[(152,158),(641,129),(642,177),(152,201)],(2048,150))
for key in ['ru','be']:
    im=Image.open(OUT/('name_'+key+'_sample.jpg')).convert('RGB');a=np.asarray(im,dtype=float)
    # Gold and its dark bevel separate from the pale marble; transparent wall background.
    saturation=(a.max(axis=2)-a.min(axis=2))/np.maximum(a.max(axis=2),1)
    gold=(a[:,:,0]-a[:,:,2]>35)&(a[:,:,1]-a[:,:,2]>20)&(saturation>.32)
    mask=Image.fromarray(np.uint8(gold)*255).filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.MinFilter(3))
    im.putalpha(mask);im.save(OUT/('name_'+key+'.png'));(OUT/('name_'+key+'_sample.jpg')).unlink()
# Camera display isolated from the end portal; no complete photo is redistributed.
rectify('132149','platform_cctv.jpg',[(445,284),(482,290),(480,312),(444,307)],(384,216))
# Outlined diagrams and safety signs. Current station 116; transfer 216 is explicitly part of this station.
s=(ROOT/'tools/moskovskaya_photo_v60/build_art.py').read_text()
s=s[s.index('from fontTools'):s.index('# Longitudinal side-hung boards.')]
s=s.replace("OUT=ROOT/'modules/stations/moskovskaya/art'", "OUT=ROOT/'modules/stations/oktyabrskaya/art'")
s=s.replace('n==11','n==6').replace('n>11','n>6').replace('n<11','n<6');exec(s,globals())
for track in [1,2]:
    b=f'<rect width="2400" height="380" fill="{WHITE}"/>'
    b+=f'<path d="M0 0H200L0 205Z" fill="{YELLOW}"/>'+text('пуць',18,30,22,'#222')+text('путь',18,56,22,'#222')
    b+='<circle cx="53" cy="111" r="41" fill="#b82c45"/>'+centered(str(track),53,128,50)
    indices=list(range(14,6,-1)) if track==1 else list(range(6))
    count=len(indices);pitch=760/count
    for j,n in enumerate(indices):
        x=10+j*pitch
        b+=f'<path d="M{x} 326L{x+252} 14H{x+pitch+250}L{x+pitch-2} 326Z" fill="{BLUE}" stroke="{WHITE}" stroke-width="3"/>'
        b+=f'<g transform="translate({x+48} 298) rotate(-50)">'+text(be[n],0,0,16)+text(ru[n],0,23,16)+'</g>'
        b+=f'<circle cx="{x+34}" cy="329" r="20" fill="{BLUE}"/>'+centered(str(n+110),x+34,337,16)
        if n==5:b+=f'<circle cx="{x+34}" cy="354" r="17" fill="{GREEN}"/>'+centered('314',x+34,360,12)
    b+=f'<path d="M780 380L1086 0H1270L964 380Z" fill="{YELLOW}"/>'
    b+='<g transform="translate(847 306) rotate(-50)">'+text('116  КАСТРЫЧНІЦКАЯ',0,0,25,'#202023')+text('ОКТЯБРЬСКАЯ',65,33,25,'#202023')+'</g>'
    b+=f'<path d="M1255 8H2390V88H1191Z" fill="{BLUE}"/>'+centered('ВЫХАД   ВЫХОД',1820,42,32)
    b+=centered('праспект Незалежнасці   проспект Независимости',1800,78,25)
    b+=centered('Кастрычніцкая плошча   Октябрьская площадь',1760,141,29,'#222')
    entries=[('вуліца Чырвонаармейская','улица Красноармейская'),('вуліца Энгельса','улица Энгельса')]
    if track==2:entries.reverse()
    for j,lines in enumerate(entries):
        for k,line in enumerate(lines):b+=text(line,1120+j*650,222+k*46,27,'#222')
    save(f'platform_track{track}.svg',2400,380,b)
# Central transfer signs: name and line number remain readable on both approaches.
b=f'<rect width="1700" height="300" fill="{WHITE}"/><rect width="1700" height="85" fill="#b62543"/>'
b+=centered('ПЕРАХОД   ПЕРЕХОД',850,59,49)
b+='<circle cx="103" cy="188" r="70" fill="#b62543"/>'+centered('2',103,216,82)
b+=text('КУПАЛАЎСКАЯ',225,166,53,'#202128')+text('КУПАЛОВСКАЯ',225,231,53,'#202128')
b+='<path d="M1510 232V139H1470L1550 90L1630 139H1590V232Z" fill="#b62543"/>'
save('transfer.svg',1700,300,b)
# Upper escalator exit panels: destinations visible in the provided photographs.
b=f'<rect width="2400" height="380" fill="{WHITE}"/><rect width="2400" height="89" fill="{BLUE}"/><rect x="940" width="600" height="52" fill="{GREEN}"/>'+centered('ВЫХАД   ВЫХОД',1240,39,35)
b+=centered('праспект Незалежнасці    проспект Независимости',1400,79,29)
b+='<rect x="12" y="10" width="400" height="350" fill="#b52643"/>'+centered('2',212,104,68)+centered('КУПАЛАЎСКАЯ',212,185,32)+centered('КУПАЛОВСКАЯ',212,235,32)
for j,lines in enumerate([('Кастрычніцкая плошча','Октябрьская площадь'),('вуліца Чырвонаармейская','улица Красноармейская'),('вуліца Энгельса','улица Энгельса')]):
    for k,line in enumerate(lines):b+=text(line,480+j*620,198+k*51,27,'#202124')
save('exit_escalators.svg',2400,380,b)
for f in sorted(ns.photos.glob('*.jpg')):records.append(dict(reference=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),reviewed=True))
for f in sorted(ns.photos.glob('*.mp4')):
    duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=nw=1:nk=1',str(f)]))
    records.append(dict(reference=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),duration_seconds=duration,review='Whole video decoded and 0.25-second reference sequence reviewed'))
(OUT/'owner_sources.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
