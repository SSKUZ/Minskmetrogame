"""Native Web export of the three rebuilt stations; viewer boot and other packs stay intact."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];OUT=Path(sys.argv[2]);OUT.mkdir(parents=True,exist_ok=True)
PREFIX='metro2/module-viewer/'
NAMES={'vostok':'Восток','moskovskaya':'Московская','park_chelyuskintsev':'Парк Челюскинцев'}
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
  stage=temp/('station-v58-'+key);stage.mkdir(exist_ok=True)
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
include_filter="*.md"
export_path="station.pck"
[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=false
''')
  run(['godot','--headless','--editor','--path',str(stage),'--import'],key+'-import.log')
  run(['godot','--headless','--path',str(stage),'--export-pack','Web Station',str((OUT/(key+'.pck')).resolve())],key+'-export.log')
elif mode=='finish':
 manifest=json.loads((OUT/'web/module-packs.json').read_text());info=json.loads((OUT/'web/build-info.json').read_text());report=json.loads((OUT/'web/pack-resources.json').read_text())
 for key in NAMES:
  p=OUT/(key+'.pck');sha=digest(p);name=key+'-'+sha[:20]+'.pck';p.rename(OUT/'web'/name)
  entry=dict(manifest['packs'][key]);entry.update(file=name,sha256=sha,bytes=(OUT/'web'/name).stat().st_size);manifest['packs'][key]=entry
  info.setdefault('module_packs',{})[key]=entry
  module=Path('modules/stations')/key
  report['resources'][key]=sorted('res://'+str(p.relative_to(ROOT)) for p in (ROOT/module).rglob('*') if p.is_file() and p.suffix in ['.gd','.tscn','.svg','.jpg','.md'])+['res://'+p for p in DEPS]
 info['station_realism_v58']={'source_commit':os.environ['GITHUB_SHA'],'stations':NAMES,'changes':'curved Vostok light coffers; native cast-glass chandelier prototype and sculpted Park vault; real licensed Moscow mosaics, fluted columns, rounded coffer beams and live stair clocks; joined upper vestibules','credits':'station-photo-credits-v58.html','validation':'Godot 4.3 mandatory resource import and native Web pack export only; no scene/game/browser/visual/performance tests','limitations':'Station Base dimensions and element spacing remain scaled estimates; full hidden corridors and street surroundings are not reconstructed'}
 for name,data in [('module-packs.json',manifest),('build-info.json',info),('pack-resources.json',report)]:
  (OUT/'web'/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 credits=(ROOT/'modules/stations/moskovskaya/ART_CREDITS.md').read_text()
 import html
 (OUT/'web/station-photo-credits-v58.html').write_text('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Station photograph credits</title><body style="max-width:900px;margin:32px auto;font:16px sans-serif;line-height:1.5"><h1>Station photograph credits</h1><p>Photographs by Antares 610, Wikimedia Commons, licensed under <a href="https://creativecommons.org/licenses/by-sa/3.0/">CC BY-SA 3.0</a>. The photographs are unmodified Wikimedia previews; selected regions are displayed on station wall geometry using UV coordinates. These photo-derived displays remain CC BY-SA 3.0.</p><ul>'+''.join('<li><a href="https://commons.wikimedia.org/wiki/File:Maskousk_'+str(n).zfill(2)+'.jpg">Maskousk '+str(n).zfill(2)+'.jpg</a> — Antares 610, 19 September 2011</li>' for n in [10,11,12,13,14,21])+'</ul><p>No photographer endorsement is implied.</p><pre style="white-space:pre-wrap">'+html.escape(credits)+'</pre></body></html>')
 (OUT/'web/SHA256SUMS-station-realism-v58').write_text(''.join(digest(p)+'  '+p.name+'\n' for p in sorted((OUT/'web').iterdir()) if p.is_file()))
