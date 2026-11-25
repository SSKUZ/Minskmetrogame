extends Node
const Player = preload("res://modules/gameplay/player_controller.gd")
const Interaction = preload("res://modules/gameplay/player_interaction.gd")
const Automatic = preload("res://modules/gameplay/automatic_service.gd")
const UI = preload("res://modules/gameplay/gameplay_ui.gd")
const Geometry = preload("res://modules/gameplay/world_geometry.gd")
const CabAccess = preload("res://modules/gameplay/cab_access.gd")
const VirtualService = preload("res://modules/gameplay/virtual_train_service.gd")
var line: Node3D
var train: Node3D
var player: CharacterBody3D
var interaction: Node
var automatic: Node
var ui: CanvasLayer
var timetable: RefCounted
var rules: Dictionary
var role:="driver"
var running:=false
var driver_seated:=false
var prepared:=false
var virtual_wait:=false
var _starting:=false
var start_station:=0
var _absence_started:=false
var _absence_armed:=false
var _absence:=0.0
var _notice_sent:=false
var _warning_at:=180.0
var _safe_station:=0
var _respawning:=false
var _cab_ready:=false
var _cab_busy:=false
var _cab_error:=""
var _geometry=Geometry.new()
var _near_busy:=false
var _near_clock:=0.0
var _near_error:=""

func initialize(world: Node3D) -> void:
    line=world
    train=line.train
    rules=JSON.parse_string(FileAccess.get_file_as_string("res://modules/gameplay/gameplay_rules.json"))
    timetable=VirtualService.new()
    timetable.initialize(self)
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
    if _cab_busy or _cab_ready: return
    _cab_busy=true
    _cab_error=""
    var car: Node3D=first_car()
    if car==null or not is_instance_valid(train.cab_runtime):
        _cab_error="Отсутствует состав или кабина V106"
        _cab_busy=false
        return
    var access=CabAccess.new()
    interaction.cab_doors=await access.prepare(car,train.cab_runtime,rules.cab_access)
    _cab_ready=not interaction.cab_doors.is_empty()
    if not _cab_ready: _cab_error="Не найдены доступные двери кабины V106"
    _cab_busy=false
    line._start_service_if_ready()

func first_car() -> Node3D:
    var cars: Array=line.passengers.layout.cars
    return cars[0] if not cars.is_empty() else null

func _wait_ready(condition: Callable, stage: String) -> bool:
    ui.loading(stage)
    var deadline: int=Time.get_ticks_msec()+int(float(rules.startup.wait_seconds)*1000.0)
    while not condition.call():
        if not is_inside_tree(): return false
        if Time.get_ticks_msec()>=deadline:
            _start_failed(stage+" · операция не завершена. Можно повторить ожидание.")
            return false
        await get_tree().process_frame
    return true

func _start_failed(reason: String) -> void:
    prepared=false
    _starting=false
    player.active=false
    player.capsule.set_deferred("disabled",true)
    ui.start_failed(reason)
    push_error("Gameplay startup: "+reason)

func retry_start() -> void:
    if _starting or running: return
    if role=="passenger": line.streamer.retry_station(start_station)
    if not _cab_ready and not _cab_busy:
        _cab_error=""
        call_deferred("_prepare")
    start_role(role,start_station)

func start_role(selected_role: String, station_index: int) -> void:
    if _starting or running: return
    if selected_role not in ["driver","passenger"]: return
    _starting=true
    prepared=false
    role=selected_role
    start_station=clampi(station_index,0,line.stations.size()-1) if role=="passenger" else 0
    ui.loading("Подготовка места появления")
    var spawn: Vector3
    if role=="driver":
        virtual_wait=false
        train.train.show()
        _train_collisions(true)
        if not _cab_ready and not _cab_busy:
            _cab_error=""
            call_deferred("_prepare")
        if not await _wait_ready(func(): return _cab_ready or not _cab_error.is_empty(),"Подготовка дверей кабины V106"): return
        if not _cab_error.is_empty():
            _start_failed(_cab_error)
            return
        var car: Node3D=first_car()
        if car==null:
            _start_failed("Не найден головной вагон V106")
            return
        var local: Vector3=interaction.cab_doors[0].threshold
        var point: Vector3=car.to_global(local+Vector3(-1.4,0,0))
        point.y=8.5
        var depot:=line.get_node_or_null("OperatingDepot") as Node3D
        if depot==null:
            _start_failed("Не найдено существующее депо")
            return
        ui.loading("Подготовка пола и препятствий возле состава")
        if not await _geometry.prepare_near(depot,point,float(rules.startup.local_radius)):
            _start_failed(_geometry.error_message)
            return
        car.add_to_group("metro_walking_train")
        ui.loading("Подготовка ближайшей части вагона и дверей")
        if not await _geometry.prepare_near(car,point,float(rules.startup.local_radius)):
            _start_failed(_geometry.error_message)
            return
        await get_tree().physics_frame
        spawn=_ground(point)
        if not is_finite(spawn.y):
            _start_failed("В зоне появления машиниста нет готовой поверхности депо")
            return
        train.door_system.request_close()
        _set_automatic(false)
        _hold_cab()
    else:
        _safe_station=start_station
        # Pin the requested station before its asynchronous download; depot and
        # remote tunnel readiness are not prerequisites for a platform spawn.
        _retire_train(true)
        player.global_position=Vector3(-5.37,1.25,float(line.stations[start_station].root_z)+40.0)
        train.camera_mode="walk"
        train._update_camera()
        train.camera.global_position=player.global_position+Vector3.UP*float(rules.walking.eye_height)
        line.streamer.register_player(player)
        line.streamer.retry_station(start_station)
        var stage: String="Загрузка платформы: "+str(line.stations[start_station].module_id)
        if not await _wait_ready(func(): return line.passengers.platform_ready(start_station),stage): return
        spawn=platform_spawn(start_station)
        await get_tree().physics_frame
        spawn=_ground(spawn+Vector3.UP*1.0)
        if not is_finite(spawn.y):
            _start_failed("На выбранной платформе отсутствует готовая поверхность")
            return
        _set_automatic(true)
        timetable.schedule(start_station)
    if not is_inside_tree(): return
    # Actual floor and capsule clearance are mandatory; no timer sets readiness.
    var query:=PhysicsShapeQueryParameters3D.new()
    query.shape=player.capsule.shape
    query.transform=Transform3D(Basis.IDENTITY,spawn+Vector3.UP*(float(rules.walking.height)*0.5+0.06))
    query.collision_mask=player.collision_mask
    query.exclude=[player.get_rid()]
    if not line.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
        _start_failed("Место появления занято физическим препятствием")
        return
    player.spawn_at(spawn)
    prepared=true
    running=true
    _starting=false
    line.streamer.register_player(player)
    train._set_camera_mode("walk")
    train.camera.make_current()
    ui.set_play_visible(true)
    line._start_service_if_ready()
    _near_clock=0.0


func walking_area_ready(point: Vector3) -> bool:
    if point.z>96.0:
        var depot:=line.get_node_or_null("OperatingDepot") as Node3D
        if not _geometry.covers(depot,point,1.0): return false
    for car in line.passengers.layout.cars:
        var box: AABB=train._pose_cache.get(car,AABB())
        if box.grow(0.4).has_point(car.to_local(point)):
            if not _cab_ready or not _geometry.covers(car,point,1.0): return false
    return true

func request_walk_area() -> void:
    if _near_busy or not running: return
    _near_busy=true
    call_deferred("_prepare_walk_area")

func _prepare_walk_area() -> void:
    var point: Vector3=player.global_position
    _near_error=""
    if point.z>96.0:
        var depot:=line.get_node_or_null("OperatingDepot") as Node3D
        if not _geometry.covers(depot,point,float(rules.startup.prefetch_margin)):
            if not await _geometry.prepare_near(depot,point,float(rules.startup.local_radius)): _near_error=_geometry.error_message
    if _cab_ready and train.train.visible:
        for car in line.passengers.layout.cars:
            if not is_inside_tree(): return
            var box: AABB=train._pose_cache.get(car,AABB())
            if not box.grow(20.0).has_point(car.to_local(point)): continue
            if _geometry.covers(car,point,float(rules.startup.prefetch_margin)): continue
            car.add_to_group("metro_walking_train")
            if not await _geometry.prepare_near(car,point,float(rules.startup.local_radius)): _near_error=_geometry.error_message
    _near_busy=false
    if not _near_error.is_empty(): ui.notice(_near_error+" · подготовка будет повторена")


func platform_spawn(index: int) -> Vector3:
    var nav=line.passengers._platforms[index].navigation
    var area: Rect2=nav.platform
    return nav.free_point(Vector3(area.get_center().x,float(nav.height),area.get_center().y))

func _ground(point: Vector3) -> Vector3:
    var query:=PhysicsRayQueryParameters3D.create(point,point-Vector3.UP*6.0,Geometry.WORLD)
    var hit: Dictionary=line.get_world_3d().direct_space_state.intersect_ray(query)
    return hit.position if not hit.is_empty() else Vector3(point.x,NAN,point.z)

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
    if not running or _respawning or next_role==role or next_role not in ["driver","passenger"]: return
    if next_role=="driver":
        if virtual_wait or absf(train.speed)>0.05 or station_at_train()<0:
            ui.notice("Принять управление можно после остановки поезда на станции")
            return
        # A distant train is not remotely claimable from another platform.
        if not is_instance_valid(player.aboard) and absf(player.global_position.z-float(train.distance))>150.0:
            ui.notice("Подойдите к прибывшему составу")
            return
        role="driver"
        timetable.cancel()
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
        # Preserve the demand that the original cab was applying before its
        # screen controls are released. Applied brake pressure is never reset.
        var demand: float=float(train.cab_runtime.controller_value)
        if train.brake: demand=-1.0
        elif train.throttle and demand>=0.0: demand=1.0
        if driver_seated: leave_driver(true)
        role="passenger"
        _absence_started=false
        _absence_armed=false
        ui.warning.hide()
        _set_automatic(true)
        automatic.enable(demand)
        ui.notice("Управление передано автоматике. Стоянка — около 30 секунд.")

func _set_automatic(enabled: bool) -> void:
    var binding: Node=train.info_binding
    binding.passenger_mode=enabled
    binding.audio.info.set_mode("auto" if enabled else "manual")
    train.throttle=false
    train.brake=false
    train.cab_runtime.cancel_interaction()
    train._flight_ui._release_pointer()

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
    if role=="passenger" and _cab_ready: timetable.update()

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
        if body.has_meta("metro_native_walk"): body.collision_layer=Geometry.TRAIN if enabled else 0

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
    line._start_service_if_ready()
    _near_clock-=_delta
    if _near_clock<=0.0:
        _near_clock=float(rules.startup.refresh_seconds)
        request_walk_area()
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
