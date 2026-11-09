extends Control
# Mobile inspection controls. Flight stays inside the station/tunnel envelope.
var game: Node3D
var lever := 0.0
var stick := Vector2.ZERO
var flight := false
var door_open := false
var _lever_touch := -1
var _stick_touch := -1
var _lever_area: Control
var _stick_area: Control
var _door_button: Button
var _info: Label
var _info_panel: PanelContainer
var _lever_handle: Label
var _stick_handle: Label
var _door_icon: Label
var _door_progress := 0.0
var _flight_button: Button

func initialize(owner: Node3D) -> void:
    game = owner
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bar := HBoxContainer.new()
    bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
    bar.offset_top = 104
    bar.offset_bottom = 150
    bar.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(bar)
    for entry in [["ПЛАТФОРМА","platform"],["КАБИНА","cabin"],["САЛОН","salon"],["СНАРУЖИ","external"],["ПОЛЁТ","flight"]]:
        var button := Button.new()
        button.text = entry[0]
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        bar.add_child(button)
        var mode: String = entry[1]
        if mode == "flight": _flight_button = button
        button.pressed.connect(func(): _select_mode(mode))
    var actions := HBoxContainer.new()
    actions.set_anchors_preset(Control.PRESET_TOP_WIDE)
    actions.offset_top = 155
    actions.offset_bottom = 199
    actions.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(actions)
    _door_button = Button.new()
    _door_button.text = "◀ │ │ ▶"
    _door_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.add_child(_door_button)
    _door_button.pressed.connect(_toggle_doors)
    var info_button := Button.new()
    info_button.text = "🔊"
    info_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.add_child(info_button)
    info_button.pressed.connect(func(): _info_panel.visible = not _info_panel.visible)
    _info_panel = PanelContainer.new()
    _info_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _info_panel.offset_left = -290
    _info_panel.offset_right = -8
    _info_panel.offset_top = 205
    _info_panel.offset_bottom = 290
    _info_panel.visible = false
    add_child(_info_panel)
    _info = Label.new()
    _info_panel.add_child(_info)
    _lever_area = _touch_zone(Vector2(26,-240),Vector2(95,210),"ТЯГА\n│\n│\n│\nТОРМОЗ",false)
    _lever_handle = Label.new()
    _lever_handle.text = "━━"
    _lever_handle.add_theme_font_size_override("font_size",32)
    _lever_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _lever_area.add_child(_lever_handle)
    _stick_area = _touch_zone(Vector2(145,-215),Vector2(150,150),"◯",true)
    _stick_handle = Label.new()
    _stick_handle.text = "●"
    _stick_handle.add_theme_font_size_override("font_size",38)
    _stick_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _stick_area.add_child(_stick_handle)
    _stick_area.visible = false

func _touch_zone(pos: Vector2, dimensions: Vector2, label: String, is_stick: bool) -> Control:
    var zone := PanelContainer.new()
    zone.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    zone.position = pos
    zone.offset_left = pos.x
    zone.offset_top = pos.y
    zone.offset_right = pos.x + dimensions.x
    zone.offset_bottom = pos.y + dimensions.y
    zone.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(zone)
    var text_label := Label.new()
    text_label.text = label
    text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    text_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    zone.add_child(text_label)
    zone.gui_input.connect(func(event: InputEvent): _zone_input(event,zone,is_stick))
    return zone

func _zone_input(event: InputEvent, zone: Control, is_stick: bool) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if is_stick: _stick_touch = event.index
            else: _lever_touch = event.index
            _update_zone(event.position,zone,is_stick)
        elif (is_stick and event.index == _stick_touch) or (not is_stick and event.index == _lever_touch):
            if is_stick:
                stick = Vector2.ZERO
                _stick_touch = -1
            else:
                lever = 0.0
                _lever_touch = -1
        accept_event()
    elif event is InputEventScreenDrag:
        if (is_stick and event.index == _stick_touch) or (not is_stick and event.index == _lever_touch):
            _update_zone(event.position,zone,is_stick)
            accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed: _update_zone(event.position,zone,is_stick)
        else:
            if is_stick: stick = Vector2.ZERO
            else: lever = 0.0
        accept_event()
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _update_zone(event.position,zone,is_stick)
        accept_event()

func _update_zone(point: Vector2, zone: Control, is_stick: bool) -> void:
    var local := zone.get_global_transform().affine_inverse() * point
    var half := zone.size * 0.5
    if is_stick:
        stick = Vector2(clampf((local.x-half.x)/maxf(half.x,1.0),-1.0,1.0),clampf((local.y-half.y)/maxf(half.y,1.0),-1.0,1.0))
        if stick.length() > 1.0: stick = stick.normalized()
    else:
        lever = clampf((half.y-local.y)/maxf(half.y,1.0),-1.0,1.0)

func _select_mode(mode: String) -> void:
    flight = mode == "flight"
    _stick_area.visible = flight
    _lever_area.visible = not flight
    stick = Vector2.ZERO
    lever = 0.0
    game.call("_set_camera_mode",mode)
    if is_instance_valid(_flight_button): _flight_button.text = "✓ ПОЛЁТ" if flight else "ПОЛЁТ"
    if flight:
        game.set("flight_position",game.get("camera").global_position)

func _toggle_doors() -> void:
    var doors: Node = game.get("door_system")
    if not is_instance_valid(doors) or not bool(doors.get("validated")):
        _door_button.text = "ДВЕРИ НЕ ГОТОВЫ"
        return
    if door_open:
        doors.call("request_close")
    else:
        doors.call("request_open",float(game.get("speed")))
    door_open = not door_open
    _door_button.text = "◀   ▶" if door_open else "▶ │ ◀"

func _process(_delta: float) -> void:
    if is_instance_valid(_lever_handle):
        _lever_handle.position = Vector2(25,clampf((_lever_area.size.y-40.0)*0.5-lever*(_lever_area.size.y-48.0)*0.5,4.0,_lever_area.size.y-40.0))
    if is_instance_valid(_stick_handle):
        _stick_handle.position = (_stick_area.size-Vector2(38,48))*0.5+stick*(_stick_area.size.x*0.32)
    var doors: Node = game.get("door_system") if is_instance_valid(game) else null
    if is_instance_valid(doors):
        var open_fraction: float = float(doors.get("openness"))
        _door_progress = move_toward(_door_progress,open_fraction,_delta*3.0)
        _door_button.text = "◀   ▶" if _door_progress > 0.65 else "◀ │ ▶" if _door_progress > 0.15 else "▶│◀"
    if not is_instance_valid(game): return
    if not flight:
        game.set("throttle",lever > 0.12)
        game.set("brake",lever < -0.12)
    else:
        game.set("throttle",false)
        game.set("brake",false)
    if _info_panel.visible:
        _info.text = "Скорость: %.0f км/ч\nОт депо: %.0f м\nРежим: %s" % [float(game.get("speed"))*3.6,430.0-float(game.get("distance")),str(game.get("camera_mode"))]
