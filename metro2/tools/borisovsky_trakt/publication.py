"""Preserve published packs; add station and update existing menu boot only."""
import hashlib,json,os,re,subprocess,sys
from pathlib import Path
PREFIX='metro2/module-viewer/'
def read(ref,path): return subprocess.check_output(['git','show',ref+':'+PREFIX+path])
def hashfile(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def config(html):
 m=re.search(r'const GODOT_CONFIG\s*=\s*(\{[^\n]+\});',html)
 if not m:raise RuntimeError('Missing Godot Web configuration')
 return m,json.loads(m[1])
mode=sys.argv[1];out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
if mode=='prepare':
 ref=sys.argv[3];html=read(ref,'index.html').decode();_,cfg=config(html)
 boot=cfg['mainPack'];(out/'old-boot.pck').write_bytes(read(ref,boot))
 for p in ['index.html','module-packs.json','build-info.json']:(out/p).write_bytes(read(ref,p))
 (out/'base.json').write_text(json.dumps({'ref':ref,'boot':boot,'boot_sha':hashfile(out/'old-boot.pck')}))
elif mode=='finish':
 base=json.loads((out/'base.json').read_text());html=(out/'index.html').read_text();m,cfg=config(html)
 files={}
 for name,prefix in [('station.pck','borisovsky_trakt'),('new-boot.pck','boot')]:
  p=out/name;sha=hashfile(p);filename=prefix+'-'+sha[:20]+'.pck';p.rename(out/filename);files[prefix]={'file':filename,'sha256':sha,'bytes':(out/filename).stat().st_size}
 boot=files['boot'];cfg['mainPack']=boot['file'];cfg['fileSizes'].pop(base['boot'],None);cfg['fileSizes'][boot['file']]=boot['bytes']
 html=html[:m.start(1)]+json.dumps(cfg,separators=(',',':'))+html[m.end(1):];(out/'index.html').write_text(html)
 manifest=json.loads((out/'module-packs.json').read_text());manifest['modules']['borisovsky_trakt']=['borisovsky_trakt'];manifest['names']['borisovsky_trakt']='Борисовский тракт';manifest['packs']['borisovsky_trakt']=dict(files['borisovsky_trakt'],warmup=[])
 (out/'module-packs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 info=json.loads((out/'build-info.json').read_text());info['borisovsky_trakt']={'source_commit':os.environ['GITHUB_SHA'],'pack':files['borisovsky_trakt'],'validation':'ZERO TESTING; editor import and export only'}
 (out/'build-info.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
 (out/'old-boot.pck').unlink();(out/'base.json').unlink()
 # Only these files will be copied into the existing publication.
 (out/'SHA256SUMS-borisovsky-trakt').write_text(''.join(hashfile(p)+'  '+p.name+'\n' for p in sorted(out.iterdir()) if p.is_file()))
