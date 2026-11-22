from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'modules/stations/akademiya_nauk/art'
font=TTFont(OUT/'station_letters.ttf');glyphs=font.getGlyphSet();cmap=font.getBestCmap();upem=font['head'].unitsPerEm
BLUE='#292467';WHITE='#faf8e8';INK='#20242a';GREEN='#08784c'
def text(s,x,y,size,fill):
 result='';scale=size/upem
 for c in s:
  name=cmap.get(ord(c),'space');pen=SVGPathPen(glyphs);glyphs[name].draw(pen)
  result+=f'<path d="{pen.getCommands()}" transform="translate({x:.3f} {y}) scale({scale:.6f} {-scale:.6f})" fill="{fill}"/>'
  x+=glyphs[name].width*scale
 return result
def fit(s,x,y,size,w,fill):
 width=sum(glyphs[cmap.get(ord(c),'space')].width*size/upem for c in s)
 return text(s,x,y,min(size,size*w/max(width,1)),fill)
data={
'exit_stairs_clear.svg':[
 ['вуліца Акадэмічная','улица Академическая','Музей Якуба Коласа'],
 ['Нацыянальная акадэмія навук','Национальная академия наук','1-я гарадская клінічная бальніца','1-я городская клиническая больница'],
 ['вуліца Хмяльніцкага','улица Хмельницкого'],
 ['Кінатэатр «Кастрычнік»','Кинотеатр «Октябрь»','БНТУ']],
'exit_escalators_clear.svg':[
 ['вуліца Сурганава','улица Сурганова','Акадэмія мастацтваў','Академия искусств'],
 ['Беларускі Дом друку','Белорусский Дом печати'],
 ['вуліца Акадэмічная','улица Академическая','Нацыянальная акадэмія навук','Национальная академия наук'],
 ['вуліца Хмяльніцкага','улица Хмельницкого','БНТУ']]}
for name,cols in data.items():
 b=f'<rect width="1920" height="280" fill="{BLUE}"/><rect x="18" y="128" width="1884" height="137" fill="{WHITE}"/><rect x="612" y="8" width="696" height="61" fill="{GREEN}"/>'
 b+=fit('ВЫХАД  ВЫХОД',680,52,43,560,WHITE)
 b+='<path d="M635 52V26H657V52M1263 52V26H1285V52" fill="none" stroke="#faf8e8" stroke-width="5"/>'
 b+='<path d="M24 76H1896" stroke="#faf8e8" stroke-width="3"/>'
 b+=fit('праспект Незалежнасці',365,113,35,575,WHITE)+fit('проспект Независимости',1005,113,35,720,WHITE)
 widths=[350,640,405,465] if 'stairs' in name else [445,430,610,375]
 x=38
 for i,rows in enumerate(cols):
  for j,row in enumerate(rows):b+=fit(row,x,158+j*30,27,widths[i]-25,INK)
  if i in [1]:b+=f'<path d="M{x+widths[i]-16} 143V250" stroke="#767975" stroke-width="2"/>'
  x+=widths[i]
 (OUT/name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="280" viewBox="0 0 1920 280">{b}</svg>')
