extends Node3D
const CAR04 = preload("res://assets/v106_original/car04/v106_car_04.glb")
var camera: Camera3D
var target := Vector3.ZERO
var orbit_yaw := 0.5
var orbit_pitch := 0.25
var orbit_radius := 20.0
var dragging := false

func _ready() -> void:
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.12, 0.17, 0.23)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color.WHITE
    env.ambient_light_energy = 1.0
    env_node.environment = env
    add_child(env_node)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45, 25, 0)
    light.light_energy = 2.0
    add_child(light)
    var wagon := CAR04.instantiate()
    add_child(wagon)
    var box := _bounds(wagon)
    camera = Camera3D.new()
    add_child(camera)
    camera.current = true
    camera.far = 250.0
    target = box.get_center()
    orbit_radius = maxf(8.0, box.size.length() * 0.85)
    _update_camera()
    var label := Label.new()
    label.text = "CAR04 ONLY | Drag to rotate | Pinch to zoom"
    label.position = Vector2(12, 12)
    add_child(label)

func _bounds(root: Node3D) -> AABB:
    var found := false
    var bounds := AABB()
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var node := stack.pop_back()
        if node is MeshInstance3D:
            var mi := node as MeshInstance3D
            if mi.mesh:
                var a := mi.global_transform * mi.get_aabb()
                if not found:
                    bounds = a
                    found = true
                else:
                    bounds = bounds.merge(a)
        for child in node.get_children():
            stack.append(child)
    return bounds if found else AABB(Vector3.ZERO, Vector3(3, 3, 20))

func _update_camera() -> void:
    if not is_instance_valid(camera):
        return
    var direction := Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch))
    camera.position = target + direction * orbit_radius
    camera.look_at(target, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        dragging = event.pressed
    elif event is InputEventScreenDrag:
        orbit_yaw -= event.relative.x * 0.008
        orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.006, -1.3, 1.3)
        _update_camera()
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            orbit_radius = maxf(2.0, orbit_radius * 0.85)
            _update_camera()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            orbit_radius = minf(120.0, orbit_radius * 1.15)
            _update_camera()
    elif event is InputEventMouseMotion and dragging:
        orbit_yaw -= event.relative.x * 0.008
        orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.006, -1.3, 1.3)
        _update_camera()
