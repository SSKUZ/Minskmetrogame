extends Node
class_name MetroAudioEventRouter
## Routes verified event IDs to spatial audio without changing the train.
signal event_requested(event_id: String, origin: Node3D)
var bank: MetroSoundBank
var listener_mode: String = "cab"
var perspective_gain_db: Dictionary = {
    "cab": {"traction": -3.0, "rolling": -7.0, "cab": 0.0, "announcer": 0.0},
    "salon": {"traction": -5.0, "rolling": -3.0, "cab": -20.0, "announcer": 0.0},
    "platform": {"traction": 1.0, "rolling": 1.0, "cab": -30.0, "announcer": -8.0},
    "free": {"traction": 0.0, "rolling": 0.0, "cab": -12.0, "announcer": -6.0}
}

func set_listener_mode(mode: String) -> void:
    if perspective_gain_db.has(mode):
        listener_mode = mode

func dispatch(event_id: String, origin: Node3D, position: Vector3 = Vector3.ZERO, gain_db: float = 0.0) -> AudioStreamPlayer3D:
    event_requested.emit(event_id, origin)
    if bank == null or not bank.has_event(event_id):
        return null
    var category: String = str(bank._entries[event_id].get("category", ""))
    var adjustment: float = float(perspective_gain_db[listener_mode].get(category, 0.0))
    return bank.play_at(event_id, origin, position, gain_db + adjustment)
