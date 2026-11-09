extends Control
## Three.js masterUnit / masterHandle / infoSpeaker translated into native vector UI.
## The cab owns the master value. This overlay writes only during a user drag.
var game: Node3D
var lever := 0.0
var stick := Vector2.ZERO
var flight := false
var _deck: Control
var _master: MasterConsole
var _joystick: FlightStick
var _doors: DeckButton
var _speaker: DeckButton
var _view: DeckButton
var _platform: DeckButton
var _flight: DeckButton
var _cab: Node3D
var _touch := -2
var _drag_kind := ""
var _drag_start := Vector2.ZERO
var _drag_value := 0.0
var _drag_moved := false
var _physical_held := false

class Artwork extends Control:
    var fonts: Font = ThemeDB.fallback_font
    static func gradient(colors: Array[Color]) -> GradientTexture2D:
        var ramp := Gradient.new()
        var offsets := PackedFloat32Array()
        for i in range(colors.size()): offsets.append(float(i)/float(colors.size()-1))
        ramp.offsets=offsets
        ramp.colors=PackedColorArray(colors)
        var texture := GradientTexture2D.new()
        texture.gradient=ramp
        texture.width=8; texture.height=128
        texture.fill_from=Vector2(0,0); texture.fill_to=Vector2(0,1)
        return texture
    static func panel(canvas: CanvasItem,rect: Rect2,fill: Color,border: Color,radius: int = 12,shadow: int = 0) -> void:
        var style := StyleBoxFlat.new()
        style.bg_color=fill
        style.border_color=border
        style.set_border_width_all(1)
        style.set_corner_radius_all(radius)
        style.shadow_color=Color(0,0,0,0.5)
        style.shadow_size=shadow
        style.shadow_offset=Vector2(0,3)
        canvas.draw_style_box(style,rect)
    func caption(text: String,rect: Rect2,font_size: int,color: Color) -> void:
        draw_string(fonts,Vector2(rect.position.x,rect.position.y+fonts.get_ascent(font_size)),text,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,font_size,color)

class MasterConsole extends Artwork:
    var value := 0.0
    var chrome: GradientTexture2D
    var shell: GradientTexture2D
    func _init() -> void:
        mouse_filter=Control.MOUSE_FILTER_STOP
        chrome=gradient([Color("#e0e8e9"),Color("#a4b0b2"),Color("#4e5b61"),Color("#1a2329"),Color("#444f55")])
        shell=gradient([Color("#484b4d"),Color("#181f25"),Color("#2e353a"),Color("#0b1117")])
    func _draw() -> void:
        panel(self,Rect2(Vector2.ZERO,size),Color("#20282e"),Color("#8d8275"),16,5)
        draw_texture_rect(shell,Rect2(5,18,size.x-10,size.y-36),false)
        draw_line(Vector2(13,5),Vector2(size.x-13,5),Color("#c3c8c5"),1,true)
        caption("КОНТРОЛЛЕР",Rect2(5,12,size.x-10,14),11,Color("#d8e6e8"))
        caption("МАШИНИСТА",Rect2(5,27,size.x-10,12),9,Color("#98a6ae"))
        panel(self,Rect2(35,54,20,174),Color("#080b0e"),Color("#6e7578"),9)
        draw_line(Vector2(42,59),Vector2(42,223),Color("#30383b"),3,true)
        for i in range(11):
            var y := 64.0+float(i)*15.4
            draw_line(Vector2(20,y),Vector2(28 if i != 5 else 31,y),Color("#839399"),1,true)
        draw_line(Vector2(13,141),Vector2(74,141),Color("#e0c37e"),2,true)
        caption("ТЯГА",Rect2(77,59,48,14),10,Color("#62e2a5"))
        caption("0",Rect2(77,134,48,16),12,Color("#e0c37e"))
        caption("ТОРМОЗ",Rect2(74,211,55,14),9,Color("#ff857b"))
        var y := 141.0-value*77.0
        panel(self,Rect2(16,y-10,59,31),Color("#11181d"),Color("#11181d"),10,5)
        panel(self,Rect2(40,y+13,10,18),Color("#879397"),Color("#a6b0b3"),3)
        panel(self,Rect2(14,y-14,62,29),Color("#4e5b61"),Color("#b5c2c4"),10,3)
        draw_texture_rect(chrome,Rect2(19,y-10,52,20),false)
        draw_line(Vector2(23,y-9),Vector2(67,y-9),Color("#f0f6f5"),1,true)
        for x in [30.0,36.0,42.0,48.0,54.0,60.0]:
            draw_line(Vector2(x,y+2),Vector2(x,y+7),Color(0.02,0.04,0.05,0.60),1,true)
        panel(self,Rect2(9,241,size.x-18,31),Color("#0a171c"),Color("#41575b"),7)
        var tone := Color("#62e2a5") if value > 0.0 else Color("#ff857b") if value < 0.0 else Color("#e0c37e")
        var text := "ТЯГА %d%%" % roundi(value*100) if value > 0.0 else "ТОРМОЗ %d%%" % roundi(-value*100) if value < 0.0 else "НЕЙТРАЛЬ"
        caption(text,Rect2(11,249,size.x-22,15),11,tone)
        draw_circle(Vector2(16,47),2.0,Color("#94a3a7"))
        draw_circle(Vector2(size.x-16,47),2.0,Color("#94a3a7"))

class DeckButton extends Button:
    var kind := ""
    var label := ""
    var amount := 0.0
    var selected := false
    var shade: GradientTexture2D
    var metal: GradientTexture2D
    func _init() -> void:
        focus_mode=Control.FOCUS_NONE
        mouse_filter=Control.MOUSE_FILTER_STOP
        mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
        for state in ["normal","hover","pressed","disabled","focus"]:
            add_theme_stylebox_override(state,StyleBoxEmpty.new())
        shade=Artwork.gradient([Color("#344c5d"),Color("#1b3040"),Color("#101e2b")])
        metal=Artwork.gradient([Color("#d2dbdd"),Color("#7e939c"),Color("#465e69")])
        button_down.connect(queue_redraw)
        button_up.connect(queue_redraw)
        mouse_entered.connect(queue_redraw)
        mouse_exited.connect(queue_redraw)
    func _draw() -> void:
        var held := is_pressed()
        var tint := Color("#a6c4d5") if not selected else Color("#69d9bc")
        if disabled: tint=Color("#66747b")
        Artwork.panel(self,Rect2(Vector2(0,2 if held else 0),size-Vector2(0,2)),Color("#102431"),tint,12,2 if held else 4)
        draw_texture_rect(shade,Rect2(6,10,size.x-12,size.y-20),false,Color(0.68,1.0,1.0) if held or selected else Color.WHITE)
        draw_line(Vector2(13,5),Vector2(size.x-13,5),Color(0.8,0.93,1,0.35),1,true)
        var ink := Color("#d8f5ff") if not disabled else Color("#7c898e")
        var center := Vector2(size.x*0.5,27 if size.y > 65 else 16)
        if kind == "doors": _draw_doors(center)
        elif kind == "speaker":
            var c := center+Vector2(-8,0)
            draw_colored_polygon(PackedVector2Array([c+Vector2(-9,-6),c+Vector2(-2,-6),c+Vector2(9,-15),c+Vector2(9,15),c+Vector2(-2,6),c+Vector2(-9,6)]),ink)
            draw_arc(c+Vector2(9,0),13,-0.8,0.8,16,ink,2,true)
            draw_arc(c+Vector2(9,0),20,-0.8,0.8,18,ink,2,true)
        elif kind == "flight":
            var c := center
            draw_colored_polygon(PackedVector2Array([c+Vector2(0,-11),c+Vector2(18,7),c+Vector2(3,3),c+Vector2(0,12),c+Vector2(-3,3),c+Vector2(-18,7)]),ink)
        elif kind == "platform":
            draw_rect(Rect2(center+Vector2(-19,-8),Vector2(38,5)),ink)
            for x in [-13.0,13.0]: draw_line(center+Vector2(x,-2),center+Vector2(x,10),ink,2,true)
            draw_line(center+Vector2(-22,11),center+Vector2(22,11),ink,2,true)
        else:
            Artwork.panel(self,Rect2(center+Vector2(-15,-11),Vector2(30,21)),Color("#102431"),ink,4)
            draw_line(center+Vector2(0,-9),center+Vector2(0,6),ink,1,true)
            draw_line(center+Vector2(-12,3),center+Vector2(12,3),ink,1,true)
        var font := ThemeDB.fallback_font
        var text_y := size.y-12.0
        draw_string(font,Vector2(2,text_y),label,HORIZONTAL_ALIGNMENT_CENTER,size.x-4,11,ink)
        if kind == "doors" or selected:
            draw_line(Vector2(15,size.y-5),Vector2(size.x-15,size.y-5),Color("#62e2a5") if selected or amount > 0.01 else Color("#e0c37e"),2,true)
    func _draw_doors(center: Vector2) -> void:
        var frame := Rect2(center+Vector2(-25,-20),Vector2(50,42))
        Artwork.panel(self,frame,Color("#080f14"),Color("#a6b7be"),5)
        # Actual train animation fraction, not a speculative button tween.
        var offset := amount*17.0
        for side in [-1.0,1.0]:
            var x: float=center.x+side*(10.5+offset)-9.5
            var r := Rect2(x,center.y-17,19,36)
            Artwork.panel(self,r,Color("#708792"),Color("#c7d4d8"),3)
            draw_texture_rect(metal,r.grow(-2),false)
            Artwork.panel(self,Rect2(x+4,center.y-12,11,16),Color("#102f40"),Color("#a0b7c0"),2)
            draw_line(Vector2(x+4,center.y+10),Vector2(x+15,center.y+10),Color("#d3dcd9"),2,true)

class FlightStick extends Artwork:
    var axis := Vector2.ZERO
    func _init() -> void: mouse_filter=Control.MOUSE_FILTER_STOP
    func _draw() -> void:
        var center := size*0.5
        draw_circle(center,61,Color(0.03,0.06,0.08,0.65))
        draw_arc(center,58,0,TAU,64,Color(0.65,0.76,0.80,0.7),2,true)
        draw_circle(center,44,Color(0.15,0.22,0.27,0.6))
        draw_arc(center,38,0,TAU,48,Color(0.50,0.65,0.70,0.35),1,true)
        var knob := center+axis*37
        draw_circle(knob+Vector2(0,4),23,Color(0,0,0,0.55))
        draw_circle(knob,23,Color("#8ca8b5"))
        draw_circle(knob+Vector2(0,-2),20,Color("#405e70"))
        draw_arc(knob+Vector2(0,-2),18,PI,TAU,24,Color("#c1d4dc"),2,true)

func initialize(owner: Node3D) -> void:
    game=owner
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    _deck=Control.new()
    _deck.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(_deck)
    _master=MasterConsole.new()
    _master.name="MasterUnit"
    _master.size=Vector2(132,284)
    _deck.add_child(_master)
    _view=_button("view","САЛОН",Vector2(100,54),func(): _toggle_cabin_salon())
    _platform=_button("platform","ПЛАТФОРМА",Vector2(100,54),func(): _select_mode("platform"))
    _flight=_button("flight","ПОЛЁТ",Vector2(100,54),func(): _select_mode("flight"))
    _doors=_button("doors","ДВЕРИ",Vector2(82,86),_toggle_doors)
    _speaker=_button("speaker","INFO",Vector2(72,78),func():
        var cab := _get_cab()
        if cab != null: cab.call("command","info"))
    _joystick=FlightStick.new()
    _joystick.size=Vector2(128,128)
    _deck.add_child(_joystick)
    resized.connect(_layout)
    _layout()
    _bind_cab()

func _button(kind: String,label: String,dimensions: Vector2,action: Callable) -> DeckButton:
    var button := DeckButton.new()
    button.kind=kind; button.label=label
    button.size=dimensions
    button.tooltip_text=label
    button.pressed.connect(action)
    _deck.add_child(button)
    return button

func _layout() -> void:
    if not is_instance_valid(_deck): return
    var factor := minf(size.x/390.0,size.y/550.0)
    factor=maxf(0.1,factor)
    _deck.scale=Vector2.ONE*factor
    _deck.size=size/factor
    var bounds := _deck.size
    _master.position=Vector2(10,bounds.y-296)
    _view.position=Vector2(bounds.x-110,80)
    _platform.position=Vector2(bounds.x-110,138)
    _flight.position=Vector2(bounds.x-110,196 if _platform.visible else 138)
    _doors.position=Vector2(bounds.x-174,bounds.y-98)
    _speaker.position=Vector2(bounds.x-82,bounds.y-90)
    _joystick.position=Vector2(bounds.x-138,bounds.y-246)

func _get_cab() -> Node3D:
    if not is_instance_valid(game): return null
    return game.get("cab_runtime") as Node3D

func _bind_cab() -> void:
    var cab := _get_cab()
    if cab == _cab: return
    _cab=cab
    if is_instance_valid(_cab):
        _cab.connect("master_interaction_changed",_physical_controller_changed)
        _physical_controller_changed(bool(_cab.call("master_is_held")))

func _physical_controller_changed(held: bool) -> void:
    _physical_held=held
    if held and _drag_kind == "master": _release_pointer()
    _master.visible=not held

func physical_controller_touched() -> void: _physical_controller_changed(true)
func physical_controller_released() -> void: _physical_controller_changed(false)

func blocks_cab_pointer(point: Vector2) -> bool:
    # Physical picking runs before GUI; reserve only actual screen control bounds.
    for control in [_master,_joystick,_view,_platform,_flight,_doors,_speaker]:
        if is_instance_valid(control) and control.is_visible_in_tree():
            if control.get_global_rect().has_point(point): return true
    return false

func _local_point(point: Vector2,control: Control) -> Vector2:
    return control.get_global_transform_with_canvas().affine_inverse()*point

func _input(event: InputEvent) -> void:
    if not is_instance_valid(_master): return
    var pointer := -2
    var point := Vector2.ZERO
    var press := false
    var release := false
    var moving := false
    if event is InputEventScreenTouch:
        pointer=event.index; point=event.position
        press=event.pressed; release=not event.pressed or event.canceled
    elif event is InputEventScreenDrag:
        pointer=event.index; point=event.position; moving=true
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.device == -1: return # Touch already owns its real finger stream.
        pointer=-1; point=event.position; press=event.pressed; release=not event.pressed
    elif event is InputEventMouseMotion:
        if event.device == -1: return
        pointer=-1; point=event.position; moving=true
    else: return
    if press and _touch == -2:
        if _master.visible and _master.get_global_rect().has_point(point) and not _physical_held:
            _drag_kind="master"
            _drag_start=_local_point(point,_master)
            _drag_value=float(_cab.call("get_master_value")) if is_instance_valid(_cab) else 0.0
            _drag_moved=false
        elif _joystick.visible and _joystick.get_global_rect().has_point(point):
            _drag_kind="stick"
        else: return
        _touch=pointer
        if _drag_kind == "stick": _move_stick(point)
        get_viewport().set_input_as_handled()
        return
    if pointer != _touch or _drag_kind.is_empty(): return
    if release:
        _release_pointer()
    elif moving:
        if _drag_kind == "master":
            var delta := _local_point(point,_master)-_drag_start
            if _drag_moved or absf(delta.y) >= 5.0:
                _drag_moved=true
                var value := clampf(_drag_value-delta.y/77.0,-1.0,1.0)
                if is_instance_valid(_cab): _cab.call("command","master",value)
        else: _move_stick(point)
    get_viewport().set_input_as_handled()

func _move_stick(point: Vector2) -> void:
    stick=(_local_point(point,_joystick)-_joystick.size*0.5)/45.0
    if stick.length() > 1.0: stick=stick.normalized()
    _joystick.axis=stick
    _joystick.queue_redraw()

func _release_pointer() -> void:
    # Release ownership only. The cab retains the commanded master setting.
    _touch=-2
    _drag_kind=""
    stick=Vector2.ZERO
    if is_instance_valid(_joystick):
        _joystick.axis=stick
        _joystick.queue_redraw()

func _toggle_cabin_salon() -> void:
    _select_mode("salon" if str(game.get("camera_mode")) == "cabin" else "cabin")

func _select_mode(mode: String) -> void:
    if mode == "platform" and not bool(game.call("platform_camera_available")): return
    _release_pointer()
    game.call("_set_camera_mode",mode)

func _toggle_doors() -> void:
    var doors := game.get("door_system") as Node
    if not is_instance_valid(doors) or not bool(doors.get("validated")): return
    var cab := _get_cab()
    if cab == null: return
    var targets: Dictionary=doors.get("side_targets")
    # Route uses the left platform side. Never invoke request_open (both sides).
    cab.call("command","close" if bool(targets.get(-1,false)) else "openLeft")

func _process(_delta: float) -> void:
    if not is_instance_valid(game) or not is_instance_valid(_master): return
    _bind_cab()
    if is_instance_valid(_cab):
        var current := float(_cab.call("get_master_value"))
        lever=current
        if not is_equal_approx(_master.value,current):
            _master.value=current
            _master.queue_redraw()
    var mode := str(game.get("camera_mode"))
    var was_flight := flight
    flight=mode == "flight"
    _joystick.visible=flight
    if not flight and was_flight: _release_pointer()
    var available := bool(game.call("platform_camera_available"))
    if _platform.visible != available:
        _platform.visible=available
        _layout()
    var view_label := "КАБИНА" if mode == "salon" else "САЛОН"
    if _view.label != view_label:
        _view.label=view_label
        _view.queue_redraw()
    for button in [_view,_platform,_flight]:
        var active: bool=(button == _view and mode in ["cabin","salon"]) or (button == _platform and mode == "platform") or (button == _flight and flight)
        if button.selected != active:
            button.selected=active
            button.queue_redraw()
    var doors := game.get("door_system") as Node
    if is_instance_valid(doors):
        var fractions: Dictionary=doors.get("side_open")
        var amount := float(fractions.get(-1,0.0))
        if not is_equal_approx(_doors.amount,amount):
            _doors.amount=amount
            _doors.queue_redraw()
        _doors.disabled=not bool(doors.get("validated"))
    if is_instance_valid(_cab):
        var radio := _cab.get("_radio") as AudioStreamPlayer
        var playing := is_instance_valid(radio) and radio.playing
        if playing != _speaker.selected:
            _speaker.selected=playing
            _speaker.queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _release_pointer()
