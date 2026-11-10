extends Control
## A single captured pointer drives the pad; other fingers remain camera gestures.
signal axis_changed(axis: Vector2)
const DEAD_ZONE := 0.12
var axis := Vector2.ZERO
var _pointer := -1
var _knob := Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    get_window().focus_exited.connect(reset)
    get_viewport().size_changed.connect(reset)
    visibility_changed.connect(reset)
    queue_redraw()

func reset() -> void:
    _pointer = -1
    _knob = Vector2.ZERO
    axis = Vector2.ZERO
    axis_changed.emit(axis)
    queue_redraw()

func _update_axis(point: Vector2) -> void:
    var radius := minf(size.x,size.y)*0.36
    _knob = ((point-global_position)-size*0.5).limit_length(radius)
    var raw := _knob/radius
    var amount := raw.length()
    axis = Vector2.ZERO if amount <= DEAD_ZONE else raw.normalized()*((amount-DEAD_ZONE)/(1.0-DEAD_ZONE))
    axis_changed.emit(axis)
    queue_redraw()

func _input(event: InputEvent) -> void:
    if not is_visible_in_tree(): return
    if event is InputEventMouse and event.device == -1: return
    if event is InputEventScreenTouch:
        if event.pressed and _pointer == -1 and get_global_rect().has_point(event.position):
            _pointer = event.index
            _update_axis(event.position)
            get_viewport().set_input_as_handled()
        elif not event.pressed and event.index == _pointer:
            reset()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and event.index == _pointer:
        _update_axis(event.position)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and _pointer == -1 and get_global_rect().has_point(event.position):
            _pointer = -2
            _update_axis(event.position)
            get_viewport().set_input_as_handled()
        elif not event.pressed and _pointer == -2:
            reset()
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and _pointer == -2:
        _update_axis(event.position)
        get_viewport().set_input_as_handled()

func _draw() -> void:
    var center := size*0.5
    var radius := minf(size.x,size.y)*0.46
    draw_circle(center,radius,Color(0.035,0.06,0.10,0.65))
    draw_arc(center,radius,0,TAU,64,Color(0.75,0.84,0.95,0.6),2.0,true)
    draw_line(center+Vector2(-radius*0.5,0),center+Vector2(radius*0.5,0),Color(0.7,0.8,1.0,0.25),1.5,true)
    draw_line(center+Vector2(0,-radius*0.5),center+Vector2(0,radius*0.5),Color(0.7,0.8,1.0,0.25),1.5,true)
    draw_circle(center+_knob,radius*0.34,Color(0.72,0.84,1.0,0.85))
