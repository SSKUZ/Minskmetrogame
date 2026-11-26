"""Select live Pages payloads without deleting archived publications from Git."""
from pathlib import Path
import hashlib
import json
import re
import struct


def world_files(pack):
    """Read static-world JSON indexes from an unencrypted Godot 4.3 PCK.

    This reads the archive directory and JSON data only; no Godot scene runs.
    """
    records = {}
    with Path(pack).open('rb') as stream:
        def read(size):
            data = stream.read(size)
            if len(data) != size:
                raise RuntimeError('Truncated resource pack: '+str(pack))
            return data

        magic, version, major, minor, patch, flags, base = struct.unpack('<6IQ', read(32))
        if magic != 0x43504447 or version != 2 or flags & 1:
            raise RuntimeError('Unsupported/encrypted resource pack: '+str(pack))
        read(64)
        count, = struct.unpack('<I', read(4))
        indexes = []
        for _ in range(count):
            length, = struct.unpack('<I', read(4))
            if length > 1024*1024:
                raise RuntimeError('Invalid PCK resource path')
            name = read(length).rstrip(b'\0').decode('utf-8')
            offset, size = struct.unpack('<QQ', read(16))
            read(16)  # Native per-file MD5.
            file_flags, = struct.unpack('<I', read(4))
            if name.endswith('.json') and '/prebuilt/' in name:
                if file_flags & 1 or size > 64*1024*1024:
                    raise RuntimeError('Unsupported static-world index: '+name)
                indexes.append((base+offset, size))

        def collect(value):
            if isinstance(value, dict):
                name = value.get('file', '')
                if isinstance(name, str) and re.fullmatch(r'world-[0-9a-f]+\.bin', name):
                    record = {key: value[key] for key in ('file', 'bytes', 'sha256')}
                    if not isinstance(record['bytes'], int) or record['bytes'] <= 0:
                        raise RuntimeError('Invalid static archive size: '+name)
                    if not re.fullmatch('[0-9a-f]{64}', record['sha256']):
                        raise RuntimeError('Invalid static archive digest: '+name)
                    if name in records and records[name] != record:
                        raise RuntimeError('Conflicting static archive: '+name)
                    records[name] = record
                for child in value.values():
                    collect(child)
            elif isinstance(value, list):
                for child in value:
                    collect(child)

        for offset, size in indexes:
            stream.seek(offset)
            collect(json.loads(read(size)))
    return sorted(records.values(), key=lambda item: item['file'])


def configuration(base, manifest, report, config, files, prefix, ci, git):
    """Exclude historical binaries from Jekyll, explicitly include every live one."""
    paths = set(git('ls-tree', '-r', '--name-only', base).decode().splitlines())
    paths.update(files)
    keep = {}

    def retain(record):
        name = record['file']
        if Path(name).name != name or not name.endswith(('.pck', '.bin')):
            raise RuntimeError('Invalid live Pages payload: '+name)
        path = prefix+name
        if path not in paths:
            raise RuntimeError('Live Pages payload is missing: '+path)
        size = int(record['bytes'])
        if path in keep and keep[path] != size:
            raise RuntimeError('Conflicting live payload size: '+path)
        if path in files and files[path].stat().st_size != size:
            raise RuntimeError('Incorrect live payload size: '+path)
        keep[path] = size

    boot = config['mainPack']
    retain({'file': boot, 'bytes': config['fileSizes'][boot]})
    for key, entry in manifest['packs'].items():
        # Migrate older package metadata once, by reading its native JSON index.
        # Packages without a compiled index need no archive inspection.
        if 'world_files' not in entry:
            indexed=any('/prebuilt/' in path and path.endswith('.json')
                        for path in report.get('resources',{}).get(key,[]))
            if not indexed:
                entry['world_files'] = []
            else:
                target = ci/'pages-indexes'/(entry['sha256']+'.pck')
                target.parent.mkdir(parents=True, exist_ok=True)
                digest = hashlib.sha256()
                with target.open('wb') as output:
                    for part in entry.get('chunks') or [entry]:
                        data = git('show', base+':'+prefix+part['file'])
                        if len(data) != part['bytes'] or hashlib.sha256(data).hexdigest() != part['sha256']:
                            raise RuntimeError('Corrupt published package: '+key)
                        output.write(data)
                        digest.update(data)
                if digest.hexdigest() != entry['sha256']:
                    raise RuntimeError('Corrupt published package: '+key)
                entry['world_files'] = world_files(target)
                target.unlink()
        for record in (entry.get('chunks') or [entry])+entry['world_files']:
            retain(record)

    # Historical previews stay in Git at their original paths. All registered
    # current modules and their archives stay available through the permanent URL.
    metro_dirs = {path.split('/')[1] for path in paths
                  if path.startswith('metro2/') and path.count('/') >= 2}
    excluded = ['cab-preview', 'preview', 'v106',
                prefix+'*.pck', prefix+'*.bin']
    excluded += ['metro2/'+name for name in sorted(metro_dirs-{
        'module-viewer', 'runtime', 'audio-library', 'audio'})]
    # Count the retained runtime, shell and audio as well. Only these small
    # ancillary files are inspected; never hydrate 90,000 historical binaries.
    extra = 0
    for path in sorted(paths):
        if path in keep or path == '.nojekyll':
            continue
        if any(path == item or path.startswith(item+'/') for item in excluded if '*' not in item):
            continue
        if path.startswith(prefix) and path.endswith(('.pck', '.bin')):
            continue
        extra += (files[path].stat().st_size if path in files else
                  int(git('cat-file', '-s', base+':'+path).decode().strip()))
    total = sum(keep.values())+extra
    # Reserve 50 MB below the service's decimal 1 GB limit for the generated
    # registries/configuration and archive framing. Never commit an oversized site.
    if total > 950_000_000:
        raise RuntimeError('Live Pages payload exceeds the 950 MB publication budget: '+str(total))
    print('Pages retained payload: '+str(total//(1024*1024))+' MiB; '+str(len(keep))+' native files', flush=True)
    # JSON is valid YAML. Jekyll EntryFilter applies explicit include before
    # exclude, so new content-addressed files need no growing exclusion list.
    return json.dumps({'include': sorted({Path(path).name for path in keep}), 'exclude': excluded,
                       'plugins': [], 'keep_files': []}, indent=2)+'\n'
