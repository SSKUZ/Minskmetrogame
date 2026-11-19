"""Export only the photo-reconstructed Moskovskaya pack; preserve the live viewer and all other modules."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];OUT=Path(sys.argv[2]);OUT.mkdir(parents=True,exist_ok=True)
PREFIX='metro2/module-viewer/'
NAMES={'moskovskaya':'Московская'}
DEPS=['scripts/playable_track_path.gd','scripts/infrastructure/station_infrastructure.gd']
def show(ref,path):return subprocess.check_output(['git','show',ref+':'+PREFIX+path])
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(args,log):
 with (OUT/'logs'/log).open('w') as f:subprocess.run(args,stdout=f,stderr=subprocess.STDOUT,check=True)
 text=(OUT/'logs'/log).read_text()
 if any(x in text for x in ['SCRIPT ERROR','Parse Error','Failed to load']):raise RuntimeError(text)
mode=sys.argv[1]
if mode=='prepare':
 ref=sys.argv[3]
 for folder in ['web','logs']:(OUT/folder).mkdir(exist_ok=True)
 for name in ['module-packs.json','build-info.json','pack-resources.json']:(OUT/'web'/name).write_bytes(show(ref,name))
elif mode=='build':
 temp=Path(os.environ['RUNNER_TEMP'])
 templates=Path.home()/'.local/share/godot/export_templates';templates.mkdir(parents=True,exist_ok=True)
 source=Path('/root/.local/share/godot/export_templates')
 if source.exists() and source.resolve()!=templates.resolve():shutil.copytree(source,templates,dirs_exist_ok=True)
 for key in NAMES:
  stage=temp/('station-v60-'+key);stage.mkdir(exist_ok=True)
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
exclude_filter="*moscow_mural_*.jpg,*mosaic_*.svg,*kremlin_clock.svg,*direction_*.svg,*name_*.svg,*network.svg,*line.svg,*exit.svg"
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
  # Generate mip levels for stable oblique marble, floor and sign rendering on mobile.
  for imported in (stage/module/'art').glob('*.import'):
   settings=imported.read_text().replace('mipmaps/generate=false','mipmaps/generate=true');imported.write_text(settings)
  run(['godot','--headless','--editor','--path',str(stage),'--import'],key+'-mipmaps.log')
  run(['godot','--headless','--path',str(stage),'--export-pack','Web Station',str((OUT/(key+'.pck')).resolve())],key+'-export.log')
elif mode=='finish':
 manifest=json.loads((OUT/'web/module-packs.json').read_text());info=json.loads((OUT/'web/build-info.json').read_text());report=json.loads((OUT/'web/pack-resources.json').read_text())
 for key in NAMES:
  p=OUT/(key+'.pck');sha=digest(p);name=key+'-'+sha[:20]+'.pck';p.rename(OUT/'web'/name)
  entry=dict(manifest['packs'][key]);entry.update(file=name,sha256=sha,bytes=(OUT/'web'/name).stat().st_size);manifest['packs'][key]=entry
  info.setdefault('module_packs',{})[key]=entry
  module=Path('modules/stations')/key
  report['resources'][key]=sorted('res://'+str(p.relative_to(ROOT)) for p in (ROOT/module).rglob('*') if p.is_file() and p.suffix in ['.gd','.tscn','.svg','.jpg','.md','.ttf','.txt','.json'])+['res://'+p for p in DEPS]
 info['moskovskaya_photo_v60']={'source_commit':os.environ['GITHUB_SHA'],'stations':NAMES,'changes':'Owner photographs and both videos: fluted marble columns, white rounded transverse ceiling ribs, girder-edge lighting, red/grey granite floor grid, real marble-inlay imagery, raised bronze lettering, accurate bilingual signs, five-seat backless benches, animated advertising screens, portal mirrors and CCTV monitors','validation':'Godot 4.3 resource import and native Web pack export only; no gameplay/browser/performance tests','limitations':'Dimensions, fixture counts and concealed rooms remain estimates; mosaic sections are rectified photo/video samples, not a surveyed panorama; advertising is an original animated vector loop; nearest visible mirror updates at 6 Hz'}
 for name,data in [('module-packs.json',manifest),('build-info.json',info),('pack-resources.json',report)]:
  (OUT/'web'/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 (OUT/'web/SHA256SUMS-moskovskaya-photo-v60').write_text(''.join(digest(p)+'  '+p.name+'\n' for p in sorted((OUT/'web').iterdir()) if p.is_file()))
