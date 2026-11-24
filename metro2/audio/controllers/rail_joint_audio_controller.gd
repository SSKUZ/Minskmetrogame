extends Node
class_name MetroRailJointAudioController
## Deterministic crossings in route metres; no randomized joint timer.
var router: MetroAudioEventRouter
var origin: Node3D
var joint_positions_m: Array[float] = []
var axle_offsets_m: Array[float] = []
var axle_origins: Array[Node3D] = []
var _previous_route_m: float = NAN
@export var teleport_threshold_m: float = 12.0
@export var joint_event_id: String = ""
@export var dedup_tolerance_m: float = 0.005

func set_track(positions_m: Array[float]) -> void:
    joint_positions_m.clear()
    for value in positions_m:
        _insert_unique(value)
    joint_positions_m.sort()
    reset()

func register_module(start_m: float, length_m: float, local_joint_m: Array[float]) -> void:
    for local_m in local_joint_m:
        if local_m < 0.0 or local_m > length_m:
            continue
        _insert_unique(start_m + local_m)
    joint_positions_m.sort()

func _insert_unique(value: float) -> void:
    for existing in joint_positions_m:
        if absf(existing - value) <= dedup_tolerance_m:
            return
    joint_positions_m.append(value)

func set_axles(offsets_m: Array[float], origins: Array[Node3D] = []) -> void:
    axle_offsets_m = offsets_m.duplicate()
    axle_origins=origins.duplicate()
    reset()

func reset() -> void:
    _previous_route_m = NAN

func advance(route_m: float) -> void:
    if joint_event_id=="" or router==null or router.bank==null or not router.bank.has_event(joint_event_id):
        _previous_route_m=route_m
        return
    if is_nan(_previous_route_m):
        _previous_route_m = route_m
        return
    var step: float = route_m - _previous_route_m
    if absf(step) > teleport_threshold_m:
        _previous_route_m = route_m
        return
    if absf(step) < 0.00001:
        return
    for axle_index in range(axle_offsets_m.size()):
        var offset_m: float=axle_offsets_m[axle_index]
        var axle_origin: Node3D=axle_origins[axle_index] if axle_index<axle_origins.size() else origin
        var from_m: float = _previous_route_m + offset_m
        var to_m: float = route_m + offset_m
        var index: int=joint_positions_m.bsearch(minf(from_m,to_m))
        while index<joint_positions_m.size() and joint_positions_m[index]<=maxf(from_m,to_m):
            var joint_m: float=joint_positions_m[index]
            var crossed: bool=(from_m<joint_m and joint_m<=to_m) if step>0.0 else (to_m<=joint_m and joint_m<from_m)
            if crossed and is_instance_valid(axle_origin):
                router.dispatch(joint_event_id,axle_origin)
            index+=1
    _previous_route_m = route_m
