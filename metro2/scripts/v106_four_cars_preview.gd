extends Node3D
const CAB_RUNTIME = preload("res://scripts/cab_v37.gd")
const DOOR_SYSTEM = preload("res://scripts/v33_door_controller.gd")
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
@export var route_end_distance := 12.0
@export var tunnel_script: Script
var distance := 300.0
var orbit_yaw := 0.35
var orbit_pitch := 0.10
var orbit_radius := 4.6
var _touch_points: Dictionary = {}
var _pinching := false
var _pinch_distance := 0.0
var _cab_fov := 80.0
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
var cab_runtime: Node3D
var door_system: Node
var _ui_layer: CanvasLayer

func _ready() -> void:
    print("TZ30_BOOT ready")
    _diagnostics_enabled = OS.has_feature("web")
    print("TZ30_BOOT diagnostics configured")
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.006, 0.008, 0.012)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.50, 0.49, 0.46)
    env.ambient_light_energy = 0.085
    _environment = env
    env.fog_enabled = true
    env.fog_mode = Environment.FOG_MODE_DEPTH
    env.fog_depth_begin = 60.0
    env.fog_depth_end = 120.0
    env.fog_depth_curve = 1.2
    env.fog_density = 1.0
    env.fog_light_color = Color(0.006,0.008,0.012)
    env.fog_light_energy = 0.025
    env.fog_sun_scatter = 0.0
    world.environment = env
    add_child(world)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-40, -25, 0)
    light.light_energy = 0.025
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
    tunnel.set_script(tunnel_script if tunnel_script != null else load("res://scripts/tunnel_lightweight_straight.gd"))
    add_child(tunnel)
    camera = Camera3D.new()
    camera.current = true
    camera.far = 120
    camera.near = 0.04
    add_child(camera)
    var ui := CanvasLayer.new()
    _ui_layer = ui
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
    door_system = DOOR_SYSTEM.new()
    door_system.name = "SharedDoorSystem"
    add_child(door_system)
    door_system.call("setup",train)
    cab_runtime = CAB_RUNTIME.new()
    cab_runtime.name = "OriginalCabIntegration"
    var lead := train.get_node("OriginalV106Car01") as Node3D
    lead.add_child(cab_runtime)
    cab_runtime.call("initialize",self,lead,door_system)
    cab_runtime.call("make_screen_controls",_ui_layer)
    var lighting := preload("res://scripts/train_interior_v36.gd").new()
    lighting.name = "TrainInteriorLighting"
    add_child(lighting)
    lighting.initialize(self,train,_ui_layer)
    _configure_tunnel()
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

func _zoom_view(ratio: float) -> void:
    if camera_mode == "cabin":
        _cab_fov = clampf(_cab_fov/ratio,42.0,105.0)
        camera.fov = _cab_fov
    else:
        orbit_radius = clampf(orbit_radius/ratio,0.35,120.0)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed: _touch_points[event.index] = event.position
        else: _touch_points.erase(event.index)
        if _touch_points.size() >= 2:
            _pinching = true
            touch_dragging = false
            if is_instance_valid(cab_runtime): cab_runtime.call("cancel_interaction")
            var points := _touch_points.values()
            _pinch_distance = (points[0] as Vector2).distance_to(points[1])
            get_viewport().set_input_as_handled()
        elif _pinching:
            get_viewport().set_input_as_handled()
            if _touch_points.is_empty():
                _pinching = false
                _pinch_distance = 0.0
        return
    if event is InputEventScreenDrag:
        if _touch_points.has(event.index): _touch_points[event.index] = event.position
        if _pinching:
            if _touch_points.size() >= 2:
                var points := _touch_points.values()
                var span := (points[0] as Vector2).distance_to(points[1])
                if _pinch_distance > 5.0 and span > 5.0: _zoom_view(span/_pinch_distance)
                _pinch_distance = span
            get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
    if _pinching or (event is InputEventMouse and not _touch_points.is_empty()): return
    if is_instance_valid(cab_runtime) and cab_runtime.call("handle_input",event,camera):
        get_viewport().set_input_as_handled()
        return
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
            _zoom_view(1.15)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom_view(1.0/1.15)

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
    var dt := minf(delta,0.1)
    var direction := 1
    if is_instance_valid(cab_runtime):
        var input: Dictionary = cab_runtime.call("physics_inputs",dt,speed,throttle,brake)
        direction = int(input.direction)
        if float(input.brake) > 0.001:
            speed = maxf(speed-dt*3.0*float(input.brake)*float(input.adhesion),0.0)
        elif float(input.traction) > 0.0:
            speed = minf(speed+dt*1.4*float(input.traction)*float(input.adhesion),22.0)
        else:
            speed = maxf(speed-dt*0.12,0.0)
    elif brake:
        speed = maxf(speed-dt*3.0,0.0)
    elif throttle:
        speed = minf(speed+dt*1.4,22.0)
    else:
        speed = maxf(speed-dt*0.12,0.0)
    distance = maxf(route_end_distance,distance-float(direction)*speed*dt)
    if distance <= route_end_distance and direction == 1: speed = 0.0
    train.position.z = distance
    var step := CAMERA_MOVE_SPEED * delta
    if camera_mode == "cabin":
        orbit_yaw = clampf(orbit_yaw,-PI*0.5,PI*0.5)
    if camera_move.get("forward", false): camera_pan.z -= step
    if camera_move.get("back", false): camera_pan.z += step
    if camera_move.get("left", false): camera_pan.x -= step
    if camera_move.get("right", false): camera_pan.x += step
    if camera_move.get("up", false): camera_pan.y += step
    if camera_move.get("down", false): camera_pan.y -= step
    if camera_move.get("near", false): _zoom_view(exp(delta))
    if camera_move.get("far", false): _zoom_view(exp(-delta))
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
        if cabin and is_instance_valid(cab_runtime):
            local_eye = cab_runtime.call("eye_in_train")
        if cabin:
            orbit_yaw = clampf(orbit_yaw,-PI*0.5,PI*0.5)
        var desired := train.to_global(local_eye if cabin else local_eye + camera_pan)
        camera.global_position = _tunnel.call("constrain_camera",desired) if is_instance_valid(_tunnel) else desired
        if cabin:
            camera.global_basis = train.global_basis*Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0))
        else:
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
    var lead := train.get_node("OriginalV106Car01") as Node3D
    _illuminate_headlamp_lenses(lead)
    # Use the actual outer lamp nodes of the preserved V106 GLB.
    for index in range(2):
        var lamp := lead.find_child("headlamp-0" if index == 0 else "headlamp-5",true,false) as Node3D
        if lamp == null:
            push_error("V106 headlamp attachment node missing")
            continue
        var headlight := SpotLight3D.new()
        headlight.name = "TrainHeadlightLeft" if index == 0 else "TrainHeadlightRight"
        lead.add_child(headlight)
        headlight.position = lead.to_local(lamp.global_position)+Vector3(0,0,-0.07)
        headlight.rotation = Vector3(deg_to_rad(-1.5),deg_to_rad(1.8 if index == 0 else -1.8),0)
        headlight.light_color = Color(1.0,0.94,0.82)
        headlight.light_energy = 3.5
        headlight.spot_range = 105.0
        headlight.spot_angle = 32.0
        headlight.spot_attenuation = 1.2
        headlight.spot_angle_attenuation = 1.5
        headlight.shadow_enabled = true


func _illuminate_headlamp_lenses(lead: Node3D) -> void:
    # Emission changes only the existing front glass surfaces. Shared GLB
    # materials, lamp housings and the two lighting beams remain untouched.
    var glowing_lens: BaseMaterial3D
    var lit_lamps := 0
    for index in range(6):
        var lamp := lead.find_child("headlamp-%d" % index,true,false) as Node3D
        if lamp == null:
            push_error("V106 headlamp lens node missing")
            continue
        var lit := false
        for child in lamp.find_children("*","MeshInstance3D",true,false):
            var lens := child as MeshInstance3D
            if lens.mesh == null:
                continue
            for surface in range(lens.mesh.get_surface_count()):
                var original := lens.get_active_material(surface) as BaseMaterial3D
                if original == null or original.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED or original.albedo_color.a >= 0.5:
                    continue
                if glowing_lens == null:
                    glowing_lens = original.duplicate() as BaseMaterial3D
                    glowing_lens.albedo_color = Color(0.65,0.60,0.49,1.0)
                    glowing_lens.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
                    glowing_lens.emission_enabled = true
                    glowing_lens.emission = Color(1.0,0.94,0.82)
                    glowing_lens.emission_energy_multiplier = 1.5
                lens.set_surface_override_material(surface,glowing_lens)
                lit = true
        if lit:
            lit_lamps += 1
    if lit_lamps != 6:
        push_error("V106: expected six illuminated headlamp lenses, found %d" % lit_lamps)

func _set_camera_mode(mode: String) -> void:
    camera_mode = mode
    camera.fov = _cab_fov if mode == "cabin" else 75.0
    if is_instance_valid(cab_runtime): cab_runtime.call("cancel_interaction")
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

func diagnostic_state() -> Dictionary:
    var cars := 0
    for child in train.get_children():
        if str(child.name).begins_with("OriginalV106Car"):
            cars += 1
    return {
        "cab_loaded":is_instance_valid(cab_runtime) and bool(cab_runtime.get("ready_for_play")),
        "cab_version":"cab-r2.1-v39-r2",
        "cab_cleanup_ready":bool(cab_runtime.get("cleanup_ready")) if is_instance_valid(cab_runtime) else false,
        "saloon_lights":get_node("TrainInteriorLighting").get("lights").size() if has_node("TrainInteriorLighting") else 0,
        "saloon_cars":int(get_node("TrainInteriorLighting").get("cars_lit")) if has_node("TrainInteriorLighting") else 0,
        "cab_textures_verified":int(cab_runtime.get("_source_recipe").get("verified_nonempty_images",0)) if is_instance_valid(cab_runtime) else 0,
        "door_system_ready":is_instance_valid(door_system) and bool(door_system.get("validated")),
        "tunnel_visible":_tunnel.is_visible_in_tree(),"train_visible":train.is_visible_in_tree(),
        "cars":cars,"focused_car":_focused_car+1,"speed":speed,"distance":distance,"view":camera_mode,
        "length":_train_bounds.size.z,
        "modules":_tunnel.call("active_module_count"),
        "recycles":_tunnel.get("recycle_count"),
        "coverage":_tunnel.call("coverage_is_valid"),
        "headlights":train.get_node("OriginalV106Car01").find_children("TrainHeadlight*","SpotLight3D",true,false).size()
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


