#!/usr/bin/env python3
"""Prepare an update of only the existing viewer directory, without moving refs."""
import base64
import hashlib
import json
from pathlib import Path
from web_publication import GitHub, REPO

PREFIX = 'metro2/module-viewer-v48/'
OLD = {
'SHA256SUMS':'8c435b2701dbfed4f0c6589a96d1c14b3a685f7c',
'build-info.json':'fa8adf84d87030f7581adae375f375fbae1119a5',
'index.audio.worklet.js':'3b94cab85cb937fa27056d17648cdbb73e44bdbd',
'index.html':'b7b80fafda0cf5b6cda7f058fdb8c2eb73711aad',
'index.js':'322c2d1ebb65ff6a0ca2dc8834227d647fea10d4',
'index.pck':'9039d61257a1a83af192b6a8c3126d247ea5d29d',
'index.png':'766b0b66efb1ac8cb53d9cd6b7fa2ef70c6ec559',
'index.wasm':'f663665cd96bed994e6498ee9defb1e7ec76c8bb'}

api = GitHub()
head = api.request(f'/repos/{REPO}/git/ref/heads/gh-pages')['object']['sha']
base = api.request(f'/repos/{REPO}/git/commits/{head}')
before = api.request(f'/repos/{REPO}/git/trees/{base["tree"]["sha"]}?recursive=1')
assert not before.get('truncated')
leaves = {e['path']:(e['mode'],e['type'],e['sha']) for e in before['tree'] if e['type'] != 'tree'}
current = {p[len(PREFIX):]:v[2] for p,v in leaves.items() if p.startswith(PREFIX)}
assert current == OLD, 'Viewer publication changed concurrently; refuse overwrite'
existing = {v[2] for v in leaves.values()}
out = Path('viewer-v48-web')
assert {p.name for p in out.iterdir()} == set(OLD)
for line in (out/'SHA256SUMS').read_text().splitlines():
    digest,name = line.split(maxsplit=1)
    assert hashlib.sha256((out/name.lstrip('*')).read_bytes()).hexdigest() == digest
entries = []
checksums = {}
for p in sorted(out.iterdir()):
    content = p.read_bytes()
    sha = hashlib.sha1(f'blob {len(content)}\0'.encode()+content).hexdigest()
    if sha not in existing:
        result = api.request(f'/repos/{REPO}/git/blobs',method='POST',data={'encoding':'base64','content':base64.b64encode(content).decode()})
        assert result['sha'] == sha
    entries.append({'path':PREFIX+p.name,'mode':'100644','type':'blob','sha':sha})
    checksums[p.name] = hashlib.sha256(content).hexdigest()
tree = api.request(f'/repos/{REPO}/git/trees',method='POST',data={'base_tree':base['tree']['sha'],'tree':entries})
after = api.request(f'/repos/{REPO}/git/trees/{tree["sha"]}?recursive=1')
assert not after.get('truncated')
new = {e['path']:(e['mode'],e['type'],e['sha']) for e in after['tree'] if e['type'] != 'tree'}
assert all(new.get(p)==v for p,v in leaves.items() if not p.startswith(PREFIX))
assert set(new)==set(leaves)
commit = api.request(f'/repos/{REPO}/git/commits',method='POST',data={'tree':tree['sha'],'parents':[head],'message':'Update only module viewer: analog joystick and direct free-flight navigation'})
proof = {'base':head,'commit':commit['sha'],'tree':tree['sha'],'preserved_files':len(leaves)-len(OLD),'sha256':checksums,'ref_updated':False}
Path('viewer-portrait-publication.json').write_text(json.dumps(proof,indent=2))
print('PORTRAIT_PUBLICATION_CANDIDATE',json.dumps(proof),flush=True)
