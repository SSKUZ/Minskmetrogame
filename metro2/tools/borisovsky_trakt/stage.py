"""Stage only this station, mandatory editor import, and one Godot Web pack export."""
from pathlib import Path
import shutil,sys
root=Path(__file__).resolve().parents[2]; out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
module='modules/stations/borisovsky_trakt'
for p in (root/module).rglob('*'):
 if p.is_file() and p.suffix in {'.gd','.tscn','.jpg','.png'}:
  target=out/p.relative_to(root);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
target=out/'scripts/playable_track_path.gd';target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/'scripts/playable_track_path.gd',target)
(out/'project.godot').write_text('config_version=5\n\n[application]\nconfig/name="Borisovsky Trakt module"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/vram_compression/import_s3tc_bptc=true\n')
(out/'export_presets.cfg').write_text('''[preset.0]
name="Web Station"
platform="Web"
runnable=false
export_filter="all_resources"
export_path="station.pck"

[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=false
''')
