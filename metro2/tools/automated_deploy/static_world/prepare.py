"""Build-time resource compilation within the existing changed-module deployment."""
from pathlib import Path
import hashlib, io, json, os, shutil, subprocess, wave

RUNTIME_FILES = ['modules/line/static_station.gd', 'modules/line/static_resource_store.gd',
                 'modules/line/build_budget.gd', 'modules/line/station_connection_adapter.gd',
                 'modules/line/route_layout.json']
COMPILER = 'tools/automated_deploy/static_world/prebuild.gd'


def source_files(root, key):
    files = RUNTIME_FILES + [COMPILER]
    if key != 'full_line':
        files += ['tools/automated_deploy/static_world/station_clock_runtime.gd']
    if key == 'uruchye':
        files += ['tools/automated_deploy/static_world/uruchye_ad_runtime.gd']
    return files


def compile_world(root, ci, stage, bundle, spec, plan, copied, native):
    key = spec['id']
    route = json.loads((root/'modules/line/route_layout.json').read_text())
    if key != 'full_line' and key not in route['station_module_ids']:
        return
    for name in source_files(root, key):
        target = stage/name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root/name, target)
        Path(str(target)+'.remap').unlink(missing_ok=True)
        target.with_suffix('.gdc').unlink(missing_ok=True)
        if name not in copied:
            copied.append(name)
    digest = hashlib.sha256(b'godot-4.3-static-world-v1')
    geometry_sources = set(spec['sources']) | set(source_files(root, key))
    if key == 'full_line':
        geometry_sources = {s for s in geometry_sources if s.startswith(('modules/line/', 'scripts/tunnel', 'scripts/depot/route_profile'))}
        geometry_sources |= set(source_files(root, key))
    for name in sorted(geometry_sources):
        source = root/name
        if source.is_file():
            digest.update(name.encode()); digest.update(source.read_bytes())
    cache = ci/'static-cache'/key/digest.hexdigest()
    index_name = 'modules/line/prebuilt/tunnels.json' if key == 'full_line' else f'modules/stations/{key}/prebuilt/index.json'
    # Cache completeness is committed last. A failed compiler never enables partial resources.
    if not (cache/'complete.json').is_file():
        if cache.exists(): shutil.rmtree(cache)
        cache.mkdir(parents=True)
        control = ci/'controls'/f'{key}-static.json'
        control.parent.mkdir(parents=True, exist_ok=True)
        control.write_text(json.dumps({'module':key, 'scene':'res://'+spec['scene'],
            'destination':str(cache), 'index':str(cache/'index.json'), 'source_commit':plan['head']}))
        native(['--path',str(stage),'--script','res://'+COMPILER],ci/'logs'/f'{key}-static.log',
               dict(os.environ,METRO_STATIC_CONTROL=str(control)))
        if not (cache/'index.json').is_file():
            raise RuntimeError('Static resource compiler did not produce '+key)
        (cache/'complete.json').write_text(json.dumps({'source_commit':plan['head']}))
    target = stage/index_name
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(cache/'index.json',target)
    copied.append(index_name)
    if json.loads((cache/'index.json').read_text()).get('legacy'):
        return
    if key == 'full_line':
        for file in (cache/'base').glob('*.res'):
            relative = 'modules/line/prebuilt/base/'+file.name
            target = stage/relative
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(file,target)
            copied.append(relative)
    for file in cache.glob('world-*.bin'):
        shutil.copy2(file,bundle/file.name)


def prepare_speech(root, stage, key, copied):
    if key not in {'full_line','v106'}:
        return
    catalogue_path = stage/'audio/data/audio_catalog.json'
    if not catalogue_path.is_file():
        return
    catalogue = json.loads(catalogue_path.read_text())
    for entry in catalogue.get('assets',[]):
        if entry.get('category') != 'announcer' or entry.get('verified') is not True:
            continue
        source = root/entry['resource'].removeprefix('res://')
        if not source.is_file():
            # An unavailable original is not replaced by invented or silent audio.
            continue
        segments = entry.get('playback_segments') or [{'from_s':0,'to_s':-1}]
        signature = hashlib.sha256(b'pcm-framecount-v2\0'+source.read_bytes()+json.dumps(segments,sort_keys=True).encode()).hexdigest()
        cache = stage.parents[1]/'static-cache'/key/'speech'/f'{signature}.wav'
        if not cache.is_file():
            # Decode and concatenate only original PCM ranges, on sample boundaries.
            decoded = subprocess.run(['ffmpeg','-v','error','-i',str(source),'-f','wav','-acodec','pcm_s16le','-'],
                                     check=True,stdout=subprocess.PIPE).stdout
            with wave.open(io.BytesIO(decoded),'rb') as audio:
                params = audio.getparams(); pcm = audio.readframes(audio.getnframes())
            frame_bytes = params.nchannels * params.sampwidth
            frames = len(pcm)//frame_bytes
            pieces = []
            for segment in segments:
                start = max(0,min(frames,round(float(segment.get('from_s',0))*params.framerate)))
                end_seconds = float(segment.get('to_s',-1))
                end = frames if end_seconds < 0 else max(start,min(frames,round(end_seconds*params.framerate)))
                pieces.append(pcm[start*frame_bytes:end*frame_bytes])
            cache.parent.mkdir(parents=True,exist_ok=True)
            payload = b''.join(pieces)
            # FFmpeg's stdout WAV header has an unknown-length sentinel. Use the
            # actual concatenated PCM frame count, never the input header count.
            temporary = cache.with_suffix('.wav.partial')
            try:
                with wave.open(str(temporary),'wb') as audio:
                    audio.setparams((params.nchannels, params.sampwidth, params.framerate,
                                     len(payload)//frame_bytes, params.comptype, params.compname))
                    audio.writeframes(payload)
                temporary.replace(cache)
            finally:
                temporary.unlink(missing_ok=True)
        relative = 'audio/prebuilt/'+entry['event_id']+'.wav'
        target = stage/relative; target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(cache,target)
        entry['prepared_resource']='res://'+relative
        copied.append(relative)
    catalogue_path.write_text(json.dumps(catalogue,ensure_ascii=False))
    if 'audio/data/audio_catalog.json' not in copied: copied.append('audio/data/audio_catalog.json')
