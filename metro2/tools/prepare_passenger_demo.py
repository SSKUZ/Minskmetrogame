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
# Preserve the original game's Web renderer workarounds and import settings.
# In Godot 4.3 single-threaded Web, losing threaded_cull_minimum_instances.web
# makes large scenes render only their background (godotengine/godot#88192).
project=(ROOT/'project.godot').read_text()
project=re.sub(r'config/name="[^"]*"','config/name="МИНСКОЕ МЕТРО 2.0 — УРУЧЬЕ"',project)
project=re.sub(r'run/main_scene="[^"]*"','run/main_scene="res://scenes/passengers/uruchye_game_boot.tscn"',project)
project=re.sub(r'window/size/viewport_width=\d+','window/size/viewport_width=960',project)
project=re.sub(r'window/size/viewport_height=\d+','window/size/viewport_height=540',project)
project=project.replace('[rendering]','window/stretch/mode="canvas_items"\nwindow/stretch/aspect="expand"\n\n[rendering]',1)
(out/'project.godot').write_text(project)
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
