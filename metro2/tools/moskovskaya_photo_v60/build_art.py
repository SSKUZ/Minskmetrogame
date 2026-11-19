"""Deterministic sign reconstruction and texture sampling from the owner's photos.
Usage: python build_art.py --photos /path/to/upload
Fonts are outlined so Godot's SVG importer does not depend on installed fonts.
"""
from pathlib import Path
import argparse, hashlib, json, math
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'modules/stations/moskovskaya/art'
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
# The two route wall panels carry different progress colours and station 121.
for reverse in [False,True]:
 indices=list(range(14,-1,-1)) if reverse else list(range(15));b='<path d="M10 292L252 7H2225L1983 292Z" fill="#c4c5bd" stroke="#888c87" stroke-width="4"/>'
 for i,n in enumerate(indices):
  x=20+i*130;col=YELLOW if n==11 else BLUE if (n>11 if reverse else n<11) else '#77777f';fg='#191d29' if n==11 else WHITE
  b+=f'<path d="M{x} 270L{x+225} 15H{x+352}L{x+127} 270Z" fill="{col}" stroke="{WHITE}" stroke-width="2"/>'
  b+=f'<g transform="translate({x+61} 244) rotate(-49)">'+text(be[n],0,0,20,fg)+text(ru[n],0,25,20,fg)+'</g>'
  b+=f'<circle cx="{x+40}" cy="273" r="19" fill="{BLUE}"/>'+centered(str(n+110),x+40,280,17)
  if n in [5,6]:
   green=n==5;col=GREEN if green else '#b82643';num='3' if green else '2'
   b+=f'<path d="M{x+40} 287V327" stroke="{col}" stroke-width="5"/><circle cx="{x+40}" cy="330" r="21" fill="{col}"/>'+centered(num,x+40,339,26)
   lx=x+68 if green else x-156
   b+=text('ВАКЗАЛЬНАЯ' if green else 'КУПАЛАЎСКАЯ',lx,320,14,col)+text('ВОКЗАЛЬНАЯ' if green else 'КУПАЛОВСКАЯ',lx,338,14,col)
 save('route_track2.svg' if reverse else 'route_track1.svg',2235,354,b)
# Longitudinal side-hung boards. Track 1 points 122–124, track 2 points 120–110.
for track in [1,2]:
 b=f'<rect width="1800" height="280" fill="{WHITE}"/><path d="M0 0H620L310 280H0Z" fill="{YELLOW}"/>'
 b+=f'<path d="M120 280L417 0H530L234 280Z" fill="{BLUE}"/>'+text('пуць',25,48,24,'#141728')+text('путь',25,76,24,'#141728')
 b+=f'<circle cx="68" cy="130" r="44" fill="{BLUE}"/>'+centered(str(track),68,149,55)
 b+=f'<g transform="translate(198 220) rotate(-42)">'+text('ДА СТАНЦЫЙ  •  К СТАНЦИЯМ',0,0,21,'#1c2030')+text('122 – 124' if track==1 else '120 – 110',15,39,36)+'</g>'
 b+=f'<g transform="translate(351 259) rotate(-42)">'+text('121  МАСКОЎСКАЯ',0,0,27,'#1c2030')+text('МОСКОВСКАЯ',69,33,27,'#1c2030')+'</g>'
 b+=f'<path d="M574 10H1782V92H486Z" fill="{BLUE}"/>'+centered('ВЫХАД   ВЫХОД',1140,44,31)+centered('праспект Незалежнасці   проспект Независимости',1140,80,29)
 b+=arrow(590,11,False,0.65)+arrow(1708,11,True,0.65)
 entries=[('Кінастудыя «Беларусьфільм»','Киностудия «Беларусьфильм»'),('вуліца Макаёнка','улица Макаёнка'),('вуліца Валгаградская','улица Волгоградская')] if track==1 else [('вуліца Макаёнка','улица Макаёнка'),('вуліца Валгаградская','улица Волгоградская'),('Кінастудыя «Беларусьфільм»','Киностудия «Беларусьфильм»')]
 for i,(a,c) in enumerate(entries):
  x=540+i*406;b+=text(a,x,163,22,'#1c2023')+text(c,x,202,22,'#1c2023')
  if i>0:b+=f'<path d="M{x-22} 120V245" stroke="#55534d" stroke-width="2"/>'
 save(f'platform_track{track}.svg',1800,280,b)
for north in [True,False]:
 b=f'<rect width="1800" height="260" fill="{BLUE}"/><rect x="620" y="0" width="560" height="55" fill="{GREEN}"/>'+centered('ВЫХАД   ВЫХОД',900,41,37)
 b+='<path d="M20 62H1780" stroke="#eee9dd" stroke-width="2"/>'+centered('праспект Незалежнасці   проспект Независимости',900,101,35)+f'<rect x="22" y="116" width="1756" height="127" fill="{WHITE}"/>'
 if north:
  b+=text('вуліца Філімонава',210,165,29,'#202125')+text('улица Филимонова',210,206,29,'#202125')
  b+=text('Кінастудыя «Беларусьфільм»',920,165,29,'#202125')+text('Киностудия «Беларусьфильм»',920,206,29,'#202125')
  b+='<path d="M800 126V229" stroke="#575653" stroke-width="2"/>'
 else:
  b+=text('вуліца Макаёнка',105,160,23,'#202125')+text('улица Макаёнка',105,193,23,'#202125')
  b+=text('Белтэлерадыёкампанія',410,160,23,'#202125')+text('Белтелерадиокомпания',410,193,23,'#202125')
  b+=text('вуліца Валгаградская',790,145,23,'#202125')+text('улица Волгоградская',790,173,23,'#202125')
  b+=text('Беларускі дзяржаўны аграрны тэхнічны ўніверсітэт',790,205,22,'#202125')+text('Белорусский государственный аграрный технический университет',790,234,20,'#202125')
  b+='<path d="M748 122V237" stroke="#575653" stroke-width="2"/>'
 for x in [43,1710]:
  b+=f'<rect x="{x}" y="178" width="30" height="39" rx="4" fill="none" stroke="#282a30" stroke-width="3"/><path d="M{x+5} 184H{x+25}V201H{x+5}Z" stroke="#282a30" fill="none" stroke-width="2"/>'
 save('exit_north_v60.svg' if north else 'exit_south_v60.svg',1800,260,b)
save('no_smoking.svg',100,100,'<rect width="100" height="100" fill="#ece9dd"/><circle cx="50" cy="50" r="38" stroke="#bc3237" stroke-width="7" fill="none"/><path d="M24 61H75V70H24ZM65 34V51M73 26V49" stroke="#46453c" stroke-width="5"/><path d="M23 19L78 81" stroke="#bc3237" stroke-width="8"/>')
save('sos_info.svg',300,460,'<rect width="300" height="460" fill="#e7c42d"/>'+centered('ЭКСТРЕННАЯ',150,42,26,'#222')+centered('СВЯЗЬ',150,79,26,'#222')+'<rect x="18" y="140" width="126" height="180" fill="#c63a3d"/><rect x="156" y="140" width="126" height="180" fill="#24599b"/>'+centered('SOS',81,250,42)+centered('INFO',219,250,33)+centered('ИНФОРМАЦИЯ',150,378,25,'#222'))
# Original fictional ad loop: three vector cards, animated and crossfaded in Godot.
b=''
for i in range(3):
 x=i*640;bg=['#103b42','#1f2c61','#b85d33'][i];accent=['#edc177','#b1deef','#f7e7b5'][i]
 b+=f'<g transform="translate({x} 0)"><rect width="640" height="360" fill="{bg}"/><circle cx="530" cy="70" r="155" fill="{accent}" opacity="0.16"/>'
 b+=text('МІНСК  •  ГОРАД ДЛЯ ЦЯБЕ',32,39,17,accent)
 if i==0:
  b+=text('КАВА',32,131,68)+text('ПА ДАРОЗЕ',34,181,39)+text('ПАЧНІ ДЗЕНЬ З ЦЯПЛА',34,302,21,accent)
  b+='<ellipse cx="488" cy="262" rx="91" ry="13" fill="#163139"/><path d="M422 128H548L534 245H436Z" fill="#f4e2bb"/><ellipse cx="484" cy="130" rx="63" ry="17" fill="#78422f"/><path d="M451 67Q433 89 452 111M484 62Q467 88 484 110M517 67Q499 89 516 111" fill="none" stroke="#f4e2bb" stroke-width="7"/>'
 elif i==1:
  b+=text('ВЫХАДНЫЯ',32,120,46)+text('Ў ГОРАДЗЕ',32,174,46)+text('АДКРЫВАЙ НОВЫЯ МАРШРУТЫ',32,302,19,accent)
  b+='<circle cx="521" cy="96" r="36" fill="#f1c46a"/><path d="M350 258V183H381V139H414V258M433 258V197H466V160H493V258M514 258V134H541V115H555V258M578 258V190H610V258" fill="#a3d3df"/>'
 else:
  b+=text('ЧЫТАЙ.',32,118,53)+text('АДКРЫВАЙ.',32,176,44)+text('ПАДАРОЖНІЧАЙ.',32,223,32)+text('ТВАЯ НАСТУПНАЯ ГІСТОРЫЯ ЎЖО БЛІЗКА',32,312,17,accent)
  b+='<path d="M445 95Q488 70 523 95Q558 70 601 95V249Q558 225 523 249Q488 225 445 249Z" fill="#f2dfb0" stroke="#7d432c" stroke-width="4"/><path d="M523 95V249M460 124L505 115M460 146L505 138M542 115L584 124M542 138L584 146" stroke="#a37e51" stroke-width="3"/>'
 b+='</g>'
save('advert_atlas.svg',1920,360,b)
args=argparse.ArgumentParser();args.add_argument('--photos',type=Path,required=True);args.add_argument('--frames',type=Path,required=True);ns=args.parse_args()
from PIL import Image,ImageEnhance
import numpy as np
records=[]
def rectify(path,name,corners,size):
 im=Image.open(path);dest=[(0,0),(size[0]-1,0),(size[0]-1,size[1]-1),(0,size[1]-1)];A=[];B=[]
 for (u,v),(x,y) in zip(dest,corners):A.extend([[u,v,1,0,0,0,-x*u,-x*v],[0,0,0,u,v,1,-y*u,-y*v]]);B.extend([x,y])
 h=np.linalg.solve(np.array(A),np.array(B));im.transform(size,Image.Transform.PERSPECTIVE,h,Image.Resampling.BICUBIC).save(OUT/name,quality=94)
 records.append({'source':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'asset':name,'source_quad_pixels':corners})
rectify(ns.photos/'02-7896.jpg','owner_mural_university.jpg',[(0,109),(1535,164),(1535,532),(0,549)],(3072,900))
rectify(ns.photos/'01-7897.jpg','owner_mural_kremlin.jpg',[(0,128),(1535,194),(1535,495),(0,530)],(3072,900))
rectify(ns.photos/'03-7877.jpg','owner_mural_domes.jpg',[(0,80),(1535,90),(1535,493),(0,515)],(3072,900))
# Frame 7880 at 2.6s supplies the opposite close-up of the low-contrast stone towers.
rectify(ns.frames/'mural-frame-7880.jpg','owner_mural_video.jpg',[(0,20),(1540,240),(1540,742),(0,891)],(3072,1050))
rectify(ns.frames/'mural-frame-7879.jpg','owner_mural_panorama.jpg',[(0,15),(1650,280),(1650,473),(0,646)],(3072,900))
rectify(ns.photos/'01-7865.jpg','platform_cctv.jpg',[(585,350),(705,373),(694,449),(575,432)],(384,216))
for src,name,rect in [('05-7869.jpg','wall_marble.jpg',(116,147,280,268)),('01-7875.jpg','column_marble.jpg',(270,437,310,676)),('03-7895.jpg','floor_red.jpg',(481,649,723,833)),('03-7895.jpg','floor_grey.jpg',(100,310,300,430)),('03-7867.jpg','stair_granite.jpg',(340,684,460,692)),('03-7895.jpg','bench_oak.jpg',(620,308,744,353))]:
 p=ns.photos/src;im=np.array(Image.open(p).crop(rect))
 Image.fromarray(im).resize((512,512),Image.Resampling.LANCZOS).save(OUT/name,quality=94)
 records.append({'source':src,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'asset':name,'source_rectangle_pixels':rect})
for video,seconds in [('7879.mp4',13.872958),('7880.mp4',8.331100)]:
 p=ns.photos/video;records.append({'source':video,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'duration_seconds':seconds,'reviewed_frames':'full sequence at 1 frame/second','sampled_frame_seconds':11.5 if video=='7879.mp4' else 2.6})
(OUT/'owner_photo_assets.json').write_text(json.dumps(records,indent=2)+'\n')
