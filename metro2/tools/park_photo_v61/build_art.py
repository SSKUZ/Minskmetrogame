"""Deterministic sign reconstruction and texture sampling from the owner's photos.
Usage: python build_art.py --photos /path/to/upload
Fonts are outlined so Godot's SVG importer does not depend on installed fonts.
"""
from pathlib import Path
import argparse, hashlib, json, math
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'modules/stations/park_chelyuskintsev/art'
OUT.mkdir(parents=True,exist_ok=True)
font=TTFont('/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf')
glyphs=font.getGlyphSet(); cmap=font.getBestCmap(); upem=font['head'].unitsPerEm
BLUE='#292369'; WHITE='#f4f1df'; YELLOW='#efb629'; GREEN='#078b58'
def text(s,x,y,size,fill=WHITE):
 b=''; scale=size/upem
 for c in s:
  n=cmap.get(ord(c),'space'); p=SVGPathPen(glyphs);glyphs[n].draw(p)
  b+=f'<path transform="translate({x:.3f} {y}) scale({scale:.6f} {-scale:.6f})" d="{p.getCommands()}" fill="{fill}"/>'
  x+=glyphs[n].width*scale
 return b
def width(s,size):return sum(glyphs[cmap.get(ord(c),'space')].width*size/upem for c in s)
def centered(s,x,y,size,fill=WHITE):return text(s,x-width(s,size)/2,y,size,fill)
def save(name,w,h,b):
 (OUT/name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{b}</svg>')
def arrow(x,y,right=True,scale=1):
 return f'<g transform="translate({x} {y}) scale({scale})"><rect width="76" height="66" fill="{GREEN}"/><path d="M14 10L36 33L14 56H30L52 33L30 10Z M34 10L56 33L34 56H48L70 33L48 10Z" fill="{YELLOW}" transform="{str() if right else "translate(76 0) scale(-1 1)"}"/></g>'
be=['МАЛІНАЎКА','ПЯТРОЎШЧЫНА','МІХАЛОВА','ГРУШАЎКА','ІНСТЫТУТ КУЛЬТУРЫ','ПЛОШЧА ЛЕНІНА','КАСТРЫЧНІЦКАЯ','ПЛОШЧА ПЕРАМОГІ','ПЛОШЧА ЯКУБА КОЛАСА','АКАДЭМІЯ НАВУК','ПАРК ЧАЛЮСКІНЦАЎ','МАСКОЎСКАЯ','УСХОД','БАРЫСАЎСКІ ТРАКТ','УРУЧЧА']
ru=['МАЛИНОВКА','ПЕТРОВЩИНА','МИХАЛОВО','ГРУШЕВКА','ИНСТИТУТ КУЛЬТУРЫ','ПЛОЩАДЬ ЛЕНИНА','ОКТЯБРЬСКАЯ','ПЛОЩАДЬ ПОБЕДЫ','ПЛОЩАДЬ ЯКУБА КОЛАСА','АКАДЕМИЯ НАУК','ПАРК ЧЕЛЮСКИНЦЕВ','МОСКОВСКАЯ','ВОСТОК','БОРИСОВСКИЙ ТРАКТ','УРУЧЬЕ']
# The two route wall panels carry different progress colours and station 120.
for reverse in [False,True]:
 indices=list(range(14,-1,-1)) if reverse else list(range(15));b='<path d="M10 292L252 7H2225L1983 292Z" fill="#c4c5bd" stroke="#888c87" stroke-width="4"/>'
 for i,n in enumerate(indices):
  x=20+i*130;col=YELLOW if n==10 else BLUE if (n>10 if reverse else n<10) else '#77777f';fg='#191d29' if n==10 else WHITE
  b+=f'<path d="M{x} 270L{x+225} 15H{x+352}L{x+127} 270Z" fill="{col}" stroke="{WHITE}" stroke-width="2"/>'
  b+=f'<g transform="translate({x+61} 244) rotate(-49)">'+text(be[n],0,0,20,fg)+text(ru[n],0,25,20,fg)+'</g>'
  b+=f'<circle cx="{x+40}" cy="273" r="19" fill="{BLUE}"/>'+centered(str(n+110),x+40,280,17)
  if n in [5,6]:
   green=n==5;col=GREEN if green else '#b82643';num='3' if green else '2'
   b+=f'<path d="M{x+40} 287V327" stroke="{col}" stroke-width="5"/><circle cx="{x+40}" cy="330" r="21" fill="{col}"/>'+centered(num,x+40,339,26)
   lx=x+68 if green else x-156
   b+=text('ВАКЗАЛЬНАЯ' if green else 'КУПАЛАЎСКАЯ',lx,320,14,col)+text('ВОКЗАЛЬНАЯ' if green else 'КУПАЛОВСКАЯ',lx,338,14,col)
 save('route_track2_v61.svg' if reverse else 'route_track1_v61.svg',2235,354,b)
for track in [1,2]:
 b=f'<rect width="510" height="1510" fill="{WHITE}"/>'
 b+=text('пуць',230,45,18,'#27282d')+text('путь',230,66,18,'#27282d')
 b+=f'<circle cx="320" cy="44" r="34" fill="{BLUE}"/>'+centered(str(track),320,58,38)
 b+=f'<path d="M367 17L394 44L367 71H391L418 44L391 17Z" fill="{YELLOW}"/><path d="M397 17L424 44L397 71H415L442 44L415 17Z" fill="{BLUE}"/>'
 indices=list(range(14,-1,-1)) if track==1 else list(range(15))
 for i,n in enumerate(indices):
  y=93+i*84;current=n==10;col=YELLOW if current else BLUE;fg='#151b24' if current else WHITE
  b+=f'<rect x="22" y="{y}" width="466" height="82" fill="{col}"/>'
  size=min(25,355/max(1,width(be[n],1)))
  b+=text(be[n],85,y+33,size,fg)+text(ru[n],85,y+64,min(25,355/max(1,width(ru[n],1))),fg)
  b+=f'<circle cx="52" cy="{y+41}" r="27" fill="{BLUE}" stroke="{WHITE}" stroke-width="2"/>'+centered(str(n+110),52,y+47,20)
  if n in [5,6]:
   col=GREEN if n==5 else '#b82643'
   b+=f'<circle cx="52" cy="{y+58}" r="17" fill="{col}"/>'+centered('314' if n==5 else '216',52,y+64,15)
 bottom=2 if track==1 else 1
 b+=f'<path d="M67 1400L39 1429L67 1458H87L59 1429L87 1400Z" fill="{BLUE}"/><path d="M96 1400L68 1429L96 1458H113L85 1429L113 1400Z" fill="{YELLOW}"/><circle cx="157" cy="1429" r="34" fill="{BLUE}"/>'+centered(str(bottom),157,1443,38)+text('пуць',204,1425,18,'#27282d')+text('путь',204,1448,18,'#27282d')
 save(f'pylon_track{track}_v61.svg',510,1510,b)

# Two narrow faces of each four-sided pylon, transcribed from 7822 / 7824.
tolbukhin=[('вуліца Талбухіна','улица Толбухина'),('парк Чалюскінцаў','парк Челюскинцев'),('Мінскі гадзіннікавы завод','Минский часовой завод'),('Дзіцячая чыгунка','Детская железная дорога')]
kalinin=[('вуліца Калініна','улица Калинина'),('САК «Алімпійскі»','СОК «Олимпийский»'),('завулак Кузьмы Чорнага','переулок Кузьмы Чорного'),('парк Чалюскінцаў','парк Челюскинцев'),('Цэнтральны батанічны сад','Центральный ботанический сад')]
for reverse in [False,True]:
 b=f'<rect width="610" height="1510" fill="{WHITE}"/><rect x="14" y="16" width="582" height="98" fill="{GREEN}"/>'+centered('ВЫХАД   ВЫХОД',305,80,42)
 b+=f'<rect x="14" y="114" width="582" height="122" fill="{BLUE}"/>'+centered('праспект Незалежнасці',305,163,31)+centered('проспект Независимости',305,208,31)
 groups=[kalinin,tolbukhin] if reverse else [tolbukhin,kalinin]
 for section,rows in enumerate(groups):
  y0=270+section*605
  b+=arrow(32 if section==0 else 487,y0,section==1,0.95)
  for i,(a,c) in enumerate(rows):
   y=y0+48+i*(105 if len(rows)==5 else 132)
   b+=centered(a,315,y,min(30,540/max(1,width(a,1))),'#17191a')+centered(c,315,y+39,min(29,540/max(1,width(c,1))),'#17191a')
  if section==0:b+='<path d="M36 845H574" stroke="#544e40" stroke-width="2"/>'
 save('pylon_exit_b_v61.svg' if reverse else 'pylon_exit_a_v61.svg',610,1510,b)

# The two lintel boards differ; both refer to Independence Avenue.
for north in [True,False]:
 b=f'<rect width="1800" height="260" fill="{BLUE}"/><rect x="620" y="0" width="560" height="55" fill="{GREEN}"/>'+centered('ВЫХАД   ВЫХОД',900,41,37)
 b+='<path d="M20 62H1780" stroke="#eee9dd" stroke-width="2"/>'+centered('праспект Незалежнасці   проспект Независимости',900,101,35)+f'<rect x="22" y="116" width="1756" height="127" fill="{WHITE}"/>'
 if north:
  groups=[(80,[('парк Чалюскінцаў','парк Челюскинцев'),('Цэнтральны батанічны сад','Центральный ботанический сад')]),(540,[('САК «Алімпійскі»','СОК «Олимпийский»')]),(1000,[('вуліца Калініна','улица Калинина'),('завулак Кузьмы Чорнага','переулок Кузьмы Чорного')]),(1460,[('плошча Калініна','площадь Калинина')])]
 else:
  groups=[(95,[('вуліца Талбухіна','улица Толбухина')]),(510,[('Мінскі гадзіннікавы завод','Минский часовой завод')]),(1050,[('парк Чалюскінцаў','парк Челюскинцев')]),(1425,[('Дзіцячая чыгунка','Детская железная дорога')])]
 for x,rows in groups:
  for j,(a,c) in enumerate(rows):
   y=149+j*57;b+=text(a,x,y,min(24,400/max(1,width(a,1))),'#202125')+text(c,x,y+27,min(24,400/max(1,width(c,1))),'#202125')
 save('exit_north_v61.svg' if north else 'exit_south_v61.svg',1800,260,b)

save('pylon_voltage_v61.svg',140,100,'<rect width="140" height="100" fill="#c6c1a8"/>'+centered('220В',70,28,27,'#a12d25')+'<path d="M70 39L99 91H41Z" fill="#e3c025" stroke="#252622" stroke-width="3"/><path d="M73 48L61 70H71L67 83L82 62H71Z" fill="#262922"/>')

# Only non-person material fragments are distributed; original frames stay private.
args=argparse.ArgumentParser();args.add_argument('--photos',type=Path,required=True);ns=args.parse_args()
from PIL import Image
import numpy as np
records=[]
def sample(src,name,rect,size=(512,512),mirror=True):
 p=ns.photos/src;im=np.asarray(Image.open(p).convert('RGB').crop(rect))
 if mirror:
  im=np.concatenate([im,im[:,::-1]],axis=1);im=np.concatenate([im,im[::-1]],axis=0)
 Image.fromarray(im).resize(size,Image.Resampling.LANCZOS).save(OUT/name,quality=95)
 records.append({'source':src,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'asset':name,'source_rectangle_pixels':rect,'mirrored_seamless_edges':mirror})
def rectify(src,name,corners,size,cutout=False):
 p=ns.photos/src;im=Image.open(p).convert('RGB');dest=[(0,0),(size[0]-1,0),(size[0]-1,size[1]-1),(0,size[1]-1)];A=[];B=[]
 for (u,v),(x,y) in zip(dest,corners):A.extend([[u,v,1,0,0,0,-x*u,-x*v],[0,0,0,u,v,1,-y*u,-y*v]]);B.extend([x,y])
 h=np.linalg.solve(np.array(A),np.array(B));out=im.transform(size,Image.Transform.PERSPECTIVE,h,Image.Resampling.BICUBIC)
 if cutout:
  rgb=np.asarray(out).astype(float)/255.;# Dark bronze and the attached dots survive; neutral plaster is removed.
  warm=rgb[:,:,0]-rgb[:,:,2];dark=1-rgb.mean(axis=2)
  alpha=np.clip((warm-.055)*22,0,1)*np.clip((dark-.26)*15,0,1)
  out.putalpha(Image.fromarray((alpha*255).astype('uint8')))
 out.save(OUT/name,**({'quality':95} if name.endswith('.jpg') else {}))
 records.append({'source':src,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'asset':name,'source_quad_pixels':corners,'plaster_removed':cutout})
sample('07-7808.jpg','floor_aggregate.jpg',(600,390,850,550))
sample('09-7810.jpg','floor_rose.jpg',(628,578,805,776))
sample('09-7819.jpg','wall_dark_granite.jpg',(770,590,885,650))
sample('10-7820.jpg','vault_plaster.jpg',(640,220,855,300))
sample('04-7805.jpg','stair_side_marble.jpg',(947,447,993,489))
sample('04-7805.jpg','stair_tread.jpg',(510,621,780,628))
sample('06-7807.jpg','chandelier_glass.jpg',(468,180,1006,684),(1024,1024),False)
rectify('06-7826.jpg','side_glass.jpg',[(594,280),(681,316),(549,551),(465,512)],(160,768))
rectify('06-7816.jpg','bronze_name_be.png',[(450,342),(1076,339),(1076,406),(450,408)],(1800,190),True)
rectify('10-7820.jpg','bronze_name_ru.png',[(363,344),(940,344),(940,398),(363,398)],(1800,168),True)
video=ns.photos/'7801.mp4';records.append({'source':'7801.mp4','sha256':hashlib.sha256(video.read_bytes()).hexdigest(),'duration_seconds':3.0323,'reviewed_frames':'full sequence sampled every 0.5 seconds','role':'vault, lighting, pylon and floor spatial arrangement'})
records.append({'reviewed_photographs':[p.name for p in sorted(ns.photos.glob('*.jpg')) if 7802<=int(p.stem.split('-')[-1])<=7829]})
(OUT/'owner_photo_assets.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
