from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
import html,json,shutil
R=Path(__file__).resolve().parents[3]
OUT=R/'metro2/modules/stations/institut_kultury/art'
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
    parts.append(f'<path d="M{x},237 L{x+118},237 L{x+155},8 L{x+37},8 Z" fill="'+('#edc84e' if number=='114' else '#252266')+'" stroke="#eeeddf" stroke-width="2"/>')
    parts.append(f'<g transform="translate({x+18},217) rotate(-76)">'+text(be,0,0,16,'#202337' if number=='114' else '#ffffff',190)+text(ru,0,18,14,'#202337' if number=='114' else '#ffffff',190)+'</g>')
    parts.append(f'<circle cx="{x+29}" cy="242" r="15" fill="#27246c"/>'+text(number,x+17,247,13,'white'))
svg('wall_route.svg',1800,260,parts)
for name,be,ru,subs in [
('exit_surazhskaya.svg','вуліца Суражская','улица Суражская',['вуліца Магілёўская / улица Могилёвская','вуліца Слонімская / улица Слонимская','Акадэмія кіравання · Чыгуначны прыпынак «Інстытут Культуры»']),
('exit_tolstogo.svg','вуліца Талстога','улица Толстого',['вуліца Рабкораўская / улица Рабкоровская','вуліца Вакзальная / улица Вокзальная','Універсітэт культуры і мастацтваў / Университет культуры и искусств'])]:
    p=['<rect width="1200" height="200" fill="#efefdc"/><rect width="1200" height="35" fill="#348f59"/><rect y="35" width="1200" height="47" fill="#252368"/>',text('ВЫХАД   ВЫХОД',465,26,27,'#fff'),text(be,24,68,31,'#fff',530),text(ru,628,68,31,'#fff',540)]
    for i,line in enumerate(subs):p.append(text(line,35,116+i*29,23,'#1d2231',1120))
    svg(name,1200,200,p)
svg('sos.svg',360,600,['<rect width="360" height="600" fill="#ddc747"/>',text('ПРЫЛАДА',34,55,36),text('ЭКСТРАННАЙ СУВЯЗІ',20,98,26,max_width=320),'<rect x="20" y="180" width="155" height="340" fill="#a53242"/><rect x="185" y="180" width="155" height="340" fill="#243b76"/>',text('SOS',39,271,55,'#fff'),text('INFO',198,271,49,'#fff'),'<circle cx="97" cy="430" r="36" fill="#333"/><circle cx="262" cy="430" r="36" fill="#333"/>'])
shutil.copy(R/'metro2/modules/stations/ploshchad_lenina/art/no_smoking.svg',OUT/'no_smoking.svg')
print('Created outlined bilingual signage')
