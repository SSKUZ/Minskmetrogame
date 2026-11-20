"""Replace Uruchye route artwork only; preserve the current live station pack."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];OUT=Path(sys.argv[2]);OUT.mkdir(parents=True,exist_ok=True)
PREFIX='metro2/module-viewer/';KEY='uruchye'
FILES=['scripts/station/uruchye_architecture.gd'];ART='assets/signage_v63/uruchye_route.svg'
def show(ref,path):return subprocess.check_output(['git','show',ref+':'+PREFIX+path])
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(args,log,env=None):
 with (OUT/'logs'/log).open('w') as f:subprocess.run(args,env=env,stdout=f,stderr=subprocess.STDOUT,check=True)
 s=(OUT/'logs'/log).read_text()
 if any(x in s for x in ['SCRIPT ERROR','Parse Error','Failed to load']):raise RuntimeError(s)
mode=sys.argv[1]
if mode=='prepare':
 ref=sys.argv[3]
 for folder in ['web','logs']:(OUT/folder).mkdir(exist_ok=True)
 for name in ['module-packs.json','build-info.json','pack-resources.json']:(OUT/'web'/name).write_bytes(show(ref,name))
 manifest=json.loads((OUT/'web/module-packs.json').read_text());(OUT/'old.pck').write_bytes(show(ref,manifest['packs'][KEY]['file']))
elif mode=='build':
 temp=Path(os.environ['RUNNER_TEMP']);stage=temp/'route-v63-import';stage.mkdir(exist_ok=True)
 p=stage/ART;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/ART,p)
 (stage/'project.godot').write_text('config_version=5\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/vram_compression/import_s3tc_bptc=true\n')
 run(['godot','--headless','--editor','--path',str(stage),'--import'],'art-import.log')
 imported=Path(str(p)+'.import');imported.write_text(imported.read_text().replace('mipmaps/generate=false','mipmaps/generate=true'))
 run(['godot','--headless','--editor','--path',str(stage),'--import'],'art-mipmaps.log')
 isolated=temp/'route-v63-packer';isolated.mkdir(exist_ok=True);(isolated/'project.godot').write_text('config_version=5\n')
 env=dict(os.environ,PATCH_SOURCE=str(ROOT),PATCH_INPUT=str((OUT/'old.pck').resolve()),PATCH_OUTPUT=str((OUT/'new.pck').resolve()),PATCH_MODE='pack',PATCH_FILES=json.dumps(FILES),PATCH_ART=str(stage),PATCH_ASSETS=json.dumps([ART]))
 run(['godot','--headless','--path',str(isolated),'--script',str(ROOT/'tools/artwork_v54/patch_pack.gd')],'route-pack.log',env)
elif mode=='finish':
 manifest=json.loads((OUT/'web/module-packs.json').read_text());info=json.loads((OUT/'web/build-info.json').read_text());report=json.loads((OUT/'web/pack-resources.json').read_text())
 p=OUT/'new.pck';sha=digest(p);name='uruchye-'+sha[:20]+'.pck';p.rename(OUT/'web'/name)
 entry=dict(manifest['packs'][KEY]);entry.update(file=name,sha256=sha,bytes=(OUT/'web'/name).stat().st_size)
 entry['warmup']=sorted(set(x for x in entry.get('warmup',[]) if x!='res://assets/station/photo_reference/route.png')|{'res://'+ART})
 manifest['packs'][KEY]=entry;info.setdefault('module_packs',{})[KEY]=entry
 report['resources'][KEY]=sorted(set(report['resources'].get(KEY,[]))|{'res://'+ART+'.remap'}|{'res://'+p for p in FILES})
 info['uruchye_route_signs_v63']={'source_commit':os.environ['GITHUB_SHA'],'changes':'Uruchye only: all four wall maps and eight faces of the four suspended route boards use aligned blue diagonal station cells with white separators; only station 124 Uruchye is yellow; bilingual transfer names and codes 115/314 to line 3 Vokzalnaya, 116/216 to line 2 Kupalovskaya; corrected artwork aspect ratio','preserved':'All other station packs, including Vostok, and existing Uruchye no-boarding/exit boards unchanged','validation':'Resource import, mipmaps and native PCK packaging only; no scene, visual, browser, game or performance tests'}
 for name,data in [('module-packs.json',manifest),('build-info.json',info),('pack-resources.json',report)]:
  (OUT/'web'/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 (OUT/'web/SHA256SUMS-uruchye-route-v63').write_text(''.join(digest(p)+'  '+p.name+'\n' for p in sorted((OUT/'web').iterdir()) if p.is_file()))
