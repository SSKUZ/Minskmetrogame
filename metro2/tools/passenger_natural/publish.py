"""Reuse current engine, train and people assets; replace behavioural scripts only."""
from pathlib import Path
import gzip,hashlib,json,os,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(sys.argv[2]);OUT.mkdir(parents=True,exist_ok=True)
PASS='metro2/passenger-demo/';VIEW='metro2/module-viewer/'
FILES=['scripts/passengers/passenger_animation.gd','scripts/passengers/passenger_agent.gd','scripts/passengers/passenger_train_adapter.gd','scripts/passengers/passenger_behaviour.gd']
DEPOT=['modules/depot/depot.tscn','scripts/depot/depot_workers.gd','scripts/passengers/passenger_animation.gd','scripts/passengers/passenger_behaviour.gd']
def show(ref,path):return subprocess.check_output(['git','show',ref+':'+path])
def hashfile(p):return hashlib.sha256(p.read_bytes()).hexdigest()
mode=sys.argv[1]
if mode=='prepare':
 ref=sys.argv[3]
 for folder in ['passenger','viewer','logs']:(OUT/folder).mkdir(exist_ok=True)
 info=json.loads(show(ref,PASS+'build-info.json'))
 compressed=b''.join(show(ref,PASS+p['file']) for p in info['pack_parts'])
 (OUT/'passenger-old.pck').write_bytes(gzip.decompress(compressed))
 for name in ['index.html','build-info.json']:(OUT/'passenger'/name).write_bytes(show(ref,PASS+name))
 for name in ['module-packs.json','build-info.json','pack-resources.json']:(OUT/'viewer'/name).write_bytes(show(ref,VIEW+name))
 manifest=json.loads((OUT/'viewer/module-packs.json').read_text())
 (OUT/'depot-old.pck').write_bytes(show(ref,VIEW+manifest['packs']['depot']['file']))
 (OUT/'shared-import.pck').write_bytes(show(ref,VIEW+manifest['packs']['shared']['file']))
elif mode=='build':
 isolated=Path(os.environ['RUNNER_TEMP'])/'natural-packer';isolated.mkdir(exist_ok=True)
 (isolated/'project.godot').write_text('config_version=5\n')
 helper=ROOT/'tools/passenger_natural/patch_pack.gd'
 stage=Path(os.environ['RUNNER_TEMP'])/'natural-import';stage.mkdir(exist_ok=True)
 def run(key,mode,files,inputfile,output,extra=None):
  env=dict(os.environ,PATCH_SOURCE=str(ROOT),PATCH_MODE=mode,PATCH_FILES=json.dumps(files),PATCH_INPUT=str(inputfile.resolve()),PATCH_OUTPUT=str(output.resolve()),PATCH_EXTRA=str(extra.resolve()) if extra else '',PATCH_REPORT=str((OUT/'worker-resources.json').resolve()))
  with (OUT/'logs'/(key+'-'+mode+'.log')).open('w') as f:subprocess.run(['godot','--headless','--path',str(isolated),'--script',str(helper)],env=env,stdout=f,stderr=subprocess.STDOUT,check=True)
 import shutil
 for name in set(FILES+DEPOT):
  if not name.endswith('.gd'):continue
  target=stage/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,target)
 (stage/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Passenger resource import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
 with (OUT/'logs/import.log').open('w') as f:subprocess.run(['godot','--headless','--editor','--path',str(stage),'--import'],stdout=f,stderr=subprocess.STDOUT,check=True)
 text=(OUT/'logs/import.log').read_text()
 if 'SCRIPT ERROR' in text or 'Parse Error' in text:raise RuntimeError(text)
 run('passenger','pack',FILES,OUT/'passenger-old.pck',OUT/'passenger-new.pck')
 run('depot','pack',DEPOT,OUT/'depot-old.pck',OUT/'depot-new.pck',OUT/'passenger-old.pck')
elif mode=='finish':
 p=OUT/'passenger-new.pck';raw=p.read_bytes();compressed=gzip.compress(raw,compresslevel=6,mtime=0);parts=[];version=hashlib.sha256(compressed).hexdigest()[:16]
 for i,start in enumerate(range(0,len(compressed),2097152)):
  data=compressed[start:start+2097152];name=f'pack-{version}-{i:03d}.bin';(OUT/'passenger'/name).write_bytes(data);parts.append({'file':name,'size':len(data),'sha256':hashlib.sha256(data).hexdigest()})
 html=(OUT/'passenger/index.html').read_text();m=re.search(r'const passengerFiles = (\{[^\n]+\});',html)
 if not m:raise RuntimeError('Unknown passenger loader manifest')
 manifest=json.loads(m[1]);manifest['pack']=parts;manifest['packBytes']=len(raw)
 html=html[:m.start(1)]+json.dumps(manifest,separators=(',',':'))+html[m.end(1):]
 (OUT/'passenger/index.html').write_text(html)
 info=json.loads((OUT/'passenger/build-info.json').read_text());info.update(source_commit=os.environ['GITHUB_SHA'],pack_parts=parts,pack_original_bytes=len(raw),transfer_bytes=len(compressed)+sum(p['size'] for p in info['wasm_parts']),natural_behaviour='stable seated pelvis; calm gaze, phone, leaflet and handrail grip')
 (OUT/'passenger/build-info.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
 p=OUT/'depot-new.pck';digest=hashfile(p);name='depot-'+digest[:20]+'.pck';p.rename(OUT/'viewer'/name)
 m=json.loads((OUT/'viewer/module-packs.json').read_text());extra=json.loads((OUT/'worker-resources.json').read_text())
 warmup=[x.removesuffix('.remap') for x in extra if x.endswith(('.png.remap','.jpg.remap','.jpeg.remap','.ctex'))]
 m['packs']['depot']={'file':name,'bytes':(OUT/'viewer'/name).stat().st_size,'sha256':digest,'warmup':warmup}
 (OUT/'viewer/module-packs.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
 info=json.loads((OUT/'viewer/build-info.json').read_text());info['depot_workers']={'source_commit':os.environ['GITHUB_SHA'],'count':8,'assets':'two existing passenger models; original geometry retained','reference':'https://www.mos.ru/news/item/106964073/'}
 (OUT/'viewer/build-info.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
 report=json.loads((OUT/'viewer/pack-resources.json').read_text());report['resources']['depot']=sorted(set(report['resources']['depot'])|set(extra)|{'res://'+x for x in DEPOT})
 (OUT/'viewer/pack-resources.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 for folder in ['passenger','viewer']:
  directory=OUT/folder;(directory/'SHA256SUMS-natural').write_text(''.join(hashfile(p)+'  '+p.name+'\n' for p in sorted(directory.iterdir()) if p.is_file()))
