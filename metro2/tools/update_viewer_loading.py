#!/usr/bin/env python3
"""Reuse the live engine and visual packs; publish viewer loader fixes and V106 chunks."""
import argparse,base64,hashlib,json,os,re,shutil,urllib.request
from pathlib import Path
from web_publication import GitHub,REPO
PREFIX='metro2/module-viewer/'
ROOT=Path(__file__).resolve().parents[1]
def digest(data):return hashlib.sha256(data).hexdigest()
def read(api,name,ref):
    return api.request(f'/repos/{REPO}/contents/{PREFIX}{name}?ref={ref}',raw=True,headers={'Accept':'application/vnd.github.raw'})
def stage(out):
    out.mkdir(parents=True,exist_ok=True);api=GitHub()
    head=api.request(f'/repos/{REPO}/git/ref/heads/gh-pages')['object']['sha']
    for name in ['index.html','module-packs.json','build-info.json','SHA256SUMS']:
        (out/name).write_bytes(read(api,name,head))
    html=(out/'index.html').read_text();config=json.loads(re.search(r'const GODOT_CONFIG\s*=\s*(\{[^\n]+\});',html).group(1))
    boot=config['mainPack'];(out/'original-boot.pck').write_bytes(read(api,boot,head))
    manifest=json.loads((out/'module-packs.json').read_text());v106=manifest['packs']['v106']
    data=read(api,v106['file'],head)
    if digest(data)!=v106['sha256']:raise RuntimeError('Source train pack hash mismatch')
    chunks=[]
    for i,start in enumerate(range(0,len(data),6*1024*1024)):
        chunk=data[start:start+6*1024*1024];sha=digest(chunk);name='v106-part-'+sha[:20]+'.bin'
        (out/name).write_bytes(chunk);chunks.append({'file':name,'bytes':len(chunk),'sha256':sha})
    v106['chunks']=chunks
    (out/'module-packs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
    (out/'publication-base.json').write_text(json.dumps({'head':head,'boot':boot}))
    # Import only the loader source code with the matching Godot 4.3 compiler.
    project=out/'compile-project';project.mkdir()
    for name in ['viewers/module_viewer.gd','viewers/module_pack_loader.gd','viewers/inspection_camera.gd','viewers/flight_joystick.gd','modules/core/module_catalog.gd','viewers/module_viewer.tscn']:
        target=project/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,target)
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Viewer loader compilation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    print('LOADER_SOURCE_STAGED',len(chunks),'chunks; original train bytes retained')
def publish(out):
    api=GitHub();base=json.loads((out/'publication-base.json').read_text());head=api.request(f'/repos/{REPO}/git/ref/heads/gh-pages')['object']['sha']
    if head!=base['head']:raise RuntimeError('Concurrent publication: rerun using the latest live packs')
    parent=api.request(f'/repos/{REPO}/git/commits/{head}')
    pack=(out/'refreshed-boot.pck').read_bytes();boot='boot-'+digest(pack)[:20]+'.pck'
    html=(out/'index.html').read_text();match=re.search(r'const GODOT_CONFIG\s*=\s*(\{[^\n]+\});',html);config=json.loads(match.group(1))
    config['mainPack']=boot;config['fileSizes'].pop(base['boot'],None);config['fileSizes'][boot]=len(pack)
    html=html[:match.start(1)]+json.dumps(config,separators=(',',':'))+html[match.end(1):]
    files={boot:pack,'index.html':html.encode(),'module-packs.json':(out/'module-packs.json').read_bytes()}
    files.update({p.name:p.read_bytes() for p in out.glob('v106-part-*.bin')})
    info=json.loads((out/'build-info.json').read_text())
    info['viewer_loading_fix']={'source_commit':os.environ['GITHUB_SHA'],'web_resource_loading':'sequential cached models','download_chunk_bytes':6*1024*1024,'stall_retry_seconds':20}
    info['initial_files'].pop(base['boot'],None);info['initial_files'][boot]=len(pack);info['initial_files']['index.html']=len(files['index.html']);info['initial_bytes']=sum(info['initial_files'].values())
    files['build-info.json']=json.dumps(info,ensure_ascii=False,indent=2).encode()
    hashes={}
    for line in (out/'SHA256SUMS').read_text().splitlines():
        value,name=line.split(maxsplit=1);hashes[name.lstrip('*')]=value
    for name,data in files.items():hashes[name]=digest(data)
    files['SHA256SUMS']=''.join(f'{value}  {name}\n' for name,value in sorted(hashes.items())).encode()
    entries=[]
    for name,data in files.items():
        blob=api.request(f'/repos/{REPO}/git/blobs','POST',{'encoding':'base64','content':base64.b64encode(data).decode()})
        entries.append({'path':PREFIX+name,'mode':'100644','type':'blob','sha':blob['sha']})
    tree=api.request(f'/repos/{REPO}/git/trees','POST',{'base_tree':parent['tree']['sha'],'tree':entries})
    commit=api.request(f'/repos/{REPO}/git/commits','POST',{'tree':tree['sha'],'parents':[head],'message':'Fix V106 Web loading: bounded chunk transfers and sequential model preparation'})
    api.request(f'/repos/{REPO}/git/refs/heads/gh-pages','PATCH',{'sha':commit['sha'],'force':False})
    print('PUBLISHED_VIEWER_LOADING_FIX',commit['sha'])
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['stage','publish']);p.add_argument('output',type=Path);a=p.parse_args();stage(a.output) if a.action=='stage' else publish(a.output)
