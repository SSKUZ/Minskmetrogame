"""Outlined, fitted station diagrams and a native angular title font. No photo pixels."""
from pathlib import Path
import math
from fontTools.ttLib import TTFont
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.transformPen import TransformPen
from fontTools.svgLib.path import parse_path
from fontTools.pens.svgPathPen import SVGPathPen
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'modules/stations/borisovsky_trakt/art_v69';OUT.mkdir(parents=True,exist_ok=True)
font=TTFont('/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf')
glyphs=font.getGlyphSet();cmap=font.getBestCmap();upem=font['head'].unitsPerEm
def width(s,size):return sum(glyphs[cmap.get(ord(c),'space')].width*size/upem for c in s)
def text(s,x,y,size,fill='#ffffff'):
 parts=[]
 for c in s:
  n=cmap.get(ord(c),'space');pen=SVGPathPen(glyphs);glyphs[n].draw(pen)
  parts.append(f'<path transform="translate({x:.3f} {y:.3f}) scale({size/upem:.7f} {-size/upem:.7f})" d="{pen.getCommands()}" fill="{fill}"/>');x+=glyphs[n].width*size/upem
 return ''.join(parts)
def centre(s,x,y,size,fill='#ffffff'):return text(s,x-width(s,size)/2,y,size,fill)
def save(name,w,h,body):
 (OUT/name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>')
be=['УРУЧЧА','БАРЫСАЎСКІ ТРАКТ','УСХОД','МАСКОЎСКАЯ','ПАРК ЧАЛЮСКІНЦАЎ','АКАДЭМІЯ НАВУК','ПЛОШЧА ЯКУБА КОЛАСА','ПЛОШЧА ПЕРАМОГІ','КАСТРЫЧНІЦКАЯ','ПЛОШЧА ЛЕНІНА','ІНСТЫТУТ КУЛЬТУРЫ','ГРУШАЎКА','МІХАЛОВА','ПЯТРОЎШЧЫНА','МАЛІНАЎКА']
ru=['УРУЧЬЕ','БОРИСОВСКИЙ ТРАКТ','ВОСТОК','МОСКОВСКАЯ','ПАРК ЧЕЛЮСКИНЦЕВ','АКАДЕМИЯ НАУК','ПЛОЩАДЬ ЯКУБА КОЛАСА','ПЛОЩАДЬ ПОБЕДЫ','ОКТЯБРЬСКАЯ','ПЛОЩАДЬ ЛЕНИНА','ИНСТИТУТ КУЛЬТУРЫ','ГРУШЕВКА','МИХАЛОВО','ПЕТРОВЩИНА','МАЛИНОВКА']
def diagram(name,indices,track,full=False):
 # The lettering and its section share the same rotated coordinate system.
 # Each section has an independent clip and generous margins for both languages.
 pitch=148;length=420;angle=math.radians(50);c=math.cos(angle);s=math.sin(angle)
 lane=pitch*s;w=round(56+(len(indices)-1)*pitch+length*c+lane*s);h=550
 body=f'<rect width="{w}" height="{h}" fill="#f4f2e8"/><rect x="12" y="12" width="{w-24}" height="42" fill="#303577"/>'
 body+=centre('ДА СТАНЦЫЙ   /   К СТАНЦИЯМ',w/2,43,25)
 if track:body+=text('››',30,45,35,'#f1bf38')+text(str(track)+'  ПУЦЬ / ПУТЬ',w-250,43,21,'#f1bf38')
 for i,n in enumerate(indices):
  x=28+i*pitch;y=380
  points=[(x,y),(x+length*c,y-length*s),(x+length*c+lane*s,y-length*s+lane*c),(x+lane*s,y+lane*c)]
  pts=' '.join(f'{a:.3f},{b:.3f}' for a,b in points)
  current=n==1
  ahead=(n==0 if track==1 else n>1) if track else n>1
  col='#ecb52d' if current else '#383b83' if ahead else '#989ca0';fg='#242733' if current else '#ffffff'
  body+=f'<defs><clipPath id="cell{i}"><polygon points="{pts}"/></clipPath></defs><polygon points="{pts}" fill="{col}" stroke="#f4f2e8" stroke-width="4"/>'
  size=min(25,370/max(width(be[n],1),width(ru[n],1)))
  body+=f'<g clip-path="url(#cell{i})"><g transform="translate({x} {y}) rotate(-50)">'+text(be[n],24,39,size,fg)+text(ru[n],24,72,size*.94,fg)+'</g></g>'
  cx=x+lane*s*.5;body+=f'<circle cx="{cx}" cy="{471}" r="22" fill="{col}" stroke="#fff" stroke-width="2"/>'+centre(str(124-n),cx,479,21,fg)
  if i<len(indices)-1:body+=f'<path d="M{cx+23} 471h{pitch-46}" stroke="#34397c" stroke-width="7"/>'
  if n in [8,9]:
   color='#b02e48' if n==8 else '#007c70';number='2' if n==8 else '3'
   body+=f'<path d="M{cx} 494v10" stroke="{color}" stroke-width="5"/><circle cx="{cx}" cy="520" r="18" fill="{color}"/>'+centre(number,cx,528,23)
 if track==1 and not full:body+=centre('НАПРАМАК УРУЧЧА   /   НАПРАВЛЕНИЕ УРУЧЬЕ',w/2,542,19,'#303577')
 save(name,w,h,body)
diagram('wall_toward_malinovka.svg',list(range(15)),2,True)
diagram('wall_toward_uruchye.svg',list(range(14,-1,-1)),1,True)
diagram('direction_2.svg',list(range(1,15)),2)
# A two-station sign uses the same fitted lanes at a normal board aspect ratio.
body='<rect width="2000" height="400" fill="#f5f3e9"/><rect x="12" y="12" width="1976" height="62" fill="#303577"/>'+centre('ДА СТАНЦЫІ   /   К СТАНЦИИ',1000,58,38)
body+='<path d="M35 320L330 105H930L635 320Z" fill="#edb72e"/><path d="M655 320L950 105H1945L1650 320Z" fill="#383b83"/>'
body+=centre('БАРЫСАЎСКІ ТРАКТ',492,207,39,'#292c34')+centre('БОРИСОВСКИЙ ТРАКТ',492,257,36,'#292c34')+centre('УРУЧЧА',1330,200,60)+centre('УРУЧЬЕ',1330,264,48)
body+=text('123',70,373,32,'#303577')+text('124',1815,373,32,'#303577')+centre('1   ПУЦЬ / ПУТЬ      →',1000,373,32,'#303577')
save('direction_1.svg',2000,400,body)
body='<rect width="2400" height="270" fill="#f2f1e6"/><rect x="12" y="12" width="2376" height="82" fill="#34387b"/>'+centre('ВЫХАД   /   ВЫХОД',1200,64,48)+centre('праспект Незалежнасці   /   проспект Независимости',1200,123,32,'#34387b')
for x,lines in [(50,['Мінская кальцавая аўтамабільная дарога','Минская кольцевая автомобильная дорога','БНТУ (корпус 15)']),(900,['вуліца Каліноўскага','улица Калиновского']),(1510,['Усходнія (Маскоўскія) могілкі','Восточное (Московское) кладбище'])]:
 for i,line in enumerate(lines):body+=text(line,x,170+i*34,24,'#292d34')
save('exit.svg',2400,270,body)
# Simple in-world advertisements, intentionally fictional and local to these monitors.
for i,(title,sub,col) in enumerate([('ГОРОД В ДВИЖЕНИИ','Каждый день — новый маршрут','#136779'),('КОФЕ С СОБОЙ','Пауза для хорошего настроения','#775031'),('ЧИТАЙТЕ В ДОРОГЕ','Истории, которые едут с вами','#48438c')]):
 body=f'<rect width="1200" height="680" fill="{col}"/>'
 for j in range(9):body+=f'<circle cx="{100+j*155}" cy="{580-j*34}" r="{80+j*9}" fill="none" stroke="#ffffff" stroke-opacity="0.14" stroke-width="16"/>'
 body+=centre(title,600,265,min(72,1080/width(title,1)))+centre(sub,600,365,35)+centre('МИНСК   •   МЕТРО',600,560,28)
 save(f'ad_{i}.svg',1200,680,body)
# Redrawn from owner close-up 6726: flared strokes, hooked U, diamond C,
# separated short-I marks. These are approximated physical contours, not photo decals.
outlines={
'Б':'M0 100V0H88L93 17H28V39H49Q50 53 69 69L86 100Z M28 58V82H51L44 67L39 58Z',
'А':'M0 100L6 69Q22 39 27 0H83V100H56V78H29L24 100Z M36 59H56V21H51Q47 42 36 59Z',
'Р':'M0 100V0H88Q95 23 82 45L61 69H28V100Z M28 20V55L47 37L55 20Z',
'Ы':'M0 0H26V38Q32 56 51 74V85H77Q58 54 57 37V0H84V100H0Z M99 0H125V100H99Z',
'С':'M80 2Q96 8 104 31L80 32Q74 19 61 19L39 49L61 79Q75 80 82 64H106Q96 95 78 100H43Q15 90 0 50Q16 11 40 0Z',
'Ў':'M0 0H27Q26 22 39 38L54 63V76H30Q21 60 12 46L0 26Z M60 0H87V100H5V80H60Z M61 -27H85L79 -9H56Z',
'К':'M0 0H27V100H0Z M38 0H69Q70 22 49 40L40 48Q59 64 68 100H39Q39 74 27 57V39Q41 21 38 0Z',
'І':'M0 0H28V100H0Z M7 -27H34L28 -9H2Z',
'Т':'M0 0H98V22H65V100H35V22H0Z'}
order=['.notdef','space']+[f'uni{ord(c):04X}' for c in outlines]
fb=FontBuilder(1000,isTTF=True);fb.setupGlyphOrder(order)
gly={};metrics={}
for c,path in outlines.items():
 name=f'uni{ord(c):04X}';pen=TTGlyphPen(None);parse_path(path,TransformPen(pen,(10,0,0,-10,20,1000)));gly[name]=pen.glyph()
 metrics[name]=((125 if c=='Ы' else 32 if c=='І' else 108 if c=='С' else 98)*10+120,20)
for name in ['.notdef','space']:gly[name]=TTGlyphPen(None).glyph();metrics[name]=(650,0)
fb.setupCharacterMap({ord(c):f'uni{ord(c):04X}' for c in outlines}|{32:'space'});fb.setupGlyf(gly);fb.setupHorizontalMetrics(metrics)
fb.setupHorizontalHeader(ascent=1300,descent=-100);fb.setupNameTable({'familyName':'Borisovsky Angular','styleName':'Regular','uniqueFontIdentifier':'MetroBorisovskyAngularV69','fullName':'Borisovsky Angular V69','psName':'BorisovskyAngularV69'})
fb.setupOS2(sTypoAscender=1300,sTypoDescender=-100,usWinAscent=1300,usWinDescent=100);fb.setupPost();fb.setupMaxp();fb.save(OUT/'station_name.ttf')
