extends Node
class_name MetroAnnouncer
## One permanent, non-spatial voice. Route, camera and geometry never stop it.
signal announcement_started(event_id: String)
signal announcement_finished(event_id: String)
var bank: MetroAudioResources
var route_events: Dictionary={}
var _player: AudioStreamPlayer
var _queue: Array[Dictionary]=[]
var _seen_visits: Dictionary={}
var _current_id: String=""
var _started_event: String=""
@export var max_queue: int=8

func _ready() -> void:
    process_priority=-100
    _player=AudioStreamPlayer.new()
    _player.name="ContinuousAnnouncer"
    _player.max_polyphony=1
    # Godot's native Web sample backend continues independently of scene work.
    # No HTMLAudioElement and no playback-position polling in Sample mode.
    _player.playback_type=AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
    add_child(_player)
    _player.finished.connect(_on_finished)

func configure_routes(mapping: Dictionary) -> void:
    route_events=mapping.duplicate()

func prepare_route(_current: String, _following: String, _direction: String) -> void:
    pass # All required recordings were prepared by load_catalog before service.

func set_speakers(_origins: Array[Node3D]) -> void:
    pass # Compatibility only; speech has no physical emitters.

func clear_pending() -> void:
    _queue.clear()

func route_announcement(station: String, phase: String, direction: String, visit: String) -> void:
    if station.is_empty() or visit.is_empty(): return
    var key: String="%s|%s|%s|%s" % [station,phase,direction,visit]
    if _seen_visits.has(key): return
    var id: String=str(route_events.get("%s|%s|%s" % [station,phase,direction],""))
    if bank==null or not bank.has_event(id): return
    if _seen_visits.size()>=64: _seen_visits.clear()
    _seen_visits[key]=true
    enqueue(id)

func enqueue(id: String, priority: int=0) -> void:
    if bank==null or not bank.has_event(id): return
    if _queue.size()>=max_queue:
        if priority<=int(_queue[-1].priority): return
        _queue.pop_back()
    var index: int=0
    while index<_queue.size() and int(_queue[index].priority)>=priority: index+=1
    _queue.insert(index,{"id":id,"priority":priority})
    _advance()

func manual_play(id: String) -> void:
    enqueue(id,10)

func repeat_current() -> void:
    if not _current_id.is_empty(): enqueue(_current_id,10)

func current_event() -> String:
    return _current_id

func is_busy() -> bool:
    return not _current_id.is_empty() or not _queue.is_empty()

func has_audio_started(id: String) -> bool:
    return not id.is_empty() and _started_event==id

func reset_visit_history() -> void:
    _seen_visits.clear()

func set_master_volume(value: float) -> void:
    var gain: float=float(bank.event_data(_current_id).get("gain_db",0.0)) if bank!=null else 0.0
    _player.volume_db=gain+linear_to_db(maxf(value,0.00001))

func _advance() -> void:
    if not _current_id.is_empty() or _queue.is_empty() or bank==null: return
    var item: Dictionary=_queue.pop_front()
    var id: String=str(item.id)
    var stream: AudioStream=bank.stream_for(id)
    if stream==null: return
    _current_id=id
    _started_event=""
    _player.stream=stream
    set_master_volume(bank.master_volume)
    _player.play()
    announcement_started.emit(id)

func _process(_delta: float) -> void:
    if _current_id.is_empty():
        _advance()
    elif _player.playing:
        # Used by the existing door-warning interlock. Do not seek/poll Sample
        # playback_position; only the single player's real playback state is read.
        _started_event=_current_id

func _on_finished() -> void:
    var completed: String=_current_id
    if completed.is_empty(): return
    _started_event=completed
    _current_id=""
    _player.stream=null
    announcement_finished.emit(completed)
    _advance()

func stop_all() -> void:
    _queue.clear()
    _player.stop()
    _player.stream=null
    var interrupted: String=_current_id
    _current_id=""
    _started_event=""
    if not interrupted.is_empty(): announcement_finished.emit(interrupted)
