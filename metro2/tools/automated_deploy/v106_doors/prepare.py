"""Prepare only original V106 side-door resources in the standard CI build."""
import hashlib, json, os, shutil

PREFIX = 'tools/automated_deploy/v106_doors/'
FILES = [PREFIX+'compile.gd', PREFIX+'skin_split.gd',
         'modules/line/build_budget.gd', 'modules/trains/v106/side_cab_door.gd',
         'modules/trains/v106/native_cab_doors.gd', 'modules/trains/v106/side_cab_doors.json']


def stage_sources(root, stage, copied):
    for name in FILES:
        target = stage/name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root/name, target)
        target.with_suffix('.gdc').unlink(missing_ok=True)
        target.with_name(target.name+'.remap').unlink(missing_ok=True)
        if name not in copied:
            copied.append(name)


def compile_doors(root, ci, stage, copied, native):
    config = json.loads((root/'modules/trains/v106/side_cab_doors.json').read_text())
    digest = hashlib.sha256(b'v106-native-side-doors-v1')
    for name in FILES:
        digest.update(name.encode())
        digest.update((root/name).read_bytes())
    # Include the real staged imported model and its mappings, never assume
    # that two model revisions have matching source paths or node transforms.
    for model in config['models']:
        source = model['source'].removeprefix('res://')
        for candidate in [stage/source, stage/(source+'.remap'), stage/(source+'.import')]:
            if candidate.is_file():
                digest.update(candidate.read_bytes())
        mapping = stage/(source+'.remap')
        if mapping.is_file():
            import re
            match = re.search(r'path="([^"]+)"', mapping.read_text())
            if match:
                artifact = stage/match[1].removeprefix('res://')
                if artifact.is_file():
                    digest.update(artifact.read_bytes())
    cache = ci/'static-cache'/'v106'/'side-doors'/digest.hexdigest()
    if not (cache/'complete.json').is_file():
        native(['--path',str(stage),'--script','res://'+PREFIX+'compile.gd'],
               ci/'logs'/'v106-side-doors.log',
               dict(os.environ, METRO_STATIC_CONTROL='v106-side-door-resources'))
        cache.mkdir(parents=True, exist_ok=True)
        for model in config['models']:
            relative = model['resource'].removeprefix('res://')
            source = stage/relative
            if not source.is_file():
                raise RuntimeError('Missing prepared side-door output '+relative)
            if source.stat().st_size > 96*1024*1024:
                raise RuntimeError('Prepared side-door resource exceeds publication limit')
            shutil.copy2(source, cache/source.name)
        (cache/'complete.json').write_text(json.dumps({'outputs':[m['resource'] for m in config['models']]}))
    for model in config['models']:
        relative = model['resource'].removeprefix('res://')
        target = stage/relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(cache/target.name, target)
        if relative not in copied:
            copied.append(relative)
    # Compiler scripts are resource tools, not runtime dependencies.
    copied[:] = [name for name in copied if not name.startswith(PREFIX)]
