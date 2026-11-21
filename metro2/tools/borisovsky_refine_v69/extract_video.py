"""Decode every source frame and write indexed reference sheets; no scene execution."""
from pathlib import Path
import argparse,hashlib,json,subprocess
from PIL import Image,ImageDraw
p=argparse.ArgumentParser();p.add_argument('video',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
frames=a.output/'frames';frames.mkdir(parents=True,exist_ok=True)
if any(frames.glob('frame_*.jpg')):raise SystemExit('Choose an empty output directory to avoid mixing video sequences')
meta=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','frame=best_effort_timestamp_time','-of','json',str(a.video)]))
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-i',str(a.video),'-map','0:v:0','-vf','scale=640:-2','-fps_mode','passthrough','-q:v','3',str(frames/'frame_%04d.jpg')],check=True)
files=sorted(frames.glob('frame_*.jpg'));times=[float(f['best_effort_timestamp_time']) for f in meta['frames']]
if len(files)!=len(times):raise RuntimeError('Decoded frame count differs from source timestamps')
for start in range(0,len(files),64):
 sheet=Image.new('RGB',(1440,2720),'#161616');d=ImageDraw.Draw(sheet)
 for k,f in enumerate(files[start:start+64]):
  i=start+k;x=k%8*180;y=k//8*340;im=Image.open(f);im.thumbnail((180,320));sheet.paste(im,(x,y));d.text((x+3,y+323),f'{i+1:04d} | {times[i]:.3f}s',fill='white')
 sheet.save(a.output/f'sheet_{start//64+1:02d}.jpg',quality=82)
(a.output/'frames.json').write_text(json.dumps({'source':a.video.name,'sha256':hashlib.sha256(a.video.read_bytes()).hexdigest(),'frame_count':len(files),'frames':[{'frame':i+1,'seconds':t} for i,t in enumerate(times)]},indent=2)+'\n')
print(len(files),'frames decoded without temporal subsampling')
