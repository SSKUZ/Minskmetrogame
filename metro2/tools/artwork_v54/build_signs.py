"""Vector lettering and route information. Uploaded photos are references only."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from xml.sax.saxutils import escape
OUT=Path(__file__).resolve().parents[2]/'assets/signage_v54';OUT.mkdir(parents=True,exist_ok=True)
font=TTFont('/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf');glyphs=font.getGlyphSet();cmap=font.getBestCmap();upem=font['head'].unitsPerEm

def text(s,x,y,size,fill='#fff'):
 scale=size/upem;parts=[]
 for char in s:
  name=cmap.get(ord(char),'space');pen=SVGPathPen(glyphs);glyphs[name].draw(pen);data=pen.getCommands()
  if data:parts.append(f'<path transform="translate({x:.3f} {y}) scale({scale:.6f} {-scale:.6f})" d="{data}" fill="{fill}"/>')
  x+=glyphs[name].width*scale
 return ''.join(parts)

def svg(w,h,body):return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'
# Independently drawn rounded plate letters, silver faces and blue water crest.
u={
'У':'M0 0H26V20Q26 38 48 38Q70 38 70 20V0H98V28Q98 57 76 68L47 100H6L39 66Q0 64 0 28Z',
'Р':'M0 100V0H61Q99 0 99 33Q99 67 61 67H30V100Z M30 24V44H57Q69 44 69 34Q69 24 57 24Z',
'Ч':'M0 0H30V26Q30 42 48 42H68V0H99V100H68V67H42Q0 67 0 29Z',
'А':'M0 100L32 0H68L100 100H68L62 77H36L30 100Z M42 53H57L50 24Z'}
body='<defs><linearGradient id="silver" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#c6c7c3"/><stop offset="0.55" stop-color="#999e9d"/><stop offset="1" stop-color="#c3c6c3"/></linearGradient></defs>'
body+='<path d="M130 157Q295 160 400 122Q570 38 755 124Q850 158 1030 160L1030 180Q830 166 712 191Q530 231 420 185Q288 170 130 180Z" fill="#165b94"/>'
x=200
for c in 'УРУЧЧА':
 body+=f'<path transform="translate({x+4} 104) scale(1.25 0.90)" d="{u[c]}" fill="#393c3b" fill-rule="evenodd"/>'
 body+=f'<path transform="translate({x} 98) scale(1.25 0.90)" d="{u[c]}" fill="url(#silver)" fill-rule="evenodd"/>';x+=130
body+='<g fill="none" stroke="#a6aaa7" stroke-width="7"><path d="M0 184H182Q245 184 281 197Q328 222 383 201Q430 182 478 190Q550 214 625 193Q700 175 767 192Q810 212 853 192Q901 160 960 180H1200"/><path d="M245 188Q515 255 760 187"/><circle cx="95" cy="215" r="18"/><circle cx="1110" cy="157" r="13"/></g>'
(OUT/'uruchye_name.svg').write_text(svg(1200,290,body))
# Angular bronze-edged letters, including the actual Belarusian Ў and І.
b={
'Б':'M0 100V0H92L83 18H30V40H65L95 58V85L80 100Z M30 60V82H61L68 76V68L60 60Z',
'А':'M0 100L31 0H64L96 100H67L60 76H34L27 100Z M40 57H54L47 26Z',
'Р':'M0 100V0H70L94 20V48L72 67H30V100Z M30 18V47H60L66 42V26L60 18Z',
'Ы':'M0 0H28V39H56L77 58V83L59 100H0Z M28 60V81H49L53 76V65L48 60Z M84 0H109V100H84Z',
'С':'M94 0L86 20H42L27 34V69L43 83H87L95 100H30L0 77V24L29 0Z',
'Ў':'M0 15H27L48 53L68 15H95L45 100H12L32 69Z M22 -11L34 -17Q48 -5 61 -17L74 -11Q49 11 22 -11Z',
'К':'M0 100V0H27V39L60 0H93L53 48L95 100H61L27 58V100Z',
'І':'M0 0H32V100H0Z',
'Т':'M0 0H98L90 22H63V100H34V22H8Z'}
body='';x=20
for c in 'БАРЫСАЎСКІ ТРАКТ':
 if c==' ':x+=65;continue
 width=109 if c=='Ы' else (32 if c=='І' else 98)
 body+=f'<path transform="translate({x+4} 28)" d="{b[c]}" fill="#3c3028" fill-rule="evenodd"/>'
 body+=f'<path transform="translate({x} 23)" d="{b[c]}" fill="#b9aa90" stroke="#514035" stroke-width="2.5" fill-rule="evenodd"/>';x+=width+17
(OUT/'borisovsky_name.svg').write_text(svg(x+15,155,body))
# Bilingual route order and transfer names from the supplied station diagrams.
be=['УРУЧЧА','БАРЫСАЎСКІ ТРАКТ','УСХОД','МАСКОЎСКАЯ','ПАРК ЧАЛЮСКІНЦАЎ','АКАДЭМІЯ НАВУК','ПЛОШЧА ЯКУБА КОЛАСА','ПЛОШЧА ПЕРАМОГІ','КАСТРЫЧНІЦКАЯ','ПЛОШЧА ЛЕНІНА','ІНСТЫТУТ КУЛЬТУРЫ','ГРУШАЎКА','МІХАЛОВА','ПЯТРОЎШЧЫНА','МАЛІНАЎКА']
ru=['УРУЧЬЕ','БОРИСОВСКИЙ ТРАКТ','ВОСТОК','МОСКОВСКАЯ','ПАРК ЧЕЛЮСКИНЦЕВ','АКАДЕМИЯ НАУК','ПЛОЩАДЬ ЯКУБА КОЛАСА','ПЛОЩАДЬ ПОБЕДЫ','ОКТЯБРЬСКАЯ','ПЛОЩАДЬ ЛЕНИНА','ИНСТИТУТ КУЛЬТУРЫ','ГРУШЕВКА','МИХАЛОВО','ПЕТРОВЩИНА','МАЛИНОВКА']
body='<rect width="3600" height="480" fill="#eeeee8"/><path d="M35 384H3550" stroke="#373a83" stroke-width="12"/>'
for i,(bel,rus) in enumerate(zip(be,ru)):
 x=32+i*231
 body+=f'<path d="M{x} 354H{x+215}L{x+418} 25H{x+203}Z" fill="#454080" stroke="#eeeee8" stroke-width="5"/>'
 body+=f'<g transform="translate({x+52} 330) rotate(-58)">'+text(bel,0,0,31)+text(rus,0,37,28)+'</g>'
 body+=f'<circle cx="{x+60}" cy="385" r="29" fill="#373a83"/>'+text(str(124-i),x+35,395,27)
for i,color,label in [(8,'#b42943','2  КУПАЛАЎСКАЯ / КУПАЛОВСКАЯ'),(9,'#24775e','3  ВАКЗАЛЬНАЯ / ВОКЗАЛЬНАЯ')]:
 x=32+i*231+60
 body+=f'<path d="M{x} 410V443" stroke="{color}" stroke-width="11"/>'+text(label,x-450 if i==8 else x+40,474,23,color)
(OUT/'moscow_line.svg').write_text(svg(3600,480,body))
