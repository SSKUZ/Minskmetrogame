extends Node
const Player = preload("res://modules/gameplay/player_controller.gd")
const Interaction = preload("res://modules/gameplay/player_interaction.gd")
const Automatic = preload("res://modules/gameplay/automatic_service.gd")
const UI = preload("res://modules/gameplay/gameplay_ui.gd")
const Geometry = preload("res://modules/gameplay/world_geometry.gd")
const WalkLite = preload("res://modules/gameplay/walk_lite.gd")
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
var direct_driver:=false
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
var _geometry=WalkLite.new()
var _near_busy:=false
var _near_clock:=0.0
var _near_error:=""
var startup_state:="INITIALIZING_WORLD"
var startup_component:=""
var _stage_deadline:=0
var _attempt:=0

func initialize(world: Node3D) -> void:
    line=world
    train=line.train
    rules=JSON.parse_string(FileAccess.get_file_as_string("res://modules/gameplay/gameplay_rules.json"))
    timetable=VirtualService.new()
    timetable.initialize(self)
    interaction=Interaction.new()
    add_child(interaction)
    interaction.initialize(self)
    automatic=Automatic.new()
    add_child(automatic)
    automatic.initialize(self)
    ui=UI.new()
    add_child(ui)
    ui.initialize(self)
    line.streamer.loading_changed.connect(func(message: String):
        if _starting and role=="passenger" and not message.is_empty():
            ui.load_text.text=startup_component+"\n"+message)
    train.info_binding._button.hide()
    _legacy_ui(false)

func _prepare() -> void:
    if direct_driver or not is_instance_valid(player): return
    if _cab_busy or _cab_ready: return
    _cab_busy=true
    var access=CabAccess.new()
    interaction.cab_points=access.prepare_points(train.train)
    _cab_ready=interaction.cab_points.size()==2
    _cab_error=access.error_message
    if not _cab_ready and _cab_error.is_empty():
        _cab_error="Не удалось подготовить обе точки доступа в кабину"
    _cab_busy=false
    if running and not _cab_error.is_empty(): ui.notice(_cab_error)
    line._start_service_if_ready()


func _ensure_player() -> void:
    if not is_instance_valid(player):
        player=Player.new()
        line.add_child(player)
        player.initialize(self,rules.walking)
    if not player.is_in_group("metro_player"): player.add_to_group("metro_player")
    player.show()

func _park_player() -> void:
    if not is_instance_valid(player): return
    if not interaction.seat.is_empty():
        line.passengers.layout.release(interaction.seat)
        interaction.seat={}
    player.seated=false
    player.active=false
    player.stick=Vector2.ZERO
    player.velocity=Vector3.ZERO
    player.capsule.set_deferred("disabled",true)
    if is_instance_valid(player.aboard): player.attach_car(null)
    if player.is_in_group("metro_player"): player.remove_from_group("metro_player")
    player.hide()

func _activate_direct_driver() -> void:
    direct_driver=true
    role="driver"
    driver_seated=true
    virtual_wait=false
    _park_player()
    line.streamer.register_player(null)
    _absence_started=false
    _absence_armed=false
    _absence=0.0
    _notice_sent=false
    ui.warning.hide()
    _legacy_ui(true)
    train._ui_layer.show()
    train._set_camera_mode("cabin")
    train.camera.make_current()
    set_meta("portable_driver_start",{"car":"OriginalV106Car01","workplace":"OriginalCabIntegration",
        "route_spawn_z":train.spawn_z,"camera":"cabin","control_owner":"driver","physical_character":false})

func _start_direct_driver() -> void:
    _stage("ACTIVATING_CONTROLS","Включение существующей кабины и пульта V106")
    line.streamer.clear_startup_target()
    line.show()
    train.show()
    train.train.show()
    (line.get_node("OperatingDepot") as Node3D).show()
    for car in line.passengers.layout.cars: car.show()
    # The existing train already owns its authored depot spawn/route placement.
    # Change authority once at startup; camera switches never repeat this.
    timetable.cancel()
    automatic.disable()
    _set_automatic(false)
    _hold_cab()
    # Instant cab access does not operate passenger-door geometry.
    _activate_direct_driver()
    if not train.camera.is_current() or not ui.activate_play():
        _start_failed("Не удалось включить камеру или интерфейс кабины")
        return
    prepared=true
    running=true
    _starting=false
    startup_state="READY"
    startup_component=""
    line._start_service_if_ready()

func _driver_to_passenger() -> void:
    var index: int=station_at_train()
    if index<0:
        ui.notice("Режим пассажира доступен после остановки на готовой станции")
        return
    if _respawning: return
    _respawning=true
    _ensure_player()
    if not await _geometry.prepare_region(line.station_instance(index),platform_spawn(index),float(rules.startup.local_radius)):
        _park_player()
        _respawning=false
        ui.notice(_geometry.error_message)
        return
    if not _geometry.prepare_train(self):
        _park_player()
        _respawning=false
        ui.notice(_geometry.error_message)
        return
    await get_tree().physics_frame
    var spawn: Vector3=_safe_platform_spawn(index,platform_spawn(index))
    if not is_finite(spawn.y):
        _park_player()
        _respawning=false
        ui.notice("Безопасная точка платформы пока недоступна")
        return
    var demand: float=float(train.cab_runtime.controller_value)
    if train.brake: demand=-1.0
    elif train.throttle and demand>=0.0: demand=1.0
    direct_driver=false
    driver_seated=false
    role="passenger"
    _absence_started=false
    _absence_armed=false
    _safe_station=index
    _legacy_ui(false)
    player.spawn_at(spawn)
    train.activate_character_view(player.eye)
    ui.activate_play()
    line.streamer.register_player(player)
    _set_automatic(true)
    automatic.enable(demand)
    # Cab access points are optional legacy interaction data, not a startup task.
    _respawning=false
    ui.notice("Режим пассажира · управление передано автоматике")

func walk_action() -> void:
    if role!="driver":
        interaction.exit_cab()
        return
    if not direct_driver:
        if absf(train.speed)>0.05 or station_at_train()<0:
            ui.notice("Вернуться за пульт можно после остановки на станции")
            return
        _hold_cab()
        _activate_direct_driver()
        ui.activate_play()
        return
    var index: int=station_at_train()
    if index<0:
        ui.notice("Пеший осмотр доступен только на станции после остановки")
        return
    if _respawning: return
    _respawning=true
    _ensure_player()
    if not await _geometry.prepare_region(line.station_instance(index),platform_spawn(index),float(rules.startup.local_radius)):
        _park_player()
        _respawning=false
        ui.notice(_geometry.error_message)
        return
    _geometry.prepare_train(self)
    await get_tree().physics_frame
    var spawn: Vector3=_safe_platform_spawn(index,platform_spawn(index))
    if not is_finite(spawn.y):
        _park_player()
        _respawning=false
        ui.notice("Нет свободного безопасного места на платформе")
        return
    _hold_cab()
    direct_driver=false
    driver_seated=false
    _safe_station=index
    _absence_armed=true
    _absence_started=true
    _absence=0.0
    _notice_sent=false
    _warning_at=float(rules.absence.warning)
    _legacy_ui(false)
    player.spawn_at(spawn)
    train.activate_character_view(player.eye)
    line.streamer.register_player(player)
    ui.activate_play()
    _respawning=false

func first_car() -> Node3D:
    var cars: Array=line.passengers.layout.cars
    return cars[0] if not cars.is_empty() else null

func _wait_ready(condition: Callable, stage: String, failure: Callable=Callable()) -> bool:
    var attempt: int=_attempt
    _stage("LOADING_REQUIRED_MODULES",stage)
    var deadline: int=Time.get_ticks_msec()+int(float(rules.startup.wait_seconds)*1000.0)
    while not condition.call():
        if not is_inside_tree() or attempt!=_attempt or startup_state=="ERROR": return false
        if failure.is_valid():
            var problem: String=str(failure.call())
            if not problem.is_empty():
                _start_failed(problem)
                return false
        if Time.get_ticks_msec()>=deadline:
            _start_failed(stage+" · операция не завершена. Можно повторить ожидание.")
            return false
        await get_tree().process_frame
    return true

func _start_failed(reason: String) -> void:
    startup_state="ERROR"
    _attempt+=1
    running=false
    train.service_ready=false
    if direct_driver:
        driver_seated=false
        _legacy_ui(false)
    prepared=false
    _starting=false
    if is_instance_valid(player):
        player.active=false
        player.capsule.set_deferred("disabled",true)
    ui.start_failed(startup_component+"\n"+reason)
    push_error("Gameplay startup: "+reason)

func _stage(state: String, component: String) -> void:
    startup_state=state
    startup_component=component
    _stage_deadline=Time.get_ticks_msec()+int(float(rules.startup.wait_seconds)*1000.0)
    ui.loading(component)

func _world_error() -> String:
    if role=="driver" and not is_instance_valid(line.get_node_or_null("OperatingDepot")): return "Не загружен модуль депо"
    if not is_instance_valid(train.train): return "Не создан состав V106"
    for index in range(1,5):
        if not is_instance_valid(train.train.get_node_or_null("OriginalV106Car%02d" % index)):
            return "Не создан вагон V106 №%d" % index
    if not is_instance_valid(train.camera): return "Не создана игровая камера"
    if role=="driver" and (not is_instance_valid(train.cab_runtime) or not train.cab_runtime.ready_for_play): return "Не готова кабина 81-717"
    if not is_instance_valid(train.door_system) or not train.door_system.validated: return "Не готова система дверей V106"
    if not is_instance_valid(train.info_binding) or not is_instance_valid(train.info_binding.audio): return "Не готов информатор состава"
    if not is_instance_valid(train._flight_ui): return "Не создано штатное управление составом"
    return ""

func retry_start() -> void:
    if _starting or running: return
    if role=="passenger": line.streamer.retry_station(start_station)
    start_role(role,start_station)

func start_role(selected_role: String, station_index: int) -> void:
    if _starting or running: return
    if selected_role not in ["driver","passenger"]: return
    _starting=true
    _attempt+=1
    var attempt: int=_attempt
    prepared=false
    role=selected_role
    _stage("INITIALIZING_WORLD","Подготовка существующего игрового мира")
    if selected_role=="passenger" and (station_index<0 or station_index>=line.stations.size()):
        _start_failed("Выберите станцию и подтвердите начало игры")
        return
    start_station=station_index if role=="passenger" else 0
    var problem: String=_world_error()
    if not problem.is_empty():
        _start_failed(problem)
        return
    if role=="driver":
        _start_direct_driver()
        return
    direct_driver=false
    _ensure_player()
    var spawn: Vector3
    _safe_station=start_station
    # Pin the requested station before its asynchronous download; depot and
    # remote tunnel readiness are not prerequisites for a platform spawn.
    line.streamer.set_startup_target(start_station)
    _retire_train(true)
    player.global_position=Vector3(-5.37,1.25,float(line.stations[start_station].root_z)+40.0)
    train.camera_mode="walk"
    train._update_camera()
    train.camera.global_position=player.global_position+Vector3.UP*float(rules.walking.eye_height)
    line.streamer.register_player(player)
    line.streamer.retry_station(start_station)
    var stage: String="Загрузка платформы: "+str(line.stations[start_station].module_id)
    if not await _wait_ready(func(): return line.streamer.is_loaded(start_station) and line.passengers.platform_navigation_ready(start_station),stage,func(): return line.streamer.station_error(start_station)): return
    if attempt!=_attempt or not _starting: return
    _stage("PREPARING_SPAWN","Выбор безопасного места на платформе")
    spawn=platform_spawn(start_station)
    _stage("PREPARING_SPAWN","Подготовка лёгких ограничителей зоны появления")
    if not await _geometry.prepare_region(line.station_instance(start_station),spawn,float(rules.startup.local_radius)):
        _start_failed(_geometry.error_message)
        return
    if not _geometry.prepare_train(self):
        _start_failed(_geometry.error_message)
        return
    await get_tree().physics_frame
    if attempt!=_attempt or not _starting: return
    spawn=_safe_platform_spawn(start_station,spawn)
    if not is_finite(spawn.y):
        _start_failed("На выбранной платформе отсутствует готовая поверхность")
        return
    _set_automatic(true)
    timetable.schedule(start_station)
    if not is_inside_tree() or attempt!=_attempt or not _starting: return
    _stage("ACTIVATING_PLAYER","Включение персонажа и камеры")
    player.spawn_at(spawn)
    if not train.activate_character_view(player.eye):
        _start_failed("Не удалось назначить камеру персонажа")
        return
    _stage("ACTIVATING_CONTROLS","Включение мобильного управления")
    if not ui.activate_play():
        _start_failed("Не удалось разместить мобильное управление")
        return
    prepared=true
    running=true
    _starting=false
    startup_state="READY"
    startup_component=""
    line.streamer.clear_startup_target()
    line.streamer.register_player(player)
    line._start_service_if_ready()
    _near_clock=0.0
    # Cab access points are optional legacy interaction data, not a startup task.


func walking_area_ready(point: Vector3) -> bool:
    if direct_driver or not is_instance_valid(player) or point.z>96.0: return false
    if is_instance_valid(player.aboard): return _geometry.covers(player.aboard,point)
    for record in line.stations:
        var station: Node3D=line.station_instance(int(record.index))
        if _geometry.covers(station,point): return true
    return false

func request_walk_area() -> void:
    if direct_driver or not is_instance_valid(player) or not player.active or player.global_position.z>96.0: return
    if _near_busy or not running: return
    _near_busy=true
    call_deferred("_prepare_walk_area")

func _prepare_walk_area() -> void:
    if direct_driver or not is_instance_valid(player) or not player.active:
        _near_busy=false
        return
    var point: Vector3=player.global_position
    for record in line.stations:
        var station: Node3D=line.station_instance(int(record.index))
        if not is_instance_valid(station) or absf(point.z-float(record.stop_z))>160.0: continue
        if not _geometry.covers(station,point,float(rules.startup.prefetch_margin)):
            if not await _geometry.prepare_region(station,point,float(rules.startup.local_radius)):
                ui.notice(_geometry.error_message)
    _geometry.prepare_train(self)
    _near_busy=false

func platform_spawn(index: int) -> Vector3:
    var nav=line.passengers._platforms[index].navigation
    var area: Rect2=nav.platform
    return nav.free_point(Vector3(area.get_center().x,float(nav.height),area.get_center().y))

func _ground(point: Vector3) -> Vector3:
    var query:=PhysicsRayQueryParameters3D.create(point,point-Vector3.UP*6.0,Geometry.WORLD)
    var hit: Dictionary=line.get_world_3d().direct_space_state.intersect_ray(query)
    return hit.position if not hit.is_empty() else Vector3(point.x,NAN,point.z)

func _safe_spawn(point: Vector3, expected_height: float=NAN) -> Vector3:
    var floor: Vector3=_ground(point)
    if not is_finite(floor.y): return floor
    if is_finite(expected_height) and absf(floor.y-expected_height)>0.25: return Vector3(point.x,NAN,point.z)
    var query:=PhysicsShapeQueryParameters3D.new()
    query.shape=player.capsule.shape
    query.transform=Transform3D(Basis.IDENTITY,floor+Vector3.UP*(float(rules.walking.height)*0.5+0.06))
    query.collision_mask=player.collision_mask
    query.exclude=[player.get_rid()]
    if not line.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
        return Vector3(point.x,NAN,point.z)
    return floor

func _safe_platform_spawn(index: int, preferred: Vector3) -> Vector3:
    var nav=line.passengers._platforms[index].navigation
    var first: Vector3=_safe_spawn(preferred+Vector3.UP,float(nav.height))
    if is_finite(first.y): return first
    var area: Rect2=nav.platform
    for x in [0.25,0.5,0.75]:
        for z in [0.2,0.35,0.5,0.65,0.8]:
            var point:=Vector3(area.position.x+area.size.x*float(x),float(nav.height)+1.0,area.position.y+area.size.y*float(z))
            var candidate: Vector3=_safe_spawn(point,float(nav.height))
            if is_finite(candidate.y): return candidate
    return Vector3(preferred.x,NAN,preferred.z)

func occupy_driver() -> void:
    if not is_instance_valid(player) or role!="driver" or driver_seated or absf(train.speed)>0.05 or player.aboard!=first_car(): return
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
    if direct_driver:
        walk_action()
        return
    if not driver_seated:
        if running: train._set_camera_mode("walk")
        return
    driver_seated=false
    train.cab_runtime.cancel_interaction()
    if is_instance_valid(train._flight_ui): train._flight_ui._release_pointer()
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
        timetable.cancel()
        automatic.disable()
        _set_automatic(false)
        _hold_cab()
        _activate_direct_driver()
        ui.notice("Управление передано машинисту")
    else:
        if direct_driver:
            _driver_to_passenger()
            return
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
    if is_instance_valid(train._flight_ui): train._flight_ui._release_pointer()

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
    if is_instance_valid(player):
        interaction.guard_doors()
        if player.active: _geometry.update_doors(self)
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
    if not direct_driver and is_instance_valid(player) and player.active and not is_instance_valid(player.aboard):
        var record: Dictionary=line.path.nearest_station(player.global_position.z)
        var index: int=int(record.index)
        if line.passengers.platform_ready(index):
            var nav=line.passengers._platforms[index].navigation
            if nav.platform_area.has_point(Vector2(player.global_position.x,player.global_position.z)) and absf(player.global_position.y-float(nav.height))<0.5: _safe_station=index
    if role=="passenger" and is_instance_valid(player) and player.active: timetable.update()

func _retire_train(initial: bool=false) -> void:
    if is_instance_valid(player) and is_instance_valid(player.aboard): return
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
    if direct_driver or not is_instance_valid(player): return
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
    var deadline: int=Time.get_ticks_msec()+int(float(rules.startup.wait_seconds)*1000.0)
    while not line.passengers.platform_navigation_ready(_safe_station):
        await get_tree().process_frame
        if not is_inside_tree(): return
        var error: String=line.streamer.station_error(_safe_station)
        if not error.is_empty() or Time.get_ticks_msec()>deadline:
            _respawning=false
            _start_failed(error if not error.is_empty() else "Не готова платформа возрождения")
            return
    if not await _geometry.prepare_region(line.station_instance(_safe_station),platform_spawn(_safe_station),float(rules.startup.local_radius)):
        _respawning=false
        _start_failed(_geometry.error_message)
        return
    await get_tree().physics_frame
    player.eye.position.y=float(rules.walking.eye_height)
    var safe: Vector3=_safe_platform_spawn(_safe_station,platform_spawn(_safe_station))
    if not is_finite(safe.y):
        _respawning=false
        _start_failed("Нет безопасной поверхности возрождения")
        return
    player.spawn_at(safe)
    train._set_camera_mode("walk")
    _respawning=false

func _process(_delta: float) -> void:
    if _starting and Time.get_ticks_msec()>=_stage_deadline:
        _start_failed("Операция прервалась или не завершилась; доступен повтор")
    if not running: return
    line._start_service_if_ready()
    _near_clock-=_delta
    if not direct_driver and is_instance_valid(player) and player.active and _near_clock<=0.0:
        _near_clock=float(rules.startup.refresh_seconds)
        request_walk_area()
    if train.camera_mode=="walk": train._update_camera()
    elif (virtual_wait or (direct_driver and not train.service_ready)) and train.camera_mode=="flight":
        var axis: Vector2=train._flight_ui.stick
        var view:=Basis.from_euler(Vector3(-train.orbit_pitch,train.orbit_yaw,0))
        train.flight_position+=(view.x*axis.x+view.z*axis.y)*train.CAMERA_MOVE_SPEED*_delta
        train._update_camera()

func _hold_cab() -> void:
    train.info_binding.applying_auto_input=true
    train.cab_runtime.command("master",-1.0)
    train.info_binding.applying_auto_input=false
