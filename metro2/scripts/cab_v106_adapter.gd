extends Node3D
signal info_pressed
## Explicit path to an authored interactive INFO Area3D; never guess mesh names.
@export var info_control_path: NodePath
var _info_control: Area3D
## Godot adapter for the ORIGINAL cab-r2 authored in Three.js (cab-development).
## No replacement cab is generated. Exported GLB must be added at CAB_PATH.
## Original source: js/cab/CabModel.js and supporting js/cab/Cab*.js.
const CAB_PATH := "res://assets/cab/cab_81_717_r2.glb"
const CAB_SCENE_PATH := "res://assets/cab/cab_81_717_r2.tscn"
var original_cab: Node3D
var door_open: bool = false
var ready_for_play: bool = false
## Adjustable placement and camera anchor; values await APK visual calibration.
const CAB_POSITION := Vector3(0.0, 0.0, -8.0)
const CAB_ROTATION_Y := PI
const CAB_EYE := Vector3(-0.35, 2.65, -8.6)
var cab_eye_local := CAB_EYE

func get_eye_position() -> Vector3:
    return cab_eye_local

func initialize(_train: Node3D) -> void:
    var path := CAB_PATH
    if not ResourceLoader.exists(path):
        path = CAB_SCENE_PATH
    if not ResourceLoader.exists(path):
        push_warning("Original cab-r2 is not exported to Godot yet. No substitute model will be shown.")
        return
    var resource := load(path)
    if not resource is PackedScene:
        push_error("Cab-r2 asset is not an imported PackedScene: " + path)
        return
    original_cab = (resource as PackedScene).instantiate() as Node3D
    if original_cab == null:
        push_error("Cab-r2 root must be Node3D")
        return
    original_cab.name = "OriginalCab81_717_R2"
    # Source cab front is +Z, while this consist travels toward -Z.
    # Place the cab at the leading end of the first car; keep scale in metres.
    original_cab.rotation.y = CAB_ROTATION_Y
    original_cab.position = CAB_POSITION
    add_child(original_cab)
    # Export must be authored in Godot metres; do NOT apply legacy Three.js 1.65 scale twice.
    ready_for_play = true
    bind_info_control()
    print("BLOCK A cab loaded: ", path, " position=", CAB_POSITION, " yaw=", CAB_ROTATION_Y, " eye=", CAB_EYE)

func set_door_state(is_open: bool) -> void:
    door_open = is_open
    # Placeholder for original cab-r2 control lamp bindings after GLB export.
    # Never animate unverified imported mesh names.

func bind_info_control() -> void:
    if not is_instance_valid(original_cab) or info_control_path.is_empty():
        return
    var target: Node = original_cab.get_node_or_null(info_control_path)
    if not target is Area3D:
        push_warning("Cab INFO path must point to an authored Area3D.")
        return
    _info_control = target as Area3D
    _info_control.input_ray_pickable = true
    if not _info_control.input_event.is_connected(_on_info_input):
        _info_control.input_event.connect(_on_info_input)

func _on_info_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        info_pressed.emit()
    elif event is InputEventScreenTouch and event.pressed:
        info_pressed.emit()
