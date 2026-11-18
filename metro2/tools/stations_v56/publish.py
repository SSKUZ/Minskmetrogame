"""Import station resources and replace only the two viewer station packs."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(sys.argv[2]);OUT.mkdir(parents=True,exist_ok=True)
PREFIX='metro2/module-viewer/'
FILES={'uruchye':['scripts/station/uruchye_architecture.gd'],'borisovsky_trakt':['modules/stations/borisovsky_trakt/borisovsky_trakt.gd']}
DEPS=['scripts/station/uruchye_platform_equipment.gd','modules/stations/borisovsky_trakt/station_base.gd','scripts/playable_track_path.gd','scripts/infrastructure/station_infrastructure.gd']
def show(ref,path):return subprocess.check_output(['git','show',ref+':'+PREFIX+path])
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
mode=sys.argv[1]
if mode=='prepare':
 ref=sys.argv[3]
 for folder in ['web','logs']:(OUT/folder).mkdir(exist_ok=True)
 for name in ['module-packs.json','build-info.json','pack-resources.json']:(OUT/'web'/name).write_bytes(show(ref,name))
 manifest=json.loads((OUT/'web/module-packs.json').read_text())
 for key in FILES:(OUT/(key+'-old.pck')).write_bytes(show(ref,manifest['packs'][key]['file']))
elif mode=='build':
 stage=Path(os.environ['RUNNER_TEMP'])/'stations-v56-import';stage.mkdir(exist_ok=True)
 isolated=Path(os.environ['RUNNER_TEMP'])/'stations-v56-packer';isolated.mkdir(exist_ok=True);(isolated/'project.godot').write_text('config_version=5\n')
 def run(key,mode,files,output):
  env=dict(os.environ,PATCH_INPUT=str((OUT/(key+'-old.pck')).resolve()),PATCH_OUTPUT=str(output.resolve()),PATCH_SOURCE=str(ROOT),PATCH_MODE=mode,PATCH_FILES=json.dumps(files))
  with (OUT/'logs'/(key+'-'+mode+'.log')).open('w') as f:subprocess.run(['godot','--headless','--path',str(isolated),'--script',str(ROOT/'tools/stations_v56/patch_pack.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,check=True)
  text=(OUT/'logs'/(key+'-'+mode+'.log')).read_text()
  if any(term in text for term in ['SCRIPT ERROR','Parse Error','Failed to load']):raise RuntimeError(text)
 for key in FILES:run(key,'assets',[],stage)
 for name in sum(FILES.values(),[])+DEPS:
  p=stage/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,p)
 for folder in ['assets/signage_v54','modules/stations/borisovsky_trakt/textures']:
  shutil.copytree(ROOT/folder,stage/folder,dirs_exist_ok=True)
 (stage/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Station resource import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/vram_compression/import_s3tc_bptc=true\n')
 with (OUT/'logs/import.log').open('w') as f:subprocess.run(['godot','--headless','--editor','--path',str(stage),'--import'],stdout=f,stderr=subprocess.STDOUT,check=True)
 text=(OUT/'logs/import.log').read_text()
 if any(term in text for term in ['SCRIPT ERROR','Parse Error','Failed to load']):raise RuntimeError(text)
 for key,files in FILES.items():run(key,'pack',files,OUT/(key+'-new.pck'))
elif mode=='finish':
 manifest=json.loads((OUT/'web/module-packs.json').read_text());report=json.loads((OUT/'web/pack-resources.json').read_text());info=json.loads((OUT/'web/build-info.json').read_text())
 for key,files in FILES.items():
  p=OUT/(key+'-new.pck');sha=digest(p);name=key+'-'+sha[:20]+'.pck';p.rename(OUT/'web'/name)
  entry=dict(manifest['packs'][key]);entry.update(file=name,bytes=(OUT/'web'/name).stat().st_size,sha256=sha);manifest['packs'][key]=entry
  info.setdefault('module_packs',{})[key]=entry
  report['resources'][key]=sorted(set(report['resources'][key])|{'res://'+p for p in files})
 info['station_detail_v56']={'source_commit':os.environ['GITHUB_SHA'],'stations':list(FILES),'changes':'Uruchye ceiling rib closures, fixture and furniture fittings; Borisovsky stair landing, round downlights, jointing and direction cases','validation':'Godot 4.3 import and native Web resource pack export only; no scene execution'}
 for name,data in [('module-packs.json',manifest),('pack-resources.json',report),('build-info.json',info)]:
  (OUT/'web'/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 (OUT/'web/SHA256SUMS-stations-v56').write_text(''.join(digest(p)+'  '+p.name+'\n' for p in sorted((OUT/'web').iterdir()) if p.is_file()))
