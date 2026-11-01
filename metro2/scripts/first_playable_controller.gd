extends Node3D
## First playable route: touch throttle/brake, doors and three camera views.
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
const STATION_STOP_Z := 9.603
var status_label: Label
var hud: Label

func _ready() -> void:
    initial_train_position = train.position
    door_system = load("res://scripts/v106_door_controller.gd").new()
    door_system.name = "DoorSystem"
    add_child(door_system)
    door_system.setup(train)
    if not door_system.validated:
        push_warning("V106 doors are not validated; movement is blocked.")
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

func _update_camera() -> void:
    if camera_mode == 0:
        camera.position = Vector3(-12.5, 5.5, 48.0)
        camera.look_at(Vector3(0.992, 1.6, 49.0), Vector3.UP)
        camera.fov = 65.0
    elif camera_mode == 1:
        camera.position = train.position + Vector3(-0.35, 2.65, -8.6)
        camera.rotation_degrees = Vector3.ZERO
        camera.fov = 75.0
    else:
        camera.position = train.position + Vector3(0.0, 2.75, 12.0)
        camera.rotation_degrees = Vector3.ZERO
        camera.fov = 80.0

func _update_hud() -> void:
    if status_label != null:
        var remaining := train.position.z - STATION_STOP_Z
        status_label.text = "До точки остановки: %.0f м  |  Двери: %s" % [remaining, "ОТКРЫТЫ" if door_system.target_open else "ЗАКРЫТЫ"]
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

    status_label = Label.new()
    status_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    status_label.offset_top = 66.0
    status_label.offset_bottom = 106.0
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 19)
    canvas.add_child(status_label)

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
    doors_open.pressed.connect(func() -> void:
        if absf(train.position.z - STATION_STOP_Z) <= 5.0:
            door_system.request_open(speed_mps)
    )

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
    door_system.request_close()
    train.position = initial_train_position
