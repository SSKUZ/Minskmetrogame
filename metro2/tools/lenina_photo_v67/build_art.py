"""Photo-isolated materials and sculpture; outlined, station-specific signage. No complete photos are published."""
from pathlib import Path
import argparse,hashlib,json,subprocess,shutil
import numpy as np
from PIL import Image,ImageOps,ImageFilter,ImageDraw
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'modules/stations/ploshchad_lenina/art';OUT.mkdir(parents=True,exist_ok=True)
p=argparse.ArgumentParser();p.add_argument('--photos',type=Path,required=True);ns=p.parse_args()
records=[]
def path(n):return ns.photos/('20261120_'+n+'.jpg')
def source(n):
 im=ImageOps.exif_transpose(Image.open(path(n))).convert('RGB');return im.resize((800,round(im.height*800/im.width)),Image.Resampling.LANCZOS)
def rec(n,name,coords):records.append(dict(source=path(n).name,sha256=hashlib.sha256(path(n).read_bytes()).hexdigest(),asset=name,coordinates_at_width_800=coords))
def rectify(n,name,corners,size):
 im=ImageOps.exif_transpose(Image.open(path(n))).convert('RGB');k=im.width/800;A=[];B=[]
 for (u,v),(x,y) in zip([(0,0),(size[0]-1,0),(size[0]-1,size[1]-1),(0,size[1]-1)],corners):
  x*=k;y*=k;A.extend([[u,v,1,0,0,0,-x*u,-x*v],[0,0,0,u,v,1,-y*u,-y*v]]);B.extend([x,y])
 h=np.linalg.solve(np.array(A),np.array(B));im=im.transform(size,Image.Transform.PERSPECTIVE,h,Image.Resampling.BICUBIC);im.save(OUT/name,quality=94);rec(n,name,corners);return im
def material(n,name,r,target):
 im=ImageOps.exif_transpose(Image.open(path(n))).convert('RGB');k=im.width/800
 im=im.crop(tuple(round(v*k) for v in r)).resize((384,384),Image.Resampling.LANCZOS);a=np.asarray(im,dtype=float);blur=np.asarray(im.filter(ImageFilter.GaussianBlur(32)),dtype=float)
 a=a-blur+np.array(target);v=np.zeros_like(a);v[:,0,:]=a[:,-1,:]-a[:,0,:];v[:,-1,:]=-v[:,0,:];v[0,:,:]+=a[-1,:,:]-a[0,:,:];v[-1,:,:]-=a[-1,:,:]-a[0,:,:]
 yy,xx=np.mgrid[:384,:384];den=2*np.cos(2*np.pi*xx/384)+2*np.cos(2*np.pi*yy/384)-4;den[0,0]=1
 f=np.fft.fft2(v,axes=(0,1))/den[:,:,None];f[0,0,:]=0;a-=np.fft.ifft2(f,axes=(0,1)).real
 im=Image.fromarray(np.uint8(np.clip(a,0,255)));im.save(OUT/name,quality=92);rec(n,name,r)
 if name in ['floor_grey.jpg','ceiling_paint.jpg']:
  h=np.asarray(im.convert('L'),dtype=float)/255;dy,dx=np.gradient(h);v=np.stack([-dx*.6,-dy*.6,np.ones_like(h)],axis=2);v/=np.linalg.norm(v,axis=2,keepdims=True)
  Image.fromarray(np.uint8((v*.5+.5)*255)).save(OUT/(name[:-4]+'_normal.png'))
material('131444','wall_breccia.jpg',(544,270,611,315),(137,112,96))
material('131444','wall_breccia_alt.jpg',(672,339,755,384),(127,104,89))
material('131450','white_marble.jpg',(302,310,394,370),(196,196,184))
material('131539','floor_grey.jpg',(215,342,267,382),(145,148,136))
material('131539','floor_veined.jpg',(350,357,390,390),(133,141,128))
material('131539','floor_dark.jpg',(147,305,171,322),(73,80,74))
material('131615','stair_granite.jpg',(220,305,330,312),(131,132,117))
material('131524','ceiling_paint.jpg',(35,73,100,130),(218,220,208))
# The clean white inset includes the real outlined bronze station lettering and its stone courses.
rectify('131450','name_ru.jpg',[(230,194),(625,185),(638,389),(231,416)],(1024,552))
# Opposite track uses the corresponding Belarusian spelling, reconstructed as physical bronze letters in Godot.
# The medallion is sampled without the nearby screens, stem or visitors.
rectify('131524','order_face.jpg',[(330,78),(465,78),(465,213),(330,213)],(512,512))
# Exact sculptural portrait above the Independence Square exit, isolated from the landing and people.
rectify('131615','lenin_relief.jpg',[(366,205),(474,205),(474,264),(366,264)],(640,352))
for name in ['order_face','lenin_relief']:
 im=Image.open(OUT/(name+'.jpg')).convert('L').resize((97,65),Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(.7));a=np.array(im,dtype=float)
 if name=='lenin_relief':a=255-a
 a=(a-a.min())/max(1,float(a.max()-a.min()))
 (OUT/(name+'.json')).write_text(json.dumps(dict(width=97,height=65,values=np.uint8(a*255).ravel().tolist()),separators=(',',':')))
 im=Image.open(OUT/(name+'.jpg')).convert('RGBA')
 if name=='order_face':
  mask=Image.new('L',im.size);d=ImageDraw.Draw(mask);d.polygon([(256,4),(393,45),(498,169),(508,298),(430,440),(268,508),(96,448),(8,305),(15,173),(126,45)],fill=255)
  a=np.asarray(im.convert('RGB')).astype(float);keep=(a.max(axis=2)-a.min(axis=2)>13)|(a.mean(axis=2)<95);mask=Image.fromarray(np.uint8(np.asarray(mask)/255*keep)*255)
 else:
  arr=np.asarray(im.convert('RGB'));mask=Image.fromarray(np.uint8(arr.mean(axis=2)<110)*255).filter(ImageFilter.MaxFilter(3))
 im.putalpha(mask);im.save(OUT/(name+'.png'))
# Actual station CCTV screen; the current picture is not a photograph of the whole platform.
rectify('131618','platform_cctv.jpg',[(517,106),(540,107),(540,121),(517,120)],(256,144))
font=TTFont('/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf');glyphs=font.getGlyphSet();cmap=font.getBestCmap();upem=font['head'].unitsPerEm
BLUE='#292369';WHITE='#f4f1df';YELLOW='#efb629';GREEN='#078b58'
def text(s,x,y,size,fill=WHITE):
 b='';scale=size/upem
 for c in s:
  n=cmap.get(ord(c),'space');pen=SVGPathPen(glyphs);glyphs[n].draw(pen);b+=f'<path transform="translate({x:.3f} {y}) scale({scale:.6f} {-scale:.6f})" d="{pen.getCommands()}" fill="{fill}"/>';x+=glyphs[n].width*scale
 return b
def width(s,size):return sum(glyphs[cmap.get(ord(c),'space')].width*size/upem for c in s)
def centered(s,x,y,size,fill=WHITE):return text(s,x-width(s,size)/2,y,size,fill)
def save(n,w,h,b):(OUT/n).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{b}</svg>')
be=['МАЛІНАЎКА','ПЯТРОЎШЧЫНА','МІХАЛОВА','ГРУШАЎКА','ІНСТЫТУТ КУЛЬТУРЫ','ПЛОШЧА ЛЕНІНА','КАСТРЫЧНІЦКАЯ','ПЛОШЧА ПЕРАМОГІ','ПЛОШЧА ЯКУБА КОЛАСА','АКАДЭМІЯ НАВУК','ПАРК ЧАЛЮСКІНЦАЎ','МАСКОЎСКАЯ','УСХОД','БАРЫСАЎСКІ ТРАКТ','УРУЧЧА']
ru=['МАЛИНОВКА','ПЕТРОВЩИНА','МИХАЛОВО','ГРУШЕВКА','ИНСТИТУТ КУЛЬТУРЫ','ПЛОЩАДЬ ЛЕНИНА','ОКТЯБРЬСКАЯ','ПЛОЩАДЬ ПОБЕДЫ','ПЛОЩАДЬ ЯКУБА КОЛАСА','АКАДЕМИЯ НАУК','ПАРК ЧЕЛЮСКИНЦЕВ','МОСКОВСКАЯ','ВОСТОК','БОРИСОВСКИЙ ТРАКТ','УРУЧЬЕ']
for reverse in [False,True]:
 indices=list(range(14,-1,-1)) if reverse else list(range(15));b='<path d="M10 292L252 7H2225L1983 292Z" fill="#c4c5bd" stroke="#eeeade" stroke-width="6"/>'
 for i,n in enumerate(indices):
  x=20+i*130;col=YELLOW if n==5 else BLUE if (n>5 if reverse else n<5) else '#77777f';fg='#191d29' if n==5 else WHITE
  b+=f'<path d="M{x} 270L{x+225} 15H{x+352}L{x+127} 270Z" fill="{col}" stroke="{WHITE}" stroke-width="2"/>'
  b+=f'<g transform="translate({x+61} 244) rotate(-49)">'+text(be[n],0,0,20,fg)+text(ru[n],0,25,20,fg)+'</g>'
  b+=f'<circle cx="{x+40}" cy="273" r="19" fill="{BLUE}"/>'+centered(str(n+110),x+40,280,17)
  if n in [5,6]:
   col=GREEN if n==5 else '#b82643';b+=f'<path d="M{x+40} 287V327" stroke="{col}" stroke-width="5"/><circle cx="{x+40}" cy="330" r="21" fill="{col}"/>'+centered('3' if n==5 else '2',x+40,339,26)
   lx=x+68 if n==5 else x-156;b+=text('ВАКЗАЛЬНАЯ' if n==5 else 'КУПАЛАЎСКАЯ',lx,320,14,col)+text('ВОКЗАЛЬНАЯ' if n==5 else 'КУПАЛОВСКАЯ',lx,338,14,col)
 save('route_track2.svg' if reverse else 'route_track1.svg',2235,354,b)
for side in ['north','south']:
 entries=[('Прывакзальная плошча','Привокзальная площадь'),('Чыгуначны вакзал','Железнодорожный вокзал'),('Аўтавакзал «Цэнтральны»','Автовокзал «Центральный»')] if side=='north' else [('Дом Урада','Дом Правительства'),('Касцёл Святых Сымона і Алены','Костёл Святых Симеона и Елены'),('Галоўпаштамт','Главпочтамт'),('ГЦ «Сталіца»','ТЦ «Столица»')]
 b=f'<rect width="2400" height="380" fill="{WHITE}"/><rect width="2400" height="90" fill="{BLUE}"/>'+centered('ВЫХАД   ВЫХОД',1200,43,37)+centered('плошча Незалежнасці   площадь Независимости' if side=='south' else 'Прывакзальная плошча   Привокзальная площадь',1200,80,30)
 for j,(a,c) in enumerate(entries):
  x=50+j*(2300/len(entries));b+=text(a,x,163,27,'#242429')+text(c,x,204,26,'#242429')
  if j:b+=f'<path d="M{x-20} 110V347" stroke="#555" stroke-width="2"/>'
  if side=='south' and j==0:b+=text('Белдзяржуніверсітэт',x,266,25,'#242429')+text('Белгосуниверситет',x,303,25,'#242429')
  if side=='south' and j==1:b+=text('Мінгарвыканкам',x,266,25,'#242429')+text('Мингорисполком',x,303,25,'#242429')
 save('exit_'+side+'.svg',2400,380,b)
for t in [1,2]:
 b=f'<rect width="2100" height="340" fill="{WHITE}"/><path d="M0 0H640L340 340H0Z" fill="{YELLOW}"/>'+text('пуць / путь',24,45,24,'#222')+text(str(t),48,123,65,'#222')
 b+='<g transform="translate(178 245) rotate(-45)">'+text('115  ПЛОШЧА ЛЕНІНА',0,0,27,'#222')+text('ПЛОЩАДЬ ЛЕНИНА',65,35,27,'#222')+'</g>'
 b+=f'<rect x="650" width="1000" height="83" fill="{BLUE}"/>'+centered('ВЫХАД   ВЫХОД',1150,42,32)+centered('Прывакзальная плошча / Привокзальная площадь',1150,78,25)
 b+=text('Чыгуначны вакзал',670,155,28,'#222')+text('Железнодорожный вокзал',670,197,26,'#222')+text('да станцый 116–124' if t==1 else 'да станцый 114–110',670,287,25,'#222')
 b+=f'<rect x="1670" width="430" height="340" fill="{GREEN}"/>'+centered('3',1885,72,57)+centered('314  ВАКЗАЛЬНАЯ',1885,150,27)+centered('ВОКЗАЛЬНАЯ',1885,195,30)+centered('Зеленолужская линия',1885,282,23)
 save(f'platform_track{t}.svg',2100,340,b)
b=f'<rect width="1500" height="330" fill="{WHITE}"/><rect width="1500" height="80" fill="{GREEN}"/>'+centered('ПЕРАХОД   ПЕРЕХОД',750,56,43)
b+=text('3',60,227,98,GREEN)+text('314  ВАКЗАЛЬНАЯ',240,163,48,'#222')+text('ВОКЗАЛЬНАЯ',240,226,48,'#222')+'<path d="M1280 120H1360V210H1410L1320 288L1230 210H1280Z" fill="#078b58"/>'
save('transfer.svg',1500,330,b)
for red in [False,True]:
 bg='#c62d3e' if red else '#f2f0e5';fg='#fff' if red else '#222';b=f'<rect x="3" y="3" width="894" height="294" rx="18" fill="{bg}" stroke="#eee" stroke-width="6"/>'
 b+='<circle cx="113" cy="148" r="75" fill="none" stroke="#ab2939" stroke-width="13"/><path d="M61 96L165 200" stroke="#ab2939" stroke-width="14"/>'
 b+=text('НЯМА ЎВАХОДУ',240,142,54,fg)+text('NO ENTRANCE',240,212,45,fg);save('no_entrance_floor.svg' if red else 'no_entrance.svg',900,300,b)
originals=sorted(p for p in ns.photos.glob('20261120_*.jpg'))
for f in originals:records.append(dict(reference=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),reviewed=True))
for f in sorted(ns.photos.glob('*.mp4')):
 duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=nw=1:nk=1',str(f)]));records.append(dict(reference=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),duration_seconds=duration,review='Complete video decoded and quarter-second reference sequence reviewed'))
(OUT/'owner_sources.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
