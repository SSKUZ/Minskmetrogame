extends "res://modules/trains/v106/v106_train.gd"
const LineInfo = preload("res://modules/line/line_info.gd")
const AudioAdapter = preload("res://audio/adapters/v106_audio_adapter.gd")
var line: Node3D
var service_ready := false
var flight_position := Vector3.ZERO
var _sound: Node
var _last_speed := 0.0
var _saloon_fov := 80.0
var _audio_doors: Dictionary = {}
var _pose_cars: Array[Dictionary] = []
var _pose_couplers: Array[Dictionary] = []
var _pose_children := -1
var _posed_distance := NAN
var _in_motion_step := false
var _last_door_samples: Dictionary = {}

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
    var motors: Array[Node3D]=[]
    for car in train.get_children():
        if not car is Node3D or not str(car.name).begins_with("OriginalV106Car"): continue
        var speaker := car.get_node("InfoSpeaker") as Marker3D
        speakers.append(speaker)
        var motor := Marker3D.new()
        motor.name="TrainMechanismAudio"
        car.add_child(motor)
        var bounds: AABB=_get_model_bounds(car)
        motor.position=bounds.get_center()
        motor.position.y=bounds.position.y+0.4
        motors.append(motor)
    var axles: Array[float]=[]
    var axle_origins: Array[Node3D]=[]
    for record in _bogie_visuals._cars.values():
        for bogie in record.bogies:
            for offset in [-1.05,1.05]:
                # Progress increases toward -Z, so a positive car offset is behind.
                axles.append(-(float(bogie.z)+float(offset)))
                var axle := Marker3D.new()
                bogie.root.add_child(axle)
                axle.position.z=float(offset)
                axle_origins.append(axle)
    _sound.bind(info_binding.audio,train,cab_runtime,line.station_sound_origin,speakers,axles,motors,axle_origins)
    _register_audio_doors()
    _configure_rail_audio()
    _install_inspection_ui()
    _set_camera_mode("cabin")
    set_physics_process(true)

func _register_audio_doors() -> void:
    # Use the original paired leaves and their car frame. Do not emit from the
    # distant train root or infer door movement from an input button.
    for leaf in door_system.leaves:
        if float(leaf.direction)>0.0: continue
        var car: Node=leaf.parts[0].node
        while car!=null and not str(car.name).begins_with("OriginalV106Car"):
            car=car.get_parent()
        if not car is Node3D: continue
        var marker := Marker3D.new()
        car.add_child(marker)
        var centre: Vector3=leaf.center
        marker.position=Vector3(centre.x,centre.y,float(leaf.seam))
        var side: int=-1 if centre.x<0.0 else 1
        var id: String="door_%d" % _audio_doors.size()
        _audio_doors[id]=side
        _sound.register_door(id,marker,float(door_system.side_open[side]))

func _configure_rail_audio() -> void:
    # Same 16 m grid and exact portal clipping as line_tunnel, independent of
    # which visual sections/stations happen to be resident.
    var joints: Dictionary={}
    for slot in range(floori(line.path.lower_z/16.0),ceili(96.0/16.0)):
        for piece in line.path.tunnel_pieces(float(slot)*16.0,float(slot+1)*16.0):
            joints[430.0-piece.x]=true
            joints[430.0-piece.y]=true
    var positions: Array[float]=[]
    for point in joints: positions.append(float(point))
    _sound.system.rail_audio.set_track(positions)

func _process(_delta: float) -> void:
    if not is_instance_valid(_sound) or not is_instance_valid(door_system): return
    # The leaf controller also advances once per rendered frame. Sampling it at
    # physics frequency would create false stops between two rendered frames.
    for side in [-1,1]:
        var value: float=float(door_system.side_open[side])
        if value==float(_last_door_samples.get(side,-1.0)): continue
        _last_door_samples[side]=value
        for id in _audio_doors:
            if int(_audio_doors[id])==side: _sound.update_door(str(id),value)

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
    if direction!=0 and is_instance_valid(_tunnel) and _tunnel.has_method("approach_limit"):
        var tunnel_limit: float=_tunnel.call("approach_limit",distance,direction,_train_bounds)
        limit=maxf(limit,tunnel_limit) if direction>0 else minf(limit,tunnel_limit)
    var before_move: float=distance
    var loading_hold: bool=is_finite(limit) and absf(distance-limit)<=1.0
    if is_finite(limit):
        var remaining: float=absf(distance-limit)
        # Loading interlock leaves the selected mode and cab input intact. It
        # limits movement only while the protected approach lacks a station.
        var safe_speed: float=sqrt(2.0*float(line.layout.streaming.braking_deceleration_mps2)*maxf(0.0,remaining-1.0))
        speed=minf(speed,safe_speed)
    _in_motion_step=true
    super._physics_process(delta)
    _in_motion_step=false
    if loading_hold or (is_finite(limit) and ((direction>0 and distance<limit) or (direction<0 and distance>limit))):
        distance=before_move if loading_hold else limit
        speed=0.0
        train.position.z=distance
    if distance>442.0:
        distance=442.0
        speed=0.0
        train.position.z=distance
    _place_consist()
    _update_camera()
    var nearest: Dictionary=line.path.nearest_station(distance)
    if not nearest.is_empty():
        _station=line.station_instance(int(nearest.index))
        _station_stop_z=float(nearest.stop_z)
        line.station_sound_origin.global_position=Vector3(0.992,1.2,_station_stop_z)
    if is_instance_valid(line.passengers): line.passengers.update_service(nearest,speed,(speed-_last_speed)/maxf(delta,0.001))
    if is_instance_valid(_sound):
        _sound.update_motion(430.0-distance,speed,(speed-_last_speed)/maxf(delta,0.001),cab_runtime.traction_actual,cab_runtime.applied_brake,float(cab_runtime.voltage_kv)>0.01,int(cab_runtime.direction))
        _sound.update_cab()
        var zone: String="depot" if distance>96.0 else "station" if line.path.in_station(distance) else "tunnel"
        _sound.system.environment_audio.enter_zone(zone)
        _sound.update_controller(cab_runtime.controller_notch)
        _sound.system.set_listener_mode("cab" if camera_mode=="cabin" else "salon" if camera_mode=="salon" else "platform" if camera_mode=="platform" else "free")
    _last_speed=speed
    if camera_mode=="flight" and is_instance_valid(_flight_ui):
        var axis: Vector2=_flight_ui.get("stick")
        var view := Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0))
        flight_position+=(view.x*axis.x+view.z*axis.y)*CAMERA_MOVE_SPEED*delta
        _update_camera()
    hud.text="ДЕПО — ПЛОЩАДЬ ЛЕНИНА · %.0f км/ч · %s" % [speed*3.6,str(info_binding.passenger_information().current_station)]

func _cache_consist() -> void:
    _pose_cars.clear()
    _pose_couplers.clear()
    for node in train.get_children():
        if not node is Node3D: continue
        var car := node as Node3D
        if str(car.name).begins_with("OriginalV106Car"):
            if not _pose_cache.has(car): _pose_cache[car]=_get_model_bounds(car)
            if not _rest_poses.has(car): _rest_poses[car]=car.transform
            var bounds: AABB=_pose_cache[car]
            var rest: Transform3D=_rest_poses[car]
            var centre: Vector3=rest*bounds.get_center()
            var supports: PackedFloat32Array=_bogie_visuals.setup_car(car,bounds,rest)
            _pose_cars.append({"node":car,"centre":centre,"model_centre":bounds.get_center(),"basis":rest.basis,
                "front":float(supports[0]),"rear":float(supports[1]),
                "balance":(centre.z-supports[0])/maxf(0.1,supports[1]-supports[0]),
                "bogies":_bogie_visuals._cars[car].bogies})
        elif car.get_child_count()>0 and car.get_child(0) is MeshInstance3D:
            if not car.has_meta("line_coupler_pose"): car.set_meta("line_coupler_pose",car.transform)
            var rest: Transform3D=car.get_meta("line_coupler_pose")
            _pose_couplers.append({"node":car,"z":float((car.get_child(0) as Node3D).position.z+rest.origin.z)})
    _pose_children=train.get_child_count()
    _posed_distance=NAN

func _pose_frame(z: float, frames: Dictionary) -> Transform3D:
    if not frames.has(z): frames[z]=line.path.frame_at(z)
    return frames[z]

func _place_consist() -> void:
    if line==null or not is_instance_valid(train): return
    if _pose_children!=train.get_child_count(): _cache_consist()
    if _posed_distance==distance: return
    _posed_distance=distance
    var frames: Dictionary={}
    var wheel_angle: float=fposmod((distance-430.0)/0.390,TAU)
    for record in _pose_cars:
        var front: Vector3=_pose_frame(distance+float(record.front),frames).origin
        var rear: Vector3=_pose_frame(distance+float(record.rear),frames).origin
        var tangent: Vector3=(rear-front).normalized()
        var right: Vector3=Vector3.UP.cross(tangent).normalized()
        var basis: Basis=Basis(right,tangent.cross(right).normalized(),tangent)*record.basis
        var target: Vector3=front.lerp(rear,float(record.balance))+Vector3(record.centre.x,record.centre.y+0.22,0)
        var pose: Transform3D=Transform3D(basis,target-basis*record.model_centre)
        if record.node.global_transform!=pose: record.node.global_transform=pose
        for bogie in record.bogies:
            var frame: Transform3D=_pose_frame(distance+float(bogie.z),frames)
            frame.origin.y+=0.390
            if bogie.root.global_transform!=frame: bogie.root.global_transform=frame
            for wheel in bogie.wheels:
                if wheel.rotation.x!=wheel_angle: wheel.rotation.x=wheel_angle
    for record in _pose_couplers:
        var frame: Transform3D=_pose_frame(distance+float(record.z),frames)
        var pose: Transform3D=Transform3D(frame.basis,frame.origin+Vector3(0,0.22,0)-frame.basis*Vector3(0,0,float(record.z)))
        if record.node.global_transform!=pose: record.node.global_transform=pose

func release_station(station: Node3D) -> void:
    if _station==station: _station=null

func platform_camera_available() -> bool:
    return is_instance_valid(_station) and absf(distance-_station_stop_z)<180.0

func _update_camera() -> void:
    if _in_motion_step: return
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
        var car: Node3D=_pose_cars[_focused_car].node
        var focus := car.to_global((_pose_cache[car] as AABB).get_center())+camera_pan
        camera.global_position=focus+Vector3(sin(orbit_yaw)*cos(orbit_pitch),sin(orbit_pitch),cos(orbit_yaw)*cos(orbit_pitch))*orbit_radius
        if camera.global_position.distance_squared_to(focus)>0.001: camera.look_at(focus)
        return
    super._update_camera()
    if camera_mode=="cabin":
        var car: Node3D=_pose_cars[0].node
        camera.global_basis=car.global_basis*Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0))

func _set_camera_mode(mode: String) -> void:
    if mode=="flight" and is_instance_valid(camera): flight_position=camera.global_position
    super._set_camera_mode(mode)

func _publish_diagnostics() -> void:
    pass
