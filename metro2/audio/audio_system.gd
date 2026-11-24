extends Node
class_name MetroAudioSystem
const BANK = preload("res://audio/sound_bank.gd")
const ROUTER = preload("res://audio/audio_event_router.gd")
const TRAIN_AUDIO = preload("res://audio/controllers/train_audio_controller.gd")
const RAIL_AUDIO = preload("res://audio/controllers/rail_joint_audio_controller.gd")
const DOOR_AUDIO = preload("res://audio/controllers/door_audio_controller.gd")
const CAB_AUDIO = preload("res://audio/controllers/cab_audio_controller.gd")
const ENVIRONMENT_AUDIO = preload("res://audio/controllers/environment_audio_controller.gd")
const ANNOUNCER = preload("res://audio/metro_announcer.gd")
const INFO = preload("res://audio/controllers/info_controller.gd")
## Opt-in independent audio module. Never registers autoload or modifies V106.
var bank: MetroSoundBank
var router: MetroAudioEventRouter
var train_audio: MetroTrainAudioController
var rail_audio: MetroRailJointAudioController
var door_audio: MetroDoorAudioController
var cab_audio: MetroCabAudioController
var environment_audio: MetroEnvironmentAudioController
var announcer: MetroAnnouncer
var info: MetroInfoController

func _ready() -> void:
    bank = BANK.new()
    bank.name = "SoundBank"
    add_child(bank)
    router = ROUTER.new()
    router.name = "EventRouter"
    router.bank = bank
    add_child(router)
    train_audio = TRAIN_AUDIO.new()
    train_audio.name = "TrainAudio"
    train_audio.router = router
    add_child(train_audio)
    rail_audio = RAIL_AUDIO.new()
    rail_audio.name = "RailJointAudio"
    rail_audio.router = router
    add_child(rail_audio)
    door_audio = DOOR_AUDIO.new()
    door_audio.name = "DoorAudio"
    door_audio.router = router
    add_child(door_audio)
    cab_audio = CAB_AUDIO.new()
    cab_audio.name = "CabAudio"
    cab_audio.router = router
    add_child(cab_audio)
    environment_audio = ENVIRONMENT_AUDIO.new()
    environment_audio.name = "EnvironmentAudio"
    environment_audio.router = router
    add_child(environment_audio)
    announcer = ANNOUNCER.new()
    announcer.name = "Announcer"
    announcer.bank = bank
    add_child(announcer)
    info = INFO.new()
    info.name = "InfoController"
    add_child(info)
    info.bind(announcer)

func load_catalog(path: String) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    bank.configure(parsed)
    announcer.configure_routes(parsed.get("route_events", {}))
    var notices: Array[String] = []
    for item in parsed.get("service_notice_events", []):
        if item is String:
            notices.append(item)
    info.configure_service_events(notices)
    train_audio.configure_layers(parsed.get("loop_events", {}),parsed.get("loop_profiles",{}))
    rail_audio.joint_event_id=str(parsed.get("rail_joint_event",""))
    environment_audio.configure_zones(parsed.get("zone_events", {}))
    return true

func bind_origins(train_origin: Node3D, cab_origin: Node3D, station_origin: Node3D) -> void:
    train_audio.origin = train_origin
    rail_audio.origin = train_origin
    cab_audio.origin = cab_origin
    environment_audio.origin = station_origin

func set_listener_mode(mode: String) -> void:
    router.set_listener_mode(mode)

func route_announcement(station_id: String, phase: String, direction: String, visit_id: String) -> void:
    # Legacy route callbacks must never bypass MANUAL INFO gating.
    if info.mode != MetroInfoController.AUTO:
        return
    if station_id == "" or visit_id == "":
        return
    if phase == MetroInfoController.ARRIVAL:
        info.set_route_context(station_id, info.next_station_id, direction, visit_id)
        info.on_auto_approach()
    elif phase == MetroInfoController.DEPARTURE:
        info.set_route_context(info.station_id, station_id, direction, visit_id)
        info.on_auto_departure()

func _exit_tree() -> void:
    if is_instance_valid(bank):
        bank.stop_all()
