extends Node
class_name MetroTrainAudioController
## Independent continuous parameter model. No invented samples are assigned.
var router: MetroAudioEventRouter
var origin: Node3D
var speed_mps: float = 0.0
var acceleration_mps2: float = 0.0
var traction_command: float = 0.0
var brake_command: float = 0.0
var powered: bool = false
var _layers: Dictionary = {}
var _mix: Dictionary = {"traction": 0.0, "rolling": 0.0, "brake": 0.0, "idle": 0.0}
@export var response_seconds: float = 0.35

func set_state(speed: float, acceleration: float, traction: float, brake: float, power: bool) -> void:
    speed_mps = maxf(0.0, absf(speed))
    acceleration_mps2 = acceleration
    traction_command = clampf(traction, 0.0, 1.0)
    brake_command = clampf(brake, 0.0, 1.0)
    powered = power

func configure_layers(layer_events: Dictionary) -> void:
    # Each key is an independent confirmed continuous loop event.
    stop_layers()
    if router == null or origin == null:
        return
    for layer in ["traction", "rolling", "brake", "idle"]:
        var event_id: String = str(layer_events.get(layer, ""))
        if event_id == "" or router.bank == null or not router.bank.has_event(event_id):
            continue
        var player: AudioStreamPlayer3D = router.dispatch(event_id, origin, Vector3.ZERO, -60.0)
        if player != null:
            _layers[layer] = player
            player.stream_paused = false

func _process(delta: float) -> void:
    var moving: float = smoothstep(0.25, 16.0, speed_mps)
    var targets: Dictionary = {
        "traction": traction_command * moving if powered else 0.0,
        "rolling": moving,
        "brake": brake_command * moving,
        "idle": 1.0 - moving if powered else 0.0
    }
    var blend: float = 1.0 - exp(-delta / maxf(response_seconds, 0.01))
    for layer in targets:
        _mix[layer] = lerpf(float(_mix[layer]), float(targets[layer]), blend)
        if _layers.has(layer) and is_instance_valid(_layers[layer]):
            var player: AudioStreamPlayer3D = _layers[layer]
            player.volume_db = linear_to_db(maxf(0.001, float(_mix[layer])))

func stop_layers() -> void:
    for player in _layers.values():
        if is_instance_valid(player):
            player.stop()
            player.queue_free()
    _layers.clear()
