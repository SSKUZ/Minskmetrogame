from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
import html,json,shutil
R=Path(__file__).resolve().parents[3]
OUT=R/'metro2/modules/stations/grushevka/art'
font=TTFont('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf');gs=font.getGlyphSet();cmap=font.getBestCmap()
def text(value,x,y,size,color='#20242b',max_width=None):
    unit=font['head'].unitsPerEm;scale=size/unit
    advance=sum(gs[cmap.get(ord(c),'space')].width for c in value)
    if max_width:scale=min(scale,max_width/max(1,advance))
    paths=[]
    for c in value:
        glyph=gs[cmap.get(ord(c),'space')];pen=SVGPathPen(gs);glyph.draw(pen)
        paths.append(f'<path transform="translate({x:.3f} {y:.3f}) scale({scale:.6f} {-scale:.6f})" d="{pen.getCommands()}" fill="{color}"/>');x+=glyph.width*scale
    return ''.join(paths)
def svg(name,w,h,parts):
    (OUT/name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'+''.join(parts)+'</svg>')
names=[('110','МАЛІНАЎКА','МАЛИНОВКА'),('111','ПЯТРОЎШЧЫНА','ПЕТРОВЩИНА'),('112','МІХАЛОВА','МИХАЛОВО'),('113','ГРУШАЎКА','ГРУШЕВКА'),('114','ІНСТЫТУТ КУЛЬТУРЫ','ИНСТИТУТ КУЛЬТУРЫ'),('115','ПЛОШЧА ЛЕНІНА','ПЛОЩАДЬ ЛЕНИНА'),('116','КАСТРЫЧНІЦКАЯ','ОКТЯБРЬСКАЯ'),('117','ПЛОШЧА ПЕРАМОГІ','ПЛОЩАДЬ ПОБЕДЫ'),('118','ПЛОШЧА ЯКУБА КОЛАСА','ПЛОЩАДЬ ЯКУБА КОЛАСА'),('119','АКАДЭМІЯ НАВУК','АКАДЕМИЯ НАУК'),('120','ПАРК ЧАЛЮСКІНЦАЎ','ПАРК ЧЕЛЮСКИНЦЕВ'),('121','МАСКОЎСКАЯ','МОСКОВСКАЯ'),('122','УСХОД','ВОСТОК'),('123','БАРЫСАЎСКІ ТРАКТ','БОРИСОВСКИЙ ТРАКТ'),('124','УРУЧЧА','УРУЧЬЕ')]
parts=['<rect width="1800" height="260" fill="#f0efdf"/>']
for i,(number,be,ru) in enumerate(names):
    x=15+i*118
    parts.append(f'<path d="M{x},237 L{x+118},237 L{x+155},8 L{x+37},8 Z" fill="'+('#edc84e' if number=='113' else '#252266')+'" stroke="#eeeddf" stroke-width="2"/>')
    parts.append(f'<g transform="translate({x+18},217) rotate(-76)">'+text(be,0,0,16,'#202337' if number=='113' else '#ffffff',190)+text(ru,0,18,14,'#202337' if number=='113' else '#ffffff',190)+'</g>')
    parts.append(f'<circle cx="{x+29}" cy="242" r="15" fill="#27246c"/>'+text(number,x+17,247,13,'white'))
svg('wall_route.svg',1800,260,parts)

svg('exit.svg',1500,180,['<rect width="1500" height="180" fill="#efefdc"/><rect width="1500" height="32" fill="#287854"/><rect y="32" width="1500" height="48" fill="#27226c"/>',text('ВЫХАД   ВЫХОД',590,25,25,'white'),text('праспект Дзяржынскага',30,68,30,'white',680),text('проспект Дзержинского',790,68,30,'white',680),text('вуліца Шчорса / улица Щорса',35,118,26,max_width=690),text('ВЫХАД У ГОРАД / ВЫХОД В ГОРОД',790,118,25,max_width=680),text('ГРУШАЎКА',35,157,24,max_width=550)])
svg('service_door.svg',360,330,['<rect width="360" height="330" fill="#eeeade"/>','<rect x="8" y="8" width="344" height="314" fill="none" stroke="#b54535" stroke-width="7"/>',text('СЛУЖБОВАЕ',31,85,36,'#a5372c',300),text('ПАМЯШКАННЕ',22,144,32,'#a5372c',315),text('ПАБОЧНЫМ',47,219,33,'#a5372c',270),text('УВАХОД ЗАБАРОНЕНЫ',20,278,24,'#a5372c',320)])
