"""Aligned station route panels following owner photo 7750; only the current station is yellow."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
ROOT=Path(__file__).resolve().parents[2]
font=TTFont('/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf');glyphs=font.getGlyphSet();cmap=font.getBestCmap();upem=font['head'].unitsPerEm
BLUE='#292369';WHITE='#ffffff';YELLOW='#efb629';DARK='#171c2a'
be=['МАЛІНАЎКА','ПЯТРОЎШЧЫНА','МІХАЛОВА','ГРУШАЎКА','ІНСТЫТУТ КУЛЬТУРЫ','ПЛОШЧА ЛЕНІНА','КАСТРЫЧНІЦКАЯ','ПЛОШЧА ПЕРАМОГІ','ПЛОШЧА ЯКУБА КОЛАСА','АКАДЭМІЯ НАВУК','ПАРК ЧАЛЮСКІНЦАЎ','МАСКОЎСКАЯ','УСХОД','БАРЫСАЎСКІ ТРАКТ','УРУЧЧА']
ru=['МАЛИНОВКА','ПЕТРОВЩИНА','МИХАЛОВО','ГРУШЕВКА','ИНСТИТУТ КУЛЬТУРЫ','ПЛОЩАДЬ ЛЕНИНА','ОКТЯБРЬСКАЯ','ПЛОЩАДЬ ПОБЕДЫ','ПЛОЩАДЬ ЯКУБА КОЛАСА','АКАДЕМИЯ НАУК','ПАРК ЧЕЛЮСКИНЦЕВ','МОСКОВСКАЯ','ВОСТОК','БОРИСОВСКИЙ ТРАКТ','УРУЧЬЕ']
def width(s,size):return sum(glyphs[cmap.get(ord(c),'space')].width*size/upem for c in s)
def text(s,x,y,size,fill=WHITE):
 b='';scale=size/upem
 for c in s:
  n=cmap.get(ord(c),'space');p=SVGPathPen(glyphs);glyphs[n].draw(p)
  b+=f'<path transform="translate({x:.3f} {y}) scale({scale:.6f} {-scale:.6f})" d="{p.getCommands()}" fill="{fill}"/>';x+=glyphs[n].width*scale
 return b
def centered(s,x,y,size,fill=WHITE):return text(s,x-width(s,size)/2,y,size,fill)
def save(path,w,h,body):
 path.parent.mkdir(parents=True,exist_ok=True);path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>')
def route(path,current,reverse=False):
 indices=list(range(14,-1,-1)) if reverse else list(range(15))
 b='<rect width="2240" height="435" fill="#fff"/><path d="M15 344L270 10H2224L1969 344Z" fill="#fff" stroke="#a8aca9" stroke-width="5"/>'
 for i,n in enumerate(indices):
  x=27+i*130;col=YELLOW if n==current else BLUE;fg=DARK if n==current else WHITE
  b+=f'<path d="M{x} 327L{x+247} 18H{x+374}L{x+127} 327Z" fill="{col}"/>'
  size=min(23,300/max(width(be[n],1),width(ru[n],1)))
  b+=f'<g transform="translate({x+76} 276) rotate(-50)">'+text(be[n],0,0,size,fg)+text(ru[n],0,27,size,fg)+'</g>'
  b+=f'<circle cx="{x+61}" cy="330" r="23" fill="{BLUE}" stroke="#fff" stroke-width="2"/>'+centered(str(n+110),x+61,338,21)
 for n,number,code,label,label_ru,col in [(5,'3','314','ВАКЗАЛЬНАЯ','ВОКЗАЛЬНАЯ','#007d72'),(6,'2','216','КУПАЛАЎСКАЯ','КУПАЛОВСКАЯ','#be2347')]:
  i=indices.index(n);x=27+i*130+61
  b+=f'<path d="M{x} 349V389" stroke="{col}" stroke-width="6"/><rect x="{x-23}" y="348" width="46" height="23" rx="10" fill="{col}"/>'+centered(code,x,366,18)
  b+=f'<circle cx="{x}" cy="399" r="26" fill="{col}" stroke="#fff" stroke-width="2"/>'+centered(number,x,411,34)
  left=(n==5 and not reverse) or (n==6 and reverse);lx=x-244 if left else x+37
  b+=text(label,lx,396,22,col)+text(label_ru,lx,420,22,col)
 save(path,2240,435,b)
route(ROOT/'assets/signage_v63/uruchye_route.svg',14)
