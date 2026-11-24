extends Node
class_name MetroSoundBank
## Independent, lazy-loaded audio bank. Only explicitly verified assets are eligible.
@export var max_cached_streams: int = 12
@export var max_voices: int = 32
@export var reserved_announcer_voices: int = 4
var master_volume: float = 1.0
var _missing_reported: Dictionary = {}
var _entries: Dictionary = {}
var _cache: Dictionary = {}
var _order: Array[String] = []
var _voices: Array[AudioStreamPlayer3D] = []
var category_db: Dictionary = {"traction": 0.0, "rolling": 0.0, "doors": 0.0, "cab": 0.0, "announcer": 0.0, "environment": 0.0}

func configure(catalog: Dictionary) -> void:
    _entries.clear()
    _cache.clear()
    _order.clear()
    for entry in catalog.get("assets", []):
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        if entry.get("verified", false) != true:
            continue
        var event_id: String = str(entry.get("event_id", ""))
        var path: String = str(entry.get("resource", ""))
        if event_id != "" and path.begins_with("res://"):
            _entries[event_id] = entry

func has_event(event_id: String) -> bool:
    return _entries.has(event_id)

func event_data(event_id: String) -> Dictionary:
    return _entries.get(event_id, {})

func _stream(event_id: String) -> AudioStream:
    if _cache.has(event_id):
        _order.erase(event_id)
        _order.append(event_id)
        return _cache[event_id]
    if not _entries.has(event_id):
        return null
    var path: String = str(_entries[event_id].get("resource", ""))
    if not ResourceLoader.exists(path):
        _report_missing(event_id,path)
        return null
    var resource: Resource = load(path)
    if not resource is AudioStream:
        _report_missing(event_id,path)
        return null
    _cache[event_id] = resource
    _order.append(event_id)
    while _order.size() > maxi(1, max_cached_streams):
        var evicted: String = _order.pop_front()
        _cache.erase(evicted)
    return resource

func play_at(event_id: String, parent: Node3D, local_position: Vector3 = Vector3.ZERO, volume_db: float = 0.0, looped: bool = false, start_seconds: float = 0.0) -> AudioStreamPlayer3D:
    if not is_instance_valid(parent):
        return null
    var stream: AudioStream = _stream(event_id)
    if stream == null:
        return null
    _cleanup_voices()
    var entry: Dictionary = _entries[event_id]
    var category: String = str(entry.get("category", ""))
    var limit: int=max_voices if category=="announcer" else maxi(1,max_voices-reserved_announcer_voices)
    if _voices.size() >= limit: return null
    var player := AudioStreamPlayer3D.new()
    # Godot 4.3 Web Sample playback has no mixer playback-position node.
    # Announcer segment boundaries, loop pitch and spatial sound need Stream.
    player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
    player.set_meta("event_id",event_id)
    player.unit_size=float(entry.get("unit_size_m",4.0))
    set_player_gain(player,volume_db)
    player.max_distance = float(entry.get("max_distance_m", 80.0))
    player.position = local_position
    # Instance-local loop flags: a spoken recording must never inherit an
    # imported loop flag, and cached source resources must remain unchanged.
    var playback: AudioStream=stream.duplicate() as AudioStream
    if playback is AudioStreamOggVorbis: playback.loop=looped
    elif playback is AudioStreamMP3: playback.loop=looped
    elif playback is AudioStreamWAV:
        playback.loop_mode=AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED
    elif looped:
        player.free()
        return null
    player.stream=playback
    parent.add_child(player)
    _voices.append(player)
    if not looped:
        player.finished.connect(_on_finished.bind(player))
    player.play(maxf(0.0, start_seconds))
    return player

func _report_missing(event_id: String, path: String) -> void:
    if _missing_reported.has(event_id): return
    _missing_reported[event_id]=true
    push_error("Metro audio: missing/unreadable event "+event_id+" at "+path)

func set_master_volume(value: float) -> void:
    master_volume=clampf(value,0.0,1.0)
    for player in _voices:
        if is_instance_valid(player):
            set_player_gain(player,float(player.get_meta("mix_gain_db",0.0)))

func set_player_gain(player: AudioStreamPlayer3D, gain_db: float) -> void:
    if not is_instance_valid(player): return
    var entry: Dictionary=event_data(str(player.get_meta("event_id","")))
    var category: String=str(entry.get("category",""))
    player.set_meta("mix_gain_db",gain_db)
    player.volume_db=gain_db+float(category_db.get(category,0.0))+float(entry.get("gain_db",0.0))+linear_to_db(maxf(0.00001,master_volume))

func _on_finished(player: AudioStreamPlayer3D) -> void:
    _voices.erase(player)
    if is_instance_valid(player):
        player.queue_free()

func _cleanup_voices() -> void:
    for i in range(_voices.size() - 1, -1, -1):
        if not is_instance_valid(_voices[i]):
            _voices.remove_at(i)

func release_player(player: AudioStreamPlayer3D) -> void:
    _voices.erase(player)
    if is_instance_valid(player):
        player.stop()
        player.queue_free()

func stop_all() -> void:
    for player in _voices:
        if is_instance_valid(player):
            player.stop()
            player.queue_free()
    _voices.clear()
