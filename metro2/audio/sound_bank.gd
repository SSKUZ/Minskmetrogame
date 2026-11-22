extends Node
class_name MetroSoundBank
## Independent, lazy-loaded audio bank. Only explicitly verified assets are eligible.
@export var max_cached_streams: int = 12
@export var max_voices: int = 24
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

func _stream(event_id: String) -> AudioStream:
    if _cache.has(event_id):
        _order.erase(event_id)
        _order.append(event_id)
        return _cache[event_id]
    if not _entries.has(event_id):
        return null
    var path: String = str(_entries[event_id].get("resource", ""))
    if not ResourceLoader.exists(path):
        return null
    var resource: Resource = load(path)
    if not resource is AudioStream:
        return null
    _cache[event_id] = resource
    _order.append(event_id)
    while _order.size() > maxi(1, max_cached_streams):
        var evicted: String = _order.pop_front()
        _cache.erase(evicted)
    return resource

func play_at(event_id: String, parent: Node3D, local_position: Vector3 = Vector3.ZERO, volume_db: float = 0.0, looped: bool = false) -> AudioStreamPlayer3D:
    if not is_instance_valid(parent):
        return null
    var stream: AudioStream = _stream(event_id)
    if stream == null:
        return null
    _cleanup_voices()
    if _voices.size() >= max_voices:
        return null
    var player := AudioStreamPlayer3D.new()
    var entry: Dictionary = _entries[event_id]
    var category: String = str(entry.get("category", ""))
    player.volume_db = volume_db + float(category_db.get(category, 0.0)) + float(entry.get("gain_db", 0.0))
    player.max_distance = float(entry.get("max_distance_m", 80.0))
    player.position = local_position
    if looped:
        if not stream is AudioStreamOggVorbis:
            return null
        var loop_stream: AudioStreamOggVorbis = stream.duplicate()
        loop_stream.loop = true
        player.stream = loop_stream
    else:
        player.stream = stream
    parent.add_child(player)
    _voices.append(player)
    if not looped:
        player.finished.connect(_on_finished.bind(player))
    player.play()
    return player

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
