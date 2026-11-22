extends Node
class_name MetroCabAudioController
## Explicit cab state transitions. No automatic substitute samples.
var router: MetroAudioEventRouter
var origin: Node3D
var _switches: Dictionary = {}
var _controller_notch: int = 0
var _horn_active: bool = false

func set_controller_notch(notch: int) -> void:
    if notch == _controller_notch:
        return
    _controller_notch = notch
    _emit("cab.controller")

func set_switch(switch_id: String, enabled: bool) -> void:
    if _switches.has(switch_id) and bool(_switches[switch_id]) == enabled:
        return
    _switches[switch_id] = enabled
    _emit("cab.switch")

func press_button(button_id: String) -> void:
    if button_id == "":
        return
    _emit("cab.button")

func set_horn(active: bool) -> void:
    if active == _horn_active:
        return
    _horn_active = active
    _emit("cab.horn_start" if active else "cab.horn_stop")

func external_event(event_id: String) -> void:
    if event_id in ["cab.emergency", "cab.radio_tx"]:
        _emit(event_id)

func _emit(event_id: String) -> void:
    if router != null and is_instance_valid(origin):
        router.dispatch(event_id, origin)
