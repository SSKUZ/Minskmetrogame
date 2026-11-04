extends Node3D
const CAR04 = preload("res://assets/v106_original/car04/v106_car_04.glb")

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
    var cam := Camera3D.new()
    add_child(cam)
    cam.current = true
    cam.far = 250.0
    var center := box.get_center()
    var radius := maxf(8.0, box.size.length() * 0.85)
    cam.position = center + Vector3(radius * 0.55, radius * 0.28, radius)
    cam.look_at(center, Vector3.UP)
    var label := Label.new()
    label.text = "CAR04 ONLY | standalone model test"
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
