extends Node3D
const V106_SCENE = preload("res://assets/v106_lod1/v106_car01_lod1_mesh289_normals_fixed.glb")
## Touch orbit camera around the imported V106 wagon.
var camera: Camera3D
var train: Node3D
var speed := 0.0
var throttle := false
var brake := false
var hud: Label
var distance := 300.0
var orbit_yaw := -0.45
var orbit_pitch := 0.20
var orbit_radius := 4.6
var touch_dragging := false
var touch_last := Vector2.ZERO
var wagon_center := Vector3(0, 1.2, 0)

func _ready() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.025, 0.045, 0.08)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.6, 0.7, 0.9)
    env.ambient_light_energy = 1.0
    world.environment = env
    add_child(world)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-40, -25, 0)
    light.light_energy = 1.5
    add_child(light)
    train = Node3D.new()
    train.name = "PlayerTrainPlacement"
    add_child(train)
    train.position = Vector3(0.992, 0.22, distance)
    var original_car := V106_SCENE.instantiate()
    original_car.name = "OriginalV106Car01"
    train.add_child(original_car)
    print("V106 SINGLE CAR: imported model instantiated")
    var bounds := _get_model_bounds(original_car)
    if bounds.size.length() > 0.01:
        wagon_center = bounds.get_center()
        orbit_radius = 4.6
        print("V106 BOUNDS: ", bounds)
    var authentic_tunnel := Node3D.new()
    authentic_tunnel.name = "ExistingTunnelRoute"
    authentic_tunnel.position.x = 0.992
    authentic_tunnel.set_script(load("res://scripts/tunnel_v2.gd"))
    add_child(authentic_tunnel)
    _remove_intruding_branch_and_shadow_artifacts(authentic_tunnel)
    _stabilize_tunnel_lighting(authentic_tunnel)
    _add_simple_track()
    camera = Camera3D.new()
    camera.current = true
    camera.far = 450
    camera.near = 0.04
    add_child(camera)
    var ui := CanvasLayer.new()
    add_child(ui)
    hud = Label.new()
    hud.position = Vector2(15, 15)
    hud.add_theme_font_size_override("font_size", 22)
    hud.add_theme_color_override("font_color", Color.YELLOW)
    ui.add_child(hud)
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
    go.button_up.connect(func(): throttle = false)
    var stop := Button.new()
    stop.text = "ТОРМОЗ"
    stop.custom_minimum_size = Vector2(180, 75)
    stop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(stop)
    stop.button_down.connect(func(): brake = true)
    stop.button_up.connect(func(): brake = false)
    _update_camera()

func _remove_intruding_branch_and_shadow_artifacts(tunnel: Node3D) -> void:
    # Diagnostic variant: eliminate the visual-only junction geometry that
    # intersects the running clearance; preserve the main bore and V106.
    for name in ["DepotSideBranch_Curved_VisualOnly", "DepotSwitchConnection_VisualOnly", "DepotBranchTrack_VisualOnly"]:
        var extra := tunnel.get_node_or_null(name)
        if extra != null:
            tunnel.remove_child(extra)
            extra.queue_free()
    # Mobile Web: disable dynamic shadows from small wall fixtures.
    # Diffuser emission and the rest of the tunnel lighting remain.
    var pending: Array[Node] = [tunnel]
    while not pending.is_empty():
        var node := pending.pop_back()
        if node is OmniLight3D:
            node.shadow_enabled = false
        for child in node.get_children():
            pending.append(child)

func _stabilize_tunnel_lighting(tunnel: Node3D) -> void:
    # Fixed electrical lighting: intensity is determined by the authored
    # tunnel segment, never by camera distance or approaching train.
    var pending: Array[Node] = [tunnel]
    while not pending.is_empty():
        var node := pending.pop_back()
        if node is OmniLight3D:
            node.distance_fade_enabled = false
            node.shadow_enabled = false
        for child in node.get_children():
            pending.append(child)

func _add_simple_track() -> void:
    # Isolated preview only: straight rails underneath V106 at z=110..310.
    # Do not use dynamic path scripts or MultiMesh until basic rendering is confirmed.
    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color(0.68, 0.72, 0.76)
    steel.metallic = 0.4
    for x_offset in [-0.9, 0.9]:
        var rail := MeshInstance3D.new()
        rail.name = "PreviewRail"
        var shape := BoxMesh.new()
        shape.size = Vector3(0.10, 0.16, 200.0)
        rail.mesh = shape
        rail.material_override = steel
        rail.position = Vector3(0.992 + x_offset, -0.08, 210.0)
        add_child(rail)

func _get_model_bounds(root: Node3D) -> AABB:
    var found := false
    var result := AABB()
    var pending: Array[Node] = [root]
    while not pending.is_empty():
        var node := pending.pop_back()
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
            orbit_radius = maxf(4.0, orbit_radius * 0.85)
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
    _update_camera()
    hud.text = "V106 + MINSK TUNNEL | %.0f km/h | Swipe: rotate | Radius %.1fm" % [speed * 3.6, orbit_radius]

func _update_camera() -> void:
    var focus := train.global_position + wagon_center
    var offset := Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * orbit_radius
    camera.global_position = focus + offset
    camera.look_at(focus, Vector3.UP)
