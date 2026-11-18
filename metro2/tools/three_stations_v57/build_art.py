"""Original vector reconstructions. Reference photographs are never embedded."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
import math
ROOT=Path(__file__).resolve().parents[2]
font=TTFont('/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed.ttf');glyphs=font.getGlyphSet();cmap=font.getBestCmap();upem=font['head'].unitsPerEm
def text(s,x,y,size,fill='#fff',stroke='',spacing=0):
 parts=[];scale=size/upem
 for ch in s:
  name=cmap.get(ord(ch),'space');pen=SVGPathPen(glyphs);glyphs[name].draw(pen);d=pen.getCommands()
  if d:parts.append(f'<path transform="translate({x:.3f} {y}) scale({scale:.6f} {-scale:.6f})" d="{d}" fill="{fill}"'+(f' stroke="{stroke}" stroke-width="35"' if stroke else '')+'/>')
  x+=glyphs[name].width*scale+spacing
 return ''.join(parts)
def width(s,size,spacing=0):return sum(glyphs[cmap.get(ord(c),'space')].width*size/upem+spacing for c in s)
def svg(w,h,b):return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{b}</svg>'
be=['МАЛІНАЎКА','ПЯТРОЎШЧЫНА','МІХАЛОВА','ГРУШАЎКА','ІНСТЫТУТ КУЛЬТУРЫ','ПЛОШЧА ЛЕНІНА','КАСТРЫЧНІЦКАЯ','ПЛОШЧА ПЕРАМОГІ','ПЛОШЧА ЯКУБА КОЛАСА','АКАДЭМІЯ НАВУК','ПАРК ЧАЛЮСКІНЦАЎ','МАСКОЎСКАЯ','УСХОД','БАРЫСАЎСКІ ТРАКТ','УРУЧЧА']
ru=['МАЛИНОВКА','ПЕТРОВЩИНА','МИХАЛОВО','ГРУШЕВКА','ИНСТИТУТ КУЛЬТУРЫ','ПЛОЩАДЬ ЛЕНИНА','ОКТЯБРЬСКАЯ','ПЛОЩАДЬ ПОБЕДЫ','ПЛОЩАДЬ ЯКУБА КОЛАСА','АКАДЕМИЯ НАУК','ПАРК ЧЕЛЮСКИНЦЕВ','МОСКОВСКАЯ','ВОСТОК','БОРИСОВСКИЙ ТРАКТ','УРУЧЬЕ']
config={'vostok':12,'moskovskaya':11,'park_chelyuskintsev':10}
for key,current in config.items():
 out=ROOT/'modules/stations'/key/'art';out.mkdir(exist_ok=True)
 for lang,names in [('be',be),('ru',ru)]:
  name=names[current];size=67 if key=='park_chelyuskintsev' else 82;spacing=13 if key=='moskovskaya' else 5;w=math.ceil(width(name,size,spacing)+35)
  b='<defs><linearGradient id="gold" x1="0" y1="0" x2="0.5" y2="1"><stop stop-color="#d7bb56"/><stop offset="0.5" stop-color="#7d6125"/><stop offset="0.7" stop-color="#c8a347"/><stop offset="1" stop-color="#78602b"/></linearGradient></defs>'
  if key=='park_chelyuskintsev':
   x=12
   for c in name:
    cw=width(c,size,spacing)
    if c!=' ':b+=f'<rect x="{x}" y="22" width="{cw}" height="74" fill="url(#gold)" stroke="#695322" stroke-width="2"/>'
    x+=cw
   b+=text(name,14,86,size,'#ad8d3e','#6d5724',spacing)
  else:b+=text(name,15,90,size,'#332c1c','#332c1c',spacing)+text(name,12,87,size,'url(#gold)','#382f1d',spacing)
  (out/f'name_{lang}.svg').write_text(svg(w,115,b))
 def route(indices,header=False,north=False):
  w=140+len(indices)*155;b=f'<rect width="{w}" height="345" fill="#eeeee4"/>'
  if header:b+=f'<rect width="{w}" height="38" fill="#323677"/>'+text('ДА СТАНЦЫЙ    К СТАНЦИЯМ',65,28,24)+text('→' if north else '←',w-60,29,27,'#e0bd41')
  for i,index in enumerate(indices):
   x=15+i*155;y=42 if header else 5;col='#d6af32' if index==current else '#414481';fg='#1c2243' if index==current else '#fff'
   b+=f'<path d="M{x} 280H{x+150}L{x+305} {y}H{x+155}Z" fill="{col}" stroke="#f1f1e7" stroke-width="3"/>'
   b+=f'<g transform="translate({x+37} 251) rotate(-58)">'+text(be[index],0,0,20,fg)+text(ru[index],0,25,18,fg)+'</g>'
   b+=f'<circle cx="{x+45}" cy="293" r="20" fill="#353a7e"/>'+text(str(110+index),x+27,300,19)
   if index in [5,6]:
    col='#28785e' if index==5 else '#ac3049';label='3' if index==5 else '2'
    b+=f'<path d="M{x+45} 310V327" stroke="{col}" stroke-width="6"/>'+text(label,x+37,343,20,col)
  return svg(w,345,b)
 (out/'line.svg').write_text(route(list(range(15))))
 (out/'direction_north.svg').write_text(route(list(range(current,15)),True,True))
 (out/'direction_south.svg').write_text(route(list(range(current,-1,-1)),True,False))
 exits=['праспект Незалежнасці','проспект Независимости'] if key!='park_chelyuskintsev' else ['парк Чалюскінцаў • Батанічны сад','парк Челюскинцев • Ботанический сад']
 b='<rect width="1400" height="160" fill="#eeeee4"/><rect width="1400" height="57" fill="#34387b"/>'+text('↑  ВЫХАД   ВЫХОД  ↑',470,41,34)+text(exits[0],70,100,27,'#2c3046')+text(exits[1],70,139,27,'#2c3046')
 (out/'exit.svg').write_text(svg(1400,160,b))
 b='<rect width="430" height="1000" fill="#eaece4"/>'+text('МІНСКІ',70,65,44,'#263765')+text('МЕТРАПАЛІТЭН',25,120,38,'#263765')
 for i,name in enumerate(be):
  y=175+i*50;col='#bd9930' if i==current else '#314a89'
  if i<14:b+=f'<path d="M35 {y}V{y+50}" stroke="#314a89" stroke-width="7"/>'
  b+=f'<circle cx="35" cy="{y}" r="11" fill="{col}"/>'+text(name,58,y+6,18,'#252c45')
 (out/'network.svg').write_text(svg(430,1000,b))
 if key=='moskovskaya':
  for panel in [0,1]:
   b='<rect width="2400" height="210" fill="#c7c5b8"/>'
   for i in range(44):
    x=i*57;shade=['#a9aaa2','#b9baac','#d6d3c4','#939b98'][(i+panel)%4];b+=f'<path d="M{x} 25H{x+85}L{x+130} 40H{x+40}Z M{x} 175H{x+90}V189H{x}Z" fill="{shade}"/>'
   for group in range(4):
    x=30+group*590
    b+=f'<path d="M{x} 177V116H{x+190}V177Z M{x+30} 116V105H{x+42}V116H{x+57}V105H{x+69}V116H{x+84}V105H{x+96}V116Z" fill="#a3a79c"/>'
    b+=f'<path d="M{x+77} 116V73H{x+88}V52L{x+99} 11L{x+110} 52V73H{x+121}V116Z" fill="#b3ab8e"/>'
    b+=f'<circle cx="{x+99}" cy="87" r="10" fill="#d8d5c4" stroke="#8d968b" stroke-width="2"/>'
    tx=x+240;b+=f'<path d="M{tx} 109L{tx+94} 74L{tx+188} 109Z M{tx} 174H{tx+188}V183H{tx}Z" fill="#959f97"/>'
    for c in range(7):b+=f'<rect x="{tx+10+c*25}" y="110" width="12" height="64" fill="#e0dcca"/>'
    for c in range(3):
     dx=x+450+c*35;dy=107+(c%2)*14;b+=f'<path d="M{dx} 175V{dy}Q{dx-15} {dy-13} {dx+5} {dy-38}Q{dx+24} {dy-13} {dx+10} {dy}V175Z" fill="#a5aa9c"/>'
   (out/f'mosaic_{panel}.svg').write_text(svg(2400,210,b))
  b='<rect width="256" height="256" fill="#9a7d36"/><circle cx="128" cy="128" r="118" fill="#191f1e" stroke="#dcc571" stroke-width="4"/>'
  for i in range(12):
   a=i*math.tau/12;x=128+99*math.sin(a);y=128-99*math.cos(a);b+=f'<circle cx="{x}" cy="{y}" r="3" fill="#d1b353"/>'
  b+='<path d="M128 128V54M128 128L176 151" stroke="#d0b354" stroke-width="6"/>'
  (out/'kremlin_clock.svg').write_text(svg(256,256,b))
