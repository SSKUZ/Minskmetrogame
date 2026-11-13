"""Patch the three current station/depot packs; reuse all other publications."""
from pathlib import Path
import hashlib,json,os,subprocess,sys
OUT=Path(sys.argv[2]);OUT.mkdir(parents=True,exist_ok=True)
ROOT=Path(__file__).resolve().parents[2]
PREFIX='metro2/module-viewer/'
FILES={
 'uruchye':['scripts/station_base_static.gd','scripts/station/uruchye_architecture.gd','scripts/station/uruchye_platform_equipment.gd','scripts/infrastructure/station_infrastructure.gd'],
 'borisovsky_trakt':['modules/stations/borisovsky_trakt/station_base.gd','modules/stations/borisovsky_trakt/borisovsky_trakt.gd','scripts/infrastructure/station_infrastructure.gd'],
 'depot':['scripts/depot/depot_track.gd']}
def show(ref,name):return subprocess.check_output(['git','show',ref+':'+PREFIX+name])
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
if sys.argv[1]=='prepare':
 ref=sys.argv[3]
 for name in ['module-packs.json','build-info.json','pack-resources.json']:(OUT/name).write_bytes(show(ref,name))
 manifest=json.loads((OUT/'module-packs.json').read_text())
 for key in FILES:(OUT/(key+'-old.pck')).write_bytes(show(ref,manifest['packs'][key]['file']))
 (OUT/'replacements.json').write_text(json.dumps(FILES))
 # Preserve the current shared pack for import dependency resolution only.
 (OUT/'shared-import.pck').write_bytes(show(ref,manifest['packs']['shared']['file']))
elif sys.argv[1]=='build':
 log=OUT/'logs';log.mkdir(exist_ok=True)
 # Unpack current resources for mandatory editor import; originals are not rebuilt.
 stage=Path(os.environ['RUNNER_TEMP'])/'infrastructure-import';stage.mkdir(exist_ok=True)
 (stage/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Station infrastructure resource import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
 isolated=Path(os.environ['RUNNER_TEMP'])/'infrastructure-packer';isolated.mkdir(exist_ok=True)
 (isolated/'project.godot').write_text('config_version=5\n')
 helper=ROOT/'tools/infrastructure/patch_pack.gd'
 def runpack(key,mode,replacements,inputfile,output):
  env=dict(os.environ,PATCH_INPUT=str(inputfile.resolve()),PATCH_OUTPUT=str(output.resolve()),PATCH_SOURCE=str(ROOT),PATCH_FILES=json.dumps(replacements),PATCH_MODE=mode)
  with (log/(key+'-'+mode+'.log')).open('w') as f:
   subprocess.run(['godot','--headless','--path',str(isolated),'--script',str(helper)],env=env,stdout=f,stderr=subprocess.STDOUT,check=True)
 runpack('shared','unpack',[],OUT/'shared-import.pck',stage)
 for key,files in FILES.items():runpack(key,'unpack',files,OUT/(key+'-old.pck'),stage)
 with (log/'import.log').open('w') as f:subprocess.run(['godot','--headless','--editor','--path',str(stage),'--import'],stdout=f,stderr=subprocess.STDOUT,check=True)
 text=(log/'import.log').read_text()
 if any(x in text for x in ['SCRIPT ERROR','Parse Error']):raise RuntimeError(text)
 for key,files in FILES.items():runpack(key,'pack',files,OUT/(key+'-old.pck'),OUT/(key+'-new.pck'))
elif sys.argv[1]=='finish':
 manifest=json.loads((OUT/'module-packs.json').read_text());report=json.loads((OUT/'pack-resources.json').read_text())
 for key,files in FILES.items():
  p=OUT/(key+'-new.pck');digest=sha(p);name=key+'-'+digest[:20]+'.pck';p.rename(OUT/name)
  old=manifest['packs'][key];manifest['packs'][key]={'file':name,'bytes':(OUT/name).stat().st_size,'sha256':digest,'warmup':old.get('warmup',[])}
  report['resources'][key]=sorted(set(report['resources'].get(key,[]))|{'res://'+f for f in files})
 info=json.loads((OUT/'build-info.json').read_text());info['station_infrastructure']={'source_commit':os.environ['GITHUB_SHA'],'modules':list(FILES),'clock_timezone':'Europe/Minsk UTC+3','departure_interval':'per track; starts only after full departure','tests':'not run'}
 (OUT/'module-packs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');(OUT/'build-info.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n');(OUT/'pack-resources.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 for p in list(OUT.glob('*-old.pck'))+[OUT/'shared-import.pck',OUT/'replacements.json']:p.unlink()
 (OUT/'SHA256SUMS-infrastructure').write_text(''.join(sha(p)+'  '+p.name+'\n' for p in sorted(OUT.iterdir()) if p.is_file()))
