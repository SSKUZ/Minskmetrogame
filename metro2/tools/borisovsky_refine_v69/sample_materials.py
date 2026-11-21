"""Sample owner stone/wood fields and decoded video; keep lighting out of albedo."""
from pathlib import Path
import argparse,hashlib,json
import numpy as np
from PIL import Image,ImageFilter
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'modules/stations/borisovsky_trakt/art_v69'
p=argparse.ArgumentParser();p.add_argument('--photos',type=Path,required=True);p.add_argument('--frames',type=Path,required=True);p.add_argument('--video',type=Path,required=True);args=p.parse_args();records=[]
def sample(path,name,rect,colour,size=(512,512),contrast=1.0):
 im=Image.open(path).convert('RGB').crop(rect).resize(size,Image.Resampling.LANCZOS)
 a=np.asarray(im,dtype=float);blur=np.asarray(im.filter(ImageFilter.GaussianBlur(42)),dtype=float)
 # Preserve the measured stone pattern, remove broad lighting, re-centre to lit material colour.
 a=(a-blur)*contrast+np.array(colour)
 h,w=a.shape[:2];v=np.zeros_like(a);v[:,0]=a[:,-1]-a[:,0];v[:,-1]=-v[:,0];v[0]+=a[-1]-a[0];v[-1]-=a[-1]-a[0]
 yy,xx=np.mgrid[:h,:w];den=2*np.cos(2*np.pi*xx/w)+2*np.cos(2*np.pi*yy/h)-4;den[0,0]=1
 f=np.fft.fft2(v,axes=(0,1))/den[:,:,None];f[0,0]=0;a-=np.fft.ifft2(f,axes=(0,1)).real
 out=Image.fromarray(np.uint8(np.clip(a,0,255)));out.save(OUT/name,quality=94)
 records.append(dict(source=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),asset=name,crop_pixels=rect,processing='Broad illumination removed; periodic boundary correction; no lettering, people or complete photographs'))
photo=args.photos/'6726.jpg'
sample(photo,'wall_marble.jpg',(635,557,803,619),(205,204,193),contrast=1.4)
sample(photo,'wall_marble_alt.jpg',(1110,594,1290,681),(202,202,193),contrast=1.25)
sample(photo,'red_granite.jpg',(650,708,970,774),(112,83,67))
sample(args.photos/'6720.jpg','column_marble.jpg',(80,670,133,790),(210,208,192),contrast=1.2)
sample(args.photos/'6720.jpg','seat_oak.jpg',(290,1160,340,1224),(160,108,43),(128,512),.7)
sample(args.frames/'frame_0331.jpg','floor_pale.jpg',(479,1030,576,1100),(166,171,160),contrast=.8)
sample(args.frames/'frame_0181.jpg','floor_dark.jpg',(60,940,172,1065),(58,48,42),contrast=.8)
sample(args.photos/'6731.jpg','stair_granite.jpg',(750,691,893,701),(146,146,131),contrast=.65)
records.append(dict(source=args.video.name,sha256=hashlib.sha256(args.video.read_bytes()).hexdigest(),seconds=13.4299,frames=806,fps=60,decoded='All 806 frames at native temporal resolution, contact sheets 01–13 reviewed; selected frames 1,181,331,481,700,806 used for structural comparison',observations=['Wide dark central floor field, pale side lanes, circular access covers and drains','Alternating cylindrical columns with double-ring steel belts and broad rounded piers with wood seats','Flat ribbed maroon central soffit, rounded side fascias and longitudinal fluorescent tubes','White transverse ceiling ribs and two rows of opal globes','Raised bronze outlined Belarusian letters and interrupted triple metal strips']))
(OUT/'reference_sources.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
