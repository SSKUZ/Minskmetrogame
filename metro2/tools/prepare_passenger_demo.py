#!/usr/bin/env python3
"""Stage only the passenger demo dependency closure for its single Web export."""
import json,re,shutil,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
queue=['scenes/passengers/uruchye_game_boot.tscn']
for folder in ['assets/passengers','assets/saloon_v46','assets/saloon_v49']:
    queue.extend(str(p.relative_to(ROOT)) for p in (ROOT/folder).rglob('*') if p.is_file() and not p.name.endswith('.import') and (p.suffix!='.glb' or p.name.endswith('-low.glb')))
seen=set()
while queue:
    name=queue.pop()
    if name in seen:continue
    seen.add(name);source=ROOT/name
    if source.is_dir():
        queue.extend(str(p.relative_to(ROOT)) for p in source.rglob('*') if p.is_file() and not p.name.endswith('.import'));continue
    if not source.is_file():raise RuntimeError('Missing export dependency: '+name)
    target=out/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    sidecar=Path(str(source)+'.import')
    if sidecar.is_file():shutil.copy2(sidecar,str(target)+'.import')
    if source.suffix in {'.gd','.tscn','.tres','.json','.gdshader'}:
        queue.extend(re.findall(r"res://([^\"'\s]+)",source.read_text()))
(out/'project.godot').write_text('''config_version=5
[application]
config/name="МИНСКОЕ МЕТРО 2.0 — УРУЧЬЕ"
run/main_scene="res://scenes/passengers/uruchye_game_boot.tscn"
[display]
window/size/viewport_width=960
window/size/viewport_height=540
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
''')
(out/'export_presets.cfg').write_text('''[preset.0]
name="Web Passenger Demo"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="*.json"
exclude_filter=""
export_path="index.html"
[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
''')
print('Passenger demo staged')
