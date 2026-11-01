extends Node3D
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
    print("BLOCK A cab loaded: ", path, " position=", CAB_POSITION, " yaw=", CAB_ROTATION_Y, " eye=", CAB_EYE)

func set_door_state(is_open: bool) -> void:
    door_open = is_open
    # Placeholder for original cab-r2 control lamp bindings after GLB export.
    # Never animate unverified imported mesh names.
