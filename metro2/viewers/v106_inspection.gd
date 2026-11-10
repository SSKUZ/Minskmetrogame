extends "res://modules/trains/v106/v106_train.gd"
## The exact V47 train, with only the known failing decorators isolated.
const ADVERTISING_STATUS := "ADVERTISING: DISABLED — EXISTING RUNTIME ERROR"

func _decorate_consist() -> void:
    # Keep both scripts/assets and gameplay behavior unchanged. No coordinate fixes.
    pass

func _attach_fourth_car(third_car: Node3D, third_bounds: AABB) -> void:
    super._attach_fourth_car(third_car,third_bounds)
    _ui_layer.hide()
    camera.current = false
    set_physics_process(false)
    _disable_input(self)

func _disable_input(node: Node) -> void:
    node.set_process_input(false)
    node.set_process_unhandled_input(false)
    node.set_process_unhandled_key_input(false)
    for child in node.get_children():
        _disable_input(child)
