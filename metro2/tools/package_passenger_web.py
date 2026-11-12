#!/usr/bin/env python3
"""Package the existing Godot export below GitHub's per-file limit, without exporting again."""
import gzip,json,sys,os
from pathlib import Path
folder=Path(sys.argv[1]);pack=folder/'index.pck'
data=pack.read_bytes();compressed=gzip.compress(data,compresslevel=6,mtime=0)
chunk_size=20*1024*1024
parts=[]
for i,start in enumerate(range(0,len(compressed),chunk_size)):
    name=f'passengers-{i:03d}.pck.gz.part'
    (folder/name).write_bytes(compressed[start:start+chunk_size]);parts.append(name)
loader='''
// Transfer the unchanged export in bounded files, then pass its original bytes
// to Godot's normal preloadFile API. No scene or model changes.
const passengerPackParts = __PARTS__;
const passengerPreload = engine.preloadFile.bind(engine);
engine.preloadFile = async function(file, path) {
    if (file !== 'index.pck') return passengerPreload(file, path);
    const chunks = [];
    let loaded = 0;
    for (const url of passengerPackParts) {
        let response;
        for (let attempt = 0; attempt < 3; attempt++) {
            try {
                response = await fetch(url);
                if (!response.ok) throw new Error('Pack transfer: '+response.status);
                const bytes = await response.arrayBuffer();
                chunks.push(bytes); loaded += bytes.byteLength;
                break;
            } catch (error) { if (attempt === 2) throw error; }
        }
        if (engine.config.onProgress) engine.config.onProgress(loaded, __TOTAL__);
    }
    const stream = new Blob(chunks).stream().pipeThrough(new DecompressionStream('gzip'));
    const original = await new Response(stream).arrayBuffer();
    return passengerPreload(original, path || file);
};
'''.replace('__PARTS__',json.dumps(parts)).replace('__TOTAL__',str(len(compressed)))
html=folder/'index.html';content=html.read_text()
needle='const engine = new Engine(GODOT_CONFIG);'
if needle not in content:raise RuntimeError('Unknown Godot 4.3 HTML export')
html.write_text(content.replace(needle,needle+'\n'+loader,1))
pack.unlink()
(folder/'build-info.json').write_text(json.dumps({'source_commit':os.environ.get('PASSENGER_SOURCE_COMMIT',os.environ.get('GITHUB_SHA','c726ba72fe739a697c852a45e820aed343188f3a')),'godot':'4.3','passenger_glb_files':24,'platform_passengers':18,'pack_original_bytes':len(data),'transfer_bytes':len(compressed),'pack_parts':parts},indent=2))
print('Packaged existing export',len(data),'bytes as',len(parts),'bounded files; no rebuild')
