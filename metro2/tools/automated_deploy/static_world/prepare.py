"""Build-time resource compilation within the existing changed-module deployment."""
from pathlib import Path
import hashlib, io, json, os, shutil, subprocess, wave

RUNTIME_FILES = ['modules/line/static_station.gd', 'modules/line/static_resource_store.gd',
                 'modules/line/build_budget.gd', 'modules/line/station_connection_adapter.gd',
                 'modules/line/route_layout.json', 'modules/gameplay/world_geometry.gd',
                 'modules/gameplay/walk_lite.gd', 'modules/gameplay/station_seating.gd']
COMPILER = 'tools/automated_deploy/static_world/prebuild.gd'


def source_files(root, key):
    # The compiler preloads navigation to bake platform data from real geometry.
    # Station stages do not inherit the full-line passenger scripts.
    files = RUNTIME_FILES + [COMPILER, 'scripts/passengers/passenger_navigation.gd']
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
    digest.update(Path(__file__).read_bytes())
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
    prepared_index = json.loads((cache/'index.json').read_text())
    if key != 'full_line' and not prepared_index.get('legacy'):
        # One verified optional station pack owns all its prepared geometry.
        # Keep native user:// dependency paths; only the archive transport moves
        # into the PCK. No geometry, materials or scene hierarchy is changed.
        embedded = set()
        for chunk in prepared_index.get('open_chunks', []) + prepared_index.get('closed_chunks', []):
            for archive in chunk.get('archives', []):
                relative = f'modules/stations/{key}/prebuilt/archives/' + archive['file']
                archive['embedded_path'] = 'res://' + relative
                if relative in embedded:
                    continue
                source = cache/archive['file']
                if not source.is_file():
                    raise RuntimeError('Missing prepared station archive: '+archive['file'])
                destination = stage/relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, destination)
                copied.append(relative)
                embedded.add(relative)
        prepared_index['embedded_station_archives'] = 1
    target.write_text(json.dumps(prepared_index, separators=(',', ':')))
    copied.append(index_name)
    if prepared_index.get('legacy'):
        return
    if key == 'full_line':
        for file in (cache/'base').glob('*.res'):
            relative = 'modules/line/prebuilt/base/'+file.name
            target = stage/relative
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(file,target)
            copied.append(relative)
    if key == 'full_line':
        # Tunnel detail remains independently streamed. Station archives are
        # already inside their own PCK and must not be published twice.
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



def prepare_benches(stage):
    """Capture real construction arguments in staged scripts, not guessed mesh names.

    Only authored bench functions and the two known curved cross-sections opt
    in. Capture helpers return the original size, leaving all geometry intact.
    The same portable anchors are baked into walking_lite for static stations
    or collected by its existing fallback for a legacy station.
    """
    import re

    helper = 'preload("res://modules/gameplay/station_seating.gd")'

    def arguments(text, opening):
        # Split a GDScript call without evaluating it. Balanced constructors,
        # nested arrays and quoted labels may contain commas of their own.
        depth, quote, escape, start, parts = 1, None, False, opening+1, []
        for pos in range(opening+1, len(text)):
            char = text[pos]
            if quote:
                if escape: escape = False
                elif char == '\\': escape = True
                elif char == quote: quote = None
                continue
            if char in "\"'": quote = char
            elif char in '([{': depth += 1
            elif char in ')]}':
                depth -= 1
                if depth == 0:
                    parts.append((start, pos))
                    return parts
            elif char == ',' and depth == 1:
                parts.append((start, pos)); start = pos+1
        raise RuntimeError('Unterminated bench geometry call')

    for folder in [stage/'modules/stations', stage/'scripts/station']:
        for path in folder.rglob('*.gd'):
            source = path.read_text()
            if 'station_seating.gd' in source: continue
            blocks = list(re.finditer(r'^func\s+(\w+)\(([^\n]*)\)[^\n]*:\s*\n', source, re.M))
            edits = []
            for number, block in enumerate(blocks):
                end = blocks[number+1].start() if number+1 < len(blocks) else len(source)
                body = source[block.end():end]
                name, parameters = block.group(1), block.group(2)
                if name == '_bench' and 'CurvedOakBenchSlats' in body and 'side: int' in parameters:
                    # This constructor's explicit seat segment is at FY+.49.
                    edits.append((block.end(), block.end(), f'    {helper}.borisovsky_row(self,x,z,FY,side)\n'))
                    continue
                if name == '_furniture_block' and 'Semicircular wooden bench' in body:
                    # Sparse positions on the real arc; never fill the cylinder
                    # interior with the rectangular bound of the whole bench.
                    for call in re.finditer(r'\b_box\s*\(', body):
                        opening = block.end()+call.end()-1
                        parts = arguments(source, opening)
                        size = source[slice(*parts[0])].strip()
                        if re.sub(r'\s+', '', size) != 'Vector3(0.07,0.14,0.58)': continue
                        point = source[slice(*parts[1])].strip()
                        edits.append((*parts[0], f'{helper}.curved(self,{size},{point},FLOOR,radial,j)'))
                    continue
                if name == '_order_pylon' and 'Vector3(0.049,0.065,3.65)' in body:
                    # Ploshchad Lenina's two real wooden benches are authored
                    # alongside the pylon, not in a separately named function.
                    for call in re.finditer(r'\bbox\s*\(', body):
                        parts = arguments(source, block.end()+call.end()-1)
                        size = source[slice(*parts[0])].strip()
                        if re.sub(r'\s+', '', size) != 'Vector3(0.049,0.065,3.65)': continue
                        point = source[slice(*parts[1])].strip()
                        value = f'{helper}.capture(self,{size},{point},p.y,Basis.IDENTITY,"lenina_pylon_bench",p,Basis.IDENTITY)'
                        edits.append((*parts[0], value))
                    continue
                if 'bench' not in name.lower(): continue
                parameter = re.search(r'\b(\w+)\s*:\s*Vector3\b', parameters)
                if not parameter:
                    parameter = re.search(r'var\s+(p)\s*:?=\s*Vector3\(', body)
                if not parameter: continue
                origin = parameter.group(1)
                angle = re.search(r'\b(yaw|angle|rotation)\s*:\s*float', parameters)
                frame = f'Basis(Vector3.UP,{angle.group(1)})' if angle else 'Basis.IDENTITY'
                for call in re.finditer(r'\b(box|_box|_b|_rounded_bench_box|_round_box|_rounded_plan_box)\s*\(', body):
                    # Ignore commented-out calls; these are not construction.
                    line_start = body.rfind('\n', 0, call.start())+1
                    if '#' in body[line_start:call.start()]: continue
                    opening = block.end()+call.end()-1
                    parts = arguments(source, opening)
                    offset = 1 if call.group(1) == '_b' else 0
                    if len(parts) < offset+3: continue
                    size = source[slice(*parts[offset])].strip()
                    point = source[slice(*parts[offset+1])].strip()
                    pose = source[slice(*parts[offset+3])].strip() if len(parts)>offset+3 and call.group(1) not in {'_rounded_bench_box','_round_box','_rounded_plan_box'} else 'Basis.IDENTITY'
                    tag = path.relative_to(stage).as_posix()+':'+name
                    value = f'{helper}.capture(self,{size},{point},{origin}.y,{pose},"{tag}",{origin},{frame})'
                    edits.append((*parts[offset], value))
            if edits:
                for start, end, value in sorted(edits, reverse=True):
                    source = source[:start]+value+source[end:]
                path.write_text(source)
