extends "res://modules/trains/v106/v106_train.gd"
## The original V47 train; V49 visual artwork/materials only.
const ADVERTISING_STATUS := "ADVERTISING: ENABLED — V49 FIXED MOUNTS"

func _decorate_consist() -> void:
    # Keep the legacy body-sticker restoration isolated; no mechanical changes.
    preload("res://scripts/depot/saloon_advertising_v46.gd").decorate(self,train,door_system)
    preload("res://scripts/depot/saloon_realism_v49.gd").apply(train,door_system)

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
