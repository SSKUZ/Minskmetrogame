extends Node
class_name MetroV106AudioAdapter
## Compatibility bridge for callers outside the line; no players or old engine.
var system: MetroAudioSystem
var _cab: Node3D

func bind(audio_system: MetroAudioSystem, train_origin: Node3D, cab_origin: Node3D, station_origin: Node3D, _speakers: Array[Node3D], _axles: Array[float], _motors: Array[Node3D]=[], _axle_origins: Array[Node3D]=[]) -> void:
    system=audio_system
    _cab=cab_origin
    if is_instance_valid(system): system.bind_origins(train_origin,cab_origin,station_origin)

func unbind() -> void:
    system=null
    _cab=null

func update_motion(_distance: float, speed: float, acceleration: float, traction: float, brake: float, power: bool, direction: int=1) -> void:
    if is_instance_valid(system): system.train_audio.set_state(speed,acceleration,traction,brake,power,direction)

func update_door(id: String, openness: float) -> void:
    if is_instance_valid(system): system.door_audio.update_openness(id,openness)

func register_door(id: String, origin: Node3D, openness: float) -> void:
    if is_instance_valid(system): system.door_audio.register_door(id,origin,openness)

func update_controller(notch: int) -> void:
    if is_instance_valid(system): system.cab_audio.set_controller_notch(notch)

func update_switch(id: String, enabled: bool) -> void:
    if is_instance_valid(system): system.cab_audio.set_switch(id,enabled)

func route_announcement(station: String, phase: String, direction: String, visit: String) -> void:
    if is_instance_valid(system): system.route_announcement(station,phase,direction,visit)

func press_info() -> String:
    return system.info.press_info() if is_instance_valid(system) else "Аудиосистема не подключена"

func set_info_mode(mode: String) -> void:
    if is_instance_valid(system): system.info.set_mode(mode)

func set_info_route(current: String, following: String, direction: String, visit: String) -> void:
    if is_instance_valid(system): system.info.set_route_context(current,following,direction,visit)

func update_info_state(approaching: bool, stopped: bool, opened: bool, closed: bool) -> void:
    if is_instance_valid(system): system.info.update_train_state(approaching,stopped,opened,closed)

func auto_info_approach() -> void:
    if is_instance_valid(system): system.info.on_auto_approach()

func auto_info_departure() -> void:
    if is_instance_valid(system): system.info.on_auto_departure()

func update_cab() -> void:
    if not is_instance_valid(system) or not is_instance_valid(_cab): return
    var switches: Dictionary=_cab.get("switches")
    for id in switches: system.cab_audio.set_switch(str(id),bool(switches[id]))
    system.set_master_volume(float(_cab.get("volume")))

func _exit_tree() -> void:
    unbind()
