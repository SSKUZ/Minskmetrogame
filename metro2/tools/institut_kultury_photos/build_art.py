from pathlib import Path
import argparse,hashlib,json,shutil
import numpy as np
from PIL import Image,ImageOps,ImageFilter
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--photos',type=Path,required=True);args=p.parse_args()
OUT=ROOT/'modules/stations/institut_kultury/art'
OUT.mkdir(parents=True,exist_ok=True)
records=[]
def source(stem):
    f=args.photos/('20261122_'+stem+'.jpg')
    im=ImageOps.exif_transpose(Image.open(f)).convert('RGB')
    im.thumbnail((1500,1200))
    return f,im
def record(stem,name,coords):
    f,_=source(stem)
    records.append(dict(source=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),asset=name,coordinates_at_preview_1500x1200=coords))
def material(stem,name,rect,target):
    _,im=source(stem)
    im=im.crop(rect).resize((384,384),Image.Resampling.LANCZOS)
    a=np.asarray(im,dtype=float);blur=np.asarray(im.filter(ImageFilter.GaussianBlur(30)),dtype=float)
    a=a-blur+np.array(target)
    # Periodic mirroring removes the crop boundary without flattening the photographed stone grains.
    a=np.uint8(np.clip(a,0,255));im=Image.fromarray(a)
    canvas=Image.new('RGB',(768,768));canvas.paste(im,(0,0));canvas.paste(ImageOps.mirror(im),(384,0));canvas.paste(ImageOps.flip(im),(0,384));canvas.paste(ImageOps.flip(ImageOps.mirror(im)),(384,384))
    canvas=canvas.resize((512,512),Image.Resampling.LANCZOS);canvas.save(OUT/name,quality=91)
    record(stem,name,rect)
def rectify(stem,name,corners,size):
    _,im=source(stem);a=[];b=[]
    for (u,v),(x,y) in zip([(0,0),(size[0]-1,0),(size[0]-1,size[1]-1),(0,size[1]-1)],corners):
        a.extend([[u,v,1,0,0,0,-x*u,-x*v],[0,0,0,u,v,1,-y*u,-y*v]]);b.extend([x,y])
    h=np.linalg.solve(np.array(a),np.array(b))
    im=im.transform(size,Image.Transform.PERSPECTIVE,h,Image.Resampling.BICUBIC)
    im.save(OUT/name,quality=94);record(stem,name,corners)

material('172341','wall_granite.jpg',(221,778,548,915),(135,115,99))
material('172052','floor_russet.jpg',(10,600,330,790),(137,113,96))
material('172052','floor_taupe.jpg',(1250,310,1480,520),(146,139,125))
material('172052','floor_light.jpg',(760,175,1000,310),(167,164,148))
material('172154','stair_granite.jpg',(42,718,560,727),(142,137,122))
material('172154','vestibule_marble.jpg',(195,325,360,414),(195,194,181))
material('172220','vault_plaster.jpg',(460,502,650,630),(221,221,211))
rectify('171932','glass_builder.jpg',[(187,602),(537,581),(589,1019),(221,1034)],(384,512))
rectify('172341','glass_musician.jpg',[(291,380),(530,366),(523,633),(305,636)],(384,448))
rectify('172017','glass_player.jpg',[(1095,348),(1248,347),(1230,526),(1082,532)],(384,448))
rectify('172017','glass_reader.jpg',[(259,346),(404,344),(432,531),(294,527)],(384,448))
rectify('172001','pylon_routes.jpg',[(221,468),(457,465),(492,1022),(238,1045)],(384,896))
rectify('172005','pylon_exits.jpg',[(244,212),(524,186),(552,827),(270,835)],(384,896))
rectify('172001','advert.jpg',[(24,0),(558,0),(576,268),(33,282)],(768,384))

# Preserve a small, native outline font for the thin raised serif station lettering.
font=TTFont('/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf')
opts=subset.Options();opts.name_IDs=['*'];opts.name_legacy=True;opts.name_languages=['*']
sub=subset.Subsetter(options=opts);sub.populate(text='ИНСТИТУТ КУЛЬТУРЫІНСТЫТУТ');sub.subset(font);font.save(OUT/'station_serif.ttf')
shutil.copy(ROOT/'modules/stations/ploshchad_lenina/art/FONT_LICENSE.txt',OUT/'FONT_LICENSE.txt')
for f in sorted(args.photos.glob('*.jpg')):
    records.append(dict(reference=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),reviewed=True))
(OUT/'owner_sources.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
print('Created',len(list(OUT.iterdir())),'assets')
