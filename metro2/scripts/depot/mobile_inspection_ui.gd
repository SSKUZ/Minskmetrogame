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
var _platform_button: Button
var _master_value: Label
var _view_button: Button
var _master_title: Label
var _master_track: Control
var _lever_dragging := false

func initialize(owner: Node3D) -> void:
    game = owner
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Compact original-style view buttons. One button alternates CABIN / SALON.
    var bar := HBoxContainer.new()
    bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    bar.anchor_left = 1.0
    bar.anchor_right = 1.0
    bar.offset_left = -410
    bar.offset_right = -8
    bar.offset_top = 106
    bar.offset_bottom = 152
    bar.add_theme_constant_override("separation",6)
    bar.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(bar)
    _view_button = Button.new()
    _view_button.text = "🚇 ВИД В САЛОНЕ"
    _style_button(_view_button,Color(0.12,0.22,0.28,0.93))
    _view_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.add_child(_view_button)
    _view_button.pressed.connect(_toggle_cabin_salon)
    _platform_button = Button.new()
    _platform_button.text = "ПЛАТФОРМА"
    _style_button(_platform_button,Color(0.18,0.27,0.26,0.95))
    _platform_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _platform_button.visible = false
    bar.add_child(_platform_button)
    _platform_button.pressed.connect(func(): _select_mode("platform"))
    _flight_button = Button.new()
    _flight_button.text = "ПОЛЁТ"
    _style_button(_flight_button,Color(0.12,0.22,0.28,0.93))
    _flight_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.add_child(_flight_button)
    _flight_button.pressed.connect(func(): _select_mode("flight"))
    # Door icon and INFO are independent bottom-right controls.
    _door_button = Button.new()
    _door_button.text = "▶│◀"
    _style_button(_door_button,Color(0.13,0.31,0.23,0.94))
    _door_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    _door_button.offset_left = -176
    _door_button.offset_right = -102
    _door_button.offset_top = -80
    _door_button.offset_bottom = -20
    add_child(_door_button)
    _door_button.pressed.connect(_toggle_doors)
    var info_button := Button.new()
    info_button.text = "◀))\nINFO"
    _style_button(info_button,Color(0.14,0.28,0.37,0.95))
    info_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    info_button.offset_left = -96
    info_button.offset_right = -12
    info_button.offset_top = -90
    info_button.offset_bottom = -12
    add_child(info_button)
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
    # Original web master-controller layout: tall dark console, central
    # vertical slot and metallic horizontal sliding handle.
    _lever_area = _touch_zone(Vector2(20,-325),Vector2(205,295),"",false)
    var master_style := StyleBoxFlat.new()
    master_style.bg_color = Color(0.10,0.14,0.17,0.96)
    master_style.border_color = Color(0.77,0.69,0.58)
    master_style.set_border_width_all(3)
    master_style.set_corner_radius_all(24)
    master_style.shadow_color = Color(0,0,0,0.65)
    master_style.shadow_size = 7
    (_lever_area as PanelContainer).add_theme_stylebox_override("panel",master_style)
    _master_title = Label.new()
    _master_title.text = "КОНТРОЛЛЕР\nМАШИНИСТА"
    _master_title.position = Vector2(30,13)
    _master_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _master_title.add_theme_font_size_override("font_size",13)
    _master_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _lever_area.add_child(_master_title)
    _master_track = Panel.new()
    _master_track.position = Vector2(92,76)
    _master_track.size = Vector2(25,151)
    _master_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var track_style := StyleBoxFlat.new()
    track_style.bg_color = Color(0.02,0.04,0.05)
    track_style.border_color = Color(0.59,0.67,0.70)
    track_style.set_border_width_all(3)
    track_style.set_corner_radius_all(13)
    _master_track.add_theme_stylebox_override("panel",track_style)
    _lever_area.add_child(_master_track)
    for item in [["▲ ТЯГА",Vector2(132,98),Color(0.39,0.90,0.67)],["▼ ТОРМОЗ",Vector2(126,210),Color(1.0,0.54,0.53)]]:
        var caption := Label.new()
        caption.text = item[0]
        caption.position = item[1]
        caption.add_theme_color_override("font_color",item[2])
        caption.add_theme_font_size_override("font_size",12)
        caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _lever_area.add_child(caption)
    _lever_handle = Label.new()
    _lever_handle.text = "━━━━"
    _lever_handle.add_theme_font_size_override("font_size",28)
    _lever_handle.add_theme_color_override("font_color",Color(0.78,0.88,0.92))
    _lever_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _lever_area.add_child(_lever_handle)
    _master_value = Label.new()
    _master_value.text = "НЕЙТРАЛЬ · 0%"
    _master_value.position = Vector2(20,260)
    _master_value.size = Vector2(165,26)
    _master_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _master_value.add_theme_font_size_override("font_size",13)
    _master_value.add_theme_color_override("font_color",Color(0.67,0.98,0.89))
    _master_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _lever_area.add_child(_master_value)
    _stick_area = _touch_zone(Vector2(26,-195),Vector2(155,155),"",true)
    _stick_handle = Label.new()
    _stick_handle.text = "●"
    _stick_handle.add_theme_font_size_override("font_size",38)
    _stick_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _stick_area.add_child(_stick_handle)
    _stick_area.visible = false

func _style_button(button: Button, color: Color) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = Color(0.57,0.73,0.78,0.92)
    style.set_border_width_all(2)
    style.set_corner_radius_all(9)
    style.shadow_color = Color(0.0,0.0,0.0,0.5)
    style.shadow_size = 3
    button.add_theme_stylebox_override("normal",style)
    var pressed := style.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.24,0.53,0.57,0.98)
    button.add_theme_stylebox_override("pressed",pressed)
    button.add_theme_stylebox_override("hover",pressed)
    button.add_theme_color_override("font_color",Color(0.92,0.98,1.0))
    button.add_theme_font_size_override("font_size",15)

func _touch_zone(pos: Vector2, dimensions: Vector2, label: String, is_stick: bool) -> Control:
    var zone := PanelContainer.new()
    zone.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    zone.position = pos
    zone.offset_left = pos.x
    zone.offset_top = pos.y
    zone.offset_right = pos.x + dimensions.x
    zone.offset_bottom = pos.y + dimensions.y
    zone.mouse_filter = Control.MOUSE_FILTER_STOP
    var frame := StyleBoxFlat.new()
    frame.bg_color = Color(0.07,0.12,0.17,0.91)
    frame.border_color = Color(0.56,0.65,0.67)
    frame.set_border_width_all(2)
    frame.set_corner_radius_all(16 if is_stick else 9)
    zone.add_theme_stylebox_override("panel",frame)
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
            else: pass # Master controller stays at the selected notch.
        accept_event()
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _update_zone(event.position,zone,is_stick)
        accept_event()

func _update_zone(point: Vector2, zone: Control, is_stick: bool) -> void:
    # Control.gui_input supplies local coordinates, not global coordinates.
    var local := point
    var half := zone.size * 0.5
    if is_stick:
        stick = Vector2(clampf((local.x-half.x)/maxf(half.x,1.0),-1.0,1.0),clampf((local.y-half.y)/maxf(half.y,1.0),-1.0,1.0))
        if stick.length() > 1.0: stick = stick.normalized()
    else:
        lever = clampf((151.0-local.y)/75.0,-1.0,1.0)

func _toggle_cabin_salon() -> void:
    var current := str(game.get("camera_mode"))
    _select_mode("salon" if current == "cabin" else "cabin")

func _select_mode(mode: String) -> void:
    if mode == "platform" and not bool(game.call("platform_camera_available")): return
    flight = mode == "flight"
    _stick_area.visible = flight
    _lever_area.visible = not flight
    stick = Vector2.ZERO
    lever = 0.0
    game.call("_set_camera_mode",mode)
    if is_instance_valid(_flight_button): _flight_button.text = "✓ ПОЛЁТ" if flight else "ПОЛЁТ"
    if is_instance_valid(_view_button): _view_button.text = "🚇 ВИД В КАБИНЕ" if mode == "salon" else "🚇 ВИД В САЛОНЕ"
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
    _door_button.text = "◀   ▶" if door_open else "▶│◀"

func _process(_delta: float) -> void:
    if is_instance_valid(_platform_button) and is_instance_valid(game):
        var available: bool = bool(game.call("platform_camera_available"))
        _platform_button.visible = available
        _platform_button.modulate = Color(1.0,0.94,0.45) if available else Color.WHITE
    if is_instance_valid(_master_value):
        _master_value.text = "ТЯГА · %d%%" % roundi(lever*100.0) if lever > 0.08 else "ТОРМОЗ · %d%%" % roundi(-lever*100.0) if lever < -0.08 else "НЕЙТРАЛЬ · 0%"
    if is_instance_valid(_lever_handle):
        _lever_handle.position = Vector2(57,clampf(135.0-lever*69.0,66.0,204.0))
    if is_instance_valid(_stick_handle):
        _stick_handle.position = (_stick_area.size-Vector2(38,48))*0.5+stick*(_stick_area.size.x*0.32)
    var doors: Node = game.get("door_system") if is_instance_valid(game) else null
    if is_instance_valid(doors):
        var open_fraction: float = float(doors.get("openness"))
        _door_progress = move_toward(_door_progress,open_fraction,_delta*3.0)
        _door_button.text = "◀   ▶" if _door_progress > 0.65 else "◀ │ ▶" if _door_progress > 0.15 else "▶│◀"
    if not is_instance_valid(game): return
    if not flight:
        game.set("throttle",false)
        game.set("brake",false)
        var cab: Node3D = game.get("cab_runtime")
        if is_instance_valid(cab):
            cab.set("controller_value",maxf(lever,0.0))
            cab.set("brake_demand",maxf(-lever,0.0))
        else:
            game.set("throttle",lever > 0.12)
            game.set("brake",lever < -0.12)
    else:
        game.set("throttle",false)
        game.set("brake",false)
    if _info_panel.visible:
        _info.text = "Скорость: %.0f км/ч\nОт депо: %.0f м\nРежим: %s" % [float(game.get("speed"))*3.6,430.0-float(game.get("distance")),str(game.get("camera_mode"))]
