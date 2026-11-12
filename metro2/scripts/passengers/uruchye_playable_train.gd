extends "res://modules/trains/v106/v106_train.gd"
## Full existing V106/cab controller, with a short flat Uruchye approach.
const STOP_Z := 9.603
var flight_position := Vector3.ZERO
var service_ready := false
var passenger_manager: Node3D
var _saloon_fov := 80.0
var _service_message := ""

func _ready() -> void:
    spawn_z=145.0
    super._ready()
    route_end_distance=-125.0
    camera.far=360.0

func _attach_fourth_car(third_car: Node3D,third_bounds: AABB) -> void:
    _boot_stage("Подготовка оригинальной кабины, дверей и камер")
    super._attach_fourth_car(third_car,third_bounds)
    _install_inspection_ui()
    var lead:=train.get_node("OriginalV106Car01") as Node3D
    var bounds: AABB=_get_model_bounds(lead)
    distance=92.112+35.0-bounds.position.z
    train.position.z=distance
    speed=0.0
    _configure_tunnel()
    _set_camera_mode("cabin")
    service_ready=true

func _decorate_consist() -> void:
    preload("res://scripts/depot/saloon_advertising_v46.gd").decorate(self,train,door_system)
    preload("res://scripts/depot/saloon_realism_v49.gd").apply(train,door_system)
    preload("res://scripts/depot/goodmix_restore.gd").apply(train)

func _install_inspection_ui() -> void:
    for child in _ui_layer.get_children():
        if child is HBoxContainer and (child.name=="ViewModes" or child.get_child_count()==2):child.hide()
        if child is VBoxContainer and child.name=="CameraMovement":child.hide()
    _flight_ui=preload("res://scripts/depot/mobile_inspection_ui.gd").new()
    _ui_layer.add_child(_flight_ui)
    _flight_ui.initialize(self)
    var row:=HBoxContainer.new()
    row.position=Vector2(15,103);row.add_theme_constant_override("separation",8)
    _ui_layer.add_child(row)
    var outside:=Button.new();outside.text="СНАРУЖИ";row.add_child(outside)
    outside.pressed.connect(func():_set_camera_mode("external"))
    var cars:=OptionButton.new()
    for i in range(4):cars.add_item("Вагон %d"%(i+1))
    row.add_child(cars)
    cars.item_selected.connect(func(index):
        _focused_car=index
        if camera_mode not in ["salon","external"]:
            _set_camera_mode("salon");_focused_car=index
        _update_camera())
    var repeat:=Button.new();repeat.text="ЗАНОВО";row.add_child(repeat)
    repeat.pressed.connect(func():get_tree().reload_current_scene())
    var exit_button:=Button.new();exit_button.text="ВЫСАДКА";row.add_child(exit_button)
    exit_button.pressed.connect(func():
        if is_instance_valid(passenger_manager) and absf(distance-STOP_Z)<2.5 and speed<0.05 and float(door_system.side_open[-1])>0.95:
            passenger_manager.request_alight())

func platform_camera_available() -> bool:
    return is_instance_valid(_station) and is_instance_valid(train)

func _place_consist() -> void:
    if not is_instance_valid(train):return
    # Keep the original bogie model on this flat station-only railway; the old
    # depot ramp profile must not lift the rear cars on the short approach.
    for node in train.get_children():
        if not node is Node3D or not str(node.name).begins_with("OriginalV106Car"):continue
        var car:=node as Node3D
        if not _pose_cache.has(car):_pose_cache[car]=_get_model_bounds(car)
        if not _rest_poses.has(car):_rest_poses[car]=car.transform
        car.transform=_rest_poses[car]
        _bogie_visuals.setup_car(car,_pose_cache[car],_rest_poses[car])
        var record: Dictionary=_bogie_visuals._cars[car]
        for bogie in record.bogies:
            var pivot:=bogie.root as Node3D
            pivot.global_transform=Transform3D(Basis.IDENTITY,Vector3(0.992,0.390,train.global_position.z+float(bogie.z)))
            for wheel in bogie.wheels:
                (wheel as Node3D).rotation.x=fposmod(distance/0.390,TAU)

func _physics_process(delta: float) -> void:
    if not service_ready:return
    _service_message=""
    if is_instance_valid(passenger_manager):
        if not passenger_manager.doors_clear() and not bool(door_system.side_targets[-1]):
            door_system.side_targets[-1]=true
            door_system.target_open=true
            _service_message="Проход через двери — закрытие заблокировано"
    var before:=speed
    super._physics_process(delta)
    if camera_mode=="flight" and is_instance_valid(_flight_ui):
        var axis: Vector2=_flight_ui.stick
        var view:=Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0))
        flight_position+=(view.x*axis.x+view.z*axis.y)*CAMERA_MOVE_SPEED*delta
        flight_position.y=clampf(flight_position.y,0.5,14.0)
        _update_camera()
    if is_instance_valid(passenger_manager):
        passenger_manager.speed=speed
        passenger_manager.acceleration=(speed-before)/maxf(delta,0.001)
        passenger_manager.exchange_enabled=speed<0.05 and absf(distance-STOP_Z)<2.5 and float(door_system.side_open[-1])>0.95
    var to_stop:=distance-STOP_Z
    var status: String="До места остановки: %.1f м"%to_stop if to_stop>=0 else "За отметкой остановки: %.1f м"%(-to_stop)
    if speed<0.05 and absf(to_stop)<2.5:status="Уручье · остановка · откройте левые двери"
    if is_instance_valid(passenger_manager) and passenger_manager.exchange_enabled:
        status="Посадка завершена — закройте двери" if passenger_manager.complete() else "Посадка пассажиров"
    if _service_message!="":status=_service_message
    hud.text="V106 · %.0f км/ч · %s"%[speed*3.6,status]

func _update_camera() -> void:
    if not is_instance_valid(camera) or not is_instance_valid(train):return
    _place_consist()
    if camera_mode=="flight":
        camera.global_position=flight_position
        camera.global_basis=Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0));return
    if camera_mode=="platform" and is_instance_valid(_station):
        camera.global_position=_station.to_global(Vector3(-2.3,2.8,32.0))
        camera.global_basis=Basis.from_euler(Vector3(-orbit_pitch,PI+orbit_yaw,0));return
    if camera_mode=="external" and _focused_car>=0 and _focused_car<_car_centers.size():
        wagon_center=_car_centers[_focused_car]
    super._update_camera()

func _set_camera_mode(mode: String) -> void:
    if mode=="flight" and is_instance_valid(camera):flight_position=camera.global_position
    super._set_camera_mode(mode)
    if mode=="salon":camera.fov=_saloon_fov

func _zoom_view(ratio: float) -> void:
    if camera_mode=="salon":
        _saloon_fov=clampf(_saloon_fov/maxf(0.01,ratio),35.0,100.0)
        if is_instance_valid(camera):camera.fov=_saloon_fov
    else:super._zoom_view(ratio)

func passenger_information() -> Dictionary:
    return {"current_station":"УРУЧЧА","next_station":"УРУЧЧА","at_station":absf(distance-STOP_Z)<2.5 and speed<0.05}

func _boot_stage(message: String) -> void:
    if OS.has_feature("web"):JavaScriptBridge.eval("window.metroBootStage && window.metroBootStage("+JSON.stringify(message)+")",true)
