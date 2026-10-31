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
var cab_view: bool = false
var initial_train_position: Vector3
var hud: Label

func _ready() -> void:
    initial_train_position = train.position
    _make_controls()
    _update_camera()
    _update_hud()

func _physics_process(delta: float) -> void:
    var acceleration: float = -COAST_MPS2
    if braking:
        acceleration = -BRAKE_MPS2
    elif throttle:
        acceleration = ACCEL_MPS2
    speed_mps = clampf(speed_mps + acceleration * delta, 0.0, MAX_SPEED_MPS)
    # Original consist faces toward decreasing Z.
    train.position.z -= speed_mps * delta
    _update_camera()
    _update_hud()

func _update_camera() -> void:
    if cab_view:
        # Camera inside the leading head car, facing the travel direction (-Z).
        camera.position = train.position + Vector3(-0.35, 2.65, -7.6)
        camera.rotation_degrees = Vector3.ZERO
        camera.fov = 75.0
    else:
        camera.position = train.position + Vector3(-34.0, 21.0, 94.0)
        camera.look_at(train.position + Vector3(0.0, 1.5, 29.0), Vector3.UP)
        camera.fov = 65.0

func _update_hud() -> void:
    if hud != null:
        hud.text = "МИНСКОЕ МЕТРО 2.0  |  %.0f км/ч  |  %s" % [
            speed_mps * 3.6, "КАБИНА" if cab_view else "ОБЗОР"
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
    view.pressed.connect(func() -> void: cab_view = not cab_view)

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
