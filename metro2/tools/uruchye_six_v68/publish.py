"""Apply six owner corrections to the current Uruchye pack; preserve other published modules."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];OUT=Path(sys.argv[2]);OUT.mkdir(parents=True,exist_ok=True)
PREFIX='metro2/module-viewer/';KEY='uruchye'
FILES=['scripts/station/uruchye_architecture.gd','scripts/station/uruchye_tracks_v68.gd','assets/station/uruchye_v68/FONT_LICENSE.txt']
ASSETS=['assets/station/uruchye_v68/'+n for n in ['route_arrived.svg','security.svg','upper_exit.svg','station_letters.ttf']]
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
 temp=Path(os.environ['RUNNER_TEMP']);stage=temp/'uruchye-v68-import';stage.mkdir(exist_ok=True)
 isolated=temp/'uruchye-v68-packer';isolated.mkdir(exist_ok=True);(isolated/'project.godot').write_text('config_version=5\n')
 # Unpack the current published station so all existing textures, scene dependencies and equipment survive.
 env=dict(os.environ,PATCH_SOURCE=str(ROOT),PATCH_INPUT=str((OUT/'old.pck').resolve()),PATCH_OUTPUT=str(stage),PATCH_MODE='unpack',PATCH_FILES=json.dumps(FILES),PATCH_ASSETS='[]')
 run(['godot','--headless','--path',str(isolated),'--script',str(ROOT/'tools/artwork_v54/patch_pack.gd')],'unpack-current-pack.log',env)
 for asset in ASSETS:
  p=stage/asset;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/asset,p)
 (stage/'project.godot').write_text('config_version=5\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/vram_compression/import_s3tc_bptc=true\n')
 run(['godot','--headless','--editor','--path',str(stage),'--import'],'station-resource-import.log')
 for asset in ASSETS:
  if asset.endswith('.svg'):
   imported=Path(str(stage/asset)+'.import');imported.write_text(imported.read_text().replace('mipmaps/generate=false','mipmaps/generate=true'))
 run(['godot','--headless','--editor','--path',str(stage),'--import'],'art-mipmaps.log')
 env=dict(os.environ,PATCH_SOURCE=str(ROOT),PATCH_INPUT=str((OUT/'old.pck').resolve()),PATCH_OUTPUT=str((OUT/'new.pck').resolve()),PATCH_MODE='pack',PATCH_FILES=json.dumps(FILES),PATCH_ART=str(stage),PATCH_ASSETS=json.dumps(ASSETS))
 run(['godot','--headless','--path',str(isolated),'--script',str(ROOT/'tools/artwork_v54/patch_pack.gd')],'station-pack.log',env)
elif mode=='finish':
 manifest=json.loads((OUT/'web/module-packs.json').read_text());info=json.loads((OUT/'web/build-info.json').read_text());report=json.loads((OUT/'web/pack-resources.json').read_text())
 p=OUT/'new.pck';sha=digest(p);name='uruchye-'+sha[:20]+'.pck';p.rename(OUT/'web'/name)
 entry=dict(manifest['packs'][KEY]);entry.update(file=name,sha256=sha,bytes=(OUT/'web'/name).stat().st_size)
 # module_pack_loader.gd loads every warmup entry strictly as Texture2D.
 # Keep the font in the PCK for TextMesh, but never enqueue it as a texture.
 texture_suffixes=('.svg','.png','.jpg','.jpeg','.webp','.ctex')
 entry['warmup']=sorted({p for p in entry.get('warmup',[]) if p.lower().endswith(texture_suffixes)}|{'res://'+a for a in ASSETS if a.lower().endswith(texture_suffixes)})
 manifest['packs'][KEY]=entry;info.setdefault('module_packs',{})[KEY]=entry
 report['resources'][KEY]=sorted(set(report['resources'].get(KEY,[]))|{'res://'+a+'.remap' for a in ASSETS}|{'res://'+p for p in FILES})
 info['uruchye_six_v68']={'source_commit':os.environ['GITHUB_SHA'],'changes':{'1_route':'No-boarding wall side: station 124 Uruchye leftmost in yellow, 123 to 110 in grey to the right; departure side and hanging boards retained','2_exits':'Both paired stairways open into visible upper landings and enclosed lit concourses, gate rows, wide gates, security booths and upper exit doors','3_enclosure':'Solid stair construction, complete concourse plinths, side and back walls; low ceilings and lamp pieces stop before the ascending flights, end-facade openings connect upper floors','4_tracks':'Native rail foot/web/head profiles at unchanged y=0 rail datum and 1.615m gauge, dark raised grainy sleepers, bearing plates, clips, bolts, ballast and covered contact rails on ceramic insulators on both tracks; original simple running geometry hidden, original plain contact pieces replaced without touching clocks','5_door':'Detached metal poles before both service doors removed; central round column nearest north service door omitted entirely','6_names':'Native extruded silver metal station letters with real side faces and raised blue water emblem: Uruchye in Russian on one wall and Uruchcha in Belarusian on the other'},'references':'Owner photographs 6695-6709; Borisovsky Trakt 6714-6720 used only as comparative navigation/stair references','limitations':'Upper gate/security areas are inferred visual extensions requested by the owner; no measured vestibule survey or detailed upper-room photos. Physical Cyrillic letters use a bundled font, so the stylised original letter contours are approximated. No gameplay gate or security simulation.','validation':'Mandatory native Godot 4.3 resource import/mipmaps/PCK packaging and publication only; no scene, game, browser, visual or performance tests'}
 for name,data in [('module-packs.json',manifest),('build-info.json',info),('pack-resources.json',report)]:
  (OUT/'web'/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 (OUT/'web/SHA256SUMS-uruchye-six-v68').write_text(''.join(digest(p)+'  '+p.name+'\n' for p in sorted((OUT/'web').iterdir()) if p.is_file()))
