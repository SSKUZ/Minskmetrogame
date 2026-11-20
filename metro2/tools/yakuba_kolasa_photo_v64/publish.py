"""Export the new Yakuba Kolasa station and extend the existing viewer; preserve every published existing pack."""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];OUT=Path(sys.argv[2]);OUT.mkdir(parents=True,exist_ok=True)
PREFIX='metro2/module-viewer/'
NAMES={'yakuba_kolasa':'Площадь Якуба Коласа'}
DEPS=['scripts/playable_track_path.gd','scripts/infrastructure/station_infrastructure.gd']
BOOT=['viewers/module_viewer.gd','modules/core/module_catalog.gd']
def show(ref,path):return subprocess.check_output(['git','show',ref+':'+PREFIX+path])
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def config(html):
 m=re.search(r'const GODOT_CONFIG\s*=\s*(\{[^\n]+\});',html)
 if not m:raise RuntimeError('Unknown viewer boot configuration')
 return m,json.loads(m[1])
def run(args,log,env=None):
 with (OUT/'logs'/log).open('w') as f:subprocess.run(args,env=env,stdout=f,stderr=subprocess.STDOUT,check=True)
 text=(OUT/'logs'/log).read_text()
 if any(x in text for x in ['SCRIPT ERROR','Parse Error','Failed to load']):raise RuntimeError(text)
mode=sys.argv[1]
if mode=='prepare':
 ref=sys.argv[3]
 for folder in ['web','logs']:(OUT/folder).mkdir(exist_ok=True)
 for path in ['index.html','module-packs.json','build-info.json','pack-resources.json']:(OUT/'web'/path).write_bytes(show(ref,path))
 html=(OUT/'web/index.html').read_text();_,cfg=config(html)
 (OUT/'old-boot.pck').write_bytes(show(ref,cfg['mainPack']))
 (OUT/'base.json').write_text(json.dumps({'boot':cfg['mainPack']}))
elif mode=='build':
 temp=Path(os.environ['RUNNER_TEMP'])
 templates=Path.home()/'.local/share/godot/export_templates';templates.mkdir(parents=True,exist_ok=True)
 source=Path('/root/.local/share/godot/export_templates')
 if source.exists() and templates.resolve()!=source.resolve():shutil.copytree(source,templates,dirs_exist_ok=True)
 for key in NAMES:
  stage=temp/('station-v64-'+key);stage.mkdir(exist_ok=True)
  module=Path('modules/stations')/key
  shutil.copytree(ROOT/module,stage/module,dirs_exist_ok=True)
  for name in DEPS:
   p=stage/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,p)
  (stage/'project.godot').write_text('config_version=5\n[application]\nconfig/name="'+NAMES[key]+' station module"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/vram_compression/import_s3tc_bptc=true\n')
  (stage/'export_presets.cfg').write_text('''[preset.0]
name="Web Station"
platform="Web"
runnable=false
export_filter="all_resources"
include_filter="*.md,*.txt,*.json"
export_path="station.pck"
[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=false
''')
  run(['godot','--headless','--editor','--path',str(stage),'--import'],key+'-import.log')
  # Generate mipmaps for oblique stone and small printed signage.
  for imported in (stage/module/'art').glob('*.import'):
   imported.write_text(imported.read_text().replace('mipmaps/generate=false','mipmaps/generate=true'))
  run(['godot','--headless','--editor','--path',str(stage),'--import'],key+'-mipmaps.log')
  run(['godot','--headless','--path',str(stage),'--export-pack','Web Station',str((OUT/(key+'.pck')).resolve())],key+'-export.log')
 # Import viewer support scripts for the new menu entry.
 stage=temp/'station-v64-menu-import';stage.mkdir(exist_ok=True)
 for name in BOOT+['viewers/inspection_camera.gd','viewers/flight_joystick.gd','viewers/module_pack_loader.gd']:
  p=stage/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,p)
 (stage/'project.godot').write_text('config_version=5\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
 run(['godot','--headless','--editor','--path',str(stage),'--import'],'menu-import.log')
 isolated=temp/'station-v64-boot';isolated.mkdir(exist_ok=True);(isolated/'project.godot').write_text('config_version=5\n')
 env=dict(os.environ,PATCH_INPUT=str((OUT/'old-boot.pck').resolve()),PATCH_OUTPUT=str((OUT/'new-boot.pck').resolve()),PATCH_SOURCE=str(ROOT),PATCH_MODE='pack',PATCH_FILES=json.dumps(BOOT))
 run(['godot','--headless','--path',str(isolated),'--script',str(ROOT/'tools/yakuba_kolasa_photo_v64/patch_boot.gd')],'menu-pack.log',env)
elif mode=='finish':
 manifest=json.loads((OUT/'web/module-packs.json').read_text());info=json.loads((OUT/'web/build-info.json').read_text());report=json.loads((OUT/'web/pack-resources.json').read_text())
 for key,title in NAMES.items():
  p=OUT/(key+'.pck');digest=sha(p);name=key+'-'+digest[:20]+'.pck';p.rename(OUT/'web'/name)
  entry={'file':name,'sha256':digest,'bytes':(OUT/'web'/name).stat().st_size,'warmup':[]}
  manifest['modules'][key]=[key];manifest['names'][key]=title;manifest['packs'][key]=entry
  info.setdefault('module_packs',{})[key]=entry
  module=Path('modules/stations')/key
  report['resources'][key]=sorted('res://'+str(p.relative_to(ROOT)) for p in (ROOT/module).rglob('*') if p.suffix in ['.gd','.tscn','.svg','.jpg','.png','.md','.ttf','.txt','.json'])+['res://'+p for p in DEPS]
  report.setdefault('entries',{})[key]=str(module/(key+'.tscn'))
 p=OUT/'new-boot.pck';digest=sha(p);name='boot-'+digest[:20]+'.pck';p.rename(OUT/'web'/name)
 html=(OUT/'web/index.html').read_text();m,cfg=config(html);base=json.loads((OUT/'base.json').read_text())
 cfg['mainPack']=name;cfg['fileSizes'].pop(base['boot'],None);cfg['fileSizes'][name]=(OUT/'web'/name).stat().st_size
 html=html[:m.start(1)]+json.dumps(cfg,separators=(',',':'))+html[m.end(1):];(OUT/'web/index.html').write_text(html)
 info['yakuba_kolasa_photo_v64']={'source_commit':os.environ['GITHUB_SHA'],'stations':NAMES,'boot':name,'references':'40 owner photographs from Yakuba Kolasa archive; no videos in archive','features':'13 distinct front compositions on 13 opposing column pairs; common wheat ornament; photo-derived geometric relief meshes with normal maps and physical octagonal rims; white chevron-plan ceiling ribs, side coffer braces and continuous girder lighting; pale marble walls, reddish granite plinth, longitudinal red/tan floor bands; photographed bilingual hanging signs, station 118 route panels, stairs, three escalators, mirrors, clocks and CCTV','limitations':'Motif inventory represents distinct front compositions visible in the supplied archive; opposite columns are paired by owner instruction; unknown column faces repeat the documented front; relief depth and unsurveyed dimensions are estimated from photographs; hidden vestibules omitted','validation':'Mandatory Godot resource import, mipmaps and native Web pack export only; no scene, game, visual, browser or performance tests'}
 for name,data in [('module-packs.json',manifest),('build-info.json',info),('pack-resources.json',report)]:
  (OUT/'web'/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 (OUT/'web/SHA256SUMS-yakuba-kolasa-v64').write_text(''.join(sha(p)+'  '+p.name+'\n' for p in sorted((OUT/'web').iterdir()) if p.is_file()))
