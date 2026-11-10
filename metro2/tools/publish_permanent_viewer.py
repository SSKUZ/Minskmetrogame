#!/usr/bin/env python3
"""Explicit publication only; no build, model changes, or push-triggered deployment.

Prepare: python3 metro2/tools/publish_permanent_viewer.py --web-dir build/viewer
Publish: add --publish --expected-pages-head <reviewed gh-pages SHA>.
First migration can reuse --reuse-prefix metro2/module-viewer-v49/ instead.
Requires GH_TOKEN and the existing web_publication.py helper in this directory.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
from web_publication import GitHub, REPO

PREFIX = 'metro2/module-viewer/'
REQUIRED = {'index.html','index.js','index.wasm','index.pck','build-info.json','SHA256SUMS'}
FETCH = 'fetch(file).then(function (response) {'
FRESH_FETCH = 'fetch(file + (file.indexOf("?") < 0 ? "?" : "&") + "v=" + Date.now(), {cache: "no-store"}).then(function (response) {'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def hosting_files(html, javascript, info, hashes):
    """Change the HTTP request only; keep Godot's virtual pack filename intact."""
    assert javascript.count(FETCH) == 1, 'Unexpected Godot 4.3 preload loader; stop'
    javascript = javascript.replace(FETCH,FRESH_FETCH)
    assert '<script src="index.js"></script>' in html
    html = html.replace('<script src="index.js"></script>', '<script src="index.js?v='+digest(javascript.encode())[:16]+'"></script>')
    info = dict(info, published=True, publication_path=PREFIX,
                pack_sha256=hashes['index.pck'], cache_policy='PCK request nonce and no-store')
    data = {'index.html':html.encode(), 'index.js':javascript.encode(),
            'build-info.json':json.dumps(info,ensure_ascii=False,indent=2).encode()}
    hashes = dict(hashes)
    for name,content in data.items(): hashes[name]=digest(content)
    data['SHA256SUMS']=''.join(f'{value}  {name}\n' for name,value in sorted(hashes.items())).encode()
    return data


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    source=parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--web-dir',type=Path)
    source.add_argument('--reuse-prefix',help='Reuse a verified existing publication without rebuilding')
    parser.add_argument('--publish',action='store_true',help='Explicitly advance gh-pages after all preservation checks')
    parser.add_argument('--expected-pages-head',help='Required lease for publication; refuse concurrent changes')
    args=parser.parse_args()
    if args.publish and not args.expected_pages_head: parser.error('--publish requires --expected-pages-head')
    api=GitHub()
    head=api.request(f'/repos/{REPO}/git/ref/heads/gh-pages')['object']['sha']
    if args.expected_pages_head and args.expected_pages_head != head: raise SystemExit('gh-pages changed; review the new HEAD first')
    base=api.request(f'/repos/{REPO}/git/commits/{head}')
    before=api.request(f'/repos/{REPO}/git/trees/{base["tree"]["sha"]}?recursive=1')
    assert not before.get('truncated')
    leaves={e['path']:(e['mode'],e['type'],e['sha']) for e in before['tree'] if e['type'] != 'tree'}
    assert PREFIX.rstrip('/') not in leaves, 'Target is a file, not a directory'
    existing={v[2] for v in leaves.values()}
    contents={}
    references={}
    if args.web_dir:
        contents={p.name:p.read_bytes() for p in args.web_dir.iterdir() if p.is_file()}
        assert REQUIRED.issubset(contents), 'Missing Web files'
        hashes={}
        for line in contents['SHA256SUMS'].decode().splitlines():
            value,name=line.split(maxsplit=1);name=name.lstrip('*')
            assert '/' not in name and '\\' not in name and name in contents
            assert digest(contents[name]) == value, 'Web checksum mismatch: '+name
            hashes[name]=value
        assert set(hashes) == set(contents)-{'SHA256SUMS'}, 'Unlisted Web file'
    else:
        prefix=args.reuse_prefix
        assert prefix.startswith('metro2/') and prefix.endswith('/') and prefix != PREFIX
        references={path[len(prefix):]:v[2] for path,v in leaves.items() if path.startswith(prefix)}
        assert REQUIRED.issubset(references), 'Missing reusable Web files'
        assert all('/' not in name for name in references), 'Expected one flat Web export'
        for name in ['index.html','index.js','build-info.json','SHA256SUMS']:
            blob=api.request(f'/repos/{REPO}/git/blobs/{references[name]}')
            contents[name]=base64.b64decode(blob['content'])
        hashes={}
        for line in contents['SHA256SUMS'].decode().splitlines():
            value,name=line.split(maxsplit=1);name=name.lstrip('*');hashes[name]=value
            if name in contents: assert digest(contents[name]) == value
        assert set(hashes) == set(references)-{'SHA256SUMS'}
    contents.update(hosting_files(contents['index.html'].decode(),contents['index.js'].decode(),json.loads(contents['build-info.json']),hashes))
    names=set(contents)|set(references)
    entries=[]
    for name in sorted(names):
        assert '/' not in name and '\\' not in name and name not in ['.','..']
        sha=references.get(name)
        if name in contents:
            content=contents[name]
            sha=hashlib.sha1(f'blob {len(content)}\0'.encode()+content).hexdigest()
            if sha not in existing:
                blob=api.request(f'/repos/{REPO}/git/blobs',method='POST',data={'encoding':'base64','content':base64.b64encode(content).decode()})
                assert blob['sha'] == sha
        entries.append({'path':PREFIX+name,'mode':'100644','type':'blob','sha':sha})
    # Remove obsolete support files only inside the permanent viewer directory.
    for path in leaves:
        if path.startswith(PREFIX) and path[len(PREFIX):] not in names:
            entries.append({'path':path,'mode':'100644','type':'blob','sha':None})
    tree=api.request(f'/repos/{REPO}/git/trees',method='POST',data={'base_tree':base['tree']['sha'],'tree':entries})
    after=api.request(f'/repos/{REPO}/git/trees/{tree["sha"]}?recursive=1')
    assert not after.get('truncated')
    new={e['path']:(e['mode'],e['type'],e['sha']) for e in after['tree'] if e['type'] != 'tree'}
    assert {p:v for p,v in leaves.items() if not p.startswith(PREFIX)} == {p:v for p,v in new.items() if not p.startswith(PREFIX)}, 'Outside publication changed'
    if tree['sha'] == base['tree']['sha']:
        print('PERMANENT_VIEWER_ALREADY_CURRENT',head)
        return
    commit=api.request(f'/repos/{REPO}/git/commits',method='POST',data={'tree':tree['sha'],'parents':[head],'message':'Update permanent module viewer only'})
    if args.publish:
        # A normal fast-forward PATCH cannot overwrite a concurrent publication.
        current=api.request(f'/repos/{REPO}/git/ref/heads/gh-pages')['object']['sha']
        assert current == head, 'Concurrent publication; refuse ref update'
        api.request(f'/repos/{REPO}/git/refs/heads/gh-pages',method='PATCH',data={'sha':commit['sha'],'force':False})
    print(json.dumps({'base':head,'commit':commit['sha'],'prefix':PREFIX,'published':args.publish,'preserved_files':sum(not p.startswith(PREFIX) for p in leaves)},indent=2))


if __name__ == '__main__': main()
