extends Node
class_name MetroAudioSystem
## Opt-in independent audio module. Never registers autoload or modifies V106.
var bank: MetroSoundBank
var router: MetroAudioEventRouter
var train_audio: MetroTrainAudioController
var rail_audio: MetroRailJointAudioController
var door_audio: MetroDoorAudioController
var cab_audio: MetroCabAudioController
var environment_audio: MetroEnvironmentAudioController
var announcer: MetroAnnouncer

func _ready() -> void:
    bank = MetroSoundBank.new()
    bank.name = "SoundBank"
    add_child(bank)
    router = MetroAudioEventRouter.new()
    router.name = "EventRouter"
    router.bank = bank
    add_child(router)
    train_audio = MetroTrainAudioController.new()
    train_audio.name = "TrainAudio"
    train_audio.router = router
    add_child(train_audio)
    rail_audio = MetroRailJointAudioController.new()
    rail_audio.name = "RailJointAudio"
    rail_audio.router = router
    add_child(rail_audio)
    door_audio = MetroDoorAudioController.new()
    door_audio.name = "DoorAudio"
    door_audio.router = router
    add_child(door_audio)
    cab_audio = MetroCabAudioController.new()
    cab_audio.name = "CabAudio"
    cab_audio.router = router
    add_child(cab_audio)
    environment_audio = MetroEnvironmentAudioController.new()
    environment_audio.name = "EnvironmentAudio"
    environment_audio.router = router
    add_child(environment_audio)
    announcer = MetroAnnouncer.new()
    announcer.name = "Announcer"
    announcer.bank = bank
    add_child(announcer)

func load_catalog(path: String) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    bank.configure(parsed)
    announcer.configure_routes(parsed.get("route_events", {}))
    return true

func bind_origins(train_origin: Node3D, cab_origin: Node3D, station_origin: Node3D) -> void:
    train_audio.origin = train_origin
    rail_audio.origin = train_origin
    cab_audio.origin = cab_origin
    environment_audio.origin = station_origin

func set_listener_mode(mode: String) -> void:
    router.set_listener_mode(mode)

func route_announcement(station_id: String, phase: String, direction: String, visit_id: String) -> void:
    announcer.route_announcement(station_id, phase, direction, visit_id)

func _exit_tree() -> void:
    if is_instance_valid(bank):
        bank.stop_all()
