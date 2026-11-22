extends Node
class_name MetroDoorAudioController
## Each door reports actual openness [0..1]; no timer-based fake movements.
var router: MetroAudioEventRouter
var _doors: Dictionary = {}
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
    if old_direction > 0 and value >= 1.0 - movement_epsilon:
        _emit("door.opened", door["origin"])
        direction = 0
    elif old_direction < 0 and value <= movement_epsilon:
        _emit("door.closed", door["origin"])
        direction = 0
    door["value"] = value
    if direction != 0 or value <= movement_epsilon or value >= 1.0 - movement_epsilon:
        door["direction"] = direction
    _doors[door_id] = door

func _emit(event_id: String, origin: Node3D) -> void:
    if router != null and is_instance_valid(origin):
        router.dispatch(event_id, origin)
