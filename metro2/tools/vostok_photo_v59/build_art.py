"""Deterministic sign reconstruction and texture sampling from the owner's photos.
Usage: python build_art.py --photos /path/to/upload
Fonts are outlined so Godot's SVG importer does not depend on installed fonts.
"""
from pathlib import Path
import argparse, hashlib, json, math
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'modules/stations/vostok/art'
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
# The wall panels are different on the two track walls. The current station is 122.
for reverse in [False,True]:
 indices=list(range(14,-1,-1)) if reverse else list(range(15))
 b='<path d="M10 292L252 7H2225L1983 292Z" fill="#c4c5bd" stroke="#888c87" stroke-width="4"/>'
 for i,n in enumerate(indices):
  x=20+i*130; col=YELLOW if n==12 else BLUE if (n>12 if reverse else n<12) else '#77777f'; fg='#191d29' if n==12 else WHITE
  b+=f'<path d="M{x} 270L{x+225} 15H{x+352}L{x+127} 270Z" fill="{col}" stroke="{WHITE}" stroke-width="2"/>'
  b+=f'<g transform="translate({x+61} 244) rotate(-49)">'+text(be[n],0,0,20,fg)+text(ru[n],0,25,20,fg)+'</g>'
  b+=f'<circle cx="{x+40}" cy="273" r="19" fill="{BLUE}"/>'+centered(str(n+110),x+40,280,17)
  if n in [5,6]:
   green=n==5;col=GREEN if green else '#b82643';num='3' if green else '2';label='ВАКЗАЛЬНАЯ' if green else 'КУПАЛАЎСКАЯ';label_ru='ВОКЗАЛЬНАЯ' if green else 'КУПАЛОВСКАЯ'
   b+=f'<path d="M{x+40} 287V327" stroke="{col}" stroke-width="5"/><circle cx="{x+40}" cy="330" r="21" fill="{col}"/>'+centered(num,x+40,339,26)
   lx=x+68 if green else x-156
   b+=text(label,lx,320,14,col)+text(label_ru,lx,338,14,col)
 save('line_to_malinovka.svg' if reverse else 'line_to_uruchye.svg',2235,354,b)
for track in [1,2]:
 b=f'<rect width="510" height="1510" fill="{WHITE}"/>'
 b+=text('пуць',230,45,18,'#27282d')+text('путь',230,66,18,'#27282d')
 b+=f'<circle cx="320" cy="44" r="34" fill="{BLUE}"/>'+centered(str(track),320,58,38)
 b+=f'<path d="M367 17L394 44L367 71H391L418 44L391 17Z" fill="{YELLOW}"/><path d="M397 17L424 44L397 71H415L442 44L415 17Z" fill="{BLUE}"/>'
 indices=list(range(14,-1,-1)) if track==1 else list(range(15))
 for i,n in enumerate(indices):
  y=93+i*84;current=n==12;col=YELLOW if current else BLUE;fg='#151b24' if current else WHITE
  b+=f'<rect x="22" y="{y}" width="466" height="82" fill="{col}"/>'
  size=min(25,355/max(1,width(be[n],1)))
  b+=text(be[n],85,y+33,size,fg)+text(ru[n],85,y+64,min(25,355/max(1,width(ru[n],1))),fg)
  b+=f'<circle cx="52" cy="{y+41}" r="27" fill="{BLUE}" stroke="{WHITE}" stroke-width="2"/>'+centered(str(n+110),52,y+47,20)
  if n in [5,6]:
   col=GREEN if n==5 else '#b82643'
   b+=f'<circle cx="52" cy="{y+58}" r="17" fill="{col}"/>'+centered('314' if n==5 else '216',52,y+64,15)
 bottom=2 if track==1 else 1
 b+=f'<path d="M67 1400L39 1429L67 1458H87L59 1429L87 1400Z" fill="{BLUE}"/><path d="M96 1400L68 1429L96 1458H113L85 1429L113 1400Z" fill="{YELLOW}"/><circle cx="157" cy="1429" r="34" fill="{BLUE}"/>'+centered(str(bottom),157,1443,38)+text('пуць',204,1425,18,'#27282d')+text('путь',204,1448,18,'#27282d')
 save(f'pylon_track{track}.svg',510,1510,b)
# Two opposite faces: arrows swap when viewed from the opposite side.
library=[('Нацыянальная','бібліятэка Беларусі'),('Национальная','библиотека Беларуси'),('мікрараён Усход','пр-т Незалежнасці, д.123–151'),('микрорайон Восток','пр-т Независимости, д.123–151'),('вуліца Філімонава','улица Филимонова')]
kalin=[('вуліца Каліноўскага','улица Калиновского'),('вуліца К. Тураўскага','улица К. Туровского'),('Храм Усіх Святых','Храм Всех Святых'),('Дом міласэрнасці','Дом милосердия'),('мікрараён Усход','микрорайон Восток')]
for reverse in [False,True]:
 b=f'<rect width="610" height="1510" fill="{WHITE}"/><rect x="14" y="16" width="582" height="100" fill="{GREEN}"/>'+centered('ВЫХАД   ВЫХОД',305,83,42)
 b+=f'<rect x="14" y="116" width="582" height="122" fill="{BLUE}"/>'+centered('праспект Незалежнасці',305,163,31)+centered('проспект Независимости',305,208,31)
 groups=[kalin,library] if reverse else [library,kalin]
 for section,rows in enumerate(groups):
  y0=270+section*605
  b+=arrow(32 if section==0 else 487,y0,section==1,0.95)
  for i,(a,c) in enumerate(rows):
   y=y0+48+i*108
   size=27 if len(a)>20 else 30
   b+=centered(a,315,y,size,'#17191a')+centered(c,315,y+40,25 if len(c)>26 else 29,'#17191a')
   if rows is kalin and i==4:
    b+=centered('пр-т Незалежнасці, д.153–157',315,y+70,18,'#17191a')+centered('пр-т Независимости, д.153–157',315,y+96,18,'#17191a')
  if section==0:b+='<path d="M36 845H574" stroke="#544e40" stroke-width="2"/>'
 save('pylon_exit_b.svg' if reverse else 'pylon_exit_a.svg',610,1510,b)
for north in [True,False]:
 b=f'<rect width="1800" height="260" fill="{BLUE}"/><rect x="620" y="0" width="560" height="55" fill="{GREEN}"/>'+centered('ВЫХАД   ВЫХОД',900,41,37)
 b+='<path d="M20 62H1780" stroke="#eee9dd" stroke-width="2"/>'+centered('праспект Незалежнасці   проспект Независимости',900,101,35)
 b+=f'<rect x="22" y="116" width="1756" height="127" fill="{WHITE}"/>'
 pairs=[('вуліца Каліноўскага','улица Калиновского'),('Храм Усіх Святых','Храм Всех Святых'),('ГЦ «Першы Нацыянальны гандлёвы дом»','ТЦ «Первый Национальный торговый дом»'),('Дом міласэрнасці','Дом милосердия')] if north else [('вуліца Язмінавая','улица Жасминовая'),('вуліца Філімонава','улица Филимонова'),('Нацыянальная бібліятэка Беларусі','Национальная библиотека Беларуси'),('мікрараён Усход','микрорайон Восток')]
 for i,(a,c) in enumerate(pairs):
  x=[130,570,960,960][i] if north else [140,140,530,1330][i]
  y=151+(57 if i==3 or (not north and i==1) else 0)
  b+=text(a,x,y,22,'#202125')+text(c,x,y+26,22,'#202125')
 for x in [43,1710]:
  for y in [137,192]:b+=f'<rect x="{x}" y="{y}" width="29" height="35" rx="4" fill="none" stroke="#222" stroke-width="3"/><path d="M{x+4} {y+25}H{x+25}M{x+7} {y+6}H{x+22}V{y+17}H{x+7}Z" stroke="#222" fill="none" stroke-width="2"/>'
 save('exit_north.svg' if north else 'exit_south.svg',1800,260,b)
save('stair_caution.svg',100,145,'<rect width="100" height="145" fill="#f4f1ea"/><circle cx="50" cy="45" r="36" fill="none" stroke="#c72535" stroke-width="7"/><path d="M22 70L78 20" stroke="#c72535" stroke-width="7"/>'+centered('БУДЬТЕ',50,113,14,'#b7212c')+centered('ОСТОРОЖНЫ',50,132,12,'#b7212c'))
# User photograph supplies only the advertisement image, no people or surroundings.
args=argparse.ArgumentParser();args.add_argument('--photos',type=Path,required=True);ns=args.parse_args()
from PIL import Image
import numpy as np
records=[]
def rectify(src,name,corners,size):
 p=ns.photos/src; im=Image.open(p)
 dest=[(0,0),(size[0]-1,0),(size[0]-1,size[1]-1),(0,size[1]-1)]
 A=[]; B=[]
 for (u,v),(x,y) in zip(dest,corners):
  A.extend([[u,v,1,0,0,0,-x*u,-x*v],[0,0,0,u,v,1,-y*u,-y*v]]);B.extend([x,y])
 H=np.linalg.solve(np.array(A),np.array(B))
 im.transform(size,Image.Transform.PERSPECTIVE,H,Image.Resampling.BICUBIC).save(OUT/name,quality=93)
 records.append({'source':src,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'asset':name,'source_quad_pixels':corners})
rectify('08-7980.jpg','screen_year_2026.jpg',[(282,100),(732,27),(759,301),(314,348)],(960,540))
# Small real stone patches supply aggregate colour and crystal structure.
for src,name,rect in [('01-7997.jpg','red_granite.jpg',(494,576,600,687)),('02-7957.jpg','grey_granite.jpg',(602,1021,731,1209)),('03-7958.jpg','stair_marble.jpg',(423,597,631,619))]:
 p=ns.photos/src;im=np.array(Image.open(p).crop(rect))
 # Mirrored tile borders avoid a sharp discontinuity without inventing stone detail.
 im=np.concatenate([im,im[:,::-1]],axis=1);im=np.concatenate([im,im[::-1]],axis=0)
 Image.fromarray(im).resize((512,512),Image.Resampling.LANCZOS).save(OUT/name,quality=94)
 records.append({'source':src,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'asset':name,'source_rectangle_pixels':rect})
(OUT/'photo_assets.json').write_text(json.dumps(records,indent=2)+'\n')
