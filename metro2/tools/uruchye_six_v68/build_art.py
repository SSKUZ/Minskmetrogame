"""Distinct arrival-side route map. Uruchye is leftmost/yellow; travelled stations are grey."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/station/uruchye_v68';OUT.mkdir(parents=True,exist_ok=True)
font=TTFont('/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf');glyphs=font.getGlyphSet();cmap=font.getBestCmap();upem=font['head'].unitsPerEm
WHITE='#ffffff';YELLOW='#efb629';GREY='#96999f';DARK='#252831'
be=['МАЛІНАЎКА','ПЯТРОЎШЧЫНА','МІХАЛОВА','ГРУШАЎКА','ІНСТЫТУТ КУЛЬТУРЫ','ПЛОШЧА ЛЕНІНА','КАСТРЫЧНІЦКАЯ','ПЛОШЧА ПЕРАМОГІ','ПЛОШЧА ЯКУБА КОЛАСА','АКАДЭМІЯ НАВУК','ПАРК ЧАЛЮСКІНЦАЎ','МАСКОЎСКАЯ','УСХОД','БАРЫСАЎСКІ ТРАКТ','УРУЧЧА']
ru=['МАЛИНОВКА','ПЕТРОВЩИНА','МИХАЛОВО','ГРУШЕВКА','ИНСТИТУТ КУЛЬТУРЫ','ПЛОЩАДЬ ЛЕНИНА','ОКТЯБРЬСКАЯ','ПЛОЩАДЬ ПОБЕДЫ','ПЛОЩАДЬ ЯКУБА КОЛАСА','АКАДЕМИЯ НАУК','ПАРК ЧЕЛЮСКИНЦЕВ','МОСКОВСКАЯ','ВОСТОК','БОРИСОВСКИЙ ТРАКТ','УРУЧЬЕ']
def width(s,size):return sum(glyphs[cmap.get(ord(c),'space')].width*size/upem for c in s)
def text(s,x,y,size,fill=WHITE):
 b='';scale=size/upem
 for c in s:
  n=cmap.get(ord(c),'space');p=SVGPathPen(glyphs);glyphs[n].draw(p);b+=f'<path transform="translate({x:.3f} {y}) scale({scale:.6f} {-scale:.6f})" d="{p.getCommands()}" fill="{fill}"/>';x+=glyphs[n].width*scale
 return b
def centered(s,x,y,size,fill=WHITE):return text(s,x-width(s,size)/2,y,size,fill)
def save(n,w,h,b):(OUT/n).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{b}</svg>')
indices=list(range(14,-1,-1));b='<rect width="2240" height="435" fill="#fff"/><path d="M15 344L270 10H2224L1969 344Z" fill="#fff" stroke="#a8aca9" stroke-width="5"/>'
for i,n in enumerate(indices):
 x=27+i*130;col=YELLOW if n==14 else GREY;fg=DARK if n==14 else WHITE
 b+=f'<path d="M{x} 327L{x+247} 18H{x+374}L{x+127} 327Z" fill="{col}"/>'
 size=min(23,300/max(width(be[n],1),width(ru[n],1)))
 b+=f'<g transform="translate({x+76} 276) rotate(-50)">'+text(be[n],0,0,size,fg)+text(ru[n],0,27,size,fg)+'</g>'
 b+=f'<circle cx="{x+61}" cy="330" r="23" fill="{YELLOW if n==14 else "#797e86"}" stroke="#fff" stroke-width="2"/>'+centered(str(n+110),x+61,338,21,fg)
for n,number,code,label,label_ru,col in [(5,'3','314','ВАКЗАЛЬНАЯ','ВОКЗАЛЬНАЯ','#007d72'),(6,'2','216','КУПАЛАЎСКАЯ','КУПАЛОВСКАЯ','#be2347')]:
 i=indices.index(n);x=27+i*130+61;b+=f'<path d="M{x} 349V389" stroke="{col}" stroke-width="6"/><rect x="{x-23}" y="348" width="46" height="23" rx="10" fill="{col}"/>'+centered(code,x,366,18)
 b+=f'<circle cx="{x}" cy="399" r="26" fill="{col}" stroke="#fff" stroke-width="2"/>'+centered(number,x,411,34)
 lx=x-244 if n==6 else x+37;b+=text(label,lx,396,22,col)+text(label_ru,lx,420,22,col)
save('route_arrived.svg',2240,435,b)
save('security.svg',1100,240,'<rect width="1100" height="240" fill="#214b8d"/>'+centered('КАНТРОЛЬ   /   КОНТРОЛЬ',550,100,52)+centered('СЛУЖБА БЯСПЕКІ   /   СЛУЖБА БЕЗОПАСНОСТИ',550,181,29))
save('upper_exit.svg',1300,240,'<rect width="1300" height="240" fill="#214b8d"/>'+centered('ВЫХАД   /   ВЫХОД',650,90,58)+centered('праспект Незалежнасці   /   проспект Независимости',650,181,31))
