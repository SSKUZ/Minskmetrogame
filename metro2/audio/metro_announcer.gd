extends Node
class_name MetroAnnouncer
## Explicit, ordered announcements. Never invent text or station-to-audio mappings.
signal announcement_started(event_id: String)
signal announcement_finished(event_id: String)
var bank: MetroSoundBank
var speaker_origins: Array[Node3D] = []
var route_events: Dictionary = {}
var _queue: Array[Dictionary] = []
var _seen_visits: Dictionary = {}
var _active: Array[AudioStreamPlayer3D] = []
var _current_id: String = ""
var _started_event: String = ""
var _segments: Array = []
var _segment_index: int = 0
@export var max_queue: int = 8

func configure_routes(mapping: Dictionary) -> void:
    route_events = mapping.duplicate(true)

func set_speakers(origins: Array[Node3D]) -> void:
    speaker_origins = origins.duplicate()

func route_announcement(station_id: String, phase: String, direction: String, visit_id: String) -> void:
    if station_id == "" or visit_id == "":
        return
    var key: String = "%s|%s|%s|%s" % [station_id, phase, direction, visit_id]
    if _seen_visits.has(key):
        return
    var event_id: String = str(route_events.get("%s|%s|%s" % [station_id, phase, direction], ""))
    if event_id == "" or bank == null or not bank.has_event(event_id):
        return
    _seen_visits[key] = true
    enqueue(event_id, 0)

func enqueue(event_id: String, priority: int = 0) -> void:
    if bank == null or not bank.has_event(event_id):
        return
    if _queue.size() >= max_queue:
        if priority <= int(_queue[-1].get("priority", 0)):
            return
        _queue.pop_back()
    var item: Dictionary = {"id": event_id, "priority": priority}
    var index: int = 0
    while index < _queue.size() and int(_queue[index]["priority"]) >= priority:
        index += 1
    _queue.insert(index, item)
    _advance()

func manual_play(event_id: String) -> void:
    enqueue(event_id, 10)

func repeat_current() -> void:
    if _current_id != "":
        enqueue(_current_id, 10)

func stop_all() -> void:
    _queue.clear()
    _started_event=""
    var interrupted: String = _current_id
    _release_active()
    _segments.clear()
    _current_id = ""
    if interrupted != "":
        announcement_finished.emit(interrupted)

func is_busy() -> bool:
    return _current_id != "" or not _queue.is_empty()

func has_audio_started(event_id: String) -> bool:
    # Reset for every new playback, retained on completion for a delayed door
    # clearance. A queued/scheduled player alone is not proof of audio progress.
    return event_id!="" and _started_event==event_id

func _mark_audio_started(event_id: String) -> void:
    if _current_id==event_id: _started_event=event_id

func current_event() -> String:
    return _current_id

func _release_active() -> void:
    for player in _active:
        if is_instance_valid(player):
            bank.release_player(player)
    _active.clear()

func reset_visit_history() -> void:
    _seen_visits.clear()

func _process(_delta: float) -> void:
    if _current_id == "":
        _advance()
        return
    var nearest: Node3D=_nearest_speaker()
    for voice in _active:
        if is_instance_valid(voice) and is_instance_valid(nearest) and voice.get_parent()!=nearest:
            voice.reparent(nearest,false)
            voice.position=Vector3.ZERO
    var any_playing: bool = false
    var end_seconds: float = float(_segments[_segment_index].get("to_s", -1.0)) if not _segments.is_empty() else -1.0
    for player in _active:
        if is_instance_valid(player) and player.playing:
            var start_seconds: float=float(_segments[_segment_index].get("from_s",0.0)) if not _segments.is_empty() else 0.0
            if player.get_playback_position()>start_seconds+0.01: _mark_audio_started(_current_id)
            if end_seconds < 0.0 or player.get_playback_position() < end_seconds:
                any_playing = true
    if not any_playing:
        _release_active()
        if _segment_index + 1 < _segments.size():
            _segment_index += 1
            if _start_segment():
                return
        var completed: String = _current_id
        _current_id = ""
        _segments.clear()
        announcement_finished.emit(completed)
        _advance()

func _advance() -> void:
    if _current_id != "" or _queue.is_empty() or bank == null:
        return
    var item: Dictionary = _queue.pop_front()
    var event_id: String = str(item["id"])
    if not bank.has_event(event_id):
        return
    _current_id = event_id
    _started_event=""
    _segments = bank.event_data(event_id).get("playback_segments", [])
    _segment_index = 0
    if not _start_segment():
        _current_id = ""
        _segments.clear()
        return
    announcement_started.emit(event_id)

func _start_segment() -> bool:
    var start_seconds: float = float(_segments[_segment_index].get("from_s", 0.0)) if not _segments.is_empty() else 0.0
    var origin: Node3D=_nearest_speaker()
    if is_instance_valid(origin):
        var player: AudioStreamPlayer3D = bank.play_at(_current_id, origin, Vector3.ZERO, 0.0, false, start_seconds)
        if player != null:
            # A clip can finish during a slow scene-instantiation frame.
            # Completion also proves it progressed, without a wall-clock guess.
            player.finished.connect(_mark_audio_started.bind(_current_id))
            _active.append(player)
    return not _active.is_empty()

func _nearest_speaker() -> Node3D:
    var camera: Camera3D=get_viewport().get_camera_3d()
    var nearest: Node3D
    var distance: float=INF
    for speaker in speaker_origins:
        if not is_instance_valid(speaker): continue
        var d: float=speaker.global_position.distance_squared_to(camera.global_position) if camera!=null else 0.0
        if d<distance:
            distance=d
            nearest=speaker
    return nearest
