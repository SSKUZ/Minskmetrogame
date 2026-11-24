extends Node
class_name MetroAudioSystem
## One audio owner, native Godot players only. Retired spatial controllers are not created.
const Resources = preload("res://audio/audio_resources.gd")
const Train = preload("res://audio/controllers/train_audio_controller.gd")
const Effects = preload("res://audio/simple_effects.gd")
const Cab = preload("res://audio/controllers/cab_audio_controller.gd")
const Doors = preload("res://audio/controllers/door_audio_controller.gd")
const Announcer = preload("res://audio/metro_announcer.gd")
const Info = preload("res://audio/controllers/info_controller.gd")
var bank: MetroAudioResources
var train_audio: MetroTrainAudioController
var effects: Node
var cab_audio: MetroCabAudioController
var door_audio: MetroDoorAudioController
var announcer: MetroAnnouncer
var info: MetroInfoController
var _game: Node3D
var _world: Node
var _cab: Node3D
var _train: Node3D
var _profiles: Dictionary={}
var _listener_mode: String=""
var _last_volume: float=-1.0
var _ready_for_audio: bool=false
var _door_values: Dictionary={}
var _last_speed: float=0.0
var _motion_sampled: bool=false

func _ready() -> void:
    bank=Resources.new()
    announcer=Announcer.new()
    announcer.name="Announcer"
    announcer.bank=bank
    add_child(announcer)
    train_audio=Train.new()
    train_audio.bank=bank
    add_child(train_audio)
    effects=Effects.new()
    effects.bank=bank
    add_child(effects)
    cab_audio=Cab.new()
    cab_audio.effects=effects
    add_child(cab_audio)
    door_audio=Doors.new()
    door_audio.effects=effects
    add_child(door_audio)
    info=Info.new()
    add_child(info)
    info.bind(announcer)

func load_catalog(path: String) -> bool:
    var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
    if not value is Dictionary: return false
    var catalog: Dictionary=value
    var engine: Dictionary=catalog.get("simple_audio",{})
    _profiles=engine.get("perspectives",{})
    _ready_for_audio=bank.configure(catalog)
    announcer.configure_routes(catalog.get("route_events",{}))
    var notices: Array[String]=[]
    for id in catalog.get("service_notice_events",[]): notices.append(str(id))
    info.configure_service_events(notices)
    train_audio.configure_states(engine.get("train_states",{}),float(engine.get("crossfade_seconds",0.35)))
    effects.configure(engine.get("effects",{}))
    return _ready_for_audio

func bind_game(game: Node3D, world: Node) -> void:
    _disconnect_cab()
    _game=game
    _door_values.clear()
    _motion_sampled=false
    _last_volume=-1.0
    _world=world
    _train=game.get("train") as Node3D
    _cab=game.get("cab_runtime") as Node3D
    if is_instance_valid(_cab):
        cab_audio.sync_switches(_cab.get("switches"),int(_cab.get("controller_notch")))
        if _cab.has_signal("audio_control_used"):
            _cab.connect("audio_control_used",_on_cab_control)
    var doors: Node=game.get("door_system") as Node
    if is_instance_valid(doors):
        var sides: Dictionary=doors.get("side_open")
        for side in sides:
            var id: String="side_"+str(side)
            var openness: float=float(sides[side])
            door_audio.register_door(id,_train,openness)
            _door_values[id]=openness

func bind_origins(train_origin: Node3D, cab_origin: Node3D, _station_origin: Node3D) -> void:
    _train=train_origin
    _cab=cab_origin

func set_master_volume(value: float) -> void:
    var volume: float=clampf(value,0.0,1.0)
    bank.master_volume=volume
    train_audio.master_volume=volume
    effects.master_volume=volume
    effects.refresh_gains()
    announcer.set_master_volume(volume)

func set_listener_mode(mode: String) -> void:
    # Free camera is resolved from its actual position, never a fourth mix preset.
    var effective: String=_free_camera_mode() if mode in ["free","flight"] else "cab" if mode=="cabin" else mode
    if effective not in ["cab","salon","platform"]: effective="platform"
    if effective==_listener_mode: return
    _listener_mode=effective
    train_audio.perspective_db=float(_profiles.get(effective,{}).get("train_db",0.0))
    effects.listener_mode=effective
    effects.refresh_gains()

func _free_camera_mode() -> String:
    var camera: Camera3D=get_viewport().get_camera_3d()
    if camera==null or not is_instance_valid(_train) or not is_instance_valid(_game): return "platform"
    var local: Vector3=_train.to_local(camera.global_position)
    var bounds: AABB=_game.get("_train_bounds")
    if not bounds.grow(0.25).has_point(local): return "platform"
    if is_instance_valid(_cab) and camera.global_position.distance_to(_cab.global_position)<4.0: return "cab"
    return "salon"

func _process(delta: float) -> void:
    if not _ready_for_audio or not is_instance_valid(_game) or not is_instance_valid(_cab): return
    var speed: float=absf(float(_game.get("speed")))
    var acceleration: float=(speed-_last_speed)/maxf(0.001,delta) if _motion_sampled else 0.0
    _last_speed=speed
    _motion_sampled=true
    train_audio.set_state(speed,acceleration,
        float(_cab.get("traction_actual")),float(_cab.get("applied_brake")),float(_cab.get("voltage_kv"))>0.01,int(_cab.get("direction")))
    cab_audio.set_controller_notch(int(_cab.get("controller_notch")))
    var switches: Dictionary=_cab.get("switches")
    for id in switches: cab_audio.set_switch(str(id),bool(switches[id]))
    var volume: float=float(_cab.get("volume"))
    if volume!=_last_volume:
        set_master_volume(volume)
        _last_volume=volume
    var doors: Node=_game.get("door_system") as Node
    if is_instance_valid(doors):
        var sides: Dictionary=doors.get("side_open")
        for side in sides:
            var id: String="side_"+str(side)
            var openness: float=float(sides[side])
            if openness!=float(_door_values.get(id,-1.0)):
                door_audio.update_openness(id,openness)
                _door_values[id]=openness
    var camera_mode: String=str(_game.get("camera_mode"))
    set_listener_mode("salon" if camera_mode=="salon" else "cab" if camera_mode=="cabin" else "platform" if camera_mode in ["platform","external"] else "free")
    train_audio.distance_gain=_platform_distance_gain() if _listener_mode=="platform" else 1.0
    effects.train_distance_gain=train_audio.distance_gain
    effects.refresh_gains()
    train_audio.duck_gain=move_toward(train_audio.duck_gain,0.65 if announcer.is_busy() else 1.0,delta*3.0)
    var manager: Node=_world.get("passengers") as Node if is_instance_valid(_world) else null
    effects.observe_passengers(delta,manager,get_viewport().get_camera_3d())

func _platform_distance_gain() -> float:
    var camera: Camera3D=get_viewport().get_camera_3d()
    if camera==null or not is_instance_valid(_train): return 0.0
    var point: Vector3=_train.to_local(camera.global_position)
    var bounds: AABB=_game.get("_train_bounds")
    var closest: Vector3=Vector3(clampf(point.x,bounds.position.x,bounds.end.x),clampf(point.y,bounds.position.y,bounds.end.y),clampf(point.z,bounds.position.z,bounds.end.z))
    return 1.0/(1.0+pow(point.distance_to(closest)/28.0,2.0))

func _on_cab_control(id: String, phase: String) -> void:
    if phase=="release" or id in ["master","tractionUp","tractionDown","reverse","horn","volume"]: return
    if (_cab.get("switches") as Dictionary).has(id): return
    cab_audio.press_button(id)

func route_announcement(station_id: String, phase: String, direction: String, visit_id: String) -> void:
    if info.mode!=MetroInfoController.AUTO: return
    if station_id.is_empty() or visit_id.is_empty(): return
    if phase==MetroInfoController.ARRIVAL:
        info.set_route_context(station_id,info.next_station_id,direction,visit_id)
        info.on_auto_approach()
    elif phase==MetroInfoController.DEPARTURE:
        info.set_route_context(info.station_id,station_id,direction,visit_id)
        info.on_auto_departure()

func _disconnect_cab() -> void:
    if is_instance_valid(_cab) and _cab.is_connected("audio_control_used",_on_cab_control):
        _cab.disconnect("audio_control_used",_on_cab_control)

func _exit_tree() -> void:
    _disconnect_cab()
    if is_instance_valid(announcer): announcer.stop_all()
    if is_instance_valid(train_audio): train_audio.stop_layers()
    if is_instance_valid(effects): effects.stop_all()
