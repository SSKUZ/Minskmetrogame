#!/usr/bin/env python3
"""Add a separate V49 viewer directory; preserve every existing published blob."""
import base64
import hashlib
import json
from pathlib import Path
from web_publication import GitHub, REPO

PREFIX = 'metro2/module-viewer-v49/'
api = GitHub()
head = api.request(f'/repos/{REPO}/git/ref/heads/gh-pages')['object']['sha']
base = api.request(f'/repos/{REPO}/git/commits/{head}')
before = api.request(f'/repos/{REPO}/git/trees/{base["tree"]["sha"]}?recursive=1')
assert not before.get('truncated')
leaves = {e['path']:(e['mode'],e['type'],e['sha']) for e in before['tree'] if e['type'] != 'tree'}
assert not any(p.startswith(PREFIX) or p == PREFIX.rstrip('/') for p in leaves), 'V49 target already exists; refuse overwrite'
existing = {v[2] for v in leaves.values()}
out = Path('viewer-v49-web')
required = {'index.html','index.js','index.wasm','index.pck','build-info.json','SHA256SUMS'}
assert required.issubset({p.name for p in out.iterdir()})
for line in (out/'SHA256SUMS').read_text().splitlines():
    digest,name = line.split(maxsplit=1)
    assert hashlib.sha256((out/name.lstrip('*')).read_bytes()).hexdigest() == digest
entries = []
checksums = {}
for p in sorted(out.iterdir()):
    assert p.is_file()
    content = p.read_bytes()
    sha = hashlib.sha1(f'blob {len(content)}\0'.encode()+content).hexdigest()
    if sha not in existing:
        blob = api.request(f'/repos/{REPO}/git/blobs',method='POST',data={'encoding':'base64','content':base64.b64encode(content).decode()})
        assert blob['sha'] == sha
    entries.append({'path':PREFIX+p.name,'mode':'100644','type':'blob','sha':sha})
    checksums[p.name] = hashlib.sha256(content).hexdigest()
tree = api.request(f'/repos/{REPO}/git/trees',method='POST',data={'base_tree':base['tree']['sha'],'tree':entries})
after = api.request(f'/repos/{REPO}/git/trees/{tree["sha"]}?recursive=1')
assert not after.get('truncated')
new = {e['path']:(e['mode'],e['type'],e['sha']) for e in after['tree'] if e['type'] != 'tree'}
assert all(new.get(p) == v for p,v in leaves.items()), 'An existing published file changed'
assert set(new)-set(leaves) == {e['path'] for e in entries}
commit = api.request(f'/repos/{REPO}/git/commits',method='POST',data={'tree':tree['sha'],'parents':[head],'message':'Add standalone V49 saloon viewer; preserve all existing publications'})
proof = {'base':head,'commit':commit['sha'],'tree':tree['sha'],'prefix':PREFIX,'preserved_files':len(leaves),'added_files':len(entries),'sha256':checksums,'ref_updated':False}
Path('viewer-v49-publication.json').write_text(json.dumps(proof,indent=2))
print('V49_PUBLICATION_CANDIDATE',json.dumps(proof),flush=True)
