#!/usr/bin/env python3
"""Use stable content-addressed engine assets and a separately versioned boot PCK."""
import argparse,hashlib,json,os,re,subprocess,sys
from pathlib import Path

p=argparse.ArgumentParser();p.add_argument('output',type=Path);args=p.parse_args();out=args.output
subprocess.run([sys.executable,str(Path(__file__).with_name('finalize_viewer_web.py')),str(out/'index.html')],check=True)
html=(out/'index.html').read_text()
match=re.search(r'const GODOT_CONFIG\s*=\s*(\{[^\n]+\});',html)
if not match: raise SystemExit('Godot 4.3 Web export configuration was not found')
config=json.loads(match.group(1));engine='engine-'+hashlib.sha256((out/'index.wasm').read_bytes()).hexdigest()[:20]
boot='boot-'+hashlib.sha256((out/'index.pck').read_bytes()).hexdigest()[:20]+'.pck'
renamed={}
for path in list(out.glob('index.*')):
    if path.suffix in {'.html','.png'}: continue
    name=boot if path.suffix=='.pck' else engine+path.name[len('index'):]
    renamed[path.name]=name;path.rename(out/name)
config['executable']=engine;config['mainPack']=boot
config['fileSizes']={renamed.get(name,name):size for name,size in config.get('fileSizes',{}).items()}
html=html[:match.start(1)]+json.dumps(config,separators=(',',':'))+html[match.end(1):]
html=html.replace('src="index.js"',f'src="{engine}.js"')
(out/'index.html').write_text(html)
manifest=json.loads((out/'module-packs.json').read_text());manifest['source_commit']=os.environ.get('GITHUB_SHA','local')
(out/'module-packs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
initial=['index.html',boot]+[name for name in renamed.values() if name!=boot]
if (out/'index.png').exists(): initial.append('index.png')
report={'source_commit':os.environ.get('GITHUB_SHA','local'),'advertising_base':'a92adccabf913074cfbd89e91b8273b34062083f','godot':'4.3',
        'initial_files':{name:(out/name).stat().st_size for name in initial},
        'initial_bytes':sum((out/name).stat().st_size for name in initial),
        'before_initial_bytes':48050080+35376909+331495+7298+6299+21443,
        'module_packs':manifest['packs'],'entry':'res://viewers/module_viewer.tscn'}
(out/'build-info.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('FAST_VIEWER_SIZES',json.dumps(report,ensure_ascii=False))
