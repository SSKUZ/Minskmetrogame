#!/usr/bin/env python3
"""Stage the standalone viewer and its dependency closure; never edit the game entry point."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]


def stage(destination: Path) -> None:
    destination = destination.resolve()
    if destination == ROOT or ROOT in destination.parents:
        raise SystemExit('Use a separate staging directory outside metro2')
    if destination.exists() and any(destination.iterdir()):
        raise SystemExit('Staging directory must be empty')
    destination.mkdir(parents=True, exist_ok=True)
    queue = ['project.godot', 'tests/module_viewer_v48_smoke.gd', 'tests/viewer_portrait_layout.gd', 'tests/viewer_joystick_input.gd']
    for folder in ['modules', 'viewers', 'assets/saloon_v46']:
        queue += [str(p.relative_to(ROOT)) for p in (ROOT / folder).rglob('*') if p.is_file() and p.suffix != '.uid']
    seen = set()
    while queue:
        name = queue.pop()
        if name in seen:
            continue
        seen.add(name)
        source = ROOT / name
        if source.is_dir():
            continue
        if not source.is_file():
            raise SystemExit('Missing viewer dependency (restore original assets first): ' + name)
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.suffix in ('.glb', '.png', '.svg', '.mp3'):
            # Local build staging reuses the same bytes/inode where supported.
            try:
                os.link(source, target)
            except OSError:
                shutil.copy2(source, target)
            sidecar = Path(str(source) + '.import')
            if sidecar.is_file():
                shutil.copy2(sidecar, str(target) + '.import')
        else:
            shutil.copy2(source, target)
        if source.suffix in ('.gd', '.tscn', '.gdshader'):
            queue += re.findall(r'''res://([^"'\s]+)''', source.read_text())
    project = (ROOT / 'project.godot').read_text()
    project = re.sub(r'run/main_scene="[^"]+"', 'run/main_scene="res://viewers/module_viewer.tscn"', project)
    project = project.replace('config/name="Minsk Metro 2.0 - Station V106 Integration"', 'config/name="Minsk Metro 2.0 - Module Viewer V48"')
    # Use an expanding minimum axis so portrait and landscape both fill the viewport.
    project = project.replace('window/size/viewport_width=1280','window/size/viewport_width=480')
    project = project.replace('window/size/viewport_height=720', 'window/size/viewport_height=480\nwindow/stretch/mode="canvas_items"\nwindow/stretch/aspect="expand"')
    (destination / 'project.godot').write_text(project)
    (destination / 'export_presets.cfg').write_text('''[preset.0]
name="Web Viewer"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="*.json"
exclude_filter="tests/*,modules/*.md,viewers/*.md"
export_path="build/web/index.html"

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
    manifest = {name: hashlib.sha256((destination / name).read_bytes()).hexdigest()
                for name in sorted(seen) if (destination / name).is_file()}
    (destination / 'viewer-dependencies.json').write_text(json.dumps(manifest, indent=2))
    for required in ['modules/core/module_catalog.gd', 'viewers/module_viewer.tscn',
                     'modules/stations/uruchye/uruchye.tscn', 'modules/depot/depot.tscn',
                     'modules/tunnels/tunnel_section_16m.tscn', 'viewers/v106_inspection.tscn']:
        assert required in manifest, required
    print('VIEWER_STAGE_READY', destination, 'dependencies=', len(manifest))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    stage(parser.parse_args().output)
