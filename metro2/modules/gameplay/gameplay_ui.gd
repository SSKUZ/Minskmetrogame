extends CanvasLayer
const Joystick = preload("res://viewers/flight_joystick.gd")
var service: Node
var root: Control
var menu: PanelContainer
var station: OptionButton
var role_button: Button
var interact: Button
var walk_button: Button
var status: Label
var message: Label
var warning: PanelContainer
var stick: Control
var _look_pointer:=-1
var _notice_left:=0.0
var flash: ColorRect

func initialize(owner_service: Node) -> void:
    service=owner_service
    layer=20
    root=Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    root.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(root)
    var top:=HBoxContainer.new()
    root.add_child(top)
    top.position=Vector2(12,12)
    role_button=_button(top,"РЕЖИМ ПАССАЖИРА",func(): service.switch_role("passenger" if service.role=="driver" else "driver"))
    walk_button=_button(top,"ИДТИ",func(): service.leave_driver())
    var view:=MenuButton.new()
    view.text="ОБЗОР"
    top.add_child(view)
    for title in ["От первого лица","Кабина","Салон","Платформа","Свободная камера"]: view.get_popup().add_item(title)
    view.get_popup().id_pressed.connect(func(id: int):
        if id==1 and not service.driver_seated: return
        service.player.stick=Vector2.ZERO
        service.train._flight_ui.stick=Vector2.ZERO
        _look_pointer=-1
        service.train._set_camera_mode(["walk","cabin","salon","platform","flight"][id]))
    status=Label.new()
    root.add_child(status)
    status.position=Vector2(14,70)
    message=Label.new()
    root.add_child(message)
    message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    message.offset_left=-230
    message.offset_right=230
    message.offset_top=110
    message.offset_bottom=162
    message.custom_minimum_size=Vector2(460,52)
    message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    message.mouse_filter=Control.MOUSE_FILTER_IGNORE
    stick=Joystick.new()
    root.add_child(stick)
    stick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    stick.offset_left=14
    stick.offset_right=184
    stick.offset_top=-192
    stick.offset_bottom=-22
    stick.axis_changed.connect(func(axis: Vector2):
        if service.train.camera_mode=="flight":
            service.train._flight_ui.stick=axis
            service.player.stick=Vector2.ZERO
        else: service.player.stick=axis)
    interact=Button.new()
    root.add_child(interact)
    interact.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    interact.offset_left=-302
    interact.offset_right=-12
    interact.offset_top=-100
    interact.offset_bottom=-28
    interact.pressed.connect(func(): service.interaction.activate())
    flash=ColorRect.new()
    root.add_child(flash)
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    flash.color=Color(0.8,0.15,0.05,0.0)
    flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _start_menu()
    _absence_panel()
    set_play_visible(false)
    get_viewport().size_changed.connect(_resize)
    _resize()

func _resize() -> void:
    var viewport_size: Vector2=get_viewport().get_visible_rect().size
    var scale_factor: float=minf(1.0,viewport_size.x/560.0)
    root.scale=Vector2.ONE*scale_factor
    root.size=viewport_size/maxf(scale_factor,0.1)

func _button(parent: Node, title: String, callback: Callable) -> Button:
    var button:=Button.new()
    button.text=title
    button.custom_minimum_size=Vector2(140,46)
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func _start_menu() -> void:
    menu=PanelContainer.new()
    root.add_child(menu)
    menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    menu.offset_left=-220
    menu.offset_right=220
    menu.offset_top=-145
    menu.offset_bottom=145
    menu.custom_minimum_size=Vector2(440,290)
    var column:=VBoxContainer.new()
    menu.add_child(column)
    var title:=Label.new()
    title.text="МИНСКОЕ МЕТРО 2.0\nВыберите игровую роль"
    title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    _button(column,"МАШИНИСТ · НАЧАТЬ В ДЕПО",func(): service.start_role("driver",0))
    station=OptionButton.new()
    column.add_child(station)
    var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://audio/data/route_stations.json"))
    for record in service.line.stations:
        var title_text: String=str(route.station_names.get(str(record.info_id),record.module_id))
        station.add_item(title_text)
    _button(column,"ПАССАЖИР · НАЧАТЬ НА СТАНЦИИ",func(): service.start_role("passenger",station.selected))
    var hint:=Label.new()
    hint.text="Ходьба: джойстик / WASD\nОбзор: палец справа / правая кнопка мыши\nВзаимодействие: кнопка / E"
    column.add_child(hint)

func _absence_panel() -> void:
    warning=PanelContainer.new()
    root.add_child(warning)
    warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    warning.offset_left=-240
    warning.offset_right=240
    warning.offset_top=165
    warning.offset_bottom=305
    warning.custom_minimum_size=Vector2(480,140)
    var column:=VBoxContainer.new()
    warning.add_child(column)
    var label:=Label.new()
    label.text="ЗАДЕРЖКА ОТПРАВЛЕНИЯ\nВернитесь в кабину и продолжите рейс\nлибо перейдите в режим пассажира"
    label.add_theme_color_override("font_color",Color(1,0.20,0.15))
    column.add_child(label)
    var row:=HBoxContainer.new()
    column.add_child(row)
    _button(row,"Продолжить рейс",func(): warning.hide())
    _button(row,"Режим пассажира",func(): service.switch_role("passenger"))
    warning.hide()

func set_play_visible(enabled: bool) -> void:
    for item in [role_button.get_parent(),status,stick,interact]: item.visible=enabled
    menu.visible=not enabled

func notice(text: String) -> void:
    message.text=text
    _notice_left=6.0

func _process(delta: float) -> void:
    flash.color.a=move_toward(flash.color.a,0.0,delta*0.65)
    _notice_left=maxf(0.0,_notice_left-delta)
    message.visible=_notice_left>0.0
    if not service.running: return
    role_button.text="РЕЖИМ МАШИНИСТА" if service.role=="passenger" else "РЕЖИМ ПАССАЖИРА"
    walk_button.visible=service.driver_seated
    stick.visible=not service.driver_seated and not service.player.seated and service.train.camera_mode in ["walk","flight"]
    status.text=("МАШИНИСТ" if service.role=="driver" else "ПАССАЖИР")+" · "+("В составе" if is_instance_valid(service.player.aboard) else "На станции / в депо")

func _unhandled_input(event: InputEvent) -> void:
    if not service.running: return
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E:
        service.interaction.activate()
        get_viewport().set_input_as_handled()
        return
    if service.driver_seated or service.train.camera_mode!="walk": return
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x>get_viewport().get_visible_rect().size.x*0.36 and _look_pointer<0: _look_pointer=event.index
        elif not event.pressed and event.index==_look_pointer: _look_pointer=-1
    elif event is InputEventScreenDrag and event.index==_look_pointer:
        service.player.look(event.relative)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        service.player.look(event.relative)
        get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
        _look_pointer=-1
        if is_instance_valid(service) and is_instance_valid(service.player):
            service.player.stick=Vector2.ZERO
            if is_instance_valid(service.train._flight_ui): service.train._flight_ui.stick=Vector2.ZERO

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and (not event.pressed or event.canceled) and event.index==_look_pointer:
        _look_pointer=-1
