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
var _voice_generation := 0
var _idle_players: Array[AudioStreamPlayer3D] = []
var _playbacks: Dictionary = {}
var _playback_order: Array[String] = []
@export var max_idle_players := 8
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
    var path: String = str(_entries[event_id].get("prepared_resource", _entries[event_id].get("resource", "")))
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

func prepare_event(event_id: String) -> void:
    _stream(event_id)

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
    var player: AudioStreamPlayer3D=_idle_players.pop_back() if not _idle_players.is_empty() else AudioStreamPlayer3D.new()
    _voice_generation+=1
    player.set_meta("voice_generation",_voice_generation)
    player.pitch_scale=1.0
    player.stream_paused=false
    # Godot 4.3 Web Sample playback has no mixer playback-position node.
    # Announcer segment boundaries, loop pitch and spatial sound need Stream.
    # Continuous loops need no timeline reads; Web's native sample backend
    # keeps these playing independently of the single-thread game mixer.
    # Speech remains Stream for accurate segment positions and door gating.
    player.playback_type=AudioServer.PLAYBACK_TYPE_SAMPLE if looped and OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
    player.set_meta("event_id",event_id)
    player.unit_size=float(entry.get("unit_size_m",4.0))
    set_player_gain(player,volume_db)
    player.max_distance = float(entry.get("max_distance_m", 80.0))
    player.position = local_position
    # Instance-local loop flags: a spoken recording must never inherit an
    # imported loop flag, and cached source resources must remain unchanged.
    var cache_key: String=event_id+(":loop" if looped else ":once")
    var playback: AudioStream=_playbacks.get(cache_key) as AudioStream
    if playback==null:
        playback=stream.duplicate() as AudioStream
        if playback is AudioStreamOggVorbis: playback.loop=looped
        elif playback is AudioStreamMP3: playback.loop=looped
        elif playback is AudioStreamWAV:
            playback.loop_mode=AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED
        elif looped:
            player.free()
            return null
        _playbacks[cache_key]=playback
    _playback_order.erase(cache_key)
    _playback_order.append(cache_key)
    while _playback_order.size()>max_cached_streams:
        _playbacks.erase(_playback_order.pop_front())
    player.stream=playback
    if player.get_parent()==null: parent.add_child(player)
    else: player.reparent(parent,false)
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
    var applied: float=gain_db+float(category_db.get(category,0.0))+float(entry.get("gain_db",0.0))+linear_to_db(maxf(0.00001,master_volume))
    if float(player.get_meta("applied_gain_db",INF))!=applied:
        player.set_meta("applied_gain_db",applied)
        player.volume_db=applied

func _on_finished(player: AudioStreamPlayer3D) -> void:
    # PA owns its source until the announcer releases the segment. Returning it
    # early could let an effect reuse that same Node while PA still references it.
    if str(event_data(str(player.get_meta("event_id",""))).get("category",""))=="announcer": return
    # Defer recycling so all announcement completion subscribers run first.
    call_deferred("_release_finished_voice",player,int(player.get_meta("voice_generation",0)))

func _release_finished_voice(player: AudioStreamPlayer3D, generation: int) -> void:
    if is_instance_valid(player) and int(player.get_meta("voice_generation",-1))==generation:
        release_player(player)

func _cleanup_voices() -> void:
    for i in range(_voices.size() - 1, -1, -1):
        if not is_instance_valid(_voices[i]):
            _voices.remove_at(i)

func release_player(player: AudioStreamPlayer3D) -> void:
    if not is_instance_valid(player) or _idle_players.has(player): return
    _voices.erase(player)
    player.stop()
    # A reused source must not retain a prior announcement's callbacks.
    for connection in player.get_signal_connection_list("finished"):
        player.disconnect("finished",connection.callable)
    player.stream=null
    if is_inside_tree() and _idle_players.size()<max_idle_players:
        player.reparent(self,false)
        _idle_players.append(player)
    else:
        player.queue_free()

func stop_all() -> void:
    for player in _voices:
        if is_instance_valid(player):
            player.stop()
            player.queue_free()
    _voices.clear()
    for player in _idle_players:
        if is_instance_valid(player): player.queue_free()
    _idle_players.clear()
    _playbacks.clear()
    _playback_order.clear()
