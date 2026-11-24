extends RefCounted
class_name MetroAudioResources
## Resource preparation only. This bank never creates or owns audio players.
var master_volume: float=1.0
var _entries: Dictionary={}
var _streams: Dictionary={}
var _loops: Dictionary={}
var ready: bool=false

func configure(catalog: Dictionary) -> bool:
    _entries.clear()
    _streams.clear()
    _loops.clear()
    ready=false
    for item in catalog.get("assets",[]):
        if not item is Dictionary: continue
        if not bool(item.get("verified",false)) and not bool(item.get("enabled",false)): continue
        var id: String=str(item.get("event_id",""))
        if not id.is_empty(): _entries[id]=item
    var required: Dictionary={}
    for item in _entries.values():
        if str(item.get("category",""))=="announcer": required[str(item.event_id)]=false
    var engine: Dictionary=catalog.get("simple_audio",{})
    for id in engine.get("train_states",{}).values(): required[str(id)]=true
    for id in engine.get("effects",{}).values(): required[str(id)]=false
    var complete: bool=true
    for id in required:
        if not _prepare(str(id),bool(required[id])): complete=false
    ready=complete
    return complete

func has_event(id: String) -> bool:
    return _entries.has(id) and _streams.has(id)

func event_data(id: String) -> Dictionary:
    return _entries.get(id,{})

func stream_for(id: String, looped: bool=false) -> AudioStream:
    # Runtime lookup only: no file IO or decoding while an announcement plays.
    return (_loops if looped else _streams).get(id) as AudioStream

func _prepare(id: String, looped: bool) -> bool:
    if not _entries.has(id):
        push_error("Metro audio: missing event "+id)
        return false
    var entry: Dictionary=_entries[id]
    var path: String=str(entry.get("prepared_resource",entry.get("resource","")))
    if str(entry.get("category",""))=="announcer" and not entry.get("playback_segments",[]).is_empty() and not entry.has("prepared_resource"):
        push_error("Metro audio: CI must prepare the continuous recording for "+id)
        return false
    var source: AudioStream=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REUSE) as AudioStream
    if source==null:
        push_error("Metro audio: cannot prepare "+path)
        return false
    var once: AudioStream=source.duplicate() as AudioStream
    _set_loop(once,false)
    _streams[id]=once
    if looped:
        var looping: AudioStream=source.duplicate() as AudioStream
        _set_loop(looping,true)
        _loops[id]=looping
    return true

func _set_loop(stream: AudioStream, enabled: bool) -> void:
    if stream is AudioStreamMP3: (stream as AudioStreamMP3).loop=enabled
    elif stream is AudioStreamOggVorbis: (stream as AudioStreamOggVorbis).loop=enabled
    elif stream is AudioStreamWAV:
        (stream as AudioStreamWAV).loop_mode=AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED
