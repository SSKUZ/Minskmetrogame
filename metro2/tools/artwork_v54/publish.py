"""Patch current game/train/station packs. Keep existing engine and all other assets."""
from pathlib import Path
import gzip,hashlib,json,os,re,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];OUT=Path(sys.argv[2]);OUT.mkdir(parents=True,exist_ok=True)
PASS='metro2/passenger-demo/';VIEW='metro2/module-viewer/'
AD=['scripts/depot/goodmix_restore.gd','scripts/depot/saloon_advertising_v46.gd']
URU=['scripts/station/uruchye_architecture.gd']
BT=['modules/stations/borisovsky_trakt/borisovsky_trakt.gd']
FILES={'passenger':AD+URU,'v106':AD,'uruchye':URU,'borisovsky_trakt':BT}
ASSETS={'passenger':['moscow_line.svg','uruchye_name.svg'],'v106':['moscow_line.svg'],'uruchye':['uruchye_name.svg'],'borisovsky_trakt':['borisovsky_name.svg']}
def asset(name):return 'assets/signage_v54/'+name
def show(ref,path):return subprocess.check_output(['git','show',ref+':'+path])
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
mode=sys.argv[1]
if mode=='prepare':
 ref=sys.argv[3]
 for name in ['game','viewer','logs']:(OUT/name).mkdir(exist_ok=True)
 info=json.loads(show(ref,PASS+'build-info.json'));compressed=b''.join(show(ref,PASS+p['file']) for p in info['pack_parts']);(OUT/'passenger-old.pck').write_bytes(gzip.decompress(compressed))
 for name in ['index.html','build-info.json']:(OUT/'game'/name).write_bytes(show(ref,PASS+name))
 for name in ['module-packs.json','build-info.json','pack-resources.json']:(OUT/'viewer'/name).write_bytes(show(ref,VIEW+name))
 manifest=json.loads((OUT/'viewer/module-packs.json').read_text())
 for key in ['v106','uruchye','borisovsky_trakt']:(OUT/(key+'-old.pck')).write_bytes(show(ref,VIEW+manifest['packs'][key]['file']))
elif mode=='build':
 isolated=Path(os.environ['RUNNER_TEMP'])/'artwork-packer';isolated.mkdir(exist_ok=True);(isolated/'project.godot').write_text('config_version=5\n')
 stage=Path(os.environ['RUNNER_TEMP'])/'artwork-import';stage.mkdir(exist_ok=True)
 helper=ROOT/'tools/artwork_v54/patch_pack.gd'
 def run(key,mode,files,output,assets=[]):
  env=dict(os.environ,PATCH_SOURCE=str(ROOT),PATCH_MODE=mode,PATCH_FILES=json.dumps(files),PATCH_INPUT=str((OUT/(key+'-old.pck')).resolve()),PATCH_OUTPUT=str(output.resolve()),PATCH_ART=str(stage),PATCH_ASSETS=json.dumps([asset(x) for x in assets]))
  with (OUT/'logs'/(key+'-'+mode+'.log')).open('w') as f:subprocess.run(['godot','--headless','--path',str(isolated),'--script',str(helper)],env=env,stdout=f,stderr=subprocess.STDOUT,check=True)
 # Imported current station images are dependencies of its unchanged decoration code.
 run('uruchye','assets',[],stage)
 for name in set(sum(FILES.values(),[])+['scripts/station/uruchye_platform_equipment.gd','modules/stations/borisovsky_trakt/station_base.gd','scripts/playable_track_path.gd','scripts/infrastructure/station_infrastructure.gd','assets/saloon_v49/goodmix-duo-zakhar.jpg','assets/saloon_v46/minsk_network.svg','assets/saloon_v46/moscow_line.svg','assets/saloon_v46/passenger_notice.svg']+[asset(x) for x in ['moscow_line.svg','uruchye_name.svg','borisovsky_name.svg']]):
  target=stage/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,target)
 (stage/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Artwork resource import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/vram_compression/import_s3tc_bptc=true\n')
 with (OUT/'logs/import.log').open('w') as f:subprocess.run(['godot','--headless','--editor','--path',str(stage),'--import'],stdout=f,stderr=subprocess.STDOUT,check=True)
 text=(OUT/'logs/import.log').read_text()
 if 'SCRIPT ERROR' in text or 'Parse Error' in text:raise RuntimeError(text)
 for key,files in FILES.items():run(key,'pack',files,OUT/(key+'-new.pck'),ASSETS[key])
elif mode=='finish':
 p=OUT/'passenger-new.pck';raw=p.read_bytes();compressed=gzip.compress(raw,compresslevel=6,mtime=0);version=hashlib.sha256(compressed).hexdigest()[:16];parts=[]
 for i,start in enumerate(range(0,len(compressed),2097152)):
  data=compressed[start:start+2097152];name=f'pack-{version}-{i:03d}.bin';(OUT/'game'/name).write_bytes(data);parts.append({'file':name,'size':len(data),'sha256':hashlib.sha256(data).hexdigest()})
 html=(OUT/'game/index.html').read_text();m=re.search(r'const passengerFiles = (\{[^\n]+\});',html)
 if not m:raise RuntimeError('Unknown passenger loader manifest')
 manifest=json.loads(m[1]);manifest['pack']=parts;manifest['packBytes']=len(raw);html=html[:m.start(1)]+json.dumps(manifest,separators=(',',':'))+html[m.end(1):];(OUT/'game/index.html').write_text(html)
 info=json.loads((OUT/'game/build-info.json').read_text());info.update(source_commit=os.environ['GITHUB_SHA'],pack_parts=parts,pack_original_bytes=len(raw),transfer_bytes=len(compressed)+sum(p['size'] for p in info['wasm_parts']),artwork_v54='upright Goodmix end and side prints; bilingual door route; photo-reference station lettering')
 (OUT/'game/build-info.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
 manifest=json.loads((OUT/'viewer/module-packs.json').read_text());report=json.loads((OUT/'viewer/pack-resources.json').read_text())
 for key in ['v106','uruchye','borisovsky_trakt']:
  p=OUT/(key+'-new.pck');sha=digest(p);name=key+'-'+sha[:20]+'.pck';p.rename(OUT/'viewer'/name)
  warmup=manifest['packs'][key].get('warmup',[])+['res://'+asset(x) for x in ASSETS[key]]
  manifest['packs'][key]={'file':name,'bytes':(OUT/'viewer'/name).stat().st_size,'sha256':sha,'warmup':sorted(set(warmup))}
  report['resources'][key]=sorted(set(report['resources'].get(key,[]))|{'res://'+x for x in FILES[key]}|{'res://'+asset(x)+'.remap' for x in ASSETS[key]})
 (OUT/'viewer/module-packs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');(OUT/'viewer/pack-resources.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 info=json.loads((OUT/'viewer/build-info.json').read_text());info['artwork_v54']={'source_commit':os.environ['GITHUB_SHA'],'changes':'Goodmix original art, explicit upright UVs; silver/bronze station lettering; bilingual route order'};(OUT/'viewer/build-info.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
 for name in ['game','viewer']:
  folder=OUT/name;(folder/'SHA256SUMS-artwork').write_text(''.join(digest(p)+'  '+p.name+'\n' for p in sorted(folder.iterdir()) if p.is_file()))
