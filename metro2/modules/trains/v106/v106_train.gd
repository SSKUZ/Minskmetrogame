extends "res://scripts/v106_four_cars_preview.gd"
## Owns one existing controller/door system. No station, depot, tunnel or world.
signal consist_ready
@export var spawn_z := 430.0
var passenger_equipment: Node3D
var route_information: Callable
var _pose_cache: Dictionary = {}
var _rest_poses: Dictionary = {}
var _flight_ui: Control

func _ready() -> void:
    distance = spawn_z
    route_end_distance = -1000000.0
    super._ready()
    _diagnostics_enabled = false

func _create_world_environment() -> void:
    pass

func _create_route_tunnel() -> void:
    pass

func _attach_fourth_car(third_car: Node3D, third_bounds: AABB) -> void:
    super._attach_fourth_car(third_car,third_bounds)
    if not is_instance_valid(door_system) or not is_instance_valid(cab_runtime):
        push_error("V47: incomplete consist")
        return
    passenger_equipment = preload("res://scripts/depot/saloon_equipment.gd").new()
    passenger_equipment.name = "PassengerSaloonEquipment"
    add_child(passenger_equipment)
    passenger_equipment.call("initialize",self,train)
    consist_ready.emit()

func bind_tunnel(tunnel: Node3D) -> void:
    # The route owns the tunnel; the existing controller only configures it.
    _tunnel = tunnel
    _configure_tunnel()

func passenger_information() -> Dictionary:
    if route_information.is_valid():
        return route_information.call()
    return {"current_station":"", "next_station":"", "at_station":false}

func _place_consist() -> void:
    preload("res://scripts/depot/v106_route_placement.gd").place(self,_pose_cache,_rest_poses)

func _configure_tunnel() -> void:
    _place_consist()
    super._configure_tunnel()

func _update_camera() -> void:
    _place_consist()
    if camera_mode == "salon" and is_instance_valid(passenger_equipment):
        var selected := train.get_node("OriginalV106Car%02d" % (_focused_car+1)) as Node3D
        var mount := passenger_equipment.call("camera_mount",selected) as Node3D
        camera.global_position = mount.global_position
        camera.global_basis = mount.global_basis*Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0))
        return
    super._update_camera()
