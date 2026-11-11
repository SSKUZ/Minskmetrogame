#!/usr/bin/env python3
"""Build and publish only Uruchye's optional Web pack, retaining the live viewer."""
import argparse,base64,hashlib,json,os,re,shutil
from pathlib import Path
from web_publication import GitHub,REPO
ROOT=Path(__file__).resolve().parents[1]
PREFIX='metro2/module-viewer/'
def read(api,name,ref='gh-pages'):
    data=api.request(f'/repos/{REPO}/contents/{PREFIX}{name}?ref={ref}')
    return base64.b64decode(data['content'])
def stage(destination):
    api=GitHub()
    resources=json.loads(read(api,'pack-resources.json'))
    shared=set(resources['resources']['shared'])
    pending=['modules/stations/uruchye/uruchye.tscn'];seen=set()
    while pending:
        name=pending.pop()
        if name in seen:continue
        source=ROOT/name
        seen.add(name)
        target=destination/name;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source,target)
        if source.suffix in {'.gd','.tscn','.tres','.gdshader'}:
            pending.extend(re.findall(r'''res://([^"'\s]+)''',source.read_text()))
    tool='tools/fast_loading/build_module_packs.gd'
    (destination/tool).parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/tool,destination/tool)
    (destination/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Uruchye Web module"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    plan={'entries':{'uruchye':'modules/stations/uruchye/uruchye.tscn'},'groups':{'shared':[],'uruchye':sorted(p for p in seen if 'res://'+p not in shared)}}
    (destination/'pack-plan.json').write_text(json.dumps(plan))
    print('Station-only Web staging ready')
def publish(folder):
    api=GitHub()
    head=api.request(f'/repos/{REPO}/git/ref/heads/gh-pages')['object']['sha']
    commit=api.request(f'/repos/{REPO}/git/commits/{head}')
    manifest=json.loads(read(api,'module-packs.json',head))
    report=json.loads(read(api,'pack-resources.json',head))
    info=json.loads(read(api,'build-info.json',head))
    update=json.loads((folder/'module-packs.json').read_text())['packs']['uruchye']
    pack=(folder/update['file']).read_bytes()
    manifest['packs']['uruchye']=update
    manifest['uruchye_source_commit']=os.environ['GITHUB_SHA']
    report['resources']['uruchye']=json.loads((folder/'pack-resources.json').read_text())['resources']['uruchye']
    info['uruchye_photo_rebuild']={'source_commit':os.environ['GITHUB_SHA'],'reference':'owner photographs 6695–6709','pack':update['file']}
    files={update['file']:pack,'module-packs.json':json.dumps(manifest,ensure_ascii=False,indent=2).encode(),'pack-resources.json':json.dumps(report,ensure_ascii=False,indent=2).encode(),'build-info.json':json.dumps(info,ensure_ascii=False,indent=2).encode()}
    hashes={}
    for line in read(api,'SHA256SUMS',head).decode().splitlines():
        digest,name=line.split(maxsplit=1);hashes[name.lstrip('*')]=digest
    for name,data in files.items():hashes[name]=hashlib.sha256(data).hexdigest()
    files['SHA256SUMS']=''.join(f'{v}  {k}\n' for k,v in sorted(hashes.items())).encode()
    entries=[]
    for name,data in files.items():
        blob=api.request(f'/repos/{REPO}/git/blobs','POST',{'encoding':'base64','content':base64.b64encode(data).decode()})
        entries.append({'path':PREFIX+name,'mode':'100644','type':'blob','sha':blob['sha']})
    tree=api.request(f'/repos/{REPO}/git/trees','POST',{'base_tree':commit['tree']['sha'],'tree':entries})
    new=api.request(f'/repos/{REPO}/git/commits','POST',{'tree':tree['sha'],'parents':[head],'message':'Rebuild Uruchye from owner photographs; update station Web pack only'})
    api.request(f'/repos/{REPO}/git/refs/heads/gh-pages','PATCH',{'sha':new['sha'],'force':False})
    print('PUBLISHED',new['sha'],'https://sskuz.github.io/Minskmetrogame/metro2/module-viewer/')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['stage','publish']);parser.add_argument('folder',type=Path);args=parser.parse_args()
    stage(args.folder) if args.action=='stage' else publish(args.folder)
