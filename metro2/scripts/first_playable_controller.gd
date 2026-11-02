extends Node3D
## First playable route: touch throttle/brake, doors and three camera views.
## Original GLB geometry and doors are not modified.
const TRACK_PATH = preload("res://scripts/playable_track_path.gd")
const DOOR_CONTROLLER = preload("res://scripts/v106_door_controller.gd")
const CAB_ADAPTER = preload("res://scripts/cab_v106_adapter.gd")
const ANNOUNCER = preload("res://scripts/station_announcer.gd")
const MAX_SPEED_MPS := 25.0
const ROUTE_END_Z := 9.603
const STOP_EPSILON := 0.02
const DOOR_STOP_TOLERANCE := 0.5
const ACCEL_MPS2 := 1.2
const MAX_PHYSICS_DELTA := 0.1
const BRAKE_MPS2 := 2.0
const COAST_MPS2 := 0.12
# Geometry centres measured in Block B audit, including scene root offsets.
const CAR_CENTERS_Z := [0.15025, 20.38751, 40.43151, 60.49701]
const CAR_CENTERS_X := [-0.08, 0.0, 0.0, 0.08]
var car_nodes: Array[Node3D] = []
var car_original_transforms: Array[Transform3D] = []

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
var announcer: Node
var arrival_announced := false
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
    announcer = ANNOUNCER.new()
    announcer.name = "StationAnnouncer"
    add_child(announcer)
    _initialize_car_followers()
    _make_controls()
    _update_camera()
    _update_hud()
    _install_render_diagnostics()
    get_tree().create_timer(3.0).timeout.connect(_refresh_render_diagnostics)
    _install_camera_render_probe()

var render_diagnostics: Label

func _install_render_diagnostics() -> void:
    var layer := CanvasLayer.new()
    layer.name = "RenderDiagnostics"
    layer.layer = 100
    add_child(layer)
    render_diagnostics = Label.new()
    render_diagnostics.name = "RenderStatus"
    render_diagnostics.set_anchors_preset(Control.PRESET_TOP_LEFT)
    render_diagnostics.position = Vector2(12, 112)
    render_diagnostics.add_theme_font_size_override("font_size", 16)
    render_diagnostics.add_theme_color_override("font_color", Color(1, 0.95, 0.2))
    render_diagnostics.add_theme_color_override("font_shadow_color", Color.BLACK)
    render_diagnostics.add_theme_constant_override("shadow_offset_x", 1)
    render_diagnostics.add_theme_constant_override("shadow_offset_y", 1)
    layer.add_child(render_diagnostics)
    _refresh_render_diagnostics()

func _refresh_render_diagnostics() -> void:
    if render_diagnostics == null or not is_instance_valid(render_diagnostics):
        return
    var meshes := 0
    var visible_meshes := 0
    var stack: Array[Node] = [self]
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is MeshInstance3D or node is MultiMeshInstance3D:
            meshes += 1
            if node.is_visible_in_tree():
                visible_meshes += 1
        for child in node.get_children():
            stack.append(child)
    var cab_loaded := cab_adapter != null and bool(cab_adapter.get("ready_for_play"))
    var camera_active := camera != null and camera.is_current()
    var cam_pos := camera.global_position if camera != null else Vector3.ZERO
    var forward := -camera.global_basis.z if camera != null else Vector3.ZERO
    var lines := [
        "3D DIAG | meshes: %d visible: %d" % [meshes, visible_meshes],
        "Cab loaded: %s | Camera active: %s" % [str(cab_loaded), str(camera_active)],
        "Camera XYZ: %.1f / %.1f / %.1f" % [cam_pos.x, cam_pos.y, cam_pos.z],
        "Look XYZ: %.2f / %.2f / %.2f" % [forward.x, forward.y, forward.z],
        "Train Z: %.1f | doors valid: %s" % [train.position.z, str(door_system != null and bool(door_system.get("validated")))]
    ]
    render_diagnostics.text = "\\n".join(lines)

# Diagnostic only: an unshaded cube fixed one metre in front of the active camera.
# It must be visible regardless of tunnel lighting or the train's world position.
func _install_camera_render_probe() -> void:
    var probe := MeshInstance3D.new()
    probe.name = "CameraRenderProbe_MAGENTA"
    var cube := BoxMesh.new()
    cube.size = Vector3(0.35, 0.35, 0.35)
    probe.mesh = cube
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(1.0, 0.0, 1.0, 1.0)
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.no_depth_test = true
    probe.material_override = material
    camera.add_child(probe)
    probe.position = Vector3(0.0, 0.0, -1.0)
    print("3D DIAG: magenta camera probe installed at -1m")

func _physics_process(delta: float) -> void:
    var acceleration: float = -COAST_MPS2
    if braking:
        acceleration = -BRAKE_MPS2
    elif throttle and door_system != null and bool(door_system.call("can_move")):
        acceleration = ACCEL_MPS2
    var dt: float = clampf(delta, 0.0, MAX_PHYSICS_DELTA)
    if dt <= 0.0:
        return
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
    _update_car_followers()
    _update_camera()
    _update_hud()
    if Engine.get_physics_frames() % 120 == 0:
        _refresh_render_diagnostics()


func _initialize_car_followers() -> void:
    # Original meshes retain their imported coordinates; only root transforms change.
    # Do not reparent nodes: door-system references and cab attachments stay intact.
    car_nodes.clear()
    car_original_transforms.clear()
    for i in range(4):
        var car := train.get_node_or_null("Car%02d" % (i + 1)) as Node3D
        if car == null:
            push_error("BLOCK B: missing car %02d; per-car curve disabled" % (i + 1))
            car_nodes.clear()
            car_original_transforms.clear()
            return
        car_nodes.append(car)
        car_original_transforms.append(car.transform)
    _update_car_followers()

func _update_car_followers() -> void:
    if car_nodes.size() != 4:
        return
    var train_z: float = train.position.z
    var train_heading: float = TRACK_PATH.heading(train_z)
    var inverse_basis := Basis(Vector3.UP, -train_heading)
    for i in range(4):
        var centre := Vector3(CAR_CENTERS_X[i], 0.0, CAR_CENTERS_Z[i])
        var world_z: float = train_z + centre.z
        var target_world := Vector3(
            initial_train_position.x + TRACK_PATH.offset(world_z) + centre.x,
            train.position.y,
            world_z
        )
        # Invert the train's heading to place each measured centre exactly
        # on its own path sample, including longitudinal rotation displacement.
        var target_local: Vector3 = inverse_basis * (target_world - train.position)
        var relative_heading: float = TRACK_PATH.heading(world_z) - train_heading
        var rotate_about_centre := Transform3D(Basis(), centre) * Transform3D(
            Basis(Vector3.UP, relative_heading), Vector3.ZERO
        ) * Transform3D(Basis(), -centre)
        car_nodes[i].transform = Transform3D(Basis(), target_local - centre) * rotate_about_centre * car_original_transforms[i]

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
        var remaining: float = maxf(0.0, train.position.z - STATION_STOP_Z)
        var brake_distance: float = speed_mps * speed_mps / (2.0 * BRAKE_MPS2)
        var stop_status := "СТОЯНКА" if remaining <= DOOR_STOP_TOLERANCE and speed_mps <= 0.05 else "ТОРМОЗИТЬ" if remaining <= brake_distance + 3.0 else "ДВИЖЕНИЕ"
        status_label.text = "%s | До остановки: %.1f м | Тормозной путь: %.0f м | Двери: %s" % [
            stop_status, remaining, brake_distance, "ОТКРЫТЫ" if door_system.get("target_open") else "ЗАКРЫТЫ"
        ]
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
        elif absf(train.position.z - STATION_STOP_Z) <= DOOR_STOP_TOLERANCE:
            door_system.call("request_open", speed_mps)
    )
    info_button = _button("Info", row)
    info_button.pressed.connect(_play_info_announcement)
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
    arrival_announced = false
    announcer.call("reset_sequence")
    door_system.call("request_close")
    train.position = initial_train_position
    train.rotation = initial_train_rotation
    _update_car_followers()
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

func _play_info_announcement() -> void:
    if announcer == null:
        return
    var at_station: bool = absf(train.position.z - STATION_STOP_Z) <= DOOR_STOP_TOLERANCE
    var approaching: bool = train.position.z <= PLATFORM_VIEW_Z and train.position.z >= STATION_STOP_Z - DOOR_STOP_TOLERANCE
    var message: String = str(announcer.call("press_info", approaching, at_station,
        bool(door_system.get("target_open")), speed_mps > 0.05))
    if status_label != null:
        status_label.text = message
        info_notice_until = Time.get_ticks_msec() + 3000
