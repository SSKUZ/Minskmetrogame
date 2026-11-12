#!/usr/bin/env python3
"""Publish the saved Godot export with bounded, resumable network transfers."""
import gzip,hashlib,json,sys,os
from pathlib import Path
folder=Path(sys.argv[1]);pack=folder/'index.pck';wasm=folder/'index.wasm'
raw=pack.read_bytes();compressed=gzip.compress(raw,compresslevel=6,mtime=0)
size=2*1024*1024

def split(data,prefix):
    version=hashlib.sha256(data).hexdigest()[:16]
    parts=[]
    for i,start in enumerate(range(0,len(data),size)):
        chunk=data[start:start+size];name=f'{prefix}-{version}-{i:03d}.bin'
        (folder/name).write_bytes(chunk)
        parts.append({'file':name,'size':len(chunk),'sha256':hashlib.sha256(chunk).hexdigest()})
    return parts

manifest={'pack':split(compressed,'pack'),'wasm':split(wasm.read_bytes(),'engine'),'packBytes':len(raw),'wasmBytes':wasm.stat().st_size}
loader=r'''
const passengerFiles = __MANIFEST__;
const passengerNativeFetch = window.fetch.bind(window);
const passengerPreload = engine.preloadFile.bind(engine);
const passengerProgress = {pack:0,wasm:0};
const passengerTotal = [...passengerFiles.pack,...passengerFiles.wasm].reduce((n,p)=>n+p.size,0);
const passengerStatus = document.createElement('div');
passengerStatus.style.cssText='position:absolute;bottom:16%;left:5%;right:5%;text-align:center;font:16px sans-serif;color:white;z-index:2';
document.getElementById('status').appendChild(passengerStatus);
let passengerStage = 'Загрузка файлов';
function passengerRender() {
    const loaded = passengerProgress.pack+passengerProgress.wasm;
    const progress = document.getElementById('status-progress');
    progress.max=passengerTotal;progress.value=loaded;
    passengerStatus.textContent=passengerStage+' · '+(loaded/1048576).toFixed(1)+' / '+(passengerTotal/1048576).toFixed(1)+' МБ';
}
async function passengerDownload(part,kind,committed) {
    let lastError;
    for (let attempt=0;attempt<3;attempt++) {
        const controller=new AbortController();
        let timer;
        const watch=()=>{clearTimeout(timer);timer=setTimeout(()=>controller.abort(),25000);};
        try {
            watch();
            const response=await passengerNativeFetch(part.file,{signal:controller.signal,cache:attempt?'reload':'default'});
            if (!response.ok) throw new Error('HTTP '+response.status);
            const reader=response.body.getReader();
            const buffer=new Uint8Array(part.size);
            let offset=0;
            while (true) {
                const {done,value}=await reader.read();
                if (done) break;
                watch();
                if (offset+value.length>buffer.length) throw new Error('Неверный размер файла');
                buffer.set(value,offset);offset+=value.length;
                passengerProgress[kind]=committed+offset;passengerRender();
            }
            if (offset!==part.size) throw new Error('Файл загружен не полностью');
            const digest=await crypto.subtle.digest('SHA-256',buffer);
            const hash=Array.from(new Uint8Array(digest),b=>b.toString(16).padStart(2,'0')).join('');
            if (hash!==part.sha256) throw new Error('Повреждённый файл');
            return buffer;
        } catch (error) {
            controller.abort();lastError=error;
            passengerProgress[kind]=committed;
            passengerStage='Повтор загрузки '+(attempt+1)+'/3';passengerRender();
        } finally {clearTimeout(timer);}
    }
    throw new Error('Не удалось загрузить '+part.file+'. '+lastError.message+' Нажмите «Повторить загрузку».');
}
function passengerStream(kind) {
    let index=0,committed=0;
    return new ReadableStream({
        async pull(controller) {
            try {
                if (index===passengerFiles[kind].length) {controller.close();return;}
                const part=passengerFiles[kind][index];
                const bytes=await passengerDownload(part,kind,committed);
                index++;committed+=bytes.byteLength;
                passengerProgress[kind]=committed;passengerStage='Загрузка файлов';passengerRender();
                controller.enqueue(bytes);
            } catch(error) {controller.error(error);}
        }
    });
}
// Godot keeps its normal WebAssembly initialization. Only its download is
// supplied as a stream of small immutable files with per-file retry/validation.
window.fetch=function(input,options) {
    const url=new URL(typeof input==='string'?input:input.url,location.href);
    if (url.origin===location.origin && url.pathname===new URL('index.wasm',location.href).pathname) {
        return Promise.resolve(new Response(passengerStream('wasm'),{headers:{'Content-Type':'application/wasm','Content-Length':String(passengerFiles.wasmBytes)}}));
    }
    return passengerNativeFetch(input,options);
};
engine.preloadFile=async function(file,path) {
    if (file!=='index.pck') return passengerPreload(file,path);
    if (typeof DecompressionStream==='undefined') throw new Error('Для этой версии нужен актуальный Chrome или Samsung Internet.');
    const stream=passengerStream('pack').pipeThrough(new DecompressionStream('gzip'));
    const original=await new Response(stream).arrayBuffer();
    if (original.byteLength!==passengerFiles.packBytes) throw new Error('Неверный размер игровых данных');
    passengerStage='Подготовка станции и поезда';passengerRender();
    return passengerPreload(new Uint8Array(original),path||file);
};
const passengerRetry=document.createElement('button');
passengerRetry.textContent='Повторить загрузку';
passengerRetry.style.cssText='display:block;position:relative;z-index:3;margin:16px auto 0;padding:12px 20px;font-size:16px';
passengerRetry.onclick=()=>location.reload();
document.getElementById('status-notice').insertAdjacentElement('afterend',passengerRetry);
passengerRender();
'''.replace('__MANIFEST__',json.dumps(manifest,separators=(',',':')))
html=folder/'index.html';content=html.read_text();needle='const engine = new Engine(GODOT_CONFIG);'
if needle not in content:raise RuntimeError('Unknown Godot 4.3 HTML export')
content=content.replace(needle,needle+'\n'+loader,1)
# Use one aggregate progress meter. Godot's WASM-only callback must not replace
# the pack byte count while the second stream is still downloading.
a=content.index("'onProgress': function (current, total) {")
b=content.index('\n\t\t}).then',a)
content=content[:a]+"'onProgress': function () { passengerRender(); },"+content[b:]
content=content.replace('src="index.js"','src="index.js?loader=2"')
html.write_text(content)
pack.unlink();wasm.unlink()
(folder/'build-info.json').write_text(json.dumps({'source_commit':os.environ.get('PASSENGER_SOURCE_COMMIT',os.environ.get('GITHUB_SHA','c726ba72fe739a697c852a45e820aed343188f3a')),'godot':'4.3','passenger_glb_files':24,'platform_passengers':18,'pack_original_bytes':len(raw),'transfer_bytes':len(compressed)+manifest['wasmBytes'],'pack_parts':manifest['pack'],'wasm_parts':manifest['wasm'],'loader_version':2},indent=2))
print('Packaged saved export with 2 MiB streamed files, timeouts and retries; no Godot rebuild')
