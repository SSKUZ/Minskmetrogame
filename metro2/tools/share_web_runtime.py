#!/usr/bin/env python3
"""Share identical Godot WASM in legacy diagnostic previews; keep all game packs.
The working Three.js, three-car scene and TZ30/31/32/33 pages are untouched.
"""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

root=Path(sys.argv[1]).resolve()
base=root/'metro2/index'
folders=['lite','probe','v106-car04-only','v106-one','v106-rails','v106-static-lights','v106-tunnel-fix','v106-two-cars']
def digest(path):
    with path.open('rb') as stream:
        h=hashlib.sha256()
        for chunk in iter(lambda:stream.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()
def total():
    names=subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0')
    return sum((root/p).stat().st_size for p in names if p and (root/p).is_file())

original=total()
reference={ext:digest(Path(str(base)+ext)) for ext in ['.wasm','.js','.audio.worklet.js']}
changes=[]
# Validate every candidate before changing any published file.
for folder in folders:
    directory=root/'metro2'/folder
    wasm=directory/'index.wasm'
    if not wasm.exists():continue
    for ext in reference:
        if digest(directory/('index'+ext))!=reference[ext]:
            raise RuntimeError('Different engine runtime: '+folder+ext)
    html=directory/'index.html'
    text=html.read_text()
    match=re.search(r'const GODOT_CONFIG\s*=\s*(\{[^\n]+\});',text)
    if not match:raise RuntimeError('Unknown Godot HTML configuration: '+folder)
    config=json.loads(match.group(1))
    if config.get('executable')!='index' or config.get('serviceWorker'):
        raise RuntimeError('Unsupported runtime configuration: '+folder)
    config['executable']='/Minskmetrogame/metro2/index'
    config['mainPack']='index.pck'
    sizes=config.get('fileSizes',{})
    if 'index.wasm' in sizes:
        sizes['/Minskmetrogame/metro2/index.wasm']=sizes.pop('index.wasm')
    replacement='const GODOT_CONFIG = '+json.dumps(config,separators=(',',':'))+';'
    changes.append((html,text[:match.start()]+replacement+text[match.end():],wasm))
for html,text,wasm in changes:
    html.write_text(text)
    wasm.unlink()
    print('Shared engine:',html.relative_to(root))
remaining=total()
if remaining>=1_000_000_000:
    raise RuntimeError('Site remains over 1 GB: '+str(remaining))
print(json.dumps({'before_bytes':original,'after_bytes':remaining,'saved_bytes':original-remaining,'changed_previews':len(changes),'game_packs_changed':False}))
