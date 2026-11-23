extends Node
class_name MetroV106AudioAdapter
## Explicit adapter for V106 owners. No reflection-based guessing of train properties.
## Owner calls bind() after consist_ready and feeds actual mechanics through methods.
var system: MetroAudioSystem
var _bound: bool = false

func bind(audio_system: MetroAudioSystem, train_origin: Node3D, cab_origin: Node3D, station_origin: Node3D, speaker_origins: Array[Node3D], axle_offsets_m: Array[float]) -> void:
    if not is_instance_valid(audio_system):
        return
    system = audio_system
    system.bind_origins(train_origin, cab_origin, station_origin)
    system.announcer.set_speakers(speaker_origins)
    system.rail_audio.set_axles(axle_offsets_m)
    _bound = true

func unbind() -> void:
    _bound = false
    system = null

func update_motion(route_distance_m: float, speed_mps: float, acceleration_mps2: float, traction: float, brake: float, power: bool) -> void:
    if not _bound or not is_instance_valid(system):
        return
    system.train_audio.set_state(speed_mps, acceleration_mps2, traction, brake, power)
    system.rail_audio.advance(route_distance_m)

func update_door(door_id: String, openness: float) -> void:
    if _bound and is_instance_valid(system):
        system.door_audio.update_openness(door_id, openness)

func register_door(door_id: String, origin: Node3D, openness: float) -> void:
    if _bound and is_instance_valid(system):
        system.door_audio.register_door(door_id, origin, openness)

func update_controller(notch: int) -> void:
    if _bound and is_instance_valid(system):
        system.cab_audio.set_controller_notch(notch)

func update_switch(switch_id: String, enabled: bool) -> void:
    if _bound and is_instance_valid(system):
        system.cab_audio.set_switch(switch_id, enabled)

func route_announcement(station_id: String, phase: String, direction: String, visit_id: String) -> void:
    if _bound and is_instance_valid(system):
        system.route_announcement(station_id, phase, direction, visit_id)

## Both the physical cab INFO button and every camera's HUD INFO button
## must call press_info(). No camera-specific counters or auto triggers in manual mode.
func press_info() -> String:
    if not _bound or not is_instance_valid(system):
        return "Аудиосистема не подключена"
    return system.info.press_info()

func set_info_mode(mode: String) -> void:
    if _bound and is_instance_valid(system):
        system.info.set_mode(mode)

func set_info_route(current_station: String, next_station: String, direction: String, visit_id: String) -> void:
    if _bound and is_instance_valid(system):
        system.info.set_route_context(current_station, next_station, direction, visit_id)

func update_info_state(approaching: bool, stopped: bool, doors_open: bool, doors_closed: bool) -> void:
    if _bound and is_instance_valid(system):
        system.info.update_train_state(approaching, stopped, doors_open, doors_closed)

func auto_info_approach() -> void:
    if _bound and is_instance_valid(system):
        system.info.on_auto_approach()

func auto_info_departure() -> void:
    if _bound and is_instance_valid(system):
        system.info.on_auto_departure()
