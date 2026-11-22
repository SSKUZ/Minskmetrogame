extends Node
class_name MetroEnvironmentAudioController
## Zone-based ambience. Events remain silent until explicitly verified.
var router: MetroAudioEventRouter
var origin: Node3D
var current_zone: String = ""
var zone_events: Dictionary = {}
var _active: AudioStreamPlayer3D

func configure_zones(events: Dictionary) -> void:
    zone_events = events.duplicate(true)

func enter_zone(zone_id: String) -> void:
    if zone_id == current_zone:
        return
    leave_zone()
    current_zone = zone_id
    var event_id: String = str(zone_events.get(zone_id, ""))
    if event_id != "" and router != null and is_instance_valid(origin):
        if router.bank != null:
            _active = router.bank.play_at(event_id, origin, Vector3.ZERO, 0.0, true)

func leave_zone() -> void:
    if is_instance_valid(_active):
        if router != null and router.bank != null:
            router.bank.release_player(_active)
        else:
            _active.stop()
            _active.queue_free()
    _active = null
    current_zone = ""
