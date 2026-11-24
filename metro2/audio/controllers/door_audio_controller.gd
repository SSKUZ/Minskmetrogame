extends Node
class_name MetroDoorAudioController
## Each door reports actual openness [0..1]; no timer-based fake movements.
var effects: Node
var _doors: Dictionary = {}
signal motion_state_changed(door_id: String, direction: int, openness: float)
@export var movement_epsilon: float = 0.002

func register_door(door_id: String, origin: Node3D, openness: float) -> void:
    _doors[door_id] = {"origin": origin, "value": clampf(openness, 0.0, 1.0), "direction": 0}

func unregister_door(door_id: String) -> void:
    _doors.erase(door_id)

func update_openness(door_id: String, openness: float) -> void:
    if not _doors.has(door_id):
        return
    var door: Dictionary = _doors[door_id]
    var value: float = clampf(openness, 0.0, 1.0)
    var previous: float = float(door["value"])
    var delta: float = value - previous
    var direction: int = 1 if delta > movement_epsilon else (-1 if delta < -movement_epsilon else 0)
    var old_direction: int = int(door["direction"])
    if direction != 0 and direction != old_direction:
        _emit("door.opening" if direction > 0 else "door.closing", door["origin"])
    if direction > 0 and value >= 1.0 - movement_epsilon:
        _emit("door.opened", door["origin"])
        direction = 0
    elif direction < 0 and value <= movement_epsilon:
        _emit("door.closed", door["origin"])
        direction = 0
    if absf(delta)>0.000001 or direction!=old_direction:
        motion_state_changed.emit(door_id,direction,value)
    door["value"] = value
    door["direction"] = direction
    _doors[door_id] = door

func _emit(event_id: String, _origin: Node3D) -> void:
    if is_instance_valid(effects): effects.play_event(event_id)
