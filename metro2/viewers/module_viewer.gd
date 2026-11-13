extends Node3D
const Catalog = preload("res://modules/core/module_catalog.gd")
const CameraRig = preload("res://viewers/inspection_camera.gd")
const Joystick = preload("res://viewers/flight_joystick.gd")
const PackLoader = preload("res://viewers/module_pack_loader.gd")
var _pack_loader: Node
const INSPECTION_TRAIN := "res://viewers/v106_inspection.tscn"
const AD_STATUS := "ADVERTISING: ENABLED — V49 FIXED MOUNTS"
var active_module: Node3D
var active_key := ""
var selected_car := 1
var busy := false
var rig: Node3D
var collision: StaticBody3D
var _single_car := false
var _status: Label
var _diagnostics: Label
var _menu: PanelContainer
var _train_tools: HFlowContainer
var _toolbar: HFlowContainer
var _joystick: Control
var _hint: Label
var _menu_scroll: ScrollContainer
var _environment: Environment
var _sun: DirectionalLight3D
var _car_label: Label
var _home_point := Vector3.ZERO
var _home_radius := 25.0
var _view_kind := "external"

func _ready() -> void:
    _create_world()
    rig = CameraRig.new()
    rig.name = "ViewerCameraRig"
    add_child(rig)
    _build_ui()
    _pack_loader = PackLoader.new()
    add_child(_pack_loader)
    _pack_loader.progress.connect(_set_status)
    get_viewport().size_changed.connect(_layout_ui)
    _layout_ui()
    _set_status("Выберите модуль для осмотра")
    _publish_state()

func _create_world() -> void:
    var world := WorldEnvironment.new()
    _environment = Environment.new()
    _environment.background_mode = Environment.BG_COLOR
    _environment.background_color = Color(0.08,0.10,0.13)
    _environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    _environment.ambient_light_color = Color(0.85,0.90,1.0)
    _environment.ambient_light_energy = 0.65
    world.environment = _environment
    add_child(world)
    _sun = DirectionalLight3D.new()
    _sun.rotation_degrees = Vector3(-47,-38,0)
    _sun.light_energy = 1.05
    add_child(_sun)

func _button(parent: Node, text: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(70,56)
    button.focus_mode = Control.FOCUS_NONE
    button.pressed.connect(action)
    parent.add_child(button)
    return button

func _build_ui() -> void:
    var ui := CanvasLayer.new()
    ui.name = "ViewerInterface"
    add_child(ui)
    var toolbar := HFlowContainer.new()
    _toolbar = toolbar
    toolbar.position = Vector2(10,8)
    ui.add_child(toolbar)
    _button(toolbar,"Модули",func():
        _menu.visible = not _menu.visible
        _joystick.visible = not _menu.visible and is_instance_valid(active_module)
        rig.clear_gestures())
    _button(toolbar,"Сброс",reset_view)
    _status = Label.new()
    _status.position = Vector2(12,62)
    _status.add_theme_font_size_override("font_size",18)
    ui.add_child(_status)
    _diagnostics = Label.new()
    _diagnostics.position = Vector2(12,88)
    _diagnostics.add_theme_font_size_override("font_size",15)
    _diagnostics.modulate = Color(1.0,0.83,0.35)
    ui.add_child(_diagnostics)
    _menu = PanelContainer.new()
    _menu.z_index = 10
    _menu.position = Vector2(10,145)
    _menu.custom_minimum_size = Vector2(270,0)
    ui.add_child(_menu)
    var list := VBoxContainer.new()
    _menu_scroll = ScrollContainer.new()
    _menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _menu.add_child(_menu_scroll)
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _menu_scroll.add_child(list)
    for group in [
        ["ПОЕЗДА",[["Состав V106 · 4 вагона","v106"],["Вагон №1","car1"],["Вагон №2","car2"],["Вагон №3","car3"],["Вагон №4","car4"]]],
        ["СТАНЦИИ",[["Уручье","uruchye"],["Борисовский тракт","borisovsky_trakt"]]],
        ["ТОННЕЛИ",[["Стандартный участок · 16 м","tunnel_16m"]]],
        ["ДЕПО",[["Электродепо","depot"]]]]:
        var heading := Label.new()
        heading.text = group[0]
        list.add_child(heading)
        for entry in group[1]:
            var key: String = entry[1]
            var button := _button(list,entry[0],func(): open_module(key))
            button.custom_minimum_size.y = 52
    _train_tools = HFlowContainer.new()
    _train_tools.position = Vector2(310,145)
    _train_tools.hide()
    ui.add_child(_train_tools)
    _button(_train_tools,"◀",func(): focus_car(wrapi(selected_car-1,1,5)))
    _car_label = Label.new()
    _train_tools.add_child(_car_label)
    _button(_train_tools,"▶",func(): focus_car(wrapi(selected_car+1,1,5)))
    _button(_train_tools,"Снаружи",func(): focus_car(selected_car))
    _button(_train_tools,"Салон",func(): inspect_interior("salon"))
    _button(_train_tools,"Кабина №1",func(): inspect_interior("cab"))
    _joystick = Joystick.new()
    _joystick.name = "FlightJoystick"
    _joystick.size = Vector2(160,160)
    ui.add_child(_joystick)
    _joystick.axis_changed.connect(func(axis: Vector2): rig.move_axis = Vector3(axis.x,0,axis.y))
    _joystick.hide()
    var hint := Label.new()
    _hint = hint
    hint.position = Vector2(-520,-35)
    hint.text = "1 палец: вращение · 2: зум · WASD / Q,E: обзор"
    hint.add_theme_font_size_override("font_size",14)
    ui.add_child(hint)

func _set_status(message: String) -> void:
    _status.text = message
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.metro2ViewerLoadStatus = "+JSON.stringify(message)+"; null",true)

func open_module(key: String) -> void:
    if busy: return
    if not (Catalog.SCENES.has(key) or key in ["car1","car2","car3","car4"]):
        _set_status("Неизвестный модуль: " + key)
        return
    busy = true
    _set_status("Загрузка: " + key)
    if not await _pack_loader.ensure_module(key):
        busy = false
        _menu.show()
        return
    await unload_module()
    await get_tree().process_frame
    var train_selection := key == "v106" or key.begins_with("car")
    if train_selection:
        # Single-thread Web builds must not wait on a background dependency graph.
        # Resolve each heavy imported model on the main thread, yielding between
        # resources; the final scene then reuses those cached resources.
        var scene: PackedScene = await _pack_loader.prepare_train_scene(INSPECTION_TRAIN)
        if scene != null:
            _set_status("Создание состава V106…")
            await get_tree().process_frame
            active_module = scene.instantiate() as Node3D
    else:
        active_module = Catalog.create_module(key)
    if active_module == null:
        _menu.show()
        _set_status("Ошибка загрузки модуля: " + key + ". Можно повторить выбор.")
        busy = false
        return
    active_key = key
    add_child(active_module)
    _single_car = key.begins_with("car")
    selected_car = int(key.substr(3)) if _single_car else 1
    if train_selection:
        # V47 defers the fourth car. Yield through its initialization once.
        var ready_started := Time.get_ticks_msec()
        while (not is_instance_valid(active_module.get("door_system")) or not is_instance_valid(active_module.get("cab_runtime"))) and Time.get_ticks_msec()-ready_started < 15000:
            await get_tree().process_frame
        if not is_instance_valid(active_module.get("door_system")) or not is_instance_valid(active_module.get("cab_runtime")):
            _set_status("Состав не готов; можно выбрать другой модуль")
            busy = false
            return
        active_module.set("camera",rig.camera)
        _set_car_visibility()
        _diagnostics.text = AD_STATUS + "\nWARNING STICKER RESTORE: DISABLED IN VIEWER"
        if _single_car: _diagnostics.text += "\nSINGLE CAR: FULL CONSIST LOADED (V47 DEPENDENCY)"
    else:
        _diagnostics.text = "Оригинальный модуль · без загрузки поезда"
    _joystick.show()
    _train_tools.visible = train_selection
    call_deferred("_layout_ui")
    _menu.hide()
    _configure_light(key)
    rig.camera.make_current()
    busy = false
    if train_selection:
        focus_car(selected_car)
        if not _single_car:
            _home_point = _bounds(active_module.get("train")).get_center()
            _home_radius = 85.0
            reset_view()
    else:
        match key:
            "borisovsky_trakt":
                _home_point = Vector3(-4.3,2.6,48.0)
                _home_radius = 3.0
            "uruchye":
                _home_point = Vector3(-5.37,2.5,39.6)
                _home_radius = 45.0
            "tunnel_16m":
                _home_point = Vector3(0.992,2.5,8)
                _home_radius = 10.0
            "depot":
                _home_point = Vector3(0.992,9,450)
                _home_radius = 160.0
        rig.move_speed = 28.0 if key == "depot" else 7.0
        reset_view()
    _set_status("Открыт: " + key + " · Свободный полёт")
    _publish_state()

func unload_module() -> void:
    rig.enabled = false
    rig.clear_gestures()
    _joystick.reset()
    _joystick.hide()
    if is_instance_valid(collision):
        collision.collision_layer = 0
        collision.queue_free()
    collision = null
    if is_instance_valid(active_module): active_module.queue_free()
    active_module = null
    active_key = ""
    _train_tools.hide()
    # Never instantiate the next module while the old subtree is pending deletion.
    await get_tree().process_frame

func _configure_light(key: String) -> void:
    _environment.ambient_light_energy = 0.085 if key == "tunnel_16m" else 0.42 if key in ["uruchye","borisovsky_trakt"] else 0.65
    _sun.light_energy = 0.025 if key == "tunnel_16m" else 0.15 if key in ["uruchye","borisovsky_trakt"] else 1.05
    _environment.background_color = Color(0.006,0.008,0.012) if key == "tunnel_16m" else Color(0.08,0.10,0.13)

func _set_car_visibility() -> void:
    var consist := active_module.get("train") as Node3D
    for node in consist.get_children():
        if not node is Node3D: continue
        var number := str(node.name).trim_prefix("OriginalV106Car").to_int()
        node.visible = not _single_car or number == selected_car

func focus_car(index: int) -> void:
    if busy or not is_instance_valid(active_module) or not (active_key == "v106" or active_key.begins_with("car")): return
    selected_car = clampi(index,1,4)
    if _single_car:
        _set_car_visibility()
    var car := (active_module.get("train") as Node3D).get_node("OriginalV106Car%02d" % selected_car) as Node3D
    var bounds := _bounds(car)
    _home_point = bounds.get_center()
    _home_radius = maxf(12.0,bounds.size.length()*0.9)
    _car_label.text = "Вагон %d/4" % selected_car
    rig.move_speed = 7.0
    reset_view()
    _publish_state()

func inspect_interior(kind: String) -> void:
    if busy or not is_instance_valid(active_module) or not _train_tools.visible: return
    var consist := active_module.get("train") as Node3D
    var pose := Transform3D.IDENTITY
    if kind == "cab":
        if _single_car and selected_car != 1:
            focus_car(1)
        var cab := active_module.get("cab_runtime") as Node3D
        var eye: Vector3 = cab.call("eye_in_train")
        pose = Transform3D(consist.global_basis,consist.to_global(eye))
    else:
        var car := consist.get_node("OriginalV106Car%02d" % selected_car) as Node3D
        var equipment := active_module.get("passenger_equipment") as Node3D
        var mount := equipment.call("camera_mount",car) as Node3D
        pose = mount.global_transform
    _view_kind = kind
    rig.enter_interior(pose)
    _set_status("Кабина №1" if kind == "cab" else "Салон вагона %d" % selected_car)
    _publish_state()

func reset_view() -> void:
    if not is_instance_valid(active_module) or busy: return
    _view_kind = "external"
    _set_status("Свободный полёт · джойстик и жесты")
    _joystick.reset()
    rig.frame_point(_home_point,_home_radius)
    if active_key in ["uruchye","tunnel_16m"]:
        rig.yaw = 0.0
        rig.pitch = 0.03
        rig._apply(false)
    _publish_state()

func _bounds(module: Node3D) -> AABB:
    var result := AABB()
    var found := false
    for node in module.find_children("*","MeshInstance3D",true,false):
        var mesh := node as MeshInstance3D
        if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
        var bounds := mesh.global_transform*mesh.get_aabb()
        result = result.merge(bounds) if found else bounds
        found = true
    return result

func diagnostic_state() -> Dictionary:
    return {"module":active_key,"loaded_modules":1 if is_instance_valid(active_module) else 0,
        "car":selected_car,"view":_view_kind,"free":rig.free_mode,"busy":busy,
        "collision_proxies":collision.get_meta("proxy_count",0) if is_instance_valid(collision) else 0,
        "advertising":AD_STATUS if _train_tools.visible else "NOT LOADED",
        "single_car_full_consist":_single_car and _train_tools.visible}

func _publish_state() -> void:
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.metro2ViewerDiagnostics = "+JSON.stringify(diagnostic_state())+"; null",true)

func _layout_ui() -> void:
    if not is_instance_valid(_toolbar): return
    var viewport_size := get_viewport().get_visible_rect().size
    var width := viewport_size.x
    var height := viewport_size.y
    var portrait := height > width
    var top := 90.0
    _toolbar.position = Vector2(12,top)
    _toolbar.size.x = width-24.0
    _toolbar.size.y = 0.0
    _status.position = Vector2(12,top+68)
    _status.size = Vector2(width-24,48)
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _diagnostics.position = Vector2(12,top+118)
    _diagnostics.size = Vector2(width-24,76)
    _diagnostics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _train_tools.position = Vector2(12 if portrait else 200,top+205)
    _train_tools.size = Vector2(width-24 if portrait else width-212,0)
    _joystick.position = Vector2(20,height-190)
    _hint.position = Vector2(12,height-30)
    _hint.size.x = width-24
    _hint.text = "Джойстик — полёт · палец — взгляд · 2 — зум" if portrait else "Джойстик / WASD — полёт · палец / мышь — взгляд · 2 пальца / колесо — зум"
    var menu_top := top+205
    _menu.position = Vector2(12,menu_top)
    _menu.custom_minimum_size = Vector2(minf(340,width-24),0)
    _menu_scroll.custom_minimum_size = Vector2(0,maxf(80,height-menu_top-215))
    _menu.size = Vector2(minf(340,width-24),maxf(80,height-menu_top-215))
    _menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
