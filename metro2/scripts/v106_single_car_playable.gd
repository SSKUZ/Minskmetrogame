extends Node3D
const V106_SCENE = preload("res://assets/v106_lod1/v106_car01_lod1_mesh289_normals_fixed.glb")
## Asset-free playable fallback to isolate heavy imported models from Web rendering.
var camera: Camera3D
var train: Node3D
var speed := 0.0
var throttle := false
var brake := false
var hud: Label
var distance := 300.0

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
    add_child(train)
    train.position = Vector3(0, 0, distance)
    var original_car := V106_SCENE.instantiate()
    original_car.name = "OriginalV106Car01"
    train.add_child(original_car)
    print("V106 SINGLE CAR: imported model instantiated")
    for i in range(18):
        var z := 20.0 + i * 20.0
        _box(self, Vector3(-2.6, 1.5, z), Vector3(0.25, 3.0, 19.0), Color(0.34, 0.36, 0.4))
        _box(self, Vector3(2.6, 1.5, z), Vector3(0.25, 3.0, 19.0), Color(0.34, 0.36, 0.4))
        _box(self, Vector3(0, 3.15, z), Vector3(5.4, 0.25, 19.0), Color(0.31, 0.33, 0.37))
        _box(self, Vector3(-0.75, -0.05, z), Vector3(0.1, 0.15, 19.0), Color(0.65, 0.68, 0.72))
        _box(self, Vector3(0.75, -0.05, z), Vector3(0.1, 0.15, 19.0), Color(0.65, 0.68, 0.72))
        _box(self, Vector3(0, -0.18, z), Vector3(5.0, 0.2, 19.0), Color(0.17, 0.18, 0.2))
    camera = Camera3D.new()
    camera.current = true
    camera.far = 450
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
    hud.text = "GODOT V106 CAR 01 | %.0f km/h | Z %.1f | 3D TUNNEL" % [speed * 3.6, distance]

func _update_camera() -> void:
    camera.position = train.position + Vector3(-7.0, 4.2, -16.0)
    camera.look_at(train.position + Vector3(0, 1.2, 0), Vector3.UP)
    camera.rotation = Vector3.ZERO
