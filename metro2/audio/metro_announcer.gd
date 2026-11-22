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
    for player in _active:
        if is_instance_valid(player):
            player.stop()
            player.queue_free()
    _active.clear()
    _current_id = ""

func reset_visit_history() -> void:
    _seen_visits.clear()

func _process(_delta: float) -> void:
    if _current_id == "":
        _advance()
        return
    var any_playing: bool = false
    for player in _active:
        if is_instance_valid(player) and player.playing:
            any_playing = true
    if not any_playing:
        var completed: String = _current_id
        for player in _active:
            if is_instance_valid(player):
                player.queue_free()
        _active.clear()
        _current_id = ""
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
    for origin in speaker_origins:
        if is_instance_valid(origin):
            var player: AudioStreamPlayer3D = bank.play_at(event_id, origin)
            if player != null:
                _active.append(player)
    if _active.is_empty():
        _current_id = ""
        return
    announcement_started.emit(event_id)
