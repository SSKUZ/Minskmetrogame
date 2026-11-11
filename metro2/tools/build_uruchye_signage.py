#!/usr/bin/env python3
"""Draw legible bilingual station signs from the owner's 6695–6709 photographs."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import math
OUT=Path(__file__).resolve().parents[1]/'assets/station/photo_reference'
OUT.mkdir(parents=True,exist_ok=True)
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
NAVY='#35365d'; YELLOW='#e9bd48'; WHITE='#f4f1df'
def text(draw,xy,value,size,fill=WHITE,anchor=None):
    draw.text(xy,value,font=ImageFont.truetype(FONT,size),fill=fill,anchor=anchor)
def save(im,name): im.save(OUT/(name+'.png'),optimize=True)
stations=[('МАЛІНАЎКА','МАЛИНОВКА'),('ПЯТРОЎШЧЫНА','ПЕТРОВЩИНА'),('МІХАЛОВА','МИХАЛОВО'),('ГРУШАЎКА','ГРУШЕВКА'),('ІНСТЫТУТ КУЛЬТУРЫ','ИНСТИТУТ КУЛЬТУРЫ'),('ПЛОШЧА ЛЕНІНА','ПЛОЩАДЬ ЛЕНИНА'),('КАСТРЫЧНІЦКАЯ','ОКТЯБРЬСКАЯ'),('ПЛОШЧА ПЕРАМОГІ','ПЛОЩАДЬ ПОБЕДЫ'),('ПЛОШЧА ЯКУБА КОЛАСА','ПЛОЩАДЬ ЯКУБА КОЛАСА'),('АКАДЭМІЯ НАВУК','АКАДЕМИЯ НАУК'),('ПАРК ЧАЛЮСКІНЦАЎ','ПАРК ЧЕЛЮСКИНЦЕВ'),('МАСКОЎСКАЯ','МОСКОВСКАЯ'),('УСХОД','ВОСТОК'),('БАРЫСАЎСКІ ТРАКТ','БОРИСОВСКИЙ ТРАКТ'),('УРУЧЧА','УРУЧЬЕ')]
im=Image.new('RGB',(2800,650),NAVY);d=ImageDraw.Draw(im)
d.rectangle((0,0,2799,649),outline='#b6b8b6',width=18)
text(d,(1400,43),'←     ДА СТАНЦЫЙ     К СТАНЦИЯМ     ←',40,anchor='mt')
d.polygon([(2410,96),(2790,96),(2790,640),(2110,640)],fill=YELLOW)
d.line((105,545,2540,545),fill=WHITE,width=12)
for i,(be,ru) in enumerate(stations):
    x=110+i*174
    layer=Image.new('RGBA',(1050,103),(0,0,0,0));ld=ImageDraw.Draw(layer)
    text(ld,(0,0),be,26,NAVY if i==14 else WHITE)
    text(ld,(0,39),ru,25,NAVY if i==14 else WHITE)
    layer=layer.crop(layer.getbbox())
    rotated=layer.rotate(53,expand=True,resample=Image.Resampling.BICUBIC)
    im.paste(rotated,(x+8,530-rotated.height),rotated)
    d=ImageDraw.Draw(im)
    d.ellipse((x-31,514,x+31,576),fill=YELLOW if i==14 else NAVY,outline=WHITE,width=4)
    text(d,(x,545),str(110+i),22,NAVY if i==14 else WHITE,'mm')
    if i in (4,5,6):
        c='#27866d' if i<6 else '#bf3e48'
        d.ellipse((x-25,588,x+25,638),fill=c)
        text(d,(x,612),'3' if i<6 else '2',29,WHITE,'mm')
save(im,'route')
im=Image.new('RGB',(2000,430),WHITE);d=ImageDraw.Draw(im)
d.rectangle((0,0,1999,429),outline='#a6aaa9',width=20)
d.polygon([(20,20),(600,20),(200,410),(20,410)],fill=YELLOW)
text(d,(300,170),'УРУЧЧА',48,NAVY,'mm');text(d,(280,233),'УРУЧЬЕ',45,NAVY,'mm')
text(d,(1120,165),'пасадкі няма',76,NAVY,'mm');text(d,(1120,260),'нет посадки',76,NAVY,'mm')
d.ellipse((1775,145,1915,285),fill=NAVY);text(d,(1845,214),'1',92,WHITE,'mm');text(d,(1845,330),'путь / пуць',23,NAVY,'mm')
save(im,'no_boarding')
for name,left,rows in [('exit_a',True,[('вуліца Астрашыцкая','улица Острошицкая'),('вуліца Старыноўская','улица Стариновская'),('вуліца Ложынская','улица Ложинская'),('вуліца Шафарнянская','улица Шафарнянская'),('вуліца Русіянава','улица Руссиянова'),('МКАД • вуліца Шугаева','МКАД • улица Шугаева')]),('exit_b',False,[('вуліца Шафарнянская','улица Шафарнянская'),('вуліца Русіянава','улица Руссиянова'),('МКАД','МКАД'),('вуліца Шугаева','улица Шугаева')])]:
    im=Image.new('RGB',(2400,500),WHITE);d=ImageDraw.Draw(im)
    d.rectangle((0,0,2399,499),outline='#a6aaa9',width=18)
    d.rectangle((20,20,2380,112),fill=NAVY);d.rectangle((20,119,2380,206),fill=NAVY)
    text(d,(1200,60),'ВЫХАД   ВЫХОД',62,WHITE,'mm')
    text(d,(115,63),'←' if left else '→',92,YELLOW,'mm');text(d,(2285,63),'→',92,YELLOW,'mm')
    text(d,(1200,161),'праспект Незалежнасці     проспект Независимости',52,WHITE,'mm')
    columns=3 if len(rows)==6 else 2
    for j,(be,ru) in enumerate(rows):
        col=j//2;row=j%2;x=55+col*(2290//columns);y=238+row*122
        text(d,(x,y),be,30,NAVY);text(d,(x,y+44),ru,30,NAVY)
    save(im,name)
for n,bg,headline,detail in [('ad_city','#0678a5','МІНСК','Горад, у які хочацца вяртацца'),('ad_theatre','#673674','ТЭАТР І МУЗЫКА','Адкрый для сябе новыя ўражанні'),('ad_travel','#167265','ПАДАРОЖЖЫ ПА БЕЛАРУСІ','Адкрый сваю краіну')]:
    im=Image.new('RGB',(960,540),bg);d=ImageDraw.Draw(im)
    for j in range(16):
        x=j*67;h=70+(j*97)%210;d.rectangle((x,540-h,x+43,540),fill='#c0d9ca')
        for y in range(550-h,525,23):d.rectangle((x+8,y,x+15,y+10),fill='#f7d783')
    text(d,(480,70),headline,48,WHITE,'mm');text(d,(480,165),detail,28,WHITE,'mm')
    text(d,(480,233),'МІНСКІ МЕТРАПАЛІТЭН',29,WHITE,'mm');save(im,n)
