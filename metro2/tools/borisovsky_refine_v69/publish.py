"""Build only the revised Borisovsky station; keep the current permanent viewer and other packs."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];OUT=Path(sys.argv[2]).resolve();OUT.mkdir(parents=True,exist_ok=True)
PREFIX='metro2/module-viewer/';KEY='borisovsky_trakt';MODULE=Path('modules/stations')/KEY
DEPS=['scripts/playable_track_path.gd','scripts/infrastructure/station_infrastructure.gd']
def show(ref,path):return subprocess.check_output(['git','show',ref+':'+PREFIX+path])
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(args,log):
 with (OUT/'logs'/log).open('w') as f:subprocess.run(args,stdout=f,stderr=subprocess.STDOUT,check=True)
 text=(OUT/'logs'/log).read_text()
 if any(x in text for x in ['SCRIPT ERROR','Parse Error','Failed to load']):raise RuntimeError(text)
mode=sys.argv[1]
if mode=='prepare':
 ref=sys.argv[3]
 for folder in ['web','logs']:(OUT/folder).mkdir(exist_ok=True)
 for path in ['module-packs.json','build-info.json','pack-resources.json']:(OUT/'web'/path).write_bytes(show(ref,path))
elif mode=='build':
 stage=Path(os.environ['RUNNER_TEMP'])/'borisovsky-v69-import';stage.mkdir(exist_ok=True)
 # Original photos and analytical contact sheets are source references, never Web payload.
 shutil.copytree(ROOT/MODULE,stage/MODULE,dirs_exist_ok=True,ignore=shutil.ignore_patterns('references_v69','ad_*.svg','*.import','*.uid'))
 for name in DEPS:
  p=stage/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,p)
 (stage/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Borisovsky Trakt V69"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/vram_compression/import_s3tc_bptc=true\n')
 (stage/'export_presets.cfg').write_text('''[preset.0]
name="Web Station"
platform="Web"
runnable=false
export_filter="all_resources"
include_filter="*.json,*.md,*.txt"
exclude_filter=""
export_path="station.pck"
[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=false
''')
 templates=Path.home()/'.local/share/godot/export_templates';templates.mkdir(parents=True,exist_ok=True)
 source=Path('/root/.local/share/godot/export_templates')
 if source.exists() and templates.resolve()!=source.resolve():shutil.copytree(source,templates,dirs_exist_ok=True)
 run(['godot','--headless','--editor','--path',str(stage),'--import'],'station-import.log')
 for imported in (stage/MODULE).rglob('*.import'):
  imported.write_text(imported.read_text().replace('mipmaps/generate=false','mipmaps/generate=true'))
 run(['godot','--headless','--editor','--path',str(stage),'--import'],'station-mipmaps.log')
 run(['godot','--headless','--path',str(stage),'--export-pack','Web Station',str(OUT/'station.pck')],'station-export.log')
elif mode=='finish':
 manifest=json.loads((OUT/'web/module-packs.json').read_text());info=json.loads((OUT/'web/build-info.json').read_text());report=json.loads((OUT/'web/pack-resources.json').read_text())
 p=OUT/'station.pck';digest=sha(p);name=KEY+'-'+digest[:20]+'.pck';p.rename(OUT/'web'/name)
 textures=sorted('res://'+str(p.relative_to(ROOT)) for p in (ROOT/MODULE/'art_v69').iterdir() if p.suffix.lower() in ['.svg','.jpg','.png'] and not p.name.startswith('ad_'))
 entry={'file':name,'sha256':digest,'bytes':(OUT/'web'/name).stat().st_size,'warmup':textures}
 manifest['packs'][KEY]=entry;info.setdefault('module_packs',{})[KEY]=entry
 report['resources'][KEY]=sorted('res://'+str(p.relative_to(ROOT)) for p in (ROOT/MODULE).rglob('*') if p.is_file() and 'references_v69' not in p.parts and not p.name.startswith('ad_') and p.suffix in ['.gd','.tscn','.svg','.jpg','.png','.md','.ttf','.txt','.json'])+['res://'+p for p in DEPS]
 report.setdefault('entries',{})[KEY]=str(MODULE/(KEY+'.tscn'))
 info['borisovsky_refinement_v69']={'source_commit':os.environ['GITHUB_SHA'],'references':'Owner photos 6715,6717,6720,6724,6726,6728,6731,6732; all 806 frames of 6723.mp4 decoded and reviewed in 13 contact sheets; six keyframes retained with source notes','features':'Native raised Belarusian lettering with custom photo-informed contours and bronze edges; interrupted triple metal wall blades and sloping ends; photographic marble and red-brown plinth; wide dark central floor field with access covers and drains; alternating round columns and bench piers with polished metal double-ring belts, curved timber seating and steel head panels; flat maroon ribbed central soffit with rounded fascias and fluorescent tubes, white curved ribs and globe rows; grey granite stair flight with clear roof opening and enclosed upper hall; fitted bilingual route/exit signs; platform mirrors and retained four portal clocks/contact rails','limitations':'Reference-based dimensions and fixture spacing retain the existing Station Base footprint and are not a measured survey. Letter outlines are manually redrawn approximations. Hidden upper areas are a modest inferred continuation; unrelated stations are not rebuilt. Existing information monitors remain neutral.','validation':'Mandatory Godot 4.3 resource import, mipmaps, Web PCK export and publication only; no game, scene, browser, visual or performance tests'}
 for name,data in [('module-packs.json',manifest),('build-info.json',info),('pack-resources.json',report)]:
  (OUT/'web'/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 (OUT/'web/SHA256SUMS-borisovsky-v69').write_text(''.join(sha(p)+'  '+p.name+'\n' for p in sorted((OUT/'web').iterdir()) if p.is_file()))
