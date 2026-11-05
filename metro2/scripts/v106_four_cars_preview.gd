extends Node3D
const CAR03_SCENE = preload("res://assets/v106_original/car03/v106_car_03.glb")
const CAR02_SCENE = preload("res://assets/v106_original/car02/v106_car_02.glb")
const V106_SCENE = preload("res://assets/v106_lod1/v106_car01_lod1_mesh289_normals_fixed.glb")
## Touch orbit camera around the imported V106 wagon.
var camera: Camera3D
var train: Node3D
var speed := 0.0
var throttle := false
var brake := false
var hud: Label
var distance := 300.0
var orbit_yaw := 0.35
var orbit_pitch := 0.10
var orbit_radius := 4.6
var touch_dragging := false
var touch_last := Vector2.ZERO
var wagon_center := Vector3(0, 1.2, 0)
var camera_pan := Vector3.ZERO
var camera_move: Dictionary = {}
const CAMERA_MOVE_SPEED := 7.0
signal station_approach_changed(distance_m: float, illumination: float)
var _tunnel: Node3D
var _train_bounds := AABB()
var camera_mode := "external"
var _environment: Environment
var _station: Node3D
var _station_stop_z := 0.0
var _diagnostics_enabled := false
var _diagnostic_clock := 0.0
var _focused_car := 0
var _car_centers: Array[Vector3] = []

func _ready() -> void:
    print("TZ30_BOOT ready")
    _diagnostics_enabled = OS.has_feature("web")
    print("TZ30_BOOT diagnostics configured")
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.006, 0.008, 0.012)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.6, 0.7, 0.9)
    env.ambient_light_energy = 0.55
    _environment = env
    env.fog_enabled = true
    env.fog_mode = Environment.FOG_MODE_DEPTH
    env.fog_depth_begin = 24.0
    env.fog_depth_end = 56.0
    env.fog_depth_curve = 1.2
    env.fog_density = 1.0
    env.fog_light_color = Color(0.006,0.008,0.012)
    env.fog_light_energy = 0.15
    env.fog_sun_scatter = 0.0
    world.environment = env
    add_child(world)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-40, -25, 0)
    light.light_energy = 0.45
    add_child(light)
    train = Node3D.new()
    train.name = "PlayerTrainPlacement"
    add_child(train)
    train.position = Vector3(0.992, 0.22, distance)
    var original_car := V106_SCENE.instantiate()
    original_car.name = "OriginalV106Car01"
    train.add_child(original_car)
    var second_car := CAR02_SCENE.instantiate()
    second_car.name = "OriginalV106Car02"
    train.add_child(second_car)
    print("V106 SINGLE CAR: imported model instantiated")
    var bounds := _get_model_bounds(original_car)
    if bounds.size.length() > 0.01:
        wagon_center = bounds.get_center()
        orbit_radius = 4.6
        print("V106 BOUNDS: ", bounds)
    var second_bounds := _get_model_bounds(second_car)
    if bounds.size.z > 1.0 and second_bounds.size.z > 1.0:
        # Align bounding-box ends, irrespective of each GLB origin.
        var gap := 0.25
        second_car.position.z = bounds.position.z + bounds.size.z + gap - second_bounds.position.z
        print("CAR02 aligned to CAR01: offset=", second_car.position.z, " gap=", gap)
        _add_visible_coupler(bounds, second_bounds, second_car.position.z, gap)
    var third_car := CAR03_SCENE.instantiate()
    third_car.name = "OriginalV106Car03"
    train.add_child(third_car)
    var third_bounds := _get_model_bounds(third_car)
    if second_bounds.size.z > 1.0 and third_bounds.size.z > 1.0:
        var third_gap := 0.25
        third_car.position.z = second_car.position.z + second_bounds.position.z + second_bounds.size.z + third_gap - third_bounds.position.z
        _add_visible_coupler_between(second_car, second_bounds, third_car, third_bounds, third_gap)
    # Car04 is loaded after the first frame; avoid blocking initial scene setup.
    call_deferred("_attach_fourth_car", third_car, third_bounds)
    # Lightweight straight route, independent from legacy tunnel_v2.gd.
    var tunnel := Node3D.new()
    _tunnel = tunnel
    tunnel.name = "LightweightStraightTunnel"
    tunnel.set_script(load("res://scripts/tunnel_lightweight_straight.gd"))
    add_child(tunnel)
    camera = Camera3D.new()
    camera.current = true
    camera.far = 120
    camera.near = 0.04
    add_child(camera)
    var ui := CanvasLayer.new()
    add_child(ui)
    hud = Label.new()
    hud.position = Vector2(15, 15)
    hud.add_theme_font_size_override("font_size", 22)
    hud.add_theme_color_override("font_color", Color.YELLOW)
    ui.add_child(hud)
    orbit_radius = 8.0
    var row := HBoxContainer.new()
    row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    row.offset_top = -90
    ui.add_child(row)
    var go := Button.new()
    go.text = "РАЗГОН"
    go.custom_minimum_size = Vector2(180, 75)
    go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(go)
    go.button_down.connect(func(): throttle = true)
    go.button_up.connect(func(): throttle = false; _publish_diagnostics())
    var stop := Button.new()
    stop.text = "ТОРМОЗ"
    stop.custom_minimum_size = Vector2(180, 75)
    stop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(stop)
    stop.button_down.connect(func(): brake = true)
    stop.button_up.connect(func(): brake = false; _publish_diagnostics())
    _add_camera_controls(ui)
    _add_view_modes(ui)
    _update_camera()
    _configure_tunnel()
    call_deferred("_log_render_metrics")

func _attach_fourth_car(third_car: Node3D, third_bounds: AABB) -> void:
    var resource := load("res://assets/v106_original/car04/v106_car_04.glb") as PackedScene
    if resource == null:
        push_error("CAR04: GLB resource failed to load")
        return
    var fourth_car := resource.instantiate() as Node3D
    if fourth_car == null:
        push_error("CAR04: GLB scene failed to instantiate")
        return
    fourth_car.name = "OriginalV106Car04"
    train.add_child(fourth_car)
    var fourth_bounds := _get_model_bounds(fourth_car)
    if third_bounds.size.z > 1.0 and fourth_bounds.size.z > 1.0:
        var gap04 := 0.25
        fourth_car.position.z = third_car.position.z + third_bounds.position.z + third_bounds.size.z + gap04 - fourth_bounds.position.z
    print("CAR04 attached; bounds=", fourth_bounds, " offset=", fourth_car.position.z)
    _configure_tunnel()
    _add_headlight()
    print("FOUR_CAR_READY bounds=", _train_bounds, " models=4")

func _add_visible_coupler_between(first: Node3D, first_bounds: AABB, second: Node3D, second_bounds: AABB, gap: float) -> void:
    var end_z := first.position.z + first_bounds.position.z + first_bounds.size.z
    var next_z := second.position.z + second_bounds.position.z
    var midpoint := (end_z + next_z) * 0.5
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color(0.13, 0.14, 0.15)
    metal.metallic = 0.65
    var root := Node3D.new()
    root.name = "CouplerCar02Car03"
    train.add_child(root)
    var shaft := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.09
    cylinder.bottom_radius = 0.09
    cylinder.height = gap + 0.16
    shaft.mesh = cylinder
    shaft.rotation.x = PI * 0.5
    shaft.position = Vector3(0, 0.46, midpoint)
    shaft.material_override = metal
    root.add_child(shaft)
    var head := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.40, 0.20, 0.19)
    head.mesh = box
    head.position = Vector3(0, 0.46, midpoint)
    head.material_override = metal
    root.add_child(head)

func _add_visible_coupler(front: AABB, rear: AABB, rear_offset: float, gap: float) -> void:
    # Static visual automatic coupler between car-end faces.
    var z0 := front.position.z + front.size.z
    var z1 := rear.position.z + rear_offset
    var mid := (z0 + z1) * 0.5
    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color(0.13, 0.14, 0.15)
    steel.metallic = 0.7
    steel.roughness = 0.64
    var coupler := Node3D.new()
    coupler.name = "VisibleInterCarCoupler"
    train.add_child(coupler)
    for y in [0.40, 0.56]:
        var shaft := MeshInstance3D.new()
        shaft.name = "CouplerSteelBar"
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.075
        mesh.bottom_radius = 0.075
        mesh.height = gap + 0.20
        shaft.mesh = mesh
        shaft.material_override = steel
        shaft.rotation.x = PI * 0.5
        shaft.position = Vector3(0, y, mid)
        coupler.add_child(shaft)
    var head := MeshInstance3D.new()
    head.name = "AutomaticCouplerHead"
    var head_mesh := BoxMesh.new()
    head_mesh.size = Vector3(0.42, 0.22, 0.20)
    head.mesh = head_mesh
    head.material_override = steel
    head.position = Vector3(0, 0.48, mid)
    coupler.add_child(head)
    for x in [-0.28, 0.28]:
        var hose := MeshInstance3D.new()
        hose.name = "CouplerAirHose"
        var hose_mesh := CylinderMesh.new()
        hose_mesh.top_radius = 0.025
        hose_mesh.bottom_radius = 0.025
        hose_mesh.height = gap + 0.14
        hose.mesh = hose_mesh
        hose.material_override = steel
        hose.rotation.x = PI * 0.5
        hose.position = Vector3(x, 0.28, mid)
        coupler.add_child(hose)

func _add_camera_controls(ui: CanvasLayer) -> void:
    var panel := VBoxContainer.new()
    panel.name = "CameraMovement"
    panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    panel.position = Vector2(-184, 55)
    panel.set_anchor(SIDE_LEFT, 1.0)
    panel.set_anchor(SIDE_RIGHT, 1.0)
    ui.add_child(panel)
    for entry in [["ВПЕРЁД", "forward"], ["НАЗАД", "back"], ["ВЛЕВО", "left"], ["ВПРАВО", "right"], ["ВЫШЕ", "up"], ["НИЖЕ", "down"], ["БЛИЖЕ", "near"], ["ДАЛЬШЕ", "far"], ["ЦЕНТР", "reset"], ["ВАГОН -", "previous_car"], ["ВАГОН +", "next_car"]]:
        var button := Button.new()
        button.text = entry[0]
        button.custom_minimum_size = Vector2(175, 42)
        panel.add_child(button)
        var action: String = entry[1]
        if action == "previous_car" or action == "next_car":
            button.pressed.connect(func(): _cycle_car_focus(-1 if action == "previous_car" else 1))
        elif action == "reset":
            button.pressed.connect(func(): _set_camera_mode("external"))
        else:
            button.button_down.connect(func(): camera_move[action] = true)
            button.button_up.connect(func(): camera_move[action] = false)

func _get_model_bounds(root: Node3D) -> AABB:
    var found := false
    var result := AABB()
    var pending: Array[Node] = [root]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        if node is MeshInstance3D:
            var mesh_node := node as MeshInstance3D
            if mesh_node.mesh != null:
                var local_bounds := mesh_node.get_aabb()
                var xf := root.global_transform.affine_inverse() * mesh_node.global_transform
                var transformed := xf * local_bounds
                if not found:
                    result = transformed
                    found = true
                else:
                    result = result.merge(transformed)
        for child in node.get_children():
            pending.append(child)
    return result

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        touch_dragging = event.pressed
        touch_last = event.position
    elif event is InputEventScreenDrag and touch_dragging:
        orbit_yaw -= event.relative.x * 0.008
        orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.006, -1.2, 1.2)
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        orbit_yaw -= event.relative.x * 0.008
        orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.006, -1.2, 1.2)
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            orbit_radius = maxf(0.35, orbit_radius * 0.85)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            orbit_radius = minf(120.0, orbit_radius * 1.15)

func _box(parent: Node3D, pos: Vector3, dimensions: Vector3, color: Color) -> void:
    var item := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    item.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    item.material_override = mat
    item.position = pos
    parent.add_child(item)

func _physics_process(delta: float) -> void:
    if throttle:
        speed = minf(speed + delta * 1.4, 22.0)
    elif brake:
        speed = maxf(speed - delta * 3.0, 0.0)
    else:
        speed = maxf(speed - delta * 0.12, 0.0)
    distance = maxf(12.0, distance - speed * delta)
    train.position.z = distance
    var step := CAMERA_MOVE_SPEED * delta
    if camera_move.get("forward", false): camera_pan.z -= step
    if camera_move.get("back", false): camera_pan.z += step
    if camera_move.get("left", false): camera_pan.x -= step
    if camera_move.get("right", false): camera_pan.x += step
    if camera_move.get("up", false): camera_pan.y += step
    if camera_move.get("down", false): camera_pan.y -= step
    if camera_move.get("near", false): orbit_radius = maxf(0.35, orbit_radius - step)
    if camera_move.get("far", false): orbit_radius = minf(90.0, orbit_radius + step)
    _update_camera()
    var station_distance := maxf(0.0, distance + _train_bounds.position.z - _station_stop_z)
    var illumination := station_illumination(station_distance)
    station_approach_changed.emit(station_distance, illumination)
    _diagnostic_clock += delta
    if _diagnostic_clock >= 1.0:
        _diagnostic_clock = 0.0
        _publish_diagnostics()
    hud.text = "V106 · 4 ВАГОНА | %.0f км/ч | %.1f м | %s" % [speed * 3.6, distance, camera_mode]

func _update_camera() -> void:
    if camera_mode == "external":
        var focus := train.global_position + wagon_center + camera_pan
        var offset := Vector3(sin(orbit_yaw)*cos(orbit_pitch),sin(orbit_pitch),cos(orbit_yaw)*cos(orbit_pitch))*orbit_radius
        var desired := focus + offset
        if is_instance_valid(_tunnel) and _tunnel.has_method("constrain_camera"):
            desired = _tunnel.call("constrain_camera",desired)
        camera.global_position = desired
        if desired.distance_squared_to(focus) > 0.001:
            camera.look_at(focus, Vector3.UP)
    else:
        var cabin := camera_mode == "cabin"
        var local_eye := Vector3(-0.4 if cabin else 0.0,2.35,_train_bounds.position.z+1.35 if cabin else -2.0)
        var desired := train.to_global(local_eye + camera_pan)
        camera.global_position = _tunnel.call("constrain_camera",desired) if is_instance_valid(_tunnel) else desired
        camera.rotation = Vector3(-orbit_pitch,orbit_yaw,0)

func _configure_tunnel() -> void:
    _train_bounds = _get_model_bounds(train)
    _car_centers.clear()
    for child in train.get_children():
        if str(child.name).begins_with("OriginalV106Car"):
            _car_centers.append(child.position+_get_model_bounds(child).get_center())
    _focused_car = mini(_focused_car,_car_centers.size()-1)
    wagon_center = _car_centers[_focused_car]
    if is_instance_valid(_tunnel) and camera != null:
        _tunnel.call("configure",train,_train_bounds,camera)

func _add_headlight() -> void:
    var headlight := SpotLight3D.new()
    headlight.name = "TrainHeadlight"
    headlight.position = Vector3(0.0,1.55,_train_bounds.position.z-0.15)
    headlight.light_color = Color(0.92,0.91,0.80)
    headlight.light_energy = 2.0
    headlight.spot_range = 42.0
    headlight.spot_angle = 42.0
    headlight.shadow_enabled = true
    train.add_child(headlight)

func _set_camera_mode(mode: String) -> void:
    camera_mode = mode
    _focused_car = 0
    if not _car_centers.is_empty():
        wagon_center = _car_centers[0]
    camera_pan = Vector3.ZERO
    orbit_radius = 8.0
    orbit_yaw = 0.35 if mode == "external" else 0.0
    orbit_pitch = 0.10 if mode == "external" else 0.0
    _update_camera()
    _publish_diagnostics()
    print("CAMERA_MODE ",mode)

func _add_view_modes(ui: CanvasLayer) -> void:
    var row := HBoxContainer.new()
    row.name = "ViewModes"
    row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    row.offset_top = -145
    row.offset_bottom = -97
    ui.add_child(row)
    for entry in [["СНАРУЖИ","external"],["КАБИНА","cabin"],["САЛОН","salon"]]:
        var button := Button.new()
        button.text = entry[0]
        button.custom_minimum_size = Vector2(150,48)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(button)
        var mode: String = entry[1]
        button.pressed.connect(func(): _set_camera_mode(mode))

# A station is attached once, before entering the 150 m approach zone.
# StationBase can be supplied by the route scene without duplicating its assets.
func attach_station(scene: PackedScene, placement: Transform3D, stop_z: float) -> void:
    if is_instance_valid(_station):
        _station.queue_free()
    _station = scene.instantiate() as Node3D
    assert(_station != null,"Station root must be Node3D")
    add_child(_station)
    _station.global_transform = placement
    _station_stop_z = stop_z

func station_illumination(distance_m: float) -> float:
    return 1.0 - smoothstep(30.0,150.0,distance_m)

func _log_render_metrics() -> void:
    await get_tree().create_timer(3.0).timeout
    print("RENDER_METRICS ",JSON.stringify({
        "camera_mode":camera_mode,
        "objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
        "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
        "texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
        "buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
        "fps":Engine.get_frames_per_second(),
        "modules":_tunnel.call("active_module_count"),
        "coverage":_tunnel.call("coverage_is_valid")
    }))

func diagnostic_state() -> Dictionary:
    var cars := 0
    for child in train.get_children():
        if str(child.name).begins_with("OriginalV106Car"):
            cars += 1
    return {
        "cars":cars,"focused_car":_focused_car+1,"speed":speed,"distance":distance,"view":camera_mode,
        "length":_train_bounds.size.z,
        "modules":_tunnel.call("active_module_count"),
        "recycles":_tunnel.get("recycle_count"),
        "coverage":_tunnel.call("coverage_is_valid"),
        "fps":Engine.get_frames_per_second(),
        "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
        "buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)
    }

func _publish_diagnostics() -> void:
    if _diagnostics_enabled:
        JavaScriptBridge.eval("window.metro2Diagnostics = "+JSON.stringify(diagnostic_state())+"; null",true)

func _cycle_car_focus(direction: int) -> void:
    if _car_centers.is_empty():
        return
    var next := posmod(_focused_car+direction,_car_centers.size())
    _set_camera_mode("external")
    _focused_car = next
    wagon_center = _car_centers[_focused_car]
    _update_camera()
    _publish_diagnostics()
