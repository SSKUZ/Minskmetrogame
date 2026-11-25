#!/usr/bin/env python3
"""Changed-pack planning, native resource packaging and atomic publication. No game execution."""
from pathlib import Path, PurePosixPath
import argparse, base64, fnmatch, hashlib, json, os, posixpath, re, shutil, struct, subprocess

ROOT=Path(__file__).resolve().parents[2]
REPO=ROOT.parent
CI=REPO/'.metro2-ci'
POLICY=json.loads((ROOT/'config/module_deploy_manifest.json').read_text())
PREFIX=POLICY['publication_prefix']
PAGES='refs/remotes/origin/'+POLICY['pages_branch']
PLAN=CI/'plan.json'
TEXT={'.gd','.tscn','.tres','.gdshader','.json','.cfg'}
MEDIA={'.png','.jpg','.jpeg','.webp','.svg','.ttf','.otf','.glb','.gltf','.wav','.ogg','.mp3'}

def git(*args,check=True,env=None,input=None):
    p=subprocess.run(['git',*args],cwd=REPO,env=env,input=input,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=False)
    if check and p.returncode: raise RuntimeError(p.stderr.decode(errors='replace'))
    return p.stdout if check else p

def write(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')

def fetch_pages():
    # Partial fetch plus a temporary Git index avoids downloading/checking out unrelated packs.
    git('config','remote.origin.promisor','true')
    git('config','remote.origin.partialclonefilter','blob:none')
    git('fetch','--filter=blob:none','--depth=1','origin','+'+POLICY['pages_branch']+':'+PAGES)
    return git('rev-parse',PAGES).decode().strip()

def published(ref,name,default=None):
    p=git('show',ref+':'+PREFIX+name,check=False)
    if p.returncode:
        if default is not None:return default
        raise RuntimeError('Missing published registry '+name)
    return json.loads(p.stdout)

def boot_config(ref):
    html=git('show',ref+':'+PREFIX+'index.html').decode()
    match=re.search(r'const GODOT_CONFIG\s*=\s*(\{[^\n]+\});',html)
    if not match:raise RuntimeError('Unknown existing viewer configuration; refusing to replace its shell')
    return html,match,json.loads(match[1])

def source_name(value):
    name=value.removeprefix('res://').removeprefix('metro2/')
    for suffix in ['.remap','.import']:
        if name.endswith(suffix):name=name[:-len(suffix)]
    if name.endswith('.gdc'):name=name[:-1]
    return name

def ignored(name):
    p=PurePosixPath(name)
    return p.suffix.lower() in POLICY['excluded_suffixes'] or any(v in POLICY['excluded_segments'] or v.startswith('references_') for v in p.parts)

def references(name):
    # Catalog entries describe optional packages, not eager resource dependencies.
    if name==POLICY['catalog']:return []
    p=ROOT/name
    if p.is_file() and p.suffix in {'.glb','.gltf'}:
        if p.suffix=='.glb':
            with p.open('rb') as model:
                header=model.read(20)
                if len(header)!=20 or header[:4]!=b'glTF' or header[16:20]!=b'JSON':return []
                document=json.loads(model.read(struct.unpack_from('<I',header,12)[0]))
        else:document=json.loads(p.read_text())
        return [posixpath.normpath(posixpath.join(str(PurePosixPath(name).parent),v['uri']))
                for v in document.get('images',[])+document.get('buffers',[])
                if v.get('uri') and not v['uri'].startswith(('data:','http:','https:'))]
    if not p.is_file() or p.suffix not in TEXT:return []
    return re.findall(r'''res://([^"'\s]+)''',p.read_text(errors='replace'))

def closure(seeds):
    todo=list(seeds);seen=set()
    while todo:
        name=todo.pop()
        if name in seen or ignored(name):continue
        p=ROOT/name
        if p.is_dir():
            todo.extend(str(q.relative_to(ROOT)) for q in p.rglob('*') if q.is_file())
            continue
        if not p.is_file():continue # A published pack can already contain the unchanged imported asset.
        seen.add(name);todo.extend(references(name))
    return seen

def static_boot_sources():
    todo=list(POLICY['boot_sources'])+list(POLICY.get('boot_class_sources',[]));seen=set()
    while todo:
        name=todo.pop()
        if name in seen:continue
        p=ROOT/name
        if not p.is_file():raise RuntimeError('Missing viewer source '+name)
        seen.add(name)
        text=p.read_text(errors='replace')
        if p.suffix=='.gd':
            todo.extend(re.findall(r'(?:preload\s*\(\s*|extends\s*)["\']res://([^"\']+)',text))
        elif p.suffix in {'.tscn','.tres'}:
            todo.extend(re.findall(r'path="res://([^"]+)"',text))
    return seen

def ancestor(sha,head):
    if not re.fullmatch('[0-9a-f]{40}',sha):return False
    git('fetch','--filter=blob:none','--depth=1','origin',sha,check=False)
    if git('merge-base','--is-ancestor',sha,head,check=False).returncode==0:return True
    branch=os.environ.get('GITHUB_REF_NAME','')
    if branch:git('fetch','--filter=blob:none','--deepen=512','origin',branch,check=False)
    return git('merge-base','--is-ancestor',sha,head,check=False).returncode==0

def guard(key,manifest,state,head):
    current=manifest['packs'].get(key)
    previous=state.get('modules',{}).get(key)
    if current is None:
        if previous:raise RuntimeError('Published module was removed externally: '+key)
        return
    if previous:
        if previous.get('pack_sha256')!=current['sha256'] or not ancestor(previous['source_commit'],head):
            raise RuntimeError('Newer/incompatible publication for '+key+'; integrate its source commit before publishing')
    elif POLICY['initial_pack_versions'].get(key)!=current['sha256']:
        raise RuntimeError('Untracked newer legacy publication for '+key+'; update the integration baseline explicitly')

def output(name,value):
    path=os.environ.get('GITHUB_OUTPUT')
    if path:
        with open(path,'a') as f:f.write(name+'='+str(value)+'\n')

def plan():
    CI.mkdir(exist_ok=True)
    event=json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
    head=os.environ['GITHUB_SHA'];before=event.get('before','')
    if not before or set(before)=={'0'}:before=POLICY['integration_base_commit']
    git('fetch','--filter=blob:none','--depth=1','origin',before)
    changed=git('diff','--name-only',before,head).decode().splitlines()
    planner_inputs={'metro2/config/module_deploy_manifest.json',
                    'metro2/tools/automated_deploy/deploy.py',
                    'metro2/tools/automated_deploy/pack_module.gd'}
    compiler_changed=any(p.startswith('metro2/tools/automated_deploy/static_world/') for p in changed)
    if planner_inputs.intersection(changed) or compiler_changed:
        # A planner repair must include runtime changes from a failed previous
        # push, even when this push changes only deployment code/configuration.
        before=POLICY['integration_base_commit']
        git('fetch','--filter=blob:none','--depth=1','origin',before)
        changed=git('diff','--name-only',before,head).decode().splitlines()
    runtime=[p[7:] for p in changed if p.startswith(('metro2/modules/','metro2/scripts/','metro2/assets/','metro2/viewers/','metro2/audio/')) and not ignored(p) and '/parts/' not in p and '/identification_tz54_1/' not in p and not p.startswith('metro2/audio/tools/')]
    part_changes=[p[7:] for p in changed if p.startswith('metro2/assets/') and '/parts/' in p]
    runtime+=part_changes
    if not runtime and not compiler_changed:
        write(PLAN,{'active':False,'head':head,'modules':{},'reason':'No runtime module changes; no Godot import/export/publication'})
        output('active','false');output('matrix','{"include":[]}');return
    ref=fetch_pages();manifest=published(ref,'module-packs.json');report=published(ref,'pack-resources.json')
    state=published(ref,POLICY['state_file'],{})
    catalog=dict(re.findall(r'"([a-z0-9_]+)"\s*:\s*"res://([^\"]+)"',(ROOT/POLICY['catalog']).read_text()))
    names={key:title for title,key in re.findall(r'\[\s*"([^\"]+)"\s*,\s*"([a-z0-9_]+)"\s*\]',(ROOT/'viewers/module_viewer.gd').read_text())}
    entries={**report.get('entries',{}),**catalog}
    if 'v106' in report.get('entries',{}):entries['v106']=report['entries']['v106']
    owners={};sources={};roots={}
    for key in set(manifest['packs'])|{k for k in catalog if k in names}:
        if not re.fullmatch(r'[a-z0-9_]+',key):raise RuntimeError('Invalid registered module ID')
        entry=entries.get(key)
        root=str(PurePosixPath(catalog.get(key,entry or '')).parent)
        roots[key]=root if root.startswith('modules/') else ''
        seeds={source_name(p) for p in report.get('resources',{}).get(key,[]) if not source_name(p).startswith('.godot/')}
        if entry:seeds.add(entry)
        if roots[key]:seeds.update(str(p.relative_to(ROOT)) for p in (ROOT/roots[key]).rglob('*') if p.is_file())
        sources[key]=closure(seeds)
        for name in seeds|sources[key]:owners.setdefault(name,set()).add(key)
    chosen=set();unknown=[];direct=set()
    boot_sources=static_boot_sources()
    for name in runtime:
        # Audio class_name scripts are also embedded in the boot pack. Updating
        # only optional packs leaves their old boot definitions winning at mount.
        if name in boot_sources:chosen.add('boot')
        if name in POLICY['boot_sources']:continue
        found=set(owners.get(name,()))
        for key,root in roots.items():
            if root and name.startswith(root+'/'):found.add(key)
        if not found and (name in POLICY.get('source_only_paths',[]) or
                          any(name.startswith(prefix) for prefix in POLICY.get('optional_media_prefixes',[]))):
            # These sources stay saved in Git. If a real module references them,
            # owners above selects that consumer normally; only unowned files skip.
            continue
        if not found:
            for prefix,key in POLICY['category_hints'].items():
                if name.startswith(prefix):found.update(manifest['packs'] if key=='integration' else [key]);break
        if not found:unknown.append(name)
        direct.update(found);chosen.update(found)
    if unknown:raise RuntimeError('Runtime files lack a registered module/dependency: '+', '.join(unknown))
    # A shared-pack change refreshes its actual consumers, never an invented independent module.
    if 'shared' in chosen:
        for deps in manifest['modules'].values():
            if 'shared' in deps:chosen.update(deps)
    # Architecture compiler changes rebuild only the registered integrated line
    # stations, using the same ancestry guards and atomic publication as before.
    static_inputs = any(p.startswith('metro2/tools/automated_deploy/static_world/') or
                        p in {'metro2/modules/line/static_station.gd', 'metro2/modules/line/static_resource_store.gd'}
                        for p in changed)
    static_modules = set()
    if static_inputs:
        static_modules = set(json.loads((ROOT/'modules/line/route_layout.json').read_text())['station_module_ids'])
        chosen.update(static_modules)
        chosen.add('full_line')
    branch=os.environ['GITHUB_REF_NAME'];scope='integration' if branch==POLICY['source_branch'] else branch.removeprefix(POLICY['branch_prefix']).split('/')[0]
    if not branch.startswith(POLICY['branch_prefix']) and branch!=POLICY['source_branch']:raise RuntimeError('Branch is not opted into automatic publication')
    if scope!='integration' and direct-{scope}:raise RuntimeError('Cross-module source change requires an integration branch: '+','.join(sorted(direct)))
    _,_,cfg=boot_config(ref)
    if 'boot' in chosen:
        prior=state.get('boot')
        if prior:
            if prior.get('file')!=cfg['mainPack'] or not ancestor(prior['source_commit'],head):raise RuntimeError('Newer incompatible viewer shell; integrate its source first')
        elif cfg['mainPack']!=POLICY['initial_boot_file']:raise RuntimeError('Viewer shell changed outside the baseline; refusing stale replacement')
    modules={}
    for key in sorted(chosen):
        if key=='boot':
            own=static_boot_sources();entry='viewers/module_viewer.tscn';deps=[];title='Универсальный просмотрщик';category='viewer'
        else:
            entry=entries.get(key);own=sources.get(key,set());deps=[]
            previous=state.get('modules',{}).get(key)
            if previous and own:
                # Integration borrows current station source trees as well as their
                # ancestry. Reuse a published pack when all its actual sources match.
                source_delta=git('diff','--name-only',previous['source_commit'],head,'--',*sorted('metro2/'+s for s in own))
                if not source_delta.strip() and key not in static_modules and not (static_inputs and key=='full_line'):continue
            # Unchanged modules above are reused verbatim. Every package we
            # actually rebuild still passes the original publication guard.
            guard(key,manifest,state,head)
            # Streaming routes explicitly replace their former eager dependency
            # list. Their station packs are build support and runtime requests.
            inherited=[] if key in POLICY.get('streamed_module_dependencies',{}) else manifest['modules'].get(key,[])
            for requirement in inherited:
                if requirement!=key and requirement not in deps:deps.append(requirement)
            # Composed routes declare existing package dependencies. Preserve each
            # dependency's real transitive pack order from the live registry.
            for requirement in POLICY.get('module_dependencies',{}).get(key,[]):
                if requirement not in manifest['packs']:raise RuntimeError('Missing route dependency '+requirement)
                for dep in manifest['modules'].get(requirement,[requirement]):
                    if dep!=key and dep not in deps:deps.append(dep)
            title=manifest.get('names',{}).get(key,names.get(key,key));category='station' if '/stations/' in (entry or '') else 'train' if key=='v106' else 'module'
            if key not in manifest['packs']:
                if not entry or key not in names:raise RuntimeError('New module must be registered in both existing scene catalog and viewer menu: '+key)
                if 'boot' not in chosen:raise RuntimeError('New module requires the updated existing viewer catalog/menu')
        deleted=[p for p in runtime if p in owners and key in owners[p] and not (ROOT/p).exists()]
        relevant_parts=[p for p in part_changes if any(p.startswith(h) and (v==key or v=='integration') for h,v in POLICY['category_hints'].items())]
        expected=cfg['mainPack'] if key=='boot' else manifest['packs'].get(key,{}).get('sha256')
        build_deps=[]
        for requirement in POLICY.get('build_support_dependencies',{}).get(key,[]):
            if requirement not in manifest['packs']:raise RuntimeError('Missing build support pack '+requirement)
            for dep in manifest['modules'].get(requirement,[requirement]):
                if dep!=key and dep not in deps and dep not in build_deps:build_deps.append(dep)
        modules[key]={'id':key,'name':title,'category':category,'source_path':roots.get(key,''),'scene':entry,'dependencies':deps,'build_dependencies':build_deps,'publication_path':PREFIX,'sources':sorted(own),'deleted':deleted,'part_changes':relevant_parts,'expected':expected,'existing':key=='boot' or key in manifest['packs']}
    result={'active':bool(modules),'head':head,'before':before,'branch':branch,'pages_base':ref,'boot_file':cfg['mainPack'],'modules':modules,'pack_versions':{k:v['sha256'] for k,v in manifest['packs'].items()}}
    write(PLAN,result);output('active',str(bool(modules)).lower());output('matrix',json.dumps({'include':[{'module':k} for k in modules]},separators=(',',':')))

def native(args,log,env=None):
    log.parent.mkdir(parents=True,exist_ok=True)
    command=['godot','--headless',*args]
    if env and env.get('METRO_STATIC_CONTROL'):
        # Mesh/MultiMesh readback needs real resource storage. Headless dummy
        # RenderingServer is unsuitable for compiling these native surfaces.
        # Software OpenGL initializes storage only: no rendering, scene playback,
        # screenshots or game main scene. Everything stays within the CI job.
        command=['xvfb-run','-a','godot','--display-driver','x11',
                 '--rendering-method','gl_compatibility','--rendering-driver','opengl3',
                 '--audio-driver','Dummy','--disable-render-loop',*args]
        env=dict(env,LIBGL_ALWAYS_SOFTWARE='1')
    with log.open('w') as f:p=subprocess.run(command,cwd=REPO,env=env,stdout=f,stderr=subprocess.STDOUT)
    data=log.read_text(errors='replace')
    if p.returncode or any(v in data for v in ['SCRIPT ERROR','Parse Error','Failed to load','ERROR:']):
        # Repeated ownership/driver warnings must not hide the first real error.
        excerpt=data if len(data)<=18000 else data[:10000]+'\n... full log retained as an artifact ...\n'+data[-8000:]
        raise RuntimeError(excerpt)

def driver(data,stage,log):
    control=CI/'controls'/log;write(control.with_suffix('.json'),data)
    runner=CI/'packer';runner.mkdir(exist_ok=True);(runner/'project.godot').write_text('config_version=5\n')
    env=dict(os.environ,METRO_DEPLOY_CONTROL=str(control.with_suffix('.json')))
    native(['--path',str(stage if data['mode'] in {'pack','prepare'} else runner),'--script',str(ROOT/'tools/automated_deploy/pack_module.gd')],CI/'logs'/(log+'.log'),env)

def pack_file(ref,name,target):
    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(git('show',ref+':'+PREFIX+name));return target

def restore_parts(spec,stage):
    manifests=set()
    for name in spec['part_changes']:
        folder=name.split('/parts/',1)[0];manifests.add(folder+'/parts/manifest.json')
    restored=[]
    for name in manifests:
        p=ROOT/name;m=json.loads(p.read_text());filename=m.get('filename','')
        if not filename or PurePosixPath(filename).name!=filename or not isinstance(m.get('parts'),list):raise RuntimeError('Unsupported model-part manifest: '+name)
        target_name=str(PurePosixPath(name).parent.parent/filename);target=stage/target_name;target.parent.mkdir(parents=True,exist_ok=True);digest=hashlib.sha256();total=0
        with target.open('wb') as f:
            for part in m['parts']:
                part_name=part['name']
                if PurePosixPath(part_name).name!=part_name:raise RuntimeError('Invalid part path')
                data=(p.parent/part_name).read_bytes()
                if len(data)!=part['size'] or hashlib.sha256(data).hexdigest()!=part['sha256']:raise RuntimeError('Corrupt saved model part '+part_name)
                f.write(data);digest.update(data);total+=len(data)
        if total!=m['size'] or digest.hexdigest()!=m['sha256']:raise RuntimeError('Restored GLB integrity mismatch')
        restored.append(target_name)
    return restored

def build(key):
    p=json.loads(PLAN.read_text());spec=p['modules'][key];stage=CI/'stage'/key;stage.mkdir(parents=True,exist_ok=True)
    ref=p['pages_base'];manifest=published(ref,'module-packs.json');own=[];foreign=set()
    pack_ids=['boot']+spec['dependencies']+spec.get('build_dependencies',[])+([key] if key!='boot' and spec['existing'] else [])
    for dep in dict.fromkeys(pack_ids):
        name=p['boot_file'] if dep=='boot' else manifest['packs'][dep]['file']
        # Old publications can be chunked; combine them only for the needed native resource pack.
        info={} if dep=='boot' else manifest['packs'][dep]
        target=CI/'inputs'/(dep+'.pck');target.parent.mkdir(parents=True,exist_ok=True)
        if info.get('chunks'):
            with target.open('wb') as f:
                for chunk in info['chunks']:f.write(git('show',ref+':'+PREFIX+chunk['file']))
        else:pack_file(ref,name,target)
        listing=CI/'lists'/(key+'-'+dep+'.json')
        driver({'mode':'unpack','pack':str(target),'destination':str(stage),'listing':str(listing)},stage,key+'-unpack-'+dep)
        paths=json.loads(listing.read_text())
        if dep==key:own=paths
        else:foreign.update(paths)
    # Seeds use current sources only after the publication ancestry/version guard.
    copied=[]
    for name in spec['sources']:
        source=ROOT/name
        if not source.is_file() or ignored(name):continue
        target=stage/name;target.parent.mkdir(parents=True,exist_ok=True)
        for suffix in ['.remap']:
            Path(str(target)+suffix).unlink(missing_ok=True)
        if target.suffix=='.gd':target.with_suffix('.gdc').unlink(missing_ok=True)
        shutil.copy2(source,target);copied.append(name)
    copied+=restore_parts(spec,stage)
    for name in spec['deleted']:
        (stage/name).unlink(missing_ok=True);Path(str(stage/name)+'.remap').unlink(missing_ok=True)
        if name.endswith('.gd'):(stage/name).with_suffix('.gdc').unlink(missing_ok=True)
    from static_world.prepare import source_files
    route_ids=json.loads((ROOT/'modules/line/route_layout.json').read_text())['station_module_ids']
    if key=='full_line' or key in route_ids:
        for name in source_files(ROOT,key):
            target=stage/name;target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(ROOT/name,target)
            Path(str(target)+'.remap').unlink(missing_ok=True)
            target.with_suffix('.gdc').unlink(missing_ok=True)
            if name not in copied:copied.append(name)
    (stage/'project.godot').write_text('config_version=5\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/vram_compression/import_s3tc_bptc=true\n[importer_defaults]\ntexture={"mipmaps/generate": true}\n')
    # Set import options before the sole mandatory editor import, including new media.
    for name in copied:
        path=stage/name
        if path.suffix.lower() in {'.png','.jpg','.jpeg','.webp','.svg'}:
            side=Path(str(path)+'.import')
            if side.exists():side.write_text(side.read_text().replace('mipmaps/generate=false','mipmaps/generate=true'))
    from static_world.prepare import prepare_speech, compile_world
    prepare_speech(ROOT,stage,key,copied)
    driver({'mode':'prepare'},stage,key+'-prepare-saved-models')
    native(['--editor','--path',str(stage),'--import'],CI/'logs'/(key+'-import.log'))
    bundle=CI/'bundles'/key;bundle.mkdir(parents=True,exist_ok=True)
    compile_world(ROOT,CI,stage,bundle,spec,p,copied,native)
    control={'mode':'pack','destination':str(stage),'output':str(bundle/'module.pck'),'base_files':own,'sources':copied,'deleted':spec['deleted'],'foreign_files':sorted(foreign),'resources':str(bundle/'resources.json'),'boot':key=='boot'}
    # Compiler entry points are build tools, not runtime dependencies.
    control['sources']=[name for name in control['sources'] if name not in {
        'tools/automated_deploy/static_world/prebuild.gd','modules/line/line_tunnel_generator.gd'}]
    driver(control,stage,key+'-pack')
    pack=bundle/'module.pck';digest=hashlib.sha256(pack.read_bytes()).hexdigest();size=pack.stat().st_size;name=key+'-'+digest[:20]+'.pck'
    resources=json.loads((bundle/'resources.json').read_text())
    if key in {'full_line','v106'}:
        # Required audio must be exported by this package or a runtime dependency;
        # build-only station packs and lone .import settings do not satisfy it.
        available=set(resources)
        runtime_report=published(ref,'pack-resources.json')
        for dep in spec['dependencies']:
            available.update(runtime_report.get('resources',{}).get(dep,[]))
        catalog_path=stage/'audio/data/audio_catalog.json'
        if not catalog_path.is_file():raise RuntimeError('Missing runtime audio catalogue for '+key)
        catalogue=json.loads(catalog_path.read_text())
        missing=[a['event_id']+': '+a.get('resource','') for a in catalogue.get('assets',[])
                 if (a.get('verified') is True or a.get('enabled') is True) and a.get('resource','') not in available
                 and a.get('resource','')+'.remap' not in available]
        for asset in catalogue.get('assets',[]):
            prepared=asset.get('prepared_resource')
            if prepared and prepared not in available and prepared+'.remap' not in available:
                missing.append(asset['event_id']+': '+prepared)
        if missing:raise RuntimeError('Required audio omitted from runtime packs: '+', '.join(missing))
    exported=set(resources)
    # Import settings can survive native staging after a dependency's exported
    # mapping is filtered out. Only an actual source or exported .remap owns a
    # runtime warmup entry; .import metadata alone must not force optional packs.
    textures=sorted({source_name(s) for s in resources
                     if source_name(s).lower().endswith(('.png','.jpg','.jpeg','.webp','.svg'))
                     and not source_name(s).startswith('.godot/')
                     and ('res://'+source_name(s) in exported or
                          'res://'+source_name(s)+'.remap' in exported)})
    entry={'file':name,'sha256':digest,'bytes':size,'warmup':['res://'+s for s in textures]}
    if key!='boot' and size>32*1024*1024:
        chunks=[]
        with pack.open('rb') as f:
            while True:
                data=f.read(POLICY['chunk_bytes'])
                if not data:break
                h=hashlib.sha256(data).hexdigest();chunk=key+'-part-'+h[:20]+'.bin';(bundle/chunk).write_bytes(data);chunks.append({'file':chunk,'bytes':len(data),'sha256':h})
        entry['chunks']=chunks;pack.unlink()
    else:pack.rename(bundle/name)
    write(bundle/'entry.json',{'module':spec,'entry':entry,'source_commit':p['head']})

def publish():
    plan_data=json.loads(PLAN.read_text());head=plan_data['head'];branch=plan_data['branch']
    newest=git('ls-remote','origin','refs/heads/'+branch).decode().split()[0]
    if newest!=head:raise RuntimeError('Superseded branch commit: no publication')
    bundles={}
    for key in plan_data['modules']:
        folder=CI/'bundles'/key;bundles[key]=(folder,json.loads((folder/'entry.json').read_text()))
    # GitHub rejects blobs over 100 MiB. Fail before creating/uploading Git
    # objects, rather than retrying the same permanently rejected payload.
    for folder,_data in bundles.values():
        for payload in folder.iterdir():
            if payload.suffix in {'.pck','.bin'} and payload.stat().st_size>96*1024*1024:
                raise RuntimeError('Publication payload must be partitioned before push: '+payload.name)
    print('Publication: bundles ready; refreshing published metadata',flush=True)
    for attempt in range(3):
        base=fetch_pages();manifest=published(base,'module-packs.json');report=published(base,'pack-resources.json');info=published(base,'build-info.json');state=published(base,POLICY['state_file'],{'schema':1,'modules':{}})
        html,match,cfg=boot_config(base);files={}
        live_versions={k:v['sha256'] for k,v in manifest['packs'].items()}
        for key,(folder,data) in bundles.items():
            spec=data['module'];entry=data['entry']
            for dep in spec['dependencies']+spec.get('build_dependencies',[]):
                if live_versions.get(dep)!=plan_data['pack_versions'].get(dep):raise RuntimeError('A required dependency changed during build: '+dep)
            actual=cfg['mainPack'] if key=='boot' else manifest['packs'].get(key,{}).get('sha256')
            if actual!=spec['expected']:raise RuntimeError('Publication moved for '+key+'; refuse stale replacement, retain build artifacts')
            if key=='boot':
                old=cfg['mainPack'];cfg['mainPack']=entry['file'];cfg.setdefault('fileSizes',{}).pop(old,None);cfg['fileSizes'][entry['file']]=entry['bytes']
                state['boot']={'source_commit':head,'file':entry['file']};continue
            manifest['packs'][key]=entry
            manifest.setdefault('modules',{})[key]=spec['dependencies']+[key]
            manifest.setdefault('names',{}).setdefault(key,spec['name'])
            report.setdefault('resources',{})[key]=json.loads((folder/'resources.json').read_text())
            if spec['scene']:report.setdefault('entries',{})[key]=spec['scene']
            info.setdefault('module_packs',{})[key]=entry
            state.setdefault('modules',{})[key]={'source_commit':head,'pack_sha256':entry['sha256'],'category':spec['category'],'scene':spec['scene'],'dependencies':spec['dependencies']}
        patch=CI/'publication';patch.mkdir(exist_ok=True)
        for name,data in [('module-packs.json',manifest),('pack-resources.json',report),('build-info.json',info),(POLICY['state_file'],state)]:write(patch/name,data)
        if 'boot' in bundles:
            (patch/'index.html').write_text(html[:match.start(1)]+json.dumps(cfg,separators=(',',':'))+html[match.end(1):])
        for key,(folder,data) in bundles.items():
            for p in folder.iterdir():
                if p.suffix in {'.pck','.bin'}:files[PREFIX+p.name]=p
        files.update({PREFIX+p.name:p for p in patch.iterdir() if p.is_file()})
        # An isolated index merges against the latest tree without checking out or deleting other modules.
        index=CI/'publication.index';index.unlink(missing_ok=True);env=dict(os.environ,GIT_INDEX_FILE=str(index))
        print('Publication: indexing '+str(len(files))+' files ('+str(sum(p.stat().st_size for p in files.values())//(1024*1024))+' MiB)',flush=True)
        git('read-tree',base,env=env)
        for path,local in files.items():
            sha=git('hash-object','-w',str(local)).decode().strip();git('update-index','--add','--cacheinfo','100644,'+sha+','+path,env=env)
        tree=git('write-tree',env=env).decode().strip()
        commit=git('-c','user.name=github-actions[bot]','-c','user.email=41898282+github-actions[bot]@users.noreply.github.com','commit-tree',tree,'-p',base,input=('Update selected Metro2 packs from '+head+'\n').encode()).decode().strip()
        # Native archives are already content-addressed; delta search across large
        # binary packs wastes CPU and can lazily fetch old blobs in this partial
        # clone. Send self-contained objects without searching for delta bases.
        print('Publication: sending Git objects, attempt '+str(attempt+1),flush=True)
        command=['git','-c','pack.window=0','-c','pack.compression=1',
                 'push','--no-thin','--progress','origin',commit+':'+POLICY['pages_branch']]
        with subprocess.Popen(command,cwd=REPO,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                              text=True,errors='replace') as pushed:
            messages=[]
            for line in pushed.stdout:
                print(line,end='',flush=True);messages.append(line)
            status=pushed.wait()
        if status==0:
            print('Publication: gh-pages updated',flush=True)
            return
        detail=''.join(messages)
        # Only a competing publication can be repaired by refreshing metadata.
        # Size limits, transport/authentication errors must remain visible.
        conflict=any(reason in detail.lower() for reason in
                     ('non-fast-forward','fetch first','stale info'))
        if not conflict or attempt==2:raise RuntimeError(detail)
        print('Publication: concurrent update; refreshing metadata',flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['plan','build','publish']);parser.add_argument('--module');args=parser.parse_args()
    if args.mode=='plan':plan()
    elif args.mode=='build':build(args.module)
    else:publish()
