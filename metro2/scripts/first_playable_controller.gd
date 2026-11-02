extends Node3D
## First playable route: touch throttle/brake, doors and three camera views.
## Original GLB geometry and doors are not modified.
const TRACK_PATH = preload("res://scripts/playable_track_path.gd")
const DOOR_CONTROLLER = preload("res://scripts/v106_door_controller.gd")
const CAB_ADAPTER = preload("res://scripts/cab_v106_adapter.gd")
const MAX_SPEED_MPS := 25.0
const ROUTE_END_Z := 9.603
const STOP_EPSILON := 0.02
const ACCEL_MPS2 := 1.2
const MAX_PHYSICS_DELTA := 0.1
const BRAKE_MPS2 := 2.0
const COAST_MPS2 := 0.12

@onready var train: Node3D = $PlayerTrainPlacement
@onready var camera: Camera3D = $OverviewCamera

var speed_mps: float = 0.0
var throttle: bool = false
var braking: bool = false
var camera_mode: int = 1
var door_system: Node
var initial_train_position: Vector3
const STATION_STOP_Z := 9.603
const CURVE_START_Z := 210.0
const CURVE_END_Z := 146.0
const CURVE_OFFSET := 0.65
var initial_train_rotation: Vector3
var status_label: Label
var hud: Label
var touch_points: Dictionary = {}
var cab_yaw := 0.0
var cab_pitch := 0.0
var cab_zoom := 75.0
var pinch_last := -1.0
var mouse_dragging := false
var camera_drag_index := -1
const CAB_FOV_MIN := 45.0
const CAB_FOV_MAX := 90.0
const SALON_EYE := Vector3(-0.75, 2.7, 1.7)
var info_notice_until := 0
var platform_view_available := false
var platform_button: Button
var info_button: Button
var cab_adapter: Node3D
var door_button: Button
const PLATFORM_VIEW_Z := 112.0

func _ready() -> void:
    initial_train_position = train.position
    initial_train_rotation = train.rotation
    door_system = DOOR_CONTROLLER.new()
    door_system.name = "DoorSystem"
    add_child(door_system)
    door_system.call("setup", train)
    cab_adapter = CAB_ADAPTER.new()
    cab_adapter.name = "CabV106Adapter"
    train.add_child(cab_adapter)
    cab_adapter.call("initialize", train)
    if not cab_adapter.get("ready_for_play"):
        push_error("BLOCK A: original cab missing. Run python3 metro2/tools/prepare_cab.py BEFORE Godot import.")
    if not door_system.get("validated"):
        push_warning("V106 doors are not validated; movement is blocked.")
    _make_controls()
    _update_camera()
    _update_hud()

func _physics_process(delta: float) -> void:
    var acceleration: float = -COAST_MPS2
    if braking:
        acceleration = -BRAKE_MPS2
    elif throttle and door_system.call("can_move"):
        acceleration = ACCEL_MPS2
    var dt: float = clampf(delta, 0.0, MAX_PHYSICS_DELTA)
    var previous_speed: float = speed_mps
    speed_mps = clampf(speed_mps + acceleration * dt, 0.0, MAX_SPEED_MPS)
    # Original consist faces toward decreasing Z.
    # Clamp to the station stop; never overshoot into unbuilt track.
    var distance_to_stop: float = maxf(0.0, train.position.z - ROUTE_END_Z)
    var travel: float = minf((previous_speed + speed_mps) * 0.5 * dt, distance_to_stop)
    train.position.z -= travel
    if distance_to_stop <= travel + STOP_EPSILON:
        train.position.z = ROUTE_END_Z
        speed_mps = 0.0
        throttle = false
    # Cab-facing visual S-curve only: keep all four car meshes rigid.
    train.position.x = initial_train_position.x + TRACK_PATH.offset(train.position.z)
    train.rotation.y = TRACK_PATH.heading(train.position.z)
    _update_camera()
    _update_hud()

func _update_camera() -> void:
    if camera_mode == 0:
        camera.global_position = Vector3(initial_train_position.x - 12.5, 5.5, STATION_STOP_Z + 5.0)
        camera.look_at(Vector3(initial_train_position.x, 1.6, STATION_STOP_Z), Vector3.UP)
        camera.fov = 65.0
    elif camera_mode == 1:
        camera.global_position = train.to_global(cab_adapter.call("get_eye_position") as Vector3)
        camera.global_basis = train.global_basis * Basis.from_euler(Vector3(cab_pitch, cab_yaw, 0.0))
        camera.fov = cab_zoom
    else:
        camera.global_position = train.to_global(SALON_EYE)
        camera.global_basis = train.global_basis
        camera.fov = 80.0

func _update_hud() -> void:
    platform_view_available = train.position.z <= PLATFORM_VIEW_Z and train.position.z >= STATION_STOP_Z - 30.0
    if platform_button != null:
        platform_button.visible = platform_view_available
    if camera_mode == 0 and not platform_view_available:
        camera_mode = 1
    if status_label != null and Time.get_ticks_msec() >= info_notice_until:
        var remaining := train.position.z - STATION_STOP_Z
        status_label.text = "До точки остановки: %.0f м  |  Двери: %s" % [remaining, "ОТКРЫТЫ" if door_system.get("target_open") else "ЗАКРЫТЫ"]
    if cab_adapter != null:
        cab_adapter.call("set_door_state", door_system.get("target_open"))
    if door_button != null:
        door_button.text = "◀ ▶ ДВЕРИ" if door_system.get("target_open") else "▶ ◀ ДВЕРИ"
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
    view.pressed.connect(func() -> void:
        camera_mode = 2 if camera_mode == 1 else 1
        _update_camera()
    )

    door_button = _button("▮▮ ДВЕРИ", row)
    door_button.pressed.connect(func() -> void:
        if door_system.get("target_open"):
            door_system.call("request_close")
        elif absf(train.position.z - STATION_STOP_Z) <= 5.0:
            door_system.call("request_open", speed_mps)
    )
    info_button = _button("Info", row)
    info_button.pressed.connect(func() -> void: _show_info_placeholder())
    platform_button = _button("ПЛАТФОРМА", row)
    platform_button.visible = false
    platform_button.pressed.connect(func() -> void:
        camera_mode = 0
        _update_camera()
    )

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
    door_system.call("request_close")
    train.position = initial_train_position
    train.rotation = initial_train_rotation
    cab_yaw = 0.0
    cab_pitch = 0.0
    cab_zoom = 75.0
    camera_mode = 1
    touch_points.clear()
    camera_drag_index = -1
    mouse_dragging = false
    pinch_last = -1.0
    _update_camera()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_points[event.index] = event.position
            if touch_points.size() == 1:
                camera_drag_index = event.index
            else:
                camera_drag_index = -1
                pinch_last = -1.0
        else:
            touch_points.erase(event.index)
            camera_drag_index = -1
            pinch_last = -1.0
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            mouse_dragging = event.pressed
        elif event.pressed and camera_mode == 1 and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            cab_zoom = clampf(cab_zoom - 3.0, CAB_FOV_MIN, CAB_FOV_MAX)
        elif event.pressed and camera_mode == 1 and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            cab_zoom = clampf(cab_zoom + 3.0, CAB_FOV_MIN, CAB_FOV_MAX)
    elif event is InputEventMouseMotion and mouse_dragging and camera_mode == 1:
        cab_yaw = clampf(cab_yaw - event.relative.x * 0.004, -1.35, 1.35)
        cab_pitch = clampf(cab_pitch - event.relative.y * 0.004, -0.75, 0.75)
    elif event is InputEventScreenDrag and camera_mode == 1:
        if not touch_points.has(event.index):
            return
        touch_points[event.index] = event.position
        if touch_points.size() >= 2:
            var points := touch_points.values()
            var distance: float = (points[0] as Vector2).distance_to(points[1] as Vector2)
            if pinch_last > 0.0:
                cab_zoom = clampf(cab_zoom - (distance - pinch_last) * 0.09, CAB_FOV_MIN, CAB_FOV_MAX)
            pinch_last = distance
        elif camera_drag_index == event.index:
            pinch_last = -1.0
            cab_yaw = clampf(cab_yaw - event.relative.x * 0.004, -1.35, 1.35)
            cab_pitch = clampf(cab_pitch - event.relative.y * 0.004, -0.75, 0.75)

func _show_info_placeholder() -> void:
    if status_label != null:
        status_label.text = "Info: информатор будет подключён позже"
        info_notice_until = Time.get_ticks_msec() + 2500
