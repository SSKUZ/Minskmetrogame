extends Node3D
## Runtime bindings for the confirmed cab-r2.1 source entry; complete fresh Three.js export.
## Control IDs, positions and handle animation follow js/cab/CabControls.js.
const CAB_SCENE = preload("res://assets/cab_r21/cab_r21.glb")
const CAB_MATERIAL = preload("res://scripts/cab_r36_material.gdshader")
const POSITION := Vector3(0,0.8975,-10.15)
const EYE := Vector3(0.0,1.82,2.235)
const CONTROL_IDS := ["cabLight","headlights","sandLeft","sandRight","wiperLeft","wiperRight","lampTest","reset","ars","open","close","doorBlock","mode","reserve","master","brake1","brake2","ept","release","service","emergency","horn","brake","volume","info","radioTalk","radioReset","radioCall","radioLine","radioClear","radioPgs","radioDsp","radioReserve","carriage","platform","forward","mirrorLeft","mirrorRight","heatLeft","heatRight"]
const CONTROL_TITLES := {"cabLight": "Освещение кабины", "headlights": "Фары", "sandLeft": "Песок слева", "sandRight": "Песок справа", "wiperLeft": "Левый дворник", "wiperRight": "Правый дворник", "lampTest": "Проверка ламп", "reset": "Сброс", "ars": "Контроль скорости АРС", "open": "Открыть выбранную сторону", "close": "Закрыть двери", "doorBlock": "Блокировка открывания дверей", "mode": "Поддержание скорости", "reserve": "Резервная тяга", "master": "Контроллер: нейтраль", "brake1": "Тормозной кран 1", "brake2": "Тормозной кран 2", "ept": "Электропневматический тормоз", "release": "Отпуск тормоза", "service": "Служебный тормоз", "emergency": "Экстренный тормоз", "horn": "Звуковой сигнал", "brake": "Тормозной кран", "volume": "Громкость", "info": "Информация о составе", "radioTalk": "Радио: передача", "radioReset": "Радио: сброс", "radioCall": "Радио: вызов", "radioLine": "Радио: линейный канал", "radioClear": "Радио: отбой", "radioPgs": "Радио: ПГС", "radioDsp": "Радио: ДСП", "radioReserve": "Радио: резервный канал", "carriage": "Камера: салон", "platform": "Камера: платформа", "forward": "Камера: путь", "mirrorLeft": "Левое зеркало", "mirrorRight": "Правое зеркало", "heatLeft": "Обогрев левого стекла", "heatRight": "Обогрев правого стекла"}
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
var cleanup_ready := false
var notice := "Пульт готов · W/S: контроллер · Пробел: тормоз"
var clock := 0.0
var _active := ""
var _pointer := -2
var _drag_origin := Vector2.ZERO
var _dragged := false
var _lever_start := 0.0
var _source_recipe: Dictionary = {}
var _source_enabled: Dictionary = {}
var _cab_materials: Array[ShaderMaterial] = []
var _material_light_state := -1.0
var _cab_light: SpotLight3D
var _cab_fill: OmniLight3D
var _cab_light_button: Button
var _horn: AudioStreamPlayer
var _info_arrival_played := false
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
    preload("res://scripts/cab_view_cleanup_v37.gd").apply(lead)
    model = CAB_SCENE.instantiate() as Node3D
    model.name = "OriginalCab81_717_R21"
    add_child(model)
    _fit_cab_to_v106()
    _source_recipe = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cab_r21/cab_r21.json"))
    for entry in _source_recipe.controls:
        _source_enabled[entry.id] = entry.enabled
    var console := model.find_child("CabConsole",true,false) as Node3D
    console.position.z -= 0.22
    model.find_child("CabCCTV",true,false).hide()
    for root in model.get_children():
        if root is Node3D and absf(absf(root.position.x)-1.268) < 0.01:
            root.hide()
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
        if node.is_visible_in_tree(): _add_pick_volume(node,id)
    _bind_instruments()
    _install_audio()
    _install_video(lead)
    _cab_light = model.find_child("OriginalCabCeilingSpot",true,false) as SpotLight3D
    _cab_fill = model.find_child("OriginalCabFill",true,false) as OmniLight3D
    _cab_light.light_energy = 2.4
    _cab_light.light_color = Color(1.0,0.97,0.93)
    _cab_light.spot_range = 5.4
    _cab_light.spot_angle = 57.6
    _cab_light.spot_angle_attenuation = 1.2
    _cab_light.shadow_enabled = true
    _cab_light.light_cull_mask = 2
    _cab_light.look_at(model.to_global(Vector3(0.18,0.98,1.25)),Vector3.UP)
    _cab_fill.light_energy = 0.45
    _cab_fill.light_color = Color(0.96,0.98,1.0)
    _cab_fill.omni_range = 3.8
    _cab_fill.light_cull_mask = 2
    _install_original_materials()
    # Both local lamps affect only cabin layer 2, never tunnel layer 1 or glass.
    for child in lead.find_children("*","MeshInstance3D",true,false):
        var instance := child as MeshInstance3D
        if not model.is_ancestor_of(instance):
            var box := lead.global_transform.affine_inverse()*instance.global_transform*instance.get_aabb()
            if box.end.z < -6.4:
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
    var banner := lead.find_child("goodmix-duo-cab-bulkhead-banner",true,false) as Node3D
    cleanup_ready = banner != null and banner.is_visible_in_tree() and _mirrors.size() == 2 and not model.find_child("CabCCTV",true,false).is_visible_in_tree()
    ready_for_play = controls.size() == CONTROL_IDS.size()
    print("CAB_V37_READY version=cab-r2.1 controls=",controls.size())

func _fit_cab_to_v106() -> void:
    var shell := model.find_child("CabInteriorShell",true,false) as Node3D
    if shell == null: return
    # Reuse the V106 shell, glass and advertised rear partition. Keep the
    # original console plus its seat and floor; hide only duplicate lining.
    for child in shell.get_children():
        if not child is Node3D: continue
        var item := child as Node3D
        if item.position.z > 2.35 and item.position.z < 2.9 and item.position.y < 1.0 and absf(item.position.x) < 0.01:
            item.position += Vector3(-0.55,0,-0.40)
            continue
        if item is MeshInstance3D:
            var a := item.transform*(item as MeshInstance3D).get_aabb()
            if a.end.y < 0.08 and a.size.x > 2.4:
                item.position.y += 0.020
                item.position.z = 1.37
                item.scale.z *= 0.64
                continue
        # The exported floor-rib group has identity position and many children.
        var ribs := false
        for descendant in item.find_children("*","MeshInstance3D",true,false):
            var a: AABB = model.global_transform.affine_inverse()*descendant.global_transform*(descendant as MeshInstance3D).get_aabb()
            if a.end.y < 0.08 and a.size.x > 2.4:
                ribs = true
                if a.get_center().z > 2.40: descendant.hide()
                else: descendant.position.y += 0.020
        if not ribs: item.hide()

func _decode_image(encoded: String) -> Image:
    var image := Image.new()
    var error := image.load_png_from_buffer(Marshalls.base64_to_raw(encoded))
    if error != OK: push_error("Original cab texture decoding failed")
    return image

func _channel(index: int) -> Vector4:
    var channels := [Vector4(1,0,0,0),Vector4(0,1,0,0),Vector4(0,0,1,0),Vector4(0,0,0,1),Vector4(0.333333,0.333333,0.333333,0)]
    return channels[clampi(index,0,4)]

func _install_original_materials() -> void:
    var cube := Cubemap.new()
    var faces: Array[Image] = []
    for encoded in _source_recipe.environment_faces:
        var image := _decode_image(encoded)
        image.generate_mipmaps()
        faces.append(image)
    cube.create_from_images(faces)
    var bumps: Dictionary = {}
    for id in _source_recipe.bumps:
        var image := _decode_image(_source_recipe.bumps[id])
        image.generate_mipmaps()
        bumps[id] = ImageTexture.create_from_image(image)
    var shared: Dictionary = {}
    for child in model.find_children("*","MeshInstance3D",true,false):
        var mesh := child as MeshInstance3D
        for surface in range(mesh.mesh.get_surface_count()):
            var original := mesh.get_active_material(surface) as BaseMaterial3D
            if original == null or not _source_recipe.materials.has(original.resource_name): continue
            if not shared.has(original):
                var recipe: Dictionary = _source_recipe.materials[original.resource_name]
                var material := ShaderMaterial.new()
                material.shader = CAB_MATERIAL
                material.set_shader_parameter("base_color",original.albedo_color)
                material.set_shader_parameter("neutral_finish",0.85 if original.resource_name in ["cab_panel","cab_ivory"] else 0.0)
                material.set_shader_parameter("original_roughness",original.roughness)
                material.set_shader_parameter("original_metallic",original.metallic)
                material.set_shader_parameter("original_specular",original.metallic_specular)
                material.set_shader_parameter("original_clearcoat",original.clearcoat if original.clearcoat_enabled else 0.0)
                material.set_shader_parameter("original_clearcoat_roughness",original.clearcoat_roughness)
                material.set_shader_parameter("has_color_map",original.albedo_texture != null)
                material.set_shader_parameter("color_map",original.albedo_texture)
                material.set_shader_parameter("has_roughness_map",original.roughness_texture != null)
                material.set_shader_parameter("roughness_map",original.roughness_texture)
                material.set_shader_parameter("roughness_channel",_channel(original.roughness_texture_channel))
                material.set_shader_parameter("has_metallic_map",original.metallic_texture != null)
                material.set_shader_parameter("metallic_map",original.metallic_texture)
                material.set_shader_parameter("metallic_channel",_channel(original.metallic_texture_channel))
                material.set_shader_parameter("cab_environment",cube)
                material.set_shader_parameter("env_intensity",recipe.env_intensity)
                if recipe.has("bump"):
                    material.set_shader_parameter("has_height_map",true)
                    material.set_shader_parameter("height_map",bumps[recipe.bump])
                    material.set_shader_parameter("bump_scale",recipe.bump_scale)
                shared[original] = material
                _cab_materials.append(material)
            mesh.set_surface_override_material(surface,shared[original])
    print("CAB_R21_SURFACES restored=",_cab_materials.size()," original_environment_faces=",faces.size())

func _restore_neutral_glazing(lead: Node3D) -> void:
    var neutral: Dictionary = {}
    for child in lead.find_children("*","MeshInstance3D",true,false):
        var mesh := child as MeshInstance3D
        var in_original := model.is_ancestor_of(mesh)
        var bounds := lead.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
        if not in_original and (bounds.get_center().z > -6.4 or bounds.get_center().y < 2.0): continue
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
    var state := 1.0 if enabled else 0.0
    if state != _material_light_state:
        _material_light_state = state
        for material in _cab_materials:
            material.set_shader_parameter("cab_light_on",state)
    if _cab_light_button != null:
        _cab_light_button.text = "СВЕТ КАБИНЫ: "+("ВКЛ." if enabled else "ВЫКЛ.")
        _cab_light_button.set_pressed_no_signal(enabled)

func _hide_old_interior(lead: Node3D) -> void:
    for child in lead.find_children("*","MeshInstance3D",true,false):
        var mesh := child as MeshInstance3D
        var bounds := lead.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
        if str(mesh.name).begins_with("goodmix-duo-"):
            mesh.show()
            continue
        if bounds.position.z > -7.80 and bounds.end.z < -7.45 and bounds.size.x > 2.3 and bounds.size.y > 1.5:
            mesh.show() # Original rear partition, behind the driver's eye.
            continue
        var blue_shell := false
        for surface in range(mesh.mesh.get_surface_count()):
            var mat := mesh.get_active_material(surface) as BaseMaterial3D
            if mat != null and mat.albedo_color.b > mat.albedo_color.r*1.6 and mat.albedo_color.g > mat.albedo_color.r*1.3:
                blue_shell = true
        if blue_shell:
            mesh.show() # Keep V106's original blue shell/doors, never repaint them.
            continue
        if bounds.position.z > -9.6 and bounds.end.z < -6.4 and bounds.position.y > 0.87 and bounds.end.y < 3.7 and bounds.position.x > -1.39 and bounds.end.x < 1.39:
            if absf(bounds.get_center().x) > 1.25 and bounds.size.y > 0.5: continue
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
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_C,KEY_V,KEY_HOME,KEY_END]:
        command({KEY_C:"carriage",KEY_V:"platform",KEY_HOME:"forward",KEY_END:"desk"}[event.physical_keycode])
        return true
    if str(game.get("camera_mode")) != "cabin":
        return false
    if event is InputEventKey and event.pressed and not event.echo:
        var keys := {KEY_W:"tractionUp",KEY_S:"tractionDown",KEY_N:"release",KEY_B:"service",KEY_SPACE:"emergency",KEY_O:"openRight" if event.shift_pressed else "openLeft",KEY_P:"close",KEY_F:"headlights",KEY_L:"cabLight",KEY_H:"horn",KEY_R:"reverse",KEY_I:"info",KEY_T:"lampTest",KEY_C:"carriage",KEY_V:"platform",KEY_HOME:"forward",KEY_END:"desk"}
        if keys.has(event.physical_keycode):
            command(keys[event.physical_keycode])
            return true
    if event is InputEventKey and not event.pressed and event.physical_keycode in [KEY_H,KEY_T]:
        command("horn" if event.physical_keycode == KEY_H else "lampTest",0.0,"release")
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
    if _source_enabled.has(id) and not bool(_source_enabled[id]):
        if not release: notice = CONTROL_TITLES[id]+" · система не моделируется"
        return
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
                if _radio.playing:
                    notice = "INFO: объявление уже звучит"
                elif bool(doors.get("target_open")):
                    _radio.stream = load("res://assets/cab_r21/malinovka_departure_petrovshchina.mp3")
                    _radio.play()
                    notice = "Исходный информатор: следующая станция — Петровщина"
                elif not _info_arrival_played:
                    _info_arrival_played = true
                    _radio.stream = load("res://assets/cab_r21/malinovka_arrival.mp3")
                    _radio.play()
                    notice = "Исходный информатор: станция Малиновка"
                else:
                    notice = "INFO: откройте двери для объявления об отправлении"
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
        "carriage":
            if not release:
                _monitor_mode = id
                game.call("_set_camera_mode","salon")
        "forward","desk":
            if not release:
                _monitor_mode = "forward"
                game.call("_set_camera_mode","cabin")
                game.set("orbit_pitch",0.49 if id == "desk" else 0.03)
                game.call("_update_camera")
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
        if _source_enabled.has(id) and not bool(_source_enabled[id]):
            node.transform = base
            continue
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
    if _video_clock > 0.2:
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
    var statuses := [traction_actual > 0.0,false,applied_brake > 0.01,false,traction_actual == 0.0 and applied_brake < 0.01,false,bool(doors.get("target_open")),moving_doors,bool(doors.call("can_move")),false]
    for index in range(_pilot_materials.size()):
        var on: bool = lamp_test or (index < statuses.size() and bool(statuses[index]))
        _pilot_materials[index].albedo_color = _pilot_colors[index] if on else Color(0.035,0.04,0.035)
        _pilot_materials[index].emission_enabled = true
        _pilot_materials[index].emission = _pilot_colors[index]
        _pilot_materials[index].emission_energy_multiplier = 0.9 if on else 0.02
    for index in range(_gauge_needles.size()):
        var fraction := 0.0 # Original electrical instruments explicitly say НЕТ ДАННЫХ.
        _gauge_needles[index].rotation.z = -PI*0.75+PI*1.5*clampf(fraction,0.0,1.0)
    _radio_readout.visible = false
    _radio_readout.text = radio_channel+" · "+("ПЕРЕДАЧА" if radio_tx else "ВЫЗОВ" if radio_call else "ПРИЁМ")
    _readout.visible = false # Preserve original panel lettering; screen HUD carries game status.


func _install_audio() -> void:
    _horn = AudioStreamPlayer.new()
    _radio = AudioStreamPlayer.new()
    add_child(_horn)
    add_child(_radio)
    _horn.stream = _tone(330.0,0.45,true)
    _radio.stream = load("res://assets/cab_r21/malinovka_arrival.mp3")

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
        bytes.encode_s16(i*2,int((sin(t*frequency*TAU)+sin(t*440.0*TAU))*2300.0*envelope))
    stream.data = bytes
    if loop:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_end = samples
    return stream

func _make_video() -> Dictionary:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(128,256)
    viewport.world_3d = get_world_3d()
    viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    viewport.transparent_bg = false
    add_child(viewport)
    var camera := Camera3D.new()
    camera.cull_mask = 1
    camera.fov = 53.0
    camera.far = 120.0
    camera.near = 0.08
    viewport.add_child(camera)
    camera.current = true
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_texture = viewport.get_texture()
    material.uv1_scale = Vector3(-1,1,1)
    material.uv1_offset = Vector3(1,0,0)
    return {"viewport":viewport,"camera":camera,"material":material}

func _install_video(lead: Node3D) -> void:
    var originals: Dictionary = preload("res://scripts/cab_view_cleanup_v37.gd").mirror_parts(lead)
    for child in lead.find_children("mirror-*","MeshInstance3D",true,false):
        var housing := child as MeshInstance3D
        if model.is_ancestor_of(housing): continue
        var center := lead.to_local(housing.to_global(housing.get_aabb().get_center()))
        var side := signf(center.x)
        var pivot := Node3D.new()
        pivot.name = "CompleteOriginalMirrorLeft" if side < 0.0 else "CompleteOriginalMirrorRight"
        lead.add_child(pivot)
        pivot.position = center
        housing.reparent(pivot,true)
        var video := _make_video()
        video["side"] = side
        video["pivot"] = pivot
        for part in originals[side]:
            lead.add_child(part)
            part.reparent(pivot,true)
            if bool(part.get_meta("reflection")):
                part.material_override = video.material
                part.layers = 32
                part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        # Move and enlarge the complete original yellow assembly, including its
        # old bracket and glass. No second mirror or added reflection quad.
        pivot.position = Vector3(side*1.57,2.70,-8.65)
        pivot.scale = Vector3.ONE*1.5
        _mirrors.append(video)

func _update_video() -> void:
    if str(game.get("camera_mode")) != "cabin": return
    var train := game.get("train") as Node3D
    for video in _mirrors:
        var enabled := bool(switches.mirrorLeft if video.side < 0.0 else switches.mirrorRight)
        var pivot := video.pivot as Node3D
        pivot.rotation.y = 0.0 if enabled else float(video.side)*PI*0.5
        if not enabled: continue
        var viewer := game.get("camera") as Camera3D
        if not viewer.is_position_in_frustum(pivot.global_position): continue
        var camera := video.camera as Camera3D
        camera.global_position = pivot.to_global(Vector3(0,0,0.04))
        camera.look_at(train.to_global(Vector3(float(video.side)*1.65,2.55,60.0)),Vector3.UP)
        (video.viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE

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
        status.text = "%s · Тяга %d · Тормоз %.0f%%\n%s" % ["ВПЕРЁД" if direction == 1 else "НАЗАД" if direction == -1 else "НЕЙТРАЛЬ",controller_notch,applied_brake*100,notice]
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
    if event is InputEventKey and not event.pressed and event.physical_keycode == KEY_T:
        lamp_test = false
    if event is InputEventKey and not event.pressed and event.physical_keycode == KEY_H:
        horn_active = false
        if _horn != null: _horn.stop()
