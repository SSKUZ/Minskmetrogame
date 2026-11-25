extends Node
const Player = preload("res://modules/gameplay/player_controller.gd")
const Interaction = preload("res://modules/gameplay/player_interaction.gd")
const Automatic = preload("res://modules/gameplay/automatic_service.gd")
const UI = preload("res://modules/gameplay/gameplay_ui.gd")
const Geometry = preload("res://modules/gameplay/world_geometry.gd")
const CabAccess = preload("res://modules/gameplay/cab_access.gd")
var line: Node3D
var train: Node3D
var player: CharacterBody3D
var interaction: Node
var automatic: Node
var ui: CanvasLayer
var rules: Dictionary
var role:="driver"
var running:=false
var driver_seated:=false
var prepared:=false
var virtual_wait:=false
var _starting:=false
var _absence_started:=false
var _absence_armed:=false
var _absence:=0.0
var _notice_sent:=false
var _warning_at:=180.0
var _safe_station:=0
var _arrival_at:=0.0
var _next_direction:=1
var _respawning:=false

func initialize(world: Node3D) -> void:
    line=world
    train=line.train
    rules=JSON.parse_string(FileAccess.get_file_as_string("res://modules/gameplay/gameplay_rules.json"))
    player=Player.new()
    line.add_child(player)
    player.initialize(self,rules.walking)
    interaction=Interaction.new()
    add_child(interaction)
    interaction.initialize(self)
    automatic=Automatic.new()
    add_child(automatic)
    automatic.initialize(self)
    ui=UI.new()
    add_child(ui)
    ui.initialize(self)
    train.info_binding._button.hide()
    _legacy_ui(false)
    call_deferred("_prepare")

func _prepare() -> void:
    var access=CabAccess.new()
    interaction.cab_doors=await access.prepare(first_car(),train.cab_runtime,rules.cab_access)
    var geometry=Geometry.new()
    await geometry.prepare(line.get_node("OperatingDepot"))
    await geometry.prepare(train.train,true)
    prepared=true

func first_car() -> Node3D:
    return line.passengers.layout.cars[0]

func start_role(selected_role: String, station_index: int) -> void:
    if _starting or running: return
    _starting=true
    role=selected_role
    ui.menu.hide()
    ui.notice("Подготовка физического мира…")
    # A physical anchor pins only the selected platform through the TZ58 streamer.
    if role=="passenger":
        _safe_station=clampi(station_index,0,line.stations.size()-1)
        player.global_position=Vector3(-5.37,1.25,float(line.stations[_safe_station].root_z)+40.0)
        train.camera.global_position=player.global_position+Vector3.UP*1.68
        train.camera_mode="walk"
        line.streamer.register_player(player)
    while not prepared or not line.ready_for_service:
        await get_tree().process_frame
        if not is_inside_tree(): return
    if role=="driver":
        var door: Dictionary=interaction.cab_doors[0] if not interaction.cab_doors.is_empty() else {}
        var local: Vector3=door.get("threshold",Vector3(-1.35,1.033,-8.4))
        var point: Vector3=first_car().to_global(local+Vector3(-1.4,0,0))
        point.y=8.5
        player.spawn_at(_ground(point))
        train.door_system.request_close()
        train.camera_mode="walk"
        train.info_binding.passenger_mode=false
        train.info_binding.audio.info.set_mode("manual")
    else:
        while not line.passengers.platform_ready(_safe_station):
            await get_tree().process_frame
            if not is_inside_tree(): return
        player.spawn_at(platform_spawn(_safe_station))
        _set_automatic(true)
        _retire_train(true)
        _arrival_at=float(Time.get_ticks_msec())/1000.0+float(rules.service.interval)
    line.streamer.register_player(player)
    running=true
    _starting=false
    ui.set_play_visible(true)
    train._update_camera()

func platform_spawn(index: int) -> Vector3:
    var nav=line.passengers._platforms[index].navigation
    var area: Rect2=nav.platform
    return nav.free_point(Vector3(area.get_center().x,float(nav.height),area.get_center().y))

func _ground(point: Vector3) -> Vector3:
    var query:=PhysicsRayQueryParameters3D.create(point,point-Vector3.UP*6.0,Geometry.WORLD)
    var hit: Dictionary=line.get_world_3d().direct_space_state.intersect_ray(query)
    return hit.position if not hit.is_empty() else Vector3(point.x,5.67,point.z)

func occupy_driver() -> void:
    if role!="driver" or driver_seated or absf(train.speed)>0.05 or player.aboard!=first_car(): return
    driver_seated=true
    player.capsule.disabled=true
    player.velocity=Vector3.ZERO
    player.position=train.cab_runtime.position+Vector3(-0.55,0.08,2.12)
    _absence_started=false
    _absence_armed=false
    _absence=0.0
    _notice_sent=false
    _warning_at=float(rules.absence.warning)
    ui.warning.hide()
    _legacy_ui(true)
    train._set_camera_mode("cabin")

func leave_driver(handover: bool=false) -> void:
    if not driver_seated:
        if running: train._set_camera_mode("walk")
        return
    driver_seated=false
    train.cab_runtime.cancel_interaction()
    train._flight_ui._release_pointer()
    if not handover: _hold_cab()
    # The native brake ramp stops an unattended moving train; no speed rewrite.
    train.throttle=false
    train.brake=false
    var car: Node3D=first_car()
    player.position=Vector3(0.05,1.073,train.cab_runtime.position.z+2.18)
    player.velocity=Vector3.ZERO
    player.capsule.disabled=false
    _absence_armed=true
    _absence_started=absf(train.speed)<0.05
    _absence=0.0
    _legacy_ui(false)
    train._set_camera_mode("walk")

func switch_role(next_role: String) -> void:
    if not running or next_role==role: return
    if next_role=="driver":
        if virtual_wait or absf(train.speed)>0.05 or station_at_train()<0:
            ui.notice("Принять управление можно после остановки поезда на станции")
            return
        # A distant train is not remotely claimable from another platform.
        if not is_instance_valid(player.aboard) and absf(player.global_position.z-float(train.distance))>150.0:
            ui.notice("Подойдите к прибывшему составу")
            return
        role="driver"
        automatic.disable()
        _set_automatic(false)
        _hold_cab()
        train.door_system.request_side(int(train.cab_runtime.door_side),float(train.speed))
        _absence_armed=true
        _absence_started=true
        _absence=0.0
        _notice_sent=false
        _warning_at=float(rules.absence.warning)
        ui.notice("Поезд ожидает машиниста. Займите рабочее место.")
    else:
        if driver_seated: leave_driver(true)
        role="passenger"
        _absence_started=false
        ui.warning.hide()
        _set_automatic(true)
        automatic.enable()
        ui.notice("Управление передано автоматике. Стоянка — около 30 секунд.")

func _set_automatic(enabled: bool) -> void:
    var binding: Node=train.info_binding
    binding.passenger_mode=enabled
    binding.audio.info.set_mode("auto" if enabled else "manual")
    train.throttle=false
    train.brake=false

func station_at_train() -> int:
    if absf(train.speed)>0.05: return -1
    var layout=line.passengers.layout
    for record in line.stations:
        var index: int=int(record.index)
        if not line.passengers.platform_ready(index): continue
        var nav=line.passengers._platforms[index].navigation
        for door in layout.doors:
            var point: Vector3=layout.landing(door)
            if absf(door.marker.global_position.y-float(nav.height))<0.6 and nav.platform_area.has_point(Vector2(point.x,point.z)): return index
    return -1

func _physics_process(delta: float) -> void:
    if not running: return
    interaction.guard_doors()
    if role=="driver" and not driver_seated and _absence_armed:
        if absf(train.speed)<0.05:
            if not _absence_started: _absence_started=true
            _absence+=delta
            if _absence>=float(rules.absence.notice) and not _notice_sent:
                _notice_sent=true
                ui.notice("Отправление задерживается. Вернитесь в кабину для продолжения рейса")
            if _absence>=_warning_at:
                ui.warning.show()
                _warning_at+=float(rules.absence.repeat)
    if not is_instance_valid(player.aboard):
        var record: Dictionary=line.path.nearest_station(player.global_position.z)
        var index: int=int(record.index)
        if line.passengers.platform_ready(index):
            var nav=line.passengers._platforms[index].navigation
            if nav.platform_area.has_point(Vector2(player.global_position.x,player.global_position.z)) and absf(player.global_position.y-float(nav.height))<0.5: _safe_station=index
    if role=="passenger": _virtual_service()

func _virtual_service() -> void:
    if is_instance_valid(player.aboard): return
    var now: float=float(Time.get_ticks_msec())/1000.0
    if not virtual_wait:
        var departed: float=(player.global_position.z-float(train.distance))*float(train.cab_runtime.direction)
        var bounds: AABB=train._train_bounds
        var view_z: float=train.camera.global_position.z
        var camera_clear: bool=absf(clampf(view_z,float(train.distance)+bounds.position.z,float(train.distance)+bounds.end.z)-view_z)>170.0
        if departed>float(rules.service.retire_distance) and camera_clear and interaction.doorway_clear():
            _retire_train()
            _arrival_at=now+float(rules.service.interval)
        return
    var record: Dictionary=line.path.nearest_station(player.global_position.z)
    var index: int=int(record.index)
    if not line.passengers.platform_ready(index): return
    var direction: int=_next_direction
    if index==line.stations.size()-1: direction=1
    var spawn_z: float=float(record.stop_z)+float(direction)*float(rules.service.appearance_distance)
    var bounds: AABB=train._train_bounds
    spawn_z=clampf(spawn_z,line.path.lower_z-bounds.position.z+8.0,96.0-bounds.end.z-8.0)
    var closest_z: float=clampf(player.global_position.z,spawn_z+bounds.position.z,spawn_z+bounds.end.z)
    # Whole consist, physical player and retained inspection camera must be safe.
    if absf(closest_z-player.global_position.z)<170.0: return
    var camera_z: float=train.camera.global_position.z
    if absf(clampf(camera_z,spawn_z+bounds.position.z,spawn_z+bounds.end.z)-camera_z)<170.0: return
    var distance: float=absf(spawn_z-float(record.stop_z))
    var cruise: float=float(rules.service.cruise_speed)
    var peak: float=minf(cruise,sqrt(2.0*distance/(1.0/0.95+1.0/float(rules.service.braking_deceleration))))
    var travel: float=peak/0.95+peak/float(rules.service.braking_deceleration)+maxf(0.0,distance-peak*peak*0.5*(1.0/0.95+1.0/float(rules.service.braking_deceleration)))/maxf(peak,0.1)
    if now<_arrival_at-travel: return
    train.distance=spawn_z
    train.train.position.z=spawn_z
    train.track_x=0.992 if direction>0 else -11.732
    train.cab_runtime.direction=direction
    train._posed_distance=NAN
    train._place_consist()
    train.cab_runtime.controller_value=0.0
    train.cab_runtime.brake_demand=1.0
    train.door_system.request_close()
    virtual_wait=false
    train.train.show()
    _train_collisions(true)
    train.service_ready=true
    automatic.approach_station(index,direction)
    _next_direction=-direction
    line.streamer.refresh()

func _retire_train(initial: bool=false) -> void:
    if is_instance_valid(player.aboard): return
    # Called only outside the protected visibility zone, or before initial spawn.
    virtual_wait=true
    automatic.disable()
    train.service_ready=false
    train.train.hide()
    _train_collisions(false)
    train.speed=0.0
    train.cab_runtime.controller_value=0.0
    train.cab_runtime.brake_demand=1.0
    if not initial: line.passengers.retire_virtual_service()

func _train_collisions(enabled: bool) -> void:
    for body in train.train.find_children("*","CollisionObject3D",true,false):
        if body.name=="WalkCollision": body.collision_layer=Geometry.TRAIN if enabled else 0

func _legacy_ui(enabled: bool) -> void:
    for control in train._ui_layer.get_children():
        if control is CanvasItem:
            if not control.has_meta("gameplay_original_visible"): control.set_meta("gameplay_original_visible",control.visible)
            control.visible=enabled and bool(control.get_meta("gameplay_original_visible"))
    if is_instance_valid(train.info_binding._button): train.info_binding._button.hide()

func respawn(message: String) -> void:
    if _respawning: return
    _respawning=true
    ui.notice(message)
    ui.flash.color.a=0.65
    player.active=false
    player.capsule.set_deferred("disabled",true)
    if not interaction.seat.is_empty():
        line.passengers.layout.release(interaction.seat)
        interaction.seat={}
        player.seated=false
    if is_instance_valid(player.aboard): player.attach_car(null)
    player.global_position=Vector3(-5.37,1.25,float(line.stations[_safe_station].root_z)+40.0)
    line.streamer.refresh()
    while not line.passengers.platform_ready(_safe_station):
        await get_tree().process_frame
        if not is_inside_tree(): return
    await get_tree().physics_frame
    player.eye.position.y=float(rules.walking.eye_height)
    player.spawn_at(platform_spawn(_safe_station))
    train._set_camera_mode("walk")
    _respawning=false

func _process(_delta: float) -> void:
    if not running: return
    if train.camera_mode=="walk": train._update_camera()
    elif virtual_wait and train.camera_mode=="flight":
        var axis: Vector2=train._flight_ui.stick
        var view:=Basis.from_euler(Vector3(-train.orbit_pitch,train.orbit_yaw,0))
        train.flight_position+=(view.x*axis.x+view.z*axis.y)*train.CAMERA_MOVE_SPEED*_delta
        train._update_camera()

func _hold_cab() -> void:
    train.info_binding.applying_auto_input=true
    train.cab_runtime.command("master",-1.0)
    train.info_binding.applying_auto_input=false
