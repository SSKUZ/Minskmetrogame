extends "res://modules/trains/v106/v106_train.gd"
const LineInfo = preload("res://modules/line/line_info.gd")
const AudioAdapter = preload("res://audio/adapters/v106_audio_adapter.gd")
var line: Node3D
var service_ready := false
var flight_position := Vector3.ZERO
var _sound: Node
var _last_speed := 0.0
var _saloon_fov := 80.0

func _ready() -> void:
    spawn_z=430.0
    super._ready()
    route_end_distance=line.path.lower_z+80.0
    set_physics_process(false)

func _attach_fourth_car(third_car: Node3D, third_bounds: AABB) -> void:
    super._attach_fourth_car(third_car,third_bounds)
    # Replace only this route instance's binding. The reusable V106 module stays intact.
    if is_instance_valid(info_binding):
        var old_mode_button := info_binding.get("_button") as Button
        if is_instance_valid(old_mode_button): old_mode_button.queue_free()
        remove_child(info_binding)
        info_binding.free()
    info_binding=LineInfo.new()
    add_child(info_binding)
    info_binding.initialize(self,line)
    _sound=AudioAdapter.new()
    add_child(_sound)
    var speakers: Array[Node3D]=[]
    for car in train.get_children():
        if car is Node3D and str(car.name).begins_with("OriginalV106Car"): speakers.append(car)
    var axles: Array[float]=[]
    for record in _bogie_visuals._cars.values():
        for bogie in record.bogies:
            axles.append(float(bogie.z)-1.05)
            axles.append(float(bogie.z)+1.05)
    _sound.bind(info_binding.audio,train,cab_runtime,line.station_sound_origin,speakers,axles)
    for side in [-1,1]: _sound.register_door(str(side),train,0.0)
    _install_inspection_ui()
    _set_camera_mode("cabin")
    set_physics_process(true)

func _decorate_consist() -> void:
    # Use the saved working passenger-demo advertising/realism integration.
    preload("res://scripts/depot/saloon_advertising_v46.gd").decorate(self,train,door_system)
    preload("res://scripts/depot/saloon_realism_v49.gd").apply(train,door_system)
    preload("res://scripts/depot/goodmix_restore.gd").apply(train)

func _install_inspection_ui() -> void:
    for child in _ui_layer.get_children():
        if child is HBoxContainer and (child.name=="ViewModes" or child.get_child_count()==2): child.hide()
        if child is VBoxContainer and child.name=="CameraMovement": child.hide()
    _flight_ui=preload("res://scripts/depot/mobile_inspection_ui.gd").new()
    _ui_layer.add_child(_flight_ui)
    _flight_ui.call("initialize",self)
    var row := HBoxContainer.new()
    row.position=Vector2(15,200)
    _ui_layer.add_child(row)
    var outside := Button.new()
    outside.text="СНАРУЖИ"
    outside.pressed.connect(func(): _set_camera_mode("external"))
    row.add_child(outside)
    var cars := OptionButton.new()
    for i in range(4): cars.add_item("Вагон %d" % (i+1))
    cars.item_selected.connect(func(i: int):
        if camera_mode not in ["salon","external"]: _set_camera_mode("salon")
        _focused_car=i
        _update_camera())
    row.add_child(cars)

func _physics_process(delta: float) -> void:
    if not service_ready: return
    if is_instance_valid(line.passengers):
        line.passengers.guard_doors(door_system)
    var direction: int=int(cab_runtime.direction)
    var limit: float=line.streamer.approach_limit(distance,direction,_train_bounds) if direction!=0 else INF
    var before_move: float=distance
    var loading_hold: bool=is_finite(limit) and absf(distance-limit)<=1.0
    if is_finite(limit):
        var remaining: float=absf(distance-limit)
        # Loading interlock leaves the selected mode and cab input intact. It
        # limits movement only while the protected approach lacks a station.
        var safe_speed: float=sqrt(2.0*float(line.layout.streaming.braking_deceleration_mps2)*maxf(0.0,remaining-1.0))
        speed=minf(speed,safe_speed)
    super._physics_process(delta)
    if loading_hold or (is_finite(limit) and ((direction>0 and distance<limit) or (direction<0 and distance>limit))):
        distance=before_move if loading_hold else limit
        speed=0.0
        train.position.z=distance
        _update_camera()
    if distance>442.0:
        distance=442.0
        speed=0.0
        train.position.z=distance
    var nearest: Dictionary=line.path.nearest_station(distance)
    if not nearest.is_empty():
        _station=line.station_instance(int(nearest.index))
        _station_stop_z=float(nearest.stop_z)
        line.station_sound_origin.global_position=Vector3(0.992,1.2,_station_stop_z)
    if is_instance_valid(line.passengers): line.passengers.update_service(nearest,speed,(speed-_last_speed)/maxf(delta,0.001))
    if is_instance_valid(_sound):
        _sound.update_motion(430.0-distance,speed,(speed-_last_speed)/maxf(delta,0.001),cab_runtime.traction_actual,cab_runtime.applied_brake,true)
        for side in [-1,1]: _sound.update_door(str(side),float(door_system.side_open[side]))
        _sound.update_controller(cab_runtime.controller_notch)
        _sound.system.set_listener_mode("cab" if camera_mode=="cabin" else "salon" if camera_mode=="salon" else "platform" if camera_mode=="platform" else "free")
    _last_speed=speed
    if camera_mode=="flight" and is_instance_valid(_flight_ui):
        var axis: Vector2=_flight_ui.get("stick")
        var view := Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0))
        flight_position+=(view.x*axis.x+view.z*axis.y)*CAMERA_MOVE_SPEED*delta
        _update_camera()
    hud.text="ДЕПО — ПЛОЩАДЬ ЛЕНИНА · %.0f км/ч · %s" % [speed*3.6,str(info_binding.passenger_information().current_station)]

func _place_consist() -> void:
    if line==null or not is_instance_valid(train): return
    for node in train.get_children():
        if not node is Node3D: continue
        var car := node as Node3D
        if str(car.name).begins_with("OriginalV106Car"):
            if not _pose_cache.has(car): _pose_cache[car]=_get_model_bounds(car)
            if not _rest_poses.has(car): _rest_poses[car]=car.transform
            var bounds: AABB=_pose_cache[car]
            var rest: Transform3D=_rest_poses[car]
            var centre := rest*bounds.get_center()
            var supports: PackedFloat32Array=_bogie_visuals.setup_car(car,bounds,rest)
            var front: Vector3=line.path.position_at(distance+supports[0])
            var rear: Vector3=line.path.position_at(distance+supports[1])
            var tangent := (rear-front).normalized()
            var right := Vector3.UP.cross(tangent).normalized()
            var basis := Basis(right,tangent.cross(right).normalized(),tangent)*rest.basis
            var balance := (centre.z-supports[0])/maxf(0.1,supports[1]-supports[0])
            var target := front.lerp(rear,balance)+Vector3(centre.x,centre.y+0.22,0)
            car.global_transform=Transform3D(basis,target-basis*bounds.get_center())
            for bogie in _bogie_visuals._cars[car].bogies:
                var frame: Transform3D=line.path.frame_at(distance+float(bogie.z))
                frame.origin.y+=0.390
                (bogie.root as Node3D).global_transform=frame
                for wheel in bogie.wheels: (wheel as Node3D).rotation.x=fposmod((distance-430.0)/0.390,TAU)
        elif car.get_child_count()>0 and car.get_child(0) is MeshInstance3D:
            if not car.has_meta("line_coupler_pose"): car.set_meta("line_coupler_pose",car.transform)
            var rest: Transform3D=car.get_meta("line_coupler_pose")
            # Existing coupler geometry is expressed in train coordinates.
            var z := (car.get_child(0) as Node3D).position.z+rest.origin.z
            var frame: Transform3D=line.path.frame_at(distance+z)
            car.global_transform=Transform3D(frame.basis,frame.origin+Vector3(0,0.22,0)-frame.basis*Vector3(0,0,z))

func release_station(station: Node3D) -> void:
    if _station==station: _station=null

func platform_camera_available() -> bool:
    return is_instance_valid(_station) and absf(distance-_station_stop_z)<180.0

func _update_camera() -> void:
    if not is_instance_valid(camera) or not is_instance_valid(train): return
    _place_consist()
    if camera_mode=="flight":
        camera.global_position=flight_position
        camera.global_basis=Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0))
        return
    if camera_mode=="platform" and is_instance_valid(_station):
        camera.global_position=_station.to_global(Vector3(-2.3,2.8,32.0))
        camera.global_basis=Basis.from_euler(Vector3(-orbit_pitch,PI+orbit_yaw,0))
        return
    if camera_mode=="external" and _focused_car>=0 and _focused_car<_car_centers.size():
        var car := train.get_node("OriginalV106Car%02d" % (_focused_car+1)) as Node3D
        var focus := car.to_global((_pose_cache[car] as AABB).get_center())+camera_pan
        camera.global_position=focus+Vector3(sin(orbit_yaw)*cos(orbit_pitch),sin(orbit_pitch),cos(orbit_yaw)*cos(orbit_pitch))*orbit_radius
        if camera.global_position.distance_squared_to(focus)>0.001: camera.look_at(focus)
        return
    super._update_camera()
    if camera_mode=="cabin":
        var car := train.get_node("OriginalV106Car01") as Node3D
        camera.global_basis=car.global_basis*Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0))

func _set_camera_mode(mode: String) -> void:
    if mode=="flight" and is_instance_valid(camera): flight_position=camera.global_position
    super._set_camera_mode(mode)

func _publish_diagnostics() -> void:
    pass
