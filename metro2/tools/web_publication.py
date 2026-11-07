#!/usr/bin/env python3
"""Bounded Godot Web hosting, verified Release archives, no model/export changes."""
import argparse
import hashlib
import json
import os
import re
import shutil
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

REPO=os.environ.get('GITHUB_REPOSITORY','SSKUZ/Minskmetrogame')
BASE='/Minskmetrogame/'
ARCHIVE_TAG='metro2-build-archive'
BUDGET=650_000_000
MODEL_SHA='2a3f37650722ba667f61f9cd063d4a3c7795fed37bc85285dd4c01c29b91d1e6'
INITIAL_CURRENT='metro2/cab-integration-v33/3c0c95f34b8dd1620450dc2f5d59259e8f17f2ed'
INITIAL_PREVIOUS='metro2/tunnel-lighting-v32/f0dcd42f2b37b502d8db561c1f4724388265e030'
THREE_CARS='metro2/v106-three-cars'
LEGACY_APK='metro2/v106-four-cars-tz30/ae13f50e739af627dacb5caeff06312bfc2df54d/MinskMetro2-TZ30-arm64.apk'
CONFIG=re.compile(r'const GODOT_CONFIG\s*=\s*(\{[^\n]+\});')

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs): return None

class GitHub:
    def __init__(self):
        self.token=os.environ['GH_TOKEN']
        self.opener=urllib.request.build_opener(NoRedirect())
    def request(self,path,method='GET',data=None,raw=False,headers=None):
        url=path if path.startswith('https://') else 'https://api.github.com'+path
        h={'Authorization':'Bearer '+self.token,'Accept':'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28','User-Agent':'MinskMetroRepositoryMaintenance'}
        if headers:h.update(headers)
        if data is not None and not isinstance(data,bytes):
            data=json.dumps(data).encode();h['Content-Type']='application/json'
        req=urllib.request.Request(url,data=data,headers=h,method=method)
        for attempt in range(4):
            try:
                with self.opener.open(req,timeout=180) as response:
                    body=response.read()
                    return body if raw else json.loads(body) if body else None
            except urllib.error.HTTPError as error:
                if error.code in (301,302,303,307,308) and raw and method=='GET':
                    # Never forward a GitHub token to signed external storage URLs.
                    location=error.headers['Location']
                    if not location.startswith('https://'):raise RuntimeError('Insecure artifact redirect')
                    with urllib.request.urlopen(location,timeout=180) as response:return response.read()
                if error.code in (429,500,502,503,504) and attempt<3:
                    time.sleep(3*(attempt+1));continue
                raise
    def paged(self,path,key=None):
        result=[]
        for page in range(1,100):
            data=self.request(path+('&' if '?' in path else '?')+f'per_page=100&page={page}')
            rows=data[key] if key else data
            result.extend(rows)
            if len(rows)<100:return result
        raise RuntimeError('Unexpected pagination depth')


def sha(path):
    digest=hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):digest.update(chunk)
    return digest.hexdigest()

def site_bytes(root):
    return sum(p.stat().st_size for p in root.rglob('*') if p.is_file() and '.git' not in p.relative_to(root).parts)

def read_config(path):
    text=path.read_text();match=CONFIG.search(text)
    if not match:raise RuntimeError('Unknown Godot loader: '+str(path))
    return text,match,json.loads(match.group(1))

def write_config(path,text,match,config):
    path.write_text(text[:match.start()]+'const GODOT_CONFIG = '+json.dumps(config,separators=(',',':'))+';'+text[match.end():])

def runtime_source(root,prefix):
    folder=root/prefix
    if (folder/'index.wasm').is_file():return folder/'index'
    _,_,config=read_config(folder/'index.html')
    executable=config['executable']
    if executable.startswith(BASE):return root/executable[len(BASE):]
    if executable.startswith('/') or '://' in executable:raise RuntimeError('Unexpected external engine URL')
    return folder/executable

class Archive:
    def __init__(self,api,target):
        self.api=api
        try:self.release=api.request(f'/repos/{REPO}/releases/tags/{ARCHIVE_TAG}')
        except urllib.error.HTTPError as error:
            if error.code!=404:raise
            self.release=api.request(f'/repos/{REPO}/releases','POST',{
                'tag_name':ARCHIVE_TAG,'target_commitish':target,'name':'Минское метро — архив Web, APK и ревизий',
                'body':'Архивные Web-сборки самостоятельны: распакуйте ZIP и откройте через HTTP-сервер. Оригинальные игровые пакеты не изменены. ZIP и загруженные файлы проверяются по SHA-256. Рабочая игра: https://sskuz.github.io/Minskmetrogame/metro2/play/','draft':False,'prerelease':False,'make_latest':'false'})
        self.refresh()
    def refresh(self):
        self.assets={a['name']:a for a in self.api.paged(f'/repos/{REPO}/releases/{self.release["id"]}/assets')}
    def upload(self,path,name=None):
        path=Path(path);name=name or path.name;expected=sha(path)
        asset=self.assets.get(name)
        if asset:
            actual=asset.get('digest')
            if actual=='sha256:'+expected and asset['size']==path.stat().st_size:return asset
            raise RuntimeError('Archive asset already exists with different contents: '+name)
        asset=self.api.request(f'https://uploads.github.com/repos/{REPO}/releases/{self.release["id"]}/assets?name='+urllib.parse.quote(name),'POST',path.read_bytes(),headers={'Content-Type':'application/octet-stream'})
        if asset['size']!=path.stat().st_size:raise RuntimeError('Release size mismatch')
        for attempt in range(5):
            if asset.get('digest'):break
            time.sleep(2);asset=self.api.request(f'/repos/{REPO}/releases/assets/{asset["id"]}')
        if asset.get('digest')!='sha256:'+expected:
            remote=self.api.request(f'/repos/{REPO}/releases/assets/{asset["id"]}',raw=True,headers={'Accept':'application/octet-stream'})
            if hashlib.sha256(remote).hexdigest()!=expected:raise RuntimeError('Release digest mismatch: '+name)
        self.assets[name]=asset
        print('ARCHIVE_VERIFIED',name,path.stat().st_size,expected,flush=True)
        return asset
    def archive_build(self,root,prefix,catalog):
        folder=root/prefix;pack=folder/'index.pck';pack_sha=sha(pack)
        key='web-'+prefix.removeprefix('metro2/').replace('/','-')+'-'+pack_sha[:12]+'.zip'
        if prefix=='metro2':key='web-legacy-root-'+pack_sha[:12]+'.zip'
        entry=catalog.get(prefix)
        if entry and entry.get('pack_sha256')==pack_sha and entry.get('asset') in self.assets:
            asset=self.assets[entry['asset']]
            if asset.get('digest')=='sha256:'+entry['zip_sha256']:return entry
        if key in self.assets:
            # Existing immutable archive from an earlier interrupted maintenance run.
            asset=self.assets[key]
            data=self.api.request(f'/repos/{REPO}/releases/assets/{asset["id"]}',raw=True,headers={'Accept':'application/octet-stream'})
            with tempfile.TemporaryDirectory() as td:
                zpath=Path(td)/key;zpath.write_bytes(data)
                with zipfile.ZipFile(zpath) as z:
                    if z.testzip() is not None or hashlib.sha256(z.read('index.pck')).hexdigest()!=pack_sha:raise RuntimeError('Existing archive game pack mismatch')
            entry={'asset':key,'url':asset['browser_download_url'],'zip_sha256':hashlib.sha256(data).hexdigest(),'pack_sha256':pack_sha,'bytes':asset['size']}
            catalog[prefix]=entry;return entry
        engine=runtime_source(root,prefix)
        html,match,config=read_config(folder/'index.html')
        config['executable']='index';config['mainPack']='index.pck'
        sizes=config.get('fileSizes',{})
        for name in list(sizes):
            if name.endswith('.wasm') and not name.endswith('.side.wasm'):sizes.pop(name)
        sizes['index.wasm']=Path(str(engine)+'.wasm').stat().st_size
        normalized=html[:match.start()]+'const GODOT_CONFIG = '+json.dumps(config,separators=(',',':'))+';'+html[match.end():]
        with tempfile.TemporaryDirectory() as td:
            target=Path(td)/key
            with zipfile.ZipFile(target,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=3) as z:
                files=list(folder.iterdir()) if prefix=='metro2' else list(folder.rglob('*'))
                for file in files:
                    if not file.is_file() or file.suffix=='.apk':continue
                    rel=str(file.relative_to(folder))
                    if prefix=='metro2' and not (rel.startswith('index.') or rel=='build-info.json'):continue
                    if rel=='index.html':z.writestr('publication-original/index.html',file.read_bytes());continue
                    if rel=='index.wasm':continue
                    z.write(file,rel)
                z.writestr('index.html',normalized)
                z.write(Path(str(engine)+'.wasm'),'index.wasm')
                # Small runtime support files are normally already local; preserve missing ones.
                present=set(z.namelist())
                for ext in ['.js','.audio.worklet.js','.worker.js','.side.wasm']:
                    support=Path(str(engine)+ext)
                    if support.exists() and 'index'+ext not in present:z.write(support,'index'+ext)
                z.writestr('archive-info.json',json.dumps({'original_path':prefix,'pack_sha256':pack_sha,'wasm_sha256':sha(Path(str(engine)+'.wasm')),'original_files_retained':True},indent=2))
            with zipfile.ZipFile(target) as z:
                if z.testzip() is not None:raise RuntimeError('ZIP CRC failure')
            asset=self.upload(target,key)
            entry={'asset':key,'url':asset['browser_download_url'],'zip_sha256':sha(target),'pack_sha256':pack_sha,'bytes':target.stat().st_size}
        catalog[prefix]=entry
        return entry


def share_runtime(root,prefix):
    folder=root/prefix;engine=runtime_source(root,prefix)
    hashes=[]
    for ext in ['.wasm','.js','.audio.worklet.js']:
        path=Path(str(engine)+ext)
        if not path.is_file():raise RuntimeError('Missing engine component: '+str(path))
        hashes.append(sha(path))
    key=hashlib.sha256('|'.join(hashes).encode()).hexdigest()[:16]
    runtime=root/'metro2/runtime'/('godot-4.3-'+key)
    runtime.mkdir(parents=True,exist_ok=True)
    for ext in ['.wasm','.js','.audio.worklet.js','.worker.js','.side.wasm']:
        source=Path(str(engine)+ext);destination=runtime/('index'+ext)
        if source.exists() and source.resolve()!=destination.resolve():
            if destination.exists() and sha(destination)!=sha(source):raise RuntimeError('Engine fingerprint collision')
            if not destination.exists():shutil.copyfile(source,destination)
    text,match,config=read_config(folder/'index.html')
    if config.get('serviceWorker'):raise RuntimeError('PWA needs explicit cache migration')
    executable=BASE+str(runtime.relative_to(root))+'/index'
    config['executable']=executable;config['mainPack']='index.pck'
    sizes=config.get('fileSizes',{})
    for name in list(sizes):
        if name.endswith('.wasm') and not name.endswith('.side.wasm'):sizes.pop(name)
    sizes[executable+'.wasm']=(runtime/'index.wasm').stat().st_size
    write_config(folder/'index.html',text,match,config)
    for ext in ['.wasm','.side.wasm']:
        duplicate=folder/('index'+ext)
        if duplicate.exists() and duplicate.resolve()!=(runtime/('index'+ext)).resolve():duplicate.unlink()
    return str(runtime.relative_to(root))


def redirect_html(target,title):
    import html
    safe=html.escape(target,quote=True)
    return '<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0;url='+safe+'"><title>'+html.escape(title)+'</title><a href="'+safe+'">'+html.escape(title)+'</a>'

def archive_landing(entry):
    import html
    url=html.escape(entry['url'],quote=True)
    return '<!doctype html><html lang="ru"><meta charset="utf-8"><title>Архив Минского метро</title><body style="font:18px Arial;max-width:760px;margin:60px auto"><h1>Эта версия перенесена в архив</h1><p><a href="'+url+'">Скачать сохранённую сборку ZIP</a></p><p><a href="'+BASE+'metro2/play/">Открыть текущую игру</a> · <a href="'+BASE+'metro2/previous/">Предыдущая версия</a> · <a href="'+BASE+'metro2/archive/">Все архивы и APK</a></p></body></html>'

def compact(root,archive,current,previous,maintenance_commit,catalog=None):
    catalog=catalog or {}
    packs=sorted(str(p.parent.relative_to(root)) for p in (root/'metro2').rglob('index.pck'))
    for prefix in packs:archive.archive_build(root,prefix,catalog)
    active={current,previous,THREE_CARS}
    active.update(packs) # Keep every previously live build online for this new route.
    for prefix in active:
        if not (root/prefix/'index.pck').is_file():raise RuntimeError('Protected build missing: '+prefix)
    # Copy canonical runtime before retiring legacy root resources.
    runtimes={share_runtime(root,prefix) for prefix in active}
    apk=root/LEGACY_APK
    if apk.exists():
        asset=archive.upload(apk)
        apk_info={'url':asset['browser_download_url'],'bytes':apk.stat().st_size,'sha256':sha(apk),'compatibility_path':LEGACY_APK}
    else:raise RuntimeError('Protected legacy APK missing')
    for prefix in packs:
        if prefix in active:continue
        folder=root/prefix
        if prefix=='metro2':
            for file in list(folder.iterdir()):
                if file.is_file() and (file.name.startswith('index.') or file.name=='build-info.json'):file.unlink()
            continue
        preserve={apk.name,'SHA256SUMS.txt','apk-verification.json'} if prefix==str(apk.parent.relative_to(root)) else set()
        for child in list(folder.iterdir()):
            if child.name in preserve:continue
            if child.is_dir():shutil.rmtree(child)
            else:child.unlink()
        (folder/'index.html').write_text(archive_landing(catalog[prefix]))
    for runtime in (root/'metro2/runtime').iterdir():
        if runtime.is_dir() and str(runtime.relative_to(root)) not in runtimes:shutil.rmtree(runtime)
    current_info=json.loads((root/current/'build-info.json').read_text())
    previous_info=json.loads((root/previous/'build-info.json').read_text())
    marker=maintenance_commit
    live_url=BASE+current+'/index.html?release='+current_info['source_commit']+'&layout='+marker[:12]
    previous_url=BASE+previous+'/index.html?release='+previous_info['source_commit']+'&layout='+marker[:12]
    for channel,url in [('play',live_url),('previous',previous_url)]:
        folder=root/'metro2'/channel;folder.mkdir(exist_ok=True)
        (folder/'index.html').write_text(redirect_html(url,'Минское метро 2.0'))
    archive_dir=root/'metro2/archive';archive_dir.mkdir(exist_ok=True)
    import html
    rows=''.join('<li><a href="'+html.escape(e['url'],quote=True)+'">'+html.escape(name)+'</a></li>' for name,e in sorted(catalog.items()))
    (archive_dir/'index.html').write_text('<!doctype html><html lang="ru"><meta charset="utf-8"><title>Архив Минского метро</title><body style="font:17px Arial;max-width:960px;margin:40px auto"><h1>Архив версий</h1><p><a href="'+BASE+'metro2/play/">Текущая игра</a> · <a href="'+BASE+'metro2/previous/">Предыдущая версия</a> · <a href="'+html.escape(apk_info['url'],quote=True)+'">Скачать APK</a></p><p>ZIP содержит самостоятельную Web-сборку. Распакуйте и запускайте через HTTP-сервер.</p><ul>'+rows+'</ul></body></html>')
    (root/'metro2/index.html').write_text('<!doctype html><html lang="ru"><meta charset="utf-8"><title>Минское метро 2.0</title><body style="font:20px Arial;max-width:800px;margin:60px auto"><h1>Минское метро 2.0</h1><p><a href="play/">Играть — текущая версия</a></p><p><a href="previous/">Предыдущая стабильная версия</a></p><p><a href="v106-three-cars/">Сохранённая трёхвагонная версия</a></p><p><a href="archive/">Архив и APK</a></p><p><a href="../index.html">Старая Three.js-игра</a></p></body></html>')
    manifest={'schema':1,'maintenance_commit':marker,'current':{'path':current,'source_commit':current_info['source_commit']},'previous':{'path':previous,'source_commit':previous_info['source_commit']},'protected_three_cars':THREE_CARS,'archive_release':archive.release['html_url'],'archive_tag':ARCHIVE_TAG,'archives':catalog,'apk':apk_info,'site_budget_bytes':BUDGET,'runtime_paths':sorted(runtimes)}
    manifest_path=root/'metro2/publication.json'
    manifest['site_bytes']=0
    manifest_path.write_text(json.dumps(manifest,indent=2,ensure_ascii=False))
    for _ in range(4):
        size=site_bytes(root)
        if manifest['site_bytes']==size:break
        manifest['site_bytes']=size
        manifest_path.write_text(json.dumps(manifest,indent=2,ensure_ascii=False))
    size=site_bytes(root)
    if size>BUDGET:raise RuntimeError(f'Publication budget exceeded: {size} > {BUDGET}; no push allowed')
    print('COMPACT_SITE',json.dumps({'site_bytes':site_bytes(root),'budget':BUDGET,'current':current,'previous':previous,'archives':len(catalog)}),flush=True)
    return manifest


def publish(args):
    root=Path(args.site).resolve();api=GitHub()
    manifest=json.loads((root/'metro2/publication.json').read_text())
    if manifest.get('schema')!=1:raise RuntimeError('Run repository maintenance before publishing')
    current=manifest['current']['path']
    destination='metro2/'+args.channel+'/'+args.commit
    folder=root/destination;folder.mkdir(parents=True,exist_ok=True)
    shutil.copytree(args.new_build,folder,dirs_exist_ok=True)
    info=json.loads((folder/'build-info.json').read_text())
    if info['source_commit']!=args.commit:raise RuntimeError('Build provenance mismatch')
    archive=Archive(api,args.commit)
    previous=current if current!=destination else manifest['previous']['path']
    entry=root/('metro2/'+args.channel+'/index.html')
    entry.parent.mkdir(parents=True,exist_ok=True)
    entry.write_text(redirect_html(BASE+destination+'/index.html','Минское метро 2.0 — Уручье'))
    compact(root,archive,destination,previous,args.commit,manifest.get('archives',{}))

def prune_generated_artifacts():
    api=GitHub()
    artifacts=[a for a in api.paged(f'/repos/{REPO}/actions/artifacts','artifacts') if not a['expired']]
    pages=sorted((a for a in artifacts if a['name']=='github-pages'),key=lambda a:a['id'],reverse=True)
    builds=sorted((a for a in artifacts if re.fullmatch(r'tz[0-9]+-web-build',a['name'])),key=lambda a:a['id'],reverse=True)
    deleted=0;freed=0
    for item in pages[1:]+builds[2:]:
        api.request(f'/repos/{REPO}/actions/artifacts/{item["id"]}','DELETE')
        deleted+=1;freed+=item['size_in_bytes']
    print('GENERATED_ARTIFACT_RETENTION',json.dumps({'removed':deleted,'freed_bytes':freed,'pages_kept':min(1,len(pages)),'web_builds_kept':min(2,len(builds))}),flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();sub=parser.add_subparsers(dest='command',required=True)
    p=sub.add_parser('publish');p.add_argument('--site',required=True);p.add_argument('--new-build',required=True);p.add_argument('--commit',required=True);p.add_argument('--channel',default='surface-depot-v40',choices=['surface-depot-v40','uruchye-v42'])
    sub.add_parser('prune-artifacts')
    args=parser.parse_args()
    if args.command=='publish':publish(args)
    else:prune_generated_artifacts()


