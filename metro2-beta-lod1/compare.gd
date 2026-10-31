extends Node3D

var camera: Camera3D
var pivot := Vector3(0, 1.5, 0)
var yaw := 0.65
var pitch := 0.27
var distance := 29.0
var touches: Dictionary = {}
var fps: Label

func _ready() -> void:
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(0.16, 0.19, 0.23)
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color = Color(0.9, 0.93, 1.0)
    environment.environment.ambient_light_energy = 0.8
    add_child(environment)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45, -30, 0)
    light.light_energy = 1.2
    add_child(light)
    for index in range(2):
        var path := "res://assets/original.glb" if index == 0 else "res://assets/lod1.glb"
        var car: Node3D = load(path).instantiate()
        car.name = "ORIGINAL" if index == 0 else "LOD1"
        car.position.x = -3.0 if index == 0 else 3.0
        # Compare supplied meshes, without Godot automatically selecting generated LODs.
        _disable_generated_lods(car)
        add_child(car)
        var label := Label3D.new()
        label.text = car.name
        label.position = Vector3(car.position.x, 4.4, 0)
        label.font_size = 72
        label.pixel_size = 0.008
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.no_depth_test = true
        add_child(label)
    camera = Camera3D.new()
    camera.near = 0.03
    camera.far = 400.0
    add_child(camera)
    camera.current = true
    var canvas := CanvasLayer.new()
    add_child(canvas)
    var panel := VBoxContainer.new()
    panel.position = Vector2(16, 12)
    canvas.add_child(panel)
    fps = Label.new()
    fps.add_theme_font_size_override("font_size", 26)
    panel.add_child(fps)
    var hint := Label.new()
    hint.text = "1 finger: orbit | 2 fingers: pan / pinch zoom"
    hint.add_theme_font_size_override("font_size", 22)
    panel.add_child(hint)
    var row := HBoxContainer.new()
    panel.add_child(row)
    for caption in ["BOTH", "ORIGINAL", "LOD1", "+", "−"]:
        var button := Button.new()
        button.text = caption
        button.custom_minimum_size = Vector2(150, 66)
        button.add_theme_font_size_override("font_size", 24)
        button.pressed.connect(_select.bind(caption))
        row.add_child(button)
    _update_camera()

func _disable_generated_lods(node: Node) -> void:
    if node is GeometryInstance3D:
        node.lod_bias = 1000000.0
    for child in node.get_children():
        _disable_generated_lods(child)

func _select(caption: String) -> void:
    touches.clear()
    if caption == "+": distance = maxf(0.4, distance * 0.8)
    elif caption == "−": distance = minf(100, distance * 1.25)
    else:
        pivot = Vector3(-3 if caption == "ORIGINAL" else (3 if caption == "LOD1" else 0), 1.5, 0)
        distance = 21.0 if caption != "BOTH" else 29.0
    _update_camera()

func _process(_delta: float) -> void:
    fps.text = "V106 vs LOD1 | FPS: %d | %s" % [Engine.get_frames_per_second(), RenderingServer.get_video_adapter_name()]

func _input(event: InputEvent) -> void:
    # Track releases even when a touch ends over a UI control.
    if event is InputEventScreenTouch and not event.pressed:
        touches.erase(event.index)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed: touches[event.index] = event.position
    elif event is InputEventScreenDrag and touches.has(event.index):
        var old: Vector2 = touches[event.index]
        if touches.size() == 1:
            yaw -= event.relative.x * 0.005
            pitch = clampf(pitch + event.relative.y * 0.005, -1.4, 1.4)
        else:
            var other: Vector2 = old
            for key in touches:
                if key != event.index:
                    other = touches[key]
                    break
            var previous_distance := old.distance_to(other)
            var new_distance: float = event.position.distance_to(other)
            if new_distance > 5.0:
                distance = clampf(distance * previous_distance / new_distance, 0.4, 100.0)
            var shift: Vector2 = event.position - old
            pivot += (-camera.global_basis.x * shift.x + camera.global_basis.y * shift.y) * distance * 0.0007
        touches[event.index] = event.position
        _update_camera()
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        yaw -= event.relative.x * 0.005
        pitch = clampf(pitch + event.relative.y * 0.005, -1.4, 1.4)
        _update_camera()
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(0.4, distance * 0.9)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(100, distance * 1.1)
        _update_camera()

func _update_camera() -> void:
    camera.position = pivot + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
    camera.look_at(pivot)
