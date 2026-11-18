"""Update depot pack only; keep saved people assets and every other module intact."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(sys.argv[2]);OUT.mkdir(parents=True,exist_ok=True)
PREFIX='metro2/module-viewer/'
FILES=['scripts/depot/depot_hall.gd','scripts/depot/depot_environment_v43.gd','scripts/depot/depot_yard.gd','scripts/depot/depot_workers.gd']
DEPS=['scripts/depot/depot_builder.gd','scripts/depot/route_profile.gd','assets/depot/industrial_surface.gdshader','scripts/passengers/passenger_animation.gd','scripts/passengers/passenger_behaviour.gd']
def show(ref,path):return subprocess.check_output(['git','show',ref+':'+PREFIX+path])
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
mode=sys.argv[1]
if mode=='prepare':
 ref=sys.argv[3]
 (OUT/'web').mkdir(exist_ok=True);(OUT/'logs').mkdir(exist_ok=True)
 for path in ['module-packs.json','build-info.json','pack-resources.json']:(OUT/'web'/path).write_bytes(show(ref,path))
 manifest=json.loads((OUT/'web/module-packs.json').read_text())
 # The current saved depot pack carries the existing eight-worker scene dependencies.
 info=json.loads((OUT/'web/build-info.json').read_text())
 if int(info.get('depot_workers',{}).get('count',0))!=8:raise RuntimeError('Expected existing eight-worker depot; refuse an outdated baseline')
 (OUT/'depot-old.pck').write_bytes(show(ref,manifest['packs']['depot']['file']))
elif mode=='build':
 stage=Path(os.environ['RUNNER_TEMP'])/'depot-v55-import';stage.mkdir(exist_ok=True)
 for name in FILES+DEPS:
  p=stage/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,p)
 (stage/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Depot resource import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
 with (OUT/'logs/import.log').open('w') as f:subprocess.run(['godot','--headless','--editor','--path',str(stage),'--import'],stdout=f,stderr=subprocess.STDOUT,check=True)
 text=(OUT/'logs/import.log').read_text()
 if any(term in text for term in ['SCRIPT ERROR','Parse Error','Failed to load']):raise RuntimeError(text)
 isolated=Path(os.environ['RUNNER_TEMP'])/'depot-v55-packer';isolated.mkdir(exist_ok=True);(isolated/'project.godot').write_text('config_version=5\n')
 env=dict(os.environ,PATCH_INPUT=str((OUT/'depot-old.pck').resolve()),PATCH_OUTPUT=str((OUT/'depot-new.pck').resolve()),PATCH_SOURCE=str(ROOT),PATCH_MODE='pack',PATCH_FILES=json.dumps(FILES))
 with (OUT/'logs/pack.log').open('w') as f:subprocess.run(['godot','--headless','--path',str(isolated),'--script',str(ROOT/'tools/depot_v55/patch_pack.gd')],stdout=f,stderr=subprocess.STDOUT,env=env,check=True)
 text=(OUT/'logs/pack.log').read_text()
 if any(term in text for term in ['SCRIPT ERROR','Parse Error','Failed to load']):raise RuntimeError(text)
elif mode=='finish':
 p=OUT/'depot-new.pck';digest=sha(p);name='depot-'+digest[:20]+'.pck';p.rename(OUT/'web'/name)
 manifest=json.loads((OUT/'web/module-packs.json').read_text());old=manifest['packs']['depot'];manifest['packs']['depot']={'file':name,'bytes':(OUT/'web'/name).stat().st_size,'sha256':digest,'warmup':old.get('warmup',[])}
 (OUT/'web/module-packs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 info=json.loads((OUT/'web/build-info.json').read_text());info['depot_detail_v55']={'source_commit':os.environ['GITHUB_SHA'],'pack':manifest['packs']['depot'],'workers':8,'added_skyline_buildings':40,'changes':'sealed glazing/eave/gable joints, workshop details and distant city backdrop','validation':'Godot 4.3 resource import and pack export only; no scene execution'}
 info['module_packs']['depot']=manifest['packs']['depot']
 (OUT/'web/build-info.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
 report=json.loads((OUT/'web/pack-resources.json').read_text());report['resources']['depot']=sorted(set(report['resources']['depot'])|{'res://'+p for p in FILES})
 (OUT/'web/pack-resources.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 (OUT/'web/SHA256SUMS-depot-v55').write_text(''.join(sha(p)+'  '+p.name+'\n' for p in sorted((OUT/'web').iterdir()) if p.is_file()))
