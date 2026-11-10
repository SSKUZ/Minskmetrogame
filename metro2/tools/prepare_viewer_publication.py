#!/usr/bin/env python3
"""Prepare an additive Pages commit from the verified V48 artifact. Never move a ref."""
import base64
import hashlib
import io
import json
from pathlib import Path
import zipfile

from web_publication import GitHub, REPO

ARTIFACT = 13755179978
ARTIFACT_NAME = 'metro2-module-viewer-v48-8fb360410bc2a7084292fccead5c8bcd44f67cdf'
ZIP_SHA = '9804a80222bc0391f01310ecc20ad40880b4f5a11f3b01552ae964aee02cc8ac'
PREFIX = 'metro2/module-viewer-v48/'
SOURCE = '8fb360410bc2a7084292fccead5c8bcd44f67cdf'


def main():
    api = GitHub()
    meta = api.request(f'/repos/{REPO}/actions/artifacts/{ARTIFACT}')
    assert meta['name'] == ARTIFACT_NAME and not meta['expired']
    assert meta['size_in_bytes'] == 41025032
    data = api.request(f'/repos/{REPO}/actions/artifacts/{ARTIFACT}/zip', raw=True)
    assert len(data) == 41025032 and hashlib.sha256(data).hexdigest() == ZIP_SHA
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        assert archive.testzip() is None
        files = {}
        for entry in archive.infolist():
            name = entry.filename
            assert not entry.is_dir() and '/' not in name and '\\' not in name and name not in ('.', '..')
            assert name not in files
            files[name] = archive.read(entry)
    for name in ['index.html','index.js','index.wasm','index.pck','build-info.json','SHA256SUMS']:
        assert files.get(name), name
    for line in files['SHA256SUMS'].decode().splitlines():
        digest, name = line.split(maxsplit=1)
        assert hashlib.sha256(files[name.lstrip('*')]).hexdigest() == digest
    assert json.loads(files['build-info.json'])['source_commit'] == SOURCE
    print('V48_1_ARTIFACT_VERIFIED', ZIP_SHA, flush=True)

    head = api.request(f'/repos/{REPO}/git/ref/heads/gh-pages')['object']['sha']
    commit = api.request(f'/repos/{REPO}/git/commits/{head}')
    before = api.request(f'/repos/{REPO}/git/trees/{commit["tree"]["sha"]}?recursive=1')
    assert not before.get('truncated')
    assert not any(e['path'] == PREFIX.rstrip('/') or e['path'].startswith(PREFIX) for e in before['tree']), 'Target already exists; no overwrite permitted'
    old_files = {e['path']:(e['mode'],e['type'],e['sha']) for e in before['tree'] if e['type'] != 'tree'}
    existing_blobs = {e['sha'] for e in before['tree'] if e['type'] == 'blob'}
    additions = []
    checksums = {}
    for name, content in sorted(files.items()):
        git_sha = hashlib.sha1(f'blob {len(content)}\0'.encode()+content).hexdigest()
        if git_sha not in existing_blobs:
            blob = api.request(f'/repos/{REPO}/git/blobs', method='POST', data={'content':base64.b64encode(content).decode(),'encoding':'base64'})
            assert blob['sha'] == git_sha
        additions.append({'path':PREFIX+name,'mode':'100644','type':'blob','sha':git_sha})
        checksums[name] = {'size':len(content),'sha256':hashlib.sha256(content).hexdigest(),'git_blob':git_sha}
    tree = api.request(f'/repos/{REPO}/git/trees', method='POST', data={'base_tree':commit['tree']['sha'],'tree':additions})
    after = api.request(f'/repos/{REPO}/git/trees/{tree["sha"]}?recursive=1')
    assert not after.get('truncated')
    new_files = {e['path']:(e['mode'],e['type'],e['sha']) for e in after['tree'] if e['type'] != 'tree'}
    assert all(new_files.get(path) == value for path,value in old_files.items()), 'Existing publication changed'
    assert set(new_files)-set(old_files) == {e['path'] for e in additions}
    candidate = api.request(f'/repos/{REPO}/git/commits', method='POST', data={
        'message':'Publish existing V48 module viewer in isolated directory; preserve every existing publication',
        'tree':tree['sha'],'parents':[head]})
    result = {'base_gh_pages_sha':head,'publication_commit':candidate['sha'],'tree':tree['sha'],
              'artifact_id':ARTIFACT,'zip_sha256':ZIP_SHA,'source_commit':SOURCE,
              'prefix':PREFIX,'existing_files_preserved':len(old_files),'added_files':checksums,
              'ref_updated':False,'godot_rebuilt':False}
    Path('viewer-publication-result.json').write_text(json.dumps(result,indent=2))
    print('V48_1_CANDIDATE',json.dumps(result),flush=True)


if __name__ == '__main__':
    main()
