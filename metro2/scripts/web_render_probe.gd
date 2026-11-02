extends Node3D
## Standalone Godot WebGL probe. No gameplay assets or dependencies.

func _ready() -> void:
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.06, 0.24, 0.55)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color.WHITE
    env.ambient_light_energy = 0.7
    environment.environment = env
    add_child(environment)

    var camera := Camera3D.new()
    camera.position = Vector3(0.0, 0.0, 3.0)
    camera.look_at(Vector3.ZERO, Vector3.UP)
    camera.current = true
    add_child(camera)

    var cube := MeshInstance3D.new()
    cube.name = "MagentaProbeCube"
    var box := BoxMesh.new()
    box.size = Vector3(1.4, 1.4, 1.4)
    cube.mesh = box
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(1.0, 0.0, 0.85)
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    cube.material_override = material
    add_child(cube)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
    add_child(light)

    var layer := CanvasLayer.new()
    add_child(layer)
    var label := Label.new()
    label.text = "GODOT WEB 3D TEST | MAGENTA CUBE | v1"
    label.position = Vector2(18, 24)
    label.add_theme_color_override("font_color", Color.YELLOW)
    label.add_theme_font_size_override("font_size", 20)
    layer.add_child(label)
    print("GODOT WEB 3D TEST: cube, camera, environment and light ready")
