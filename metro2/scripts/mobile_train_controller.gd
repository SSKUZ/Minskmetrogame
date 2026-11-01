extends Node3D
## Mobile prototype controller: train motion and two camera presets.
## Original GLB geometry and doors are not modified.
const MAX_SPEED_MPS := 25.0
const ACCEL_MPS2 := 1.2
const BRAKE_MPS2 := 2.0
const COAST_MPS2 := 0.12

@onready var train: Node3D = $PlayerTrainPlacement
@onready var camera: Camera3D = $OverviewCamera

var speed_mps: float = 0.0
var throttle: bool = false
var braking: bool = false
var camera_mode: int = 0
var door_system: Node
var initial_train_position: Vector3
var hud: Label
var headlights: Array[SpotLight3D] = []
var cab_mount: Node3D
var cab_camera: Camera3D
const CAB_SCENE_PATH := "res://assets/cab/cab_81_717.glb"

func _ready() -> void:
    initial_train_position = train.position
    door_system = load("res://scripts/v106_door_controller.gd").new()
    door_system.name = "DoorSystem"
    add_child(door_system)
    door_system.setup(train)
    _make_cab_mount()
    _make_headlights()
    _make_controls()
    _update_camera()
    _update_hud()

func _physics_process(delta: float) -> void:
    var acceleration: float = -COAST_MPS2
    if braking:
        acceleration = -BRAKE_MPS2
    elif throttle and door_system.can_move():
        acceleration = ACCEL_MPS2
    speed_mps = clampf(speed_mps + acceleration * delta, 0.0, MAX_SPEED_MPS)
    # Original consist faces toward decreasing Z.
    train.position.z -= speed_mps * delta
    _update_camera()
    _update_hud()

func _make_cab_mount() -> void:
    # Real cab is exported from cab-development; never substitute an invented cab.
    # Mount and camera remain train-relative, unlike the legacy world-space camera.
    cab_mount = Node3D.new()
    cab_mount.name = "Cab81_717Mount"
    cab_mount.position = Vector3(0.0, 0.0, -8.0)
    train.add_child(cab_mount)
    if ResourceLoader.exists(CAB_SCENE_PATH):
        var cab_resource := load(CAB_SCENE_PATH)
        if cab_resource is PackedScene:
            var cab_instance := (cab_resource as PackedScene).instantiate()
            cab_instance.name = "Cab81_717"
            cab_mount.add_child(cab_instance)
    else:
        push_error("Cab GLB must be restored from metro2/assets/cab/parts before import: " + CAB_SCENE_PATH)
    cab_camera = Camera3D.new()
    cab_camera.name = "DriverCabCamera"
    cab_camera.position = Vector3(-0.38, 1.85, 2.5)
    cab_camera.rotation_degrees = Vector3.ZERO
    cab_camera.fov = 75.0
    cab_camera.far = 400.0
    cab_mount.add_child(cab_camera)

func _make_headlights() -> void:
    # Attach the light sources to the moving consist; train travels toward -Z.
    for side in [-1.0, 1.0]:
        var beam := SpotLight3D.new()
        beam.name = "HeadlightLeft" if side < 0.0 else "HeadlightRight"
        beam.position = Vector3(side * 1.02, 1.48, -8.0)
        # Godot SpotLight3D shines along local -Z, matching train travel.
        beam.rotation_degrees = Vector3.ZERO
        beam.light_color = Color("#f0f6ff")
        beam.light_energy = 2.8
        beam.spot_range = 88.0
        beam.spot_angle = 22.0
        beam.spot_attenuation = 1.4
        # Only one shadow-casting beam for mobile performance.
        beam.shadow_enabled = side < 0.0
        train.add_child(beam)
        headlights.append(beam)

func _update_camera() -> void:
    camera.current = camera_mode != 1
    if cab_camera != null:
        cab_camera.current = camera_mode == 1
    if camera_mode == 0:
        camera.position = train.position + Vector3(-23.0, 11.0, 41.0)
        camera.look_at(train.position + Vector3(0.0, 1.6, 24.0), Vector3.UP)
        camera.fov = 65.0
    elif camera_mode == 1:
        camera.position = train.position + Vector3(-0.35, 2.65, -7.6)
        camera.rotation_degrees = Vector3.ZERO
        camera.fov = 75.0
    else:
        camera.position = train.position + Vector3(0.0, 2.75, 12.0)
        camera.rotation_degrees = Vector3.ZERO
        camera.fov = 80.0

func _update_hud() -> void:
    if hud != null:
        hud.text = "МИНСКОЕ МЕТРО 2.0  |  %.0f км/ч  |  %s" % [
            speed_mps * 3.6, ["ПЛАТФОРМА", "КАБИНА", "САЛОН"][camera_mode]
        ]

func _make_controls() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "MobileControls"
    add_child(canvas)

    var background := PanelContainer.new()
    background.set_anchors_preset(Control.PRESET_TOP_WIDE)
    background.offset_bottom = 62.0
    canvas.add_child(background)
    hud = Label.new()
    hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hud.add_theme_font_size_override("font_size", 21)
    background.add_child(hud)

    var row := HBoxContainer.new()
    row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    row.offset_top = -100.0
    row.add_theme_constant_override("separation", 10)
    canvas.add_child(row)

    var accelerate := _button("РАЗГОН", row)
    accelerate.button_down.connect(func() -> void: throttle = true)
    accelerate.button_up.connect(func() -> void: throttle = false)
    accelerate.focus_exited.connect(func() -> void: throttle = false)

    var brake := _button("ТОРМОЗ", row)
    brake.button_down.connect(func() -> void: braking = true)
    brake.button_up.connect(func() -> void: braking = false)
    brake.focus_exited.connect(func() -> void: braking = false)

    var view := _button("КАМЕРА", row)
    view.pressed.connect(func() -> void: camera_mode = (camera_mode + 1) % 3)

    var doors_open := _button("ДВЕРИ +", row)
    doors_open.pressed.connect(func() -> void: door_system.request_open(speed_mps))

    var doors_close := _button("ДВЕРИ −", row)
    doors_close.pressed.connect(func() -> void: door_system.request_close())

    var reset := _button("СБРОС", row)
    reset.pressed.connect(_reset_train)

func _button(caption: String, parent: HBoxContainer) -> Button:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(100, 80)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 19)
    parent.add_child(button)
    return button

func _reset_train() -> void:
    throttle = false
    braking = false
    speed_mps = 0.0
    train.position = initial_train_position
