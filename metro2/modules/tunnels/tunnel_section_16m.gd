extends "res://scripts/depot/depot_tunnel.gd"
## Reuse the exact current section builder, without a moving pool or darkness cap.
func _ready() -> void:
    super._ready()
    _entrance_shade.hide()
    _entrance_shade.queue_free()
    _entrance_shade = null
    set_process(false)
    var section := _new_section()
    section.name = "Section16m"
    section.position.x = center_x
