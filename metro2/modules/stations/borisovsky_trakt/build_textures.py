"""Draw public station information and procedural stone. No uploaded images read."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math,random
OUT=Path(__file__).with_name('textures');OUT.mkdir(exist_ok=True)
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def font(size):return ImageFont.truetype(FONT,size)
BLUE='#302a72';YELLOW='#e5bd36';SILVER='#d5d7d3'
names=['МАЛІНАЎКА','ПЯТРОЎШЧЫНА','МІХАЛОВА','ГРУШАЎКА','ІНСТЫТУТ КУЛЬТУРЫ','ПЛОШЧА ЛЕНІНА','КАСТРЫЧНІЦКАЯ','ПЛОШЧА ПЕРАМОГІ','ПЛОШЧА ЯКУБА КОЛАСА','АКАДЭМІЯ НАВУК','ПАРК ЧАЛЮСКІНЦАЎ','МАСКОЎСКАЯ','УСХОД','БАРЫСАЎСКІ ТРАКТ','УРУЧЧА']
ru=['МАЛИНОВКА','ПЕТРОВЩИНА','МИХАЛОВО','ГРУШЕВКА','ИНСТИТУТ КУЛЬТУРЫ','ПЛОЩАДЬ ЛЕНИНА','ОКТЯБРЬСКАЯ','ПЛОЩАДЬ ПОБЕДЫ','ПЛОЩАДЬ ЯКУБА КОЛАСА','АКАДЕМИЯ НАУК','ПАРК ЧЕЛЮСКИНЦЕВ','МОСКОВСКАЯ','ВОСТОК','БОРИСОВСКИЙ ТРАКТ','УРУЧЬЕ']
def diagram(filename,track=0):
 im=Image.new('RGB',(1800,360),'#f1f1e8');d=ImageDraw.Draw(im)
 d.rectangle((3,3,1796,356),outline=SILVER,width=9)
 d.rectangle((15,14,1784,58),fill=BLUE);d.text((580,18),'ДА СТАНЦЫЙ    К СТАНЦИЯМ',font=font(26),fill='white')
 d.text((35,18),'«',font=font(30),fill=YELLOW);d.text((1730,18),'»',font=font(30),fill=YELLOW)
 if track==1:
  d.line((50,300,1710,300),fill=BLUE,width=9)
  indices=[13,14];xs=[1110,1450]
 else:
  indices=list(range(14 if track==2 else 15));xs=[100+i*(1550/max(len(indices)-1,1)) for i in range(len(indices))]
  d.line((60,300,1720,300),fill=BLUE,width=9)
 for idx,x in zip(indices,xs):
  panel=Image.new('RGBA',(340,50),(0,0,0,0));pd=ImageDraw.Draw(panel)
  pd.text((0,0),names[idx],font=font(16),fill='#191919' if idx==13 else 'white')
  pd.text((0,23),ru[idx],font=font(16),fill='#191919' if idx==13 else 'white')
  rotated=panel.rotate(51,expand=True,resample=Image.Resampling.BICUBIC)
  d.polygon([(x-18,294),(x+60,294),(x+280,72),(x+200,72)],fill=YELLOW if idx==13 else BLUE)
  im.paste(rotated,(int(x-10),80),rotated)
  d.ellipse((x-20,282,x+24,326),fill=BLUE);d.text((x-15,291),str(110+idx),font=font(15),fill='white')
 if track:
  d.ellipse((1700,170,1775,245),fill=BLUE);d.text((1720,179),str(track),font=font(43),fill='white');d.text((1701,255),'пуць',font=font(16),fill=BLUE);d.text((1701,278),'путь',font=font(16),fill=BLUE)
 else:
  for idx,color,text in [(5,'#207c65','3  ВАКЗАЛЬНАЯ'),(6,'#b52942','2  КУПАЛАЎСКАЯ')]:
   x=xs[idx];d.rectangle((x-4,315,x+4,344),fill=color);d.text((x-32,337),text,font=font(14),fill=color)
 im.save(OUT/filename,quality=94)
diagram('direction_1.jpg',1);diagram('direction_2.jpg',2);diagram('wall_map.jpg')
im=Image.new('RGB',(1800,240),'#f0f1e9');d=ImageDraw.Draw(im)
d.rectangle((2,2,1797,237),outline=SILVER,width=9);d.rectangle((15,14,1784,78),fill=BLUE)
d.text((700,18),'ВЫХАД  ВЫХОД',font=font(36),fill='white');d.text((420,83),'праспект Незалежнасці    проспект Независимости',font=font(27),fill=BLUE)
for x,a,b in [(36,'Мінская кальцавая аўтамабільная дарога','Минская кольцевая автомобильная дорога'),(725,'БНТУ (корпус 15)','вуліца Каліноўскага / улица Калиновского'),(1320,'Усходнія (Маскоўскія) могілкі','Восточное (Московское) кладбище')]:
 d.text((x,145),a,font=font(18),fill='#292929');d.text((x,177),b,font=font(18),fill='#292929')
im.save(OUT/'exit.jpg',quality=95)
im=Image.new('RGBA',(1600,150));d=ImageDraw.Draw(im);f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf',88)
text='БАРЫСАЎСКІ ТРАКТ';box=d.textbbox((0,0),text,font=f);x=(1600-(box[2]-box[0]))/2
for dx,dy,c in [(5,6,'#3c2b22'),(0,0,'#ad987a')]:d.text((x+dx,-box[1]+16+dy),text,font=f,fill=c,stroke_width=2,stroke_fill='#594332')
im.save(OUT/'name.png')
rng=random.Random(51)
for name,base,noise in [('marble.jpg',(211,209,195),8),('granite.jpg',(96,71,59),35),('floor.jpg',(154,154,143),15)]:
 im=Image.new('RGB',(512,512));pix=im.load()
 for y in range(512):
  for x in range(512):
   n=rng.gauss(0,noise)
   if name=='marble.jpg':
    wave=abs(math.sin(x*.027+math.sin(y*.018)*1.8+math.sin(x*.011+y*.037)*.5))
    n-=max(0,0.09-wave)*500
   pix[x,y]=tuple(max(0,min(255,int(c+n))) for c in base)
 im.save(OUT/name,quality=90)

# Bounded web texture sizes.
for p in OUT.glob('*.jpg'):
 im=Image.open(p)
 if p.stem in ['floor','granite','marble']:im=im.resize((128,128));q=65
 else:im.thumbnail((1200,240));q=75
 im.save(p,quality=q,optimize=True)
