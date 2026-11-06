extends Node3D
## Runtime bindings for the complete saved cab-r2 from cab-development/aef6e01a10c9.
## Control IDs, positions and handle animation follow js/cab/CabControls.js.
const CAB_SCENE = preload("res://assets/cab/cab_81_717_r2.glb")
const POSITION := Vector3(0,0.8975,-10.15)
const EYE := Vector3(-0.55,1.7525,2.03)
const CONTROL_IDS := ["cabLight","headlights","sandLeft","sandRight","wiperLeft","wiperRight","lampTest","reset","ars","open","close","doorBlock","mode","reserve","master","brake1","brake2","ept","release","service","emergency","horn","brake","volume","info","radioTalk","radioReset","radioCall","radioLine","radioClear","radioPgs","radioDsp","radioReserve","carriage","platform","forward","mirrorLeft","mirrorRight","heatLeft","heatRight"]
const CONTROL_TITLES := {"cabLight": "Освещение кабины", "headlights": "Фары", "sandLeft": "Песок слева", "sandRight": "Песок справа", "wiperLeft": "Левый дворник", "wiperRight": "Правый дворник", "lampTest": "Проверка ламп", "reset": "Сброс", "ars": "Контроль скорости АРС", "open": "Открыть выбранную сторону", "close": "Закрыть двери", "doorBlock": "Блокировка открывания дверей", "mode": "Поддержание скорости", "reserve": "Резервная тяга", "master": "Контроллер: нейтраль", "brake1": "Тормозной кран 1", "brake2": "Тормозной кран 2", "ept": "Электропневматический тормоз", "release": "Отпуск тормоза", "service": "Служебный тормоз", "emergency": "Экстренный тормоз", "horn": "Звуковой сигнал", "brake": "Тормозной кран", "volume": "Громкость", "info": "Информация о составе", "radioTalk": "Радио: передача", "radioReset": "Радио: сброс", "radioCall": "Радио: вызов", "radioLine": "Радио: линейный канал", "radioClear": "Радио: отбой", "radioPgs": "Радио: ПГС", "radioDsp": "Радио: ДСП", "radioReserve": "Радио: резервный канал", "carriage": "Монитор: салон", "platform": "Монитор: платформа", "forward": "Монитор: путь", "mirrorLeft": "Левое зеркало", "mirrorRight": "Правое зеркало", "heatLeft": "Обогрев левого стекла", "heatRight": "Обогрев правого стекла"}
const ROTARIES := ["cabLight","headlights","wiperLeft","wiperRight","mode","reserve","brake1","brake2","ept","volume","mirrorLeft","mirrorRight","heatLeft","heatRight"]
const PICK_MASK := 1 << 12
var game: Node3D
var doors: Node
var model: Node3D
var controls: Dictionary = {}
var moving: Dictionary = {}
var bases: Dictionary = {}
var switches := {"cabLight":true,"headlights":true,"wiperLeft":false,"wiperRight":false,"ars":false,"doorBlock":false,"mode":false,"reserve":false,"ept":true,"mirrorLeft":true,"mirrorRight":true,"heatLeft":false,"heatRight":false}
var controller_notch := 0
var brake_demand := 0.0
var applied_brake := 0.0
var direction := 1
var door_side := -1
var lamp_test := false
var emergency := false
var horn_active := false
var radio_tx := false
var sand_left := false
var sand_right := false
var target_speed := 8.33
var traction_actual := 0.0
var voltage_kv := 0.75
var current_ka := 0.0
var line_pressure := 5.0
var cylinder_pressure := 0.0
var window_temperature := Vector2(8,8)
var volume := 0.6
var radio_channel := "ЛИНИЯ"
var radio_call := false
var ready_for_play := false
var notice := "Пульт готов · W/S: контроллер · Пробел: тормоз"
var clock := 0.0
var _active := ""
var _pointer := -2
var _drag_origin := Vector2.ZERO
var _dragged := false
var _lever_start := 0.0
var _cab_light: SpotLight3D
var _cab_fill: OmniLight3D
var _cab_light_button: Button
var _horn: AudioStreamPlayer
var _radio: AudioStreamPlayer
var _radio_readout: Label3D
var _readout: Label3D
var _speed_segments: Array[MeshInstance3D] = []
var _pilot_materials: Array[BaseMaterial3D] = []
var _pilot_colors: Array[Color] = []
var _gauge_needles: Array[Node3D] = []
var _mirrors: Array[Dictionary] = []
var _monitor: Dictionary = {}
var _monitor_mode := "carriage"
var _video_clock := 0.0
var _lamp_materials: Array[BaseMaterial3D] = []

func initialize(owner_game: Node3D, lead: Node3D, door_system: Node) -> void:
    game = owner_game
    doors = door_system
    position = POSITION
    _hide_old_interior(lead)
    model = CAB_SCENE.instantiate() as Node3D
    model.name = "OriginalCab81_717_R2"
    add_child(model)
    # Recover the original lining, labels, side-door hardware and front bulkhead.
    # Fit only its structural shell to the existing V106 cabin partition.
    var shell := model.find_child("CabInteriorShell",true,false) as Node3D
    if shell != null:
        _fit_original_shell(shell)
    # Fit freestanding equipment to the retained V106 side walls.
    var radio := model.find_child("RadioConsole",true,false) as Node3D
    radio.position.x += 0.10
    var cctv := model.find_child("CabCCTV",true,false) as Node3D
    cctv.position.x -= 0.14
    for root in model.get_children():
        if root is Node3D and absf(root.position.x+1.145) < 0.005 and absf(root.position.z-1.89) < 0.005:
            root.position.x += 0.09
    for mesh in model.find_children("*","MeshInstance3D",true,false):
        (mesh as MeshInstance3D).layers = 2
    for id in CONTROL_IDS:
        var node := model.find_child("Moving_master" if id == "master" else "Control_"+id,true,false) as Node3D
        var handle := model.find_child("Moving_"+id,true,false) as Node3D
        if node == null or handle == null:
            push_error("Original cab control missing: "+id)
            continue
        controls[id] = node
        moving[id] = handle
        bases[id] = handle.transform
        _add_pick_volume(node,id)
    _bind_instruments()
    _install_audio()
    _install_video()
    _cab_light = SpotLight3D.new()
    _cab_light.position = Vector3(-0.62,2.04,1.91)
    _cab_light.light_color = Color(1.0,0.93,0.82)
    _cab_light.light_energy = 2.0
    _cab_light.spot_range = 3.2
    _cab_light.spot_angle = 68.0
    _cab_light.spot_attenuation = 1.1
    _cab_light.spot_angle_attenuation = 1.2
    _cab_light.light_cull_mask = 2
    add_child(_cab_light)
    _cab_light.look_at(to_global(Vector3(0.18,0.98,1.25)),Vector3.UP)
    _cab_fill = OmniLight3D.new()
    _cab_fill.position = Vector3(0.65,1.85,1.95)
    _cab_fill.light_color = Color(0.94,0.96,1.0)
    _cab_fill.light_energy = 0.6
    _cab_fill.omni_range = 2.8
    _cab_fill.light_cull_mask = 2
    add_child(_cab_fill)
    # Both local lamps affect only cabin layer 2, never tunnel layer 1 or glass.
    for child in lead.find_children("*","MeshInstance3D",true,false):
        var instance := child as MeshInstance3D
        if not model.is_ancestor_of(instance):
            var box := lead.global_transform.affine_inverse()*instance.global_transform*instance.get_aabb()
            if box.end.z < -7.3:
                instance.layers |= 2
    _restore_neutral_glazing(lead)
    _apply_cab_light()
    for lamp in lead.find_children("headlamp-*","Node3D",true,false):
        for child in lamp.find_children("*","MeshInstance3D",true,false):
            var instance := child as MeshInstance3D
            for surface in range(instance.mesh.get_surface_count()):
                var material := instance.get_active_material(surface) as BaseMaterial3D
                if material != null and material.emission_enabled and not _lamp_materials.has(material):
                    _lamp_materials.append(material)
    ready_for_play = controls.size() == CONTROL_IDS.size()
    print("CAB_V34_READY original_r2_sha256=3d236f283081d6a88d87e4d4d3265a358a0a2124bf2a883db711d03eab92fea3 controls=",controls.size())

func _fit_original_shell(shell: Node3D) -> void:
    for child in shell.get_children():
        if not child is Node3D: continue
        var item := child as Node3D
        if item.position.z > 2.35 and item.position.z < 2.9 and item.position.y < 1.0 and absf(item.position.x) < 0.01:
            item.reparent(model,true)
            item.position += Vector3(-0.55,0,-0.55)
        elif absf(item.position.x) > 1.3 and absf(item.position.z-1.6) < 0.01:
            # Original side-door group: retain every fitting, label and switch.
            item.position.x = signf(item.position.x)*1.265
            item.position.z = 1.45
            item.scale.x *= 0.8
        elif item.position.z > 3.4:
            item.position.z -= 1.17
        elif item is MeshInstance3D:
            var bounds := item.transform*(item as MeshInstance3D).get_aabb()
            if bounds.size.z > 2.8:
                item.position.z = 0.38+(item.position.z-0.38)*0.65
                item.scale.z *= 0.65
    # The authored floor ribs are shared instances; retain those inside the cab.
    for child in shell.find_children("*","MeshInstance3D",true,false):
        var mesh := child as MeshInstance3D
        var bounds := model.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
        if bounds.size.y < 0.005 and bounds.size.z < 0.01 and bounds.position.z > 2.4:
            mesh.hide()

func _restore_neutral_glazing(lead: Node3D) -> void:
    var neutral: Dictionary = {}
    for child in lead.find_children("*","MeshInstance3D",true,false):
        var mesh := child as MeshInstance3D
        var in_original := model.is_ancestor_of(mesh)
        var bounds := lead.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
        if not in_original and (bounds.get_center().z > -7.5 or bounds.get_center().y < 2.0): continue
        for surface in range(mesh.mesh.get_surface_count()):
            var source := mesh.get_active_material(surface) as BaseMaterial3D
            if source == null or source.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA: continue
            # Original lettering/decals have textures and must remain untouched.
            if source.albedo_texture != null or source.albedo_color.a > 0.5: continue
            if not neutral.has(source):
                var glass := source.duplicate() as BaseMaterial3D
                # Remove the fixed bright unlit/reflection veil. The same neutral
                # transmission applies from every camera, with no exposure change.
                glass.albedo_color = Color(0,0,0,0.018)
                glass.emission_enabled = false
                glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                glass.metallic = 0.0
                glass.metallic_specular = 0.0
                glass.refraction_enabled = false
                neutral[source] = glass
            mesh.set_surface_override_material(surface,neutral[source])
            mesh.layers = 4

func _apply_cab_light() -> void:
    var enabled: bool = switches.cabLight
    if _cab_light != null: _cab_light.visible = enabled
    if _cab_fill != null: _cab_fill.visible = enabled
    if _cab_light_button != null:
        _cab_light_button.text = "СВЕТ КАБИНЫ: "+("ВКЛ." if enabled else "ВЫКЛ.")
        _cab_light_button.set_pressed_no_signal(enabled)

func _hide_old_interior(lead: Node3D) -> void:
    for child in lead.find_children("*","MeshInstance3D",true,false):
        var mesh := child as MeshInstance3D
        var bounds := lead.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
        # Completely internal old desk, seat and equipment only. Exterior,
        # passenger doors, floor, rear partition and all window glass stay intact.
        if bounds.position.z > -9.6 and bounds.position.z < -7.9 and bounds.end.z < -7.75 and bounds.position.y > 0.90 and bounds.end.y < 3.3 and bounds.position.x > -1.26 and bounds.end.x < 1.26:
            mesh.hide()

func eye_in_train() -> Vector3:
    return (game.get("train") as Node3D).to_local(to_global(EYE))

func _add_pick_volume(root: Node3D, id: String) -> void:
    var box := AABB()
    var found := false
    var meshes: Array[Node] = root.find_children("*","MeshInstance3D",true,false)
    if root is MeshInstance3D:
        meshes.append(root)
    for child in meshes:
        var mesh := child as MeshInstance3D
        var bounds := root.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
        box = box.merge(bounds) if found else bounds
        found = true
    var body := StaticBody3D.new()
    body.collision_layer = PICK_MASK
    body.collision_mask = 0
    body.set_meta("cab_control",id)
    root.add_child(body)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(maxf(box.size.x,0.065),maxf(box.size.y,0.065),maxf(box.size.z,0.055))
    collision.shape = shape
    collision.position = box.get_center()
    body.add_child(collision)

func handle_input(event: InputEvent, camera: Camera3D) -> bool:
    if str(game.get("camera_mode")) != "cabin":
        return false
    if event is InputEventKey and event.pressed and not event.echo:
        var keys := {KEY_W:"tractionUp",KEY_S:"tractionDown",KEY_N:"release",KEY_B:"service",KEY_SPACE:"emergency",KEY_O:"openRight" if event.shift_pressed else "openLeft",KEY_P:"close",KEY_F:"headlights",KEY_L:"cabLight",KEY_H:"horn",KEY_R:"reverse",KEY_I:"info"}
        if keys.has(event.physical_keycode):
            command(keys[event.physical_keycode])
            return true
    if event is InputEventKey and not event.pressed and event.physical_keycode == KEY_H:
        command("horn",0.0,"release")
        return true
    var press := false
    var release := false
    var point := Vector2.ZERO
    var relative := Vector2.ZERO
    var pointer := -2
    if event is InputEventScreenTouch:
        press = event.pressed
        release = not event.pressed
        point = event.position
        pointer = event.index
    elif event is InputEventScreenDrag:
        point = event.position
        relative = event.relative
        pointer = event.index
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        press = event.pressed
        release = not event.pressed
        point = event.position
        pointer = -1
    elif event is InputEventMouseMotion:
        point = event.position
        relative = event.relative
        pointer = -1
    else:
        return false
    if press:
        if not _active.is_empty(): return true
        var start := camera.project_ray_origin(point)
        var ray := PhysicsRayQueryParameters3D.create(start,start+camera.project_ray_normal(point)*5.0,PICK_MASK)
        var hit := get_world_3d().direct_space_state.intersect_ray(ray)
        if hit.is_empty():
            return false
        var body := hit["collider"] as Node
        _active = str(body.get_meta("cab_control",""))
        _pointer = pointer
        _drag_origin = point
        _dragged = false
        _lever_start = float(controller_notch)/5.0 if _active == "master" else brake_demand
        if _active not in ["master","brake","brake1","brake2"]:
            command(_active)
        return true
    if _active.is_empty() or pointer != _pointer:
        return false
    if release:
        if _active in ["master","brake","brake1","brake2"] and not _dragged:
            if _active == "master":
                command("tractionUp")
            else:
                command("brake",fmod(brake_demand+0.25,1.25))
        command(_active,0.0,"release")
        _active = ""
        _pointer = -2
        return true
    if relative != Vector2.ZERO and _active in ["master","brake","brake1","brake2"]:
        if point.distance_to(_drag_origin) > 4.0:
            _dragged = true
            var value := _lever_start+(_drag_origin.y-point.y)*0.008
            command(_active,clampf(value,-1.0,1.0) if _active == "master" else clampf(-value+2.0*_lever_start,0.0,1.0))
    return true

func command(id: String, value: float = 0.0, phase: String = "press") -> void:
    var release := phase == "release"
    match id:
        "master":
            if not release:
                controller_notch = clampi(roundi(value*5.0),-5,5)
                brake_demand = maxf(0.0,-value)
                if value >= 0.0:
                    emergency = false
        "tractionUp":
            controller_notch = mini(5,controller_notch+1)
            if controller_notch >= 0:
                brake_demand = 0.0
                emergency = false
        "tractionDown":
            controller_notch = maxi(-5,controller_notch-1)
            brake_demand = maxf(0.0,-float(controller_notch)/5.0)
        "brake","brake1","brake2":
            if not release:
                brake_demand = clampf(value,0.0,1.0)
                controller_notch = 0
                emergency = false
        "release":
            if not release:
                controller_notch = 0
                brake_demand = 0.0
                emergency = false
        "service":
            if not release:
                controller_notch = 0
                brake_demand = 0.5
        "emergency":
            if not release:
                controller_notch = 0
                brake_demand = 1.0
                emergency = true
        "reverse":
            if not release:
                if float(game.get("speed")) <= 0.05 and controller_notch == 0:
                    direction = 0 if direction == 1 else -1 if direction == 0 else 1
                else:
                    notice = "Реверсор: сначала остановка и нейтраль контроллера"
        "open","openLeft","openRight":
            if not release:
                if id != "open": door_side = -1 if id == "openLeft" else 1
                if switches.doorBlock:
                    notice = "Открытие дверей заблокировано"
                elif not bool(doors.call("request_side",door_side,float(game.get("speed")))):
                    notice = "Двери: открытие разрешено только на остановке"
        "close":
            if not release: doors.call("request_close")
        "lampTest": lamp_test = not release
        "reset":
            if not release:
                lamp_test = false
                if float(game.get("speed")) <= 0.05: emergency = false
                notice = "Проверка приборов сброшена"
        "horn":
            horn_active = not release
            if horn_active: _horn.play()
            else: _horn.stop()
        "sandLeft": sand_left = not release
        "sandRight": sand_right = not release
        "volume":
            if not release: volume = 0.0 if volume >= 0.99 else minf(1.0,volume+0.25)
        "info":
            if not release:
                notice = "Состав 4 вагона · двери %s · %.0f км/ч" % ["закрыты" if doors.call("can_move") else "открыты",float(game.get("speed"))*3.6]
                _radio.play()
        "radioTalk":
            radio_tx = not release
            if not release:
                notice = "Игровая радиопередача · "+radio_channel
                _radio.play()
        "radioReset","radioClear":
            if not release:
                radio_tx = false
                radio_call = false
                notice = "Радиоканал сброшен"
        "radioCall":
            if not release:
                radio_call = not radio_call
                _radio.play()
        "radioLine","radioPgs","radioDsp","radioReserve":
            if not release:
                radio_channel = {"radioLine":"ЛИНИЯ","radioPgs":"ПГС","radioDsp":"ДСП","radioReserve":"РЕЗЕРВ"}[id]
                notice = "Выбран канал "+radio_channel
        "carriage","forward":
            if not release: _monitor_mode = id
        "platform":
            if not release:
                if not is_instance_valid(game.get("_station")):
                    notice = "Камера платформы: станция не подключена"
                else: _monitor_mode = id
        _:
            if switches.has(id) and not release:
                switches[id] = not switches[id]
                if id == "mode": target_speed = maxf(8.33,float(game.get("speed")))
                if id == "doorBlock" and switches.doorBlock: doors.call("request_close")
    if not release and moving.has(id):
        moving[id].set_meta("pressed_until",clock+0.16)

func physics_inputs(delta: float, speed: float, screen_throttle: bool, screen_brake: bool) -> Dictionary:
    var desired_brake := maxf(brake_demand,1.0 if screen_brake or emergency else 0.0)
    if bool(switches.ars) and speed > 16.67:
        desired_brake = maxf(desired_brake,0.65)
        notice = "АРС: ограничение 60 км/ч"
    var desired_traction := maxf(float(maxi(controller_notch,0))/5.0,1.0 if screen_throttle else 0.0)
    if bool(switches.mode) and not screen_throttle and not screen_brake and brake_demand == 0.0 and controller_notch > 0:
        desired_traction = clampf((target_speed-speed)*0.5,0.0,1.0)
        desired_brake = maxf(desired_brake,clampf((speed-target_speed)*0.3,0.0,0.5))
    if switches.reserve: desired_traction = minf(desired_traction,0.4)
    applied_brake = move_toward(applied_brake,desired_brake,delta*(5.0 if switches.ept or emergency or screen_brake else 1.5))
    if applied_brake > 0.01 or not bool(doors.call("can_move")) or direction == 0:
        desired_traction = 0.0
    traction_actual = desired_traction
    line_pressure = 5.0-applied_brake*3.5
    cylinder_pressure = applied_brake*3.5
    window_temperature.x = move_toward(window_temperature.x,32.0 if switches.heatLeft else 8.0,delta*0.45)
    window_temperature.y = move_toward(window_temperature.y,32.0 if switches.heatRight else 8.0,delta*0.45)
    voltage_kv = 0.75
    current_ka = desired_traction*0.65*(1.0-0.55*speed/22.0)+(0.002 if switches.cabLight else 0.0)+(0.004 if switches.heatLeft else 0.0)+(0.004 if switches.heatRight else 0.0)
    return {"traction":desired_traction,"brake":applied_brake,"direction":direction,"adhesion":1.1 if sand_left or sand_right else 1.0}

func _process(delta: float) -> void:
    if not ready_for_play:
        return
    clock += delta
    var smooth := 1.0-exp(-minf(delta,0.1)*18.0)
    for id in moving:
        var node := moving[id] as Node3D
        var base: Transform3D = bases[id]
        if id == "master":
            var lever := -maxf(brake_demand,1.0 if bool(game.get("brake")) else 0.0) if brake_demand > 0.0 or bool(game.get("brake")) else maxf(float(controller_notch)/5.0,1.0 if bool(game.get("throttle")) else 0.0)
            node.position.y = lerpf(node.position.y,-0.079+lever*(0.249 if lever > 0.0 else 0.079),smooth)
        elif id == "brake":
            node.rotation.y = lerpf(node.rotation.y,-applied_brake*1.6,smooth)
        elif id in ROTARIES:
            var setting: float = float(switches.get(id,false))
            if id in ["brake1","brake2"]: setting = brake_demand
            if id == "volume": setting = volume
            node.rotation.z = lerpf(node.rotation.z,base.basis.get_euler().z-(setting-0.5)*1.5,smooth)
        else:
            var pressed := float(node.get_meta("pressed_until",0.0)) > clock
            if id == "lampTest": pressed = lamp_test
            if id == "horn": pressed = horn_active
            if id == "radioTalk": pressed = radio_tx
            if id == "sandLeft": pressed = sand_left
            if id == "sandRight": pressed = sand_right
            node.position.z = lerpf(node.position.z,base.origin.z-(0.005 if pressed else 0.0),smooth)
    for id in ["Left","Right"]:
        var wiper := model.find_child("Wiper_"+id,true,false) as Node3D
        if wiper != null: wiper.rotation.z = (sin(clock*2.6)*0.45+0.45)*(1.0 if id == "Left" else -1.0) if switches["wiper"+id] else 0.0
    _apply_cab_light()
    var train := game.get("train") as Node3D
    for lamp in train.find_children("TrainHeadlight*","SpotLight3D",true,false):
        (lamp as SpotLight3D).visible = bool(switches.headlights)
    for material in _lamp_materials:
        material.emission_energy_multiplier = 1.5 if switches.headlights else 0.0
        material.albedo_color = Color(0.65,0.60,0.49) if switches.headlights else Color(0.075,0.07,0.06)
    _horn.volume_db = linear_to_db(maxf(volume,0.001))
    _radio.volume_db = linear_to_db(maxf(volume,0.001))
    _update_instruments()
    _video_clock += delta
    if _video_clock > 0.5:
        _video_clock = 0.0
        _update_video()

func _bind_instruments() -> void:
    var speed_group := model.find_child("SpeedDisplay",true,false) as Node3D
    for child in speed_group.get_children():
        if child is MeshInstance3D and child.get_aabb().size.x > 0.04 and child.get_aabb().size.x < 0.055 and child.get_aabb().size.y < 0.012:
            var segment := child as MeshInstance3D
            var original := segment.get_active_material(0) as BaseMaterial3D
            segment.material_override = original.duplicate() as BaseMaterial3D
            _speed_segments.append(segment)
    var upper := model.find_child("InstrumentBinnacle",true,false) as Node3D
    for child in upper.find_children("*","MeshInstance3D",true,false):
        var mesh := child as MeshInstance3D
        var size := mesh.get_aabb().size
        if size.x > 0.029 and size.x < 0.032 and size.y > 0.029 and size.y < 0.032 and size.z < 0.015:
            var material := (mesh.get_active_material(0) as BaseMaterial3D).duplicate() as BaseMaterial3D
            _pilot_colors.append(material.albedo_color)
            _pilot_materials.append(material)
            mesh.material_override = material
    for id in ["Gauge_кВ_Needle","Gauge_кА_Needle"]:
        var needle := model.find_child(id,true,false) as Node3D
        if needle != null: _gauge_needles.append(needle)
    var radio := model.find_child("RadioConsole",true,false) as Node3D
    _radio_readout = Label3D.new()
    _radio_readout.position = Vector3(0.02,-0.25,0.075)
    _radio_readout.pixel_size = 0.00045
    _radio_readout.font_size = 20
    _radio_readout.modulate = Color(0.6,0.9,0.5)
    _radio_readout.layers = 2
    radio.add_child(_radio_readout)
    if _speed_segments.size() != 14 or _pilot_materials.size() != 10 or _gauge_needles.size() != 2:
        push_error("Cab instrument attachment mismatch: segments=%d lamps=%d needles=%d" % [_speed_segments.size(),_pilot_materials.size(),_gauge_needles.size()])
    _readout = Label3D.new()
    _readout.font_size = 28
    _readout.pixel_size = 0.0007
    _readout.position = Vector3(0.3,1.11,1.05)
    _readout.rotation.x = -0.1
    _readout.modulate = Color(0.7,1.0,0.55)
    _readout.layers = 2
    model.add_child(_readout)

func _update_instruments() -> void:
    var speed := float(game.get("speed"))*3.6
    var number := 88 if lamp_test else mini(99,roundi(speed))
    var bits := [0x3f,0x06,0x5b,0x4f,0x66,0x6d,0x7d,0x07,0x7f,0x6f]
    for index in range(_speed_segments.size()):
        var digit := int(number/10) if index < 7 else number%10
        var on := (int(bits[digit]) & (1 << (index%7))) != 0
        var material := _speed_segments[index].material_override as BaseMaterial3D
        material.albedo_color = Color(0.65,0.88,0.13) if on else Color(0.018,0.027,0.012)
        material.emission_enabled = on
        material.emission = Color(0.4,0.65,0.08)
    var moving_doors := float(doors.get("openness")) > 0.001 and float(doors.get("openness")) < 0.999
    var statuses := [traction_actual > 0.0,bool(switches.headlights),applied_brake > 0.01,bool(switches.cabLight),traction_actual == 0.0 and applied_brake < 0.01,bool(switches.ars),bool(doors.get("target_open")),moving_doors,bool(doors.call("can_move")),bool(switches.doorBlock)]
    for index in range(_pilot_materials.size()):
        var on: bool = lamp_test or (index < statuses.size() and bool(statuses[index]))
        _pilot_materials[index].albedo_color = _pilot_colors[index] if on else Color(0.035,0.04,0.035)
        _pilot_materials[index].emission_enabled = true
        _pilot_materials[index].emission = _pilot_colors[index]
        _pilot_materials[index].emission_energy_multiplier = 0.9 if on else 0.02
    for index in range(_gauge_needles.size()):
        var fraction := voltage_kv/1.5 if index == 0 else current_ka
        _gauge_needles[index].rotation.z = -PI*0.75+PI*1.5*clampf(fraction,0.0,1.0)
    _radio_readout.text = radio_channel+" · "+("ПЕРЕДАЧА" if radio_tx else "ВЫЗОВ" if radio_call else "ПРИЁМ")
    _readout.text = "%.0f км/ч · %.0f В · %.0f А\nТМ %.1f · ТЦ %.1f бар · %s" % [speed,voltage_kv*1000.0,current_ka*1000.0,line_pressure,cylinder_pressure,"ВПЕРЁД" if direction == 1 else "НАЗАД" if direction == -1 else "НЕЙТРАЛЬ"]

func _install_audio() -> void:
    _horn = AudioStreamPlayer.new()
    _radio = AudioStreamPlayer.new()
    add_child(_horn)
    add_child(_radio)
    _horn.stream = _tone(220.0,0.45,true)
    _radio.stream = _tone(660.0,0.18,false)

func _tone(frequency: float, seconds: float, loop: bool) -> AudioStreamWAV:
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = 22050
    var samples := int(seconds*22050.0)
    var bytes := PackedByteArray()
    bytes.resize(samples*2)
    for i in range(samples):
        var t := float(i)/22050.0
        var envelope := minf(1.0,float(mini(i,samples-1-i))/220.0)
        bytes.encode_s16(i*2,int((sin(t*frequency*TAU)+0.25*sin(t*frequency*2.0*TAU))*5000.0*envelope))
    stream.data = bytes
    if loop:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_end = samples
    return stream

func _make_video() -> Dictionary:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(160,128)
    viewport.world_3d = get_world_3d()
    viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    viewport.transparent_bg = false
    add_child(viewport)
    var camera := Camera3D.new()
    camera.cull_mask = 1
    camera.far = 120.0
    camera.near = 0.08
    viewport.add_child(camera)
    camera.current = true
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_texture = viewport.get_texture()
    return {"viewport":viewport,"camera":camera,"material":material}

func _install_video() -> void:
    # The original GLB contains the original monitor/mirror surfaces, not render targets.
    for side in [-1.0,1.0]:
        var video := _make_video()
        video["side"] = side
        for root in model.get_children():
            if root is Node3D and absf(absf(root.position.x)-1.268) < 0.01:
                if signf(root.position.x) != side: continue
                root.position.x = side*1.17
                for child in root.find_children("*","MeshInstance3D",true,false):
                    var mesh := child as MeshInstance3D
                    var size := mesh.get_aabb().size
                    if absf(size.x-0.062) < 0.005 and absf(size.y-0.253) < 0.01:
                        mesh.material_override = video.material
                        video["face"] = mesh
        _mirrors.append(video)
    _monitor = _make_video()
    var cctv := model.find_child("CabCCTV",true,false) as Node3D
    for child in cctv.find_children("*","MeshInstance3D",true,false):
        var mesh := child as MeshInstance3D
        var size := mesh.get_aabb().size
        if absf(size.x-0.286) < 0.005 and absf(size.y-0.290) < 0.005:
            var material := mesh.get_active_material(0) as BaseMaterial3D
            if material != null and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
                mesh.material_override = _monitor.material

func _update_video() -> void:
    if str(game.get("camera_mode")) != "cabin": return
    var train := game.get("train") as Node3D
    for video in _mirrors:
        var enabled := bool(switches.mirrorLeft if video.side < 0.0 else switches.mirrorRight)
        if video.has("face"): video.face.visible = enabled
        if not enabled: continue
        var camera := video.camera as Camera3D
        camera.global_position = train.to_global(Vector3(float(video.side)*1.72,2.5,-9.3))
        camera.look_at(train.to_global(Vector3(float(video.side)*1.72,2.5,60.0)),Vector3.UP)
        (video.viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
    var camera := _monitor.camera as Camera3D
    if _monitor_mode == "carriage":
        camera.global_position = train.to_global(Vector3(0,2.5,-4.5))
        camera.look_at(train.to_global(Vector3(0,2.4,8.0)),Vector3.UP)
    elif _monitor_mode == "platform" and is_instance_valid(game.get("_station")):
        camera.global_position = (game.get("_station") as Node3D).global_position+Vector3(-3,3,0)
        camera.look_at(train.global_position,Vector3.UP)
    else:
        camera.global_position = train.to_global(Vector3(-0.55,2.65,-9.2))
        camera.global_basis = train.global_basis
    (_monitor.viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE

func make_screen_controls(ui: CanvasLayer) -> void:
    _cab_light_button = Button.new()
    _cab_light_button.position = Vector2(245,55)
    _cab_light_button.custom_minimum_size = Vector2(240,42)
    _cab_light_button.toggle_mode = true
    ui.add_child(_cab_light_button)
    _cab_light_button.pressed.connect(func(): command("cabLight"); _apply_cab_light())
    _apply_cab_light()
    var toggle := Button.new()
    toggle.text = "ПУЛЬТ / ДВЕРИ"
    toggle.position = Vector2(15,55)
    toggle.custom_minimum_size = Vector2(220,42)
    ui.add_child(toggle)
    var panel := VBoxContainer.new()
    panel.position = Vector2(15,100)
    panel.visible = false
    ui.add_child(panel)
    toggle.pressed.connect(func(): panel.visible = not panel.visible)
    var row := GridContainer.new()
    row.columns = 3
    panel.add_child(row)
    for entry in [["ТЯГА +","tractionUp"],["НЕЙТРАЛЬ","release"],["ТЯГА −","tractionDown"],["ЛЕВЫЕ ДВЕРИ","openLeft"],["ЗАКРЫТЬ","close"],["ПРАВЫЕ ДВЕРИ","openRight"],["РЕВЕРС","reverse"],["ФАРЫ","headlights"],["СВЕТ КАБИНЫ","cabLight"],["СЛУЖ. ТОРМОЗ","service"],["ЭКСТРЕННЫЙ","emergency"],["СИГНАЛ","horn"]]:
        var button := Button.new()
        button.text = entry[0]
        button.custom_minimum_size = Vector2(150,42)
        row.add_child(button)
        var id: String = entry[1]
        if id == "horn":
            button.button_down.connect(func(): command(id))
            button.button_up.connect(func(): command(id,0.0,"release"))
        else:
            button.pressed.connect(func(): command(id))
    var all_controls := OptionButton.new()
    for id in CONTROL_IDS:
        all_controls.add_item(CONTROL_TITLES[id])
    panel.add_child(all_controls)
    var activate := Button.new()
    activate.text = "Выбранный орган: нажать / удерживать"
    panel.add_child(activate)
    activate.button_down.connect(func(): command(CONTROL_IDS[all_controls.selected]))
    activate.button_up.connect(func(): command(CONTROL_IDS[all_controls.selected],0.0,"release"))
    var status := Label.new()
    status.add_theme_font_size_override("font_size",16)
    panel.add_child(status)
    var timer := Timer.new()
    timer.wait_time = 0.25
    timer.autostart = true
    panel.add_child(timer)
    timer.timeout.connect(func():
        status.text = "%s · Тяга %d · Тормоз %.0f%%\nТМ %.1f / ТЦ %.1f бар · Обогрев %.0f / %.0f°C\nРадио: %s · %s\n%s" % ["ВПЕРЁД" if direction == 1 else "НАЗАД" if direction == -1 else "НЕЙТРАЛЬ",controller_notch,applied_brake*100,line_pressure,cylinder_pressure,window_temperature.x,window_temperature.y,radio_channel,"ПЕРЕДАЧА" if radio_tx else "ВЫЗОВ" if radio_call else "ПРИЁМ",notice]
    )

func cancel_interaction() -> void:
    _active = ""
    _pointer = -2
    horn_active = false
    radio_tx = false
    sand_left = false
    sand_right = false
    lamp_test = false
    if _horn != null: _horn.stop()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        cancel_interaction()


func _input(event: InputEvent) -> void:
    # Release a captured 3D control even if the pointer ends over screen UI.
    var released: bool = (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed)
    if released and not _active.is_empty() and is_instance_valid(game):
        if handle_input(event,game.get("camera") as Camera3D):
            get_viewport().set_input_as_handled()
    if event is InputEventKey and not event.pressed and event.physical_keycode == KEY_H:
        horn_active = false
        if _horn != null: _horn.stop()
