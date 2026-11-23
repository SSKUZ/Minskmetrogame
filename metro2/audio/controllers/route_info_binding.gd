extends Node
## Glue for the existing V106 owner, cab, doors and shared INFO state machine.
## Only actually instantiated station modules supply coordinates. Never invent a route layout.
const AudioSystem = preload("res://audio/audio_system.gd")
const Tracker = preload("res://audio/controllers/station_position_tracker.gd")
const StationBase = preload("res://scripts/station_base_static.gd")
var game: Node3D
var route_root: Node
var audio: MetroAudioSystem
var tracker: MetroStationPositionTracker
var passenger_mode := false
var applying_auto_input := false
var _route: Dictionary = {}
var _markers: Array[Node3D] = []
var _state: Dictionary = {}
var _auto_visit := ""
var _auto_phase := "approach"
var _dwell_until := -1
var _close_at := -1
var _departure_event := ""
var _next_target := ""
var _button: Button
var _last_train_z := INF
var _registration_pending := false

func initialize(owner_game: Node3D, world: Node) -> void:
    game = owner_game
    route_root = world
    process_priority = -10
    _route = JSON.parse_string(FileAccess.get_file_as_string("res://audio/data/route_stations.json"))
    tracker = Tracker.new()
    tracker.route_ids = _route.get("station_ids", [])
    audio = AudioSystem.new()
    audio.name = "RouteAudioSystem"
    add_child(audio)
    audio.load_catalog("res://audio/data/audio_catalog.json")
    var speakers: Array[Node3D] = []
    var consist: Node3D = game.get("train")
    for car in consist.get_children():
        if car is Node3D and str(car.name).begins_with("OriginalV106Car"):
            var speaker := Marker3D.new()
            speaker.name = "InfoSpeaker"
            car.add_child(speaker)
            var bounds: AABB = game.call("_get_model_bounds", car)
            speaker.position = bounds.get_center()
            speakers.append(speaker)
    if speakers.is_empty():
        speakers.append(consist)
    audio.announcer.set_speakers(speakers)
    audio.info.departure_started.connect(_on_departure_started)
    get_tree().node_added.connect(_on_node_added)
    _discover(route_root)
    _refresh_markers()
    var layer: CanvasLayer = game.get("_ui_layer")
    if layer != null:
        _button = Button.new()
        _button.text = "РЕЖИМ ПАССАЖИРА"
        _button.position = Vector2(14, 80)
        _button.custom_minimum_size = Vector2(230, 48)
        _button.pressed.connect(func() -> void: select_passenger_mode(not passenger_mode))
        layer.add_child(_button)

func _station_id(node: Node) -> String:
    var script: Script = node.get_script()
    if script == null:
        return ""
    var mapping: Dictionary = _route.get("module_ids", {})
    for id in mapping:
        var module: String = str(mapping[id])
        if script.resource_path == "res://modules/stations/%s/%s.gd" % [module, module]:
            return str(id)
    if script.resource_path == "res://scripts/station_base_static.gd" and bool(node.get("uruchye_architecture")):
        return "uruchye"
    return ""

func _discover(node: Node) -> void:
    if node == game.get("train"):
        return
    if node is Node3D:
        var id: String = _station_id(node)
        if id != "":
            _register_station(node as Node3D, id)
            return
    for child in node.get_children():
        _discover(child)

func _register_station(station: Node3D, id: String) -> void:
    if station.has_node("InfoTrainReferenceStop"):
        var existing := station.get_node("InfoTrainReferenceStop") as Node3D
        if not _markers.has(existing):
            _markers.append(existing)
        return
    var point := Marker3D.new()
    point.name = "InfoTrainReferenceStop"
    point.set_meta("station_id", id)
    # The existing four-car root stop datum, not the nose, platform centre or GPS.
    point.position = Vector3(0.992, 0.22, StationBase.STOP_Z)
    station.add_child(point)
    _markers.append(point)

func _on_node_added(node: Node) -> void:
    if not is_instance_valid(route_root) or not route_root.is_ancestor_of(node):
        return
    if _station_id(node) == "" or _registration_pending:
        return
    _registration_pending = true
    call_deferred("_register_added_stations")

func _register_added_stations() -> void:
    _registration_pending = false
    _discover(route_root)
    _refresh_markers()

func _refresh_markers() -> void:
    var points: Array[Dictionary] = []
    for marker in _markers:
        if is_instance_valid(marker):
            points.append({"id": str(marker.get_meta("station_id")), "position": marker.global_position, "side": -1})
    tracker.configure(points, tracker.direction)

func press_info() -> String:
    _update_context()
    if tracker.stations.is_empty():
        return "INFO: в этой сцене нет станционных точек остановки"
    return audio.info.press_info()

func select_passenger_mode(enabled: bool) -> void:
    # Called only by the explicit mode button; camera changes never enter here.
    passenger_mode = enabled
    game.set("throttle", false)
    game.set("brake", false)
    _close_at = -1
    _auto_visit = ""
    _auto_phase = "approach"
    audio.info.set_mode("auto" if enabled else "manual")
    if not enabled:
        _drive_request(0.0, 1.0)
    if _button != null:
        _button.text = "РЕЖИМ МАШИНИСТА" if enabled else "РЕЖИМ ПАССАЖИРА"

func _update_context() -> void:
    if not is_instance_valid(game) or not is_instance_valid(game.get("train")) or not is_instance_valid(game.get("door_system")):
        return
    var train: Node3D = game.get("train")
    var cab: Node = game.get("cab_runtime")
    var gear: int = int(cab.get("direction")) if is_instance_valid(cab) else 0
    var travel: float = train.global_position.z - _last_train_z
    _last_train_z = train.global_position.z
    if gear != 0:
        tracker.set_direction("forward" if gear > 0 else "reverse")
    elif is_finite(travel) and absf(travel) > 0.001:
        tracker.set_direction("forward" if travel < 0.0 else "reverse")
    _state = tracker.update(train.global_position)
    if not _state.is_empty():
        audio.info.set_route_context(str(_state.station_id), str(_state.next_station_id), tracker.direction, str(_state.visit_id))
    var doors: Node = game.get("door_system")
    var stopped: bool = not _state.is_empty() and bool(_state.at_station) and absf(float(game.get("speed"))) <= 0.05
    var towards: bool = false
    if not _state.is_empty() and not stopped:
        var point: Vector3 = tracker.stations[tracker.active_index]["position"]
        towards = (point.z - train.global_position.z) * (-1.0 if tracker.direction == "forward" else 1.0) >= 0.0
    # Request-open is not a physical open state; a closing leaf is not an open door.
    var open: bool = bool(doors.get("target_open")) and float(doors.get("openness")) >= 0.99
    audio.info.update_train_state(towards and float(game.get("speed")) > 0.05, stopped, open, bool(doors.call("can_move")))

func _physics_process(_delta: float) -> void:
    _update_context()
    if not passenger_mode:
        return
    var doors: Node = game.get("door_system")
    if not is_instance_valid(doors) or not bool(doors.get("validated")):
        return
    if not _state.is_empty() and str(_state.visit_id) != _auto_visit:
        _auto_visit = str(_state.visit_id)
        _auto_phase = "approach"
        _close_at = -1
        _dwell_until = -1
    audio.info.on_auto_approach()
    if audio.info.stopped and _auto_phase == "approach":
        _auto_phase = "dwell"
        _dwell_until = Time.get_ticks_msec() + 8000
        doors.call("request_side", int(_state.get("platform_side", -1)), 0.0)
    if _auto_phase == "dwell":
        _drive_request(0.0, 1.0)
        if Time.get_ticks_msec() >= _dwell_until and _has_loaded_stop(str(_state.get("next_station_id", ""))):
            audio.info.on_auto_departure()
        return
    if _auto_phase == "warning":
        _drive_request(0.0, 1.0)
        if _close_at >= 0 and Time.get_ticks_msec() >= _close_at:
            # Only this explicit auto path closes doors; manual INFO never does.
            if audio.announcer.current_event() == _departure_event and audio.info.stopped:
                doors.call("request_close")
                _auto_phase = "departing"
            _close_at = -1
        return
    if _auto_phase == "departing":
        if not bool(doors.call("can_move")):
            _drive_request(0.0, 1.0)
            return
        if float(game.get("speed")) > 2.0:
            audio.info.on_auto_service()
        _drive_to_stop(_next_target)
        return
    _drive_to_stop("")

func _on_departure_started(event_id: String, warning_seconds: float) -> void:
    if not passenger_mode:
        return
    if warning_seconds <= 0.0:
        return
    _departure_event = event_id
    _next_target = audio.info.next_station_id
    _auto_phase = "warning"
    _close_at = Time.get_ticks_msec() + int((warning_seconds + 0.05) * 1000.0)

func _has_loaded_stop(id: String) -> bool:
    return id != "" and tracker.stations.any(func(s: Dictionary) -> bool: return str(s.id) == id)

func _drive_to_stop(id: String) -> void:
    var train: Node3D = game.get("train")
    var remaining: float = INF
    for stop in tracker.stations:
        if id != "" and str(stop.id) != id:
            continue
        var ahead: float = ((stop.position as Vector3).z - train.global_position.z) * (-1.0 if tracker.direction == "forward" else 1.0)
        if ahead >= -tracker.stop_radius_m:
            remaining = minf(remaining, maxf(0.0, ahead))
    if not is_finite(remaining):
        _drive_request(0.0, 1.0)
        return
    var speed: float = absf(float(game.get("speed")))
    # Existing cab brake ramps in; keep its braking margin, then approach at walking pace.
    var target_speed: float = minf(16.0, sqrt(2.0 * 0.65 * maxf(0.0, remaining - 0.1)))
    var brake: float = clampf((speed - target_speed) * 0.8, 0.0, 1.0)
    if remaining <= tracker.stop_radius_m:
        brake = 1.0
    _drive_request(1.0 if speed < target_speed - 0.15 and brake <= 0.01 else 0.0, brake)

func _drive_request(traction: float, brake: float) -> void:
    var cab: Node = game.get("cab_runtime")
    if not is_instance_valid(cab) or bool(cab.get("emergency")):
        return
    applying_auto_input = true
    cab.call("command", "master", -brake if brake > 0.0 else traction)
    applying_auto_input = false

func passenger_information() -> Dictionary:
    var names: Dictionary = _route.get("station_names", {})
    return {"current_station": str(names.get(audio.info.station_id, "")),
        "next_station": str(names.get(audio.info.next_station_id, "")), "at_station": audio.info.stopped}

func _exit_tree() -> void:
    if is_instance_valid(audio):
        audio.announcer.stop_all()
