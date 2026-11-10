extends Node3D
## One inspection camera for every module. It never drives the train.
const CAMERA_MASK := 1 << 19
var camera: Camera3D
var pivot := Vector3.ZERO
var yaw := 0.55
var pitch := 0.22
var distance := 25.0
var free_mode := false
var pan_mode := false
var move_axis := Vector3.ZERO
var move_speed := 7.0
var enabled := false
var _touches: Dictionary = {}
var _pinch_span := 0.0
var _held_motion: Dictionary = {}
var _sphere := SphereShape3D.new()

func _ready() -> void:
    camera = Camera3D.new()
    camera.name = "InspectionCamera"
    camera.current = true
    camera.near = 0.04
    camera.far = 1800.0
    add_child(camera)
    _sphere.radius = 0.18
    get_window().focus_exited.connect(clear_gestures)
    get_viewport().size_changed.connect(clear_gestures)

func frame_point(point: Vector3, radius: float) -> void:
    clear_gestures()
    pivot = point
    distance = clampf(radius,0.7,1800.0)
    yaw = 0.55
    pitch = 0.22
    free_mode = false
    enabled = true
    _apply(false)
    free_mode = true

func enter_interior(pose: Transform3D) -> void:
    clear_gestures()
    free_mode = true
    enabled = true
    camera.global_transform = pose
    var angles := pose.basis.get_euler()
    yaw = angles.y
    pitch = -angles.x

func set_free(value: bool) -> void:
    free_mode = value
    clear_gestures()
    if not value:
        pivot = camera.global_position-camera.global_basis.z*distance
    _apply(false)

func clear_gestures() -> void:
    _touches.clear()
    _pinch_span = 0.0
    move_axis = Vector3.ZERO
    _held_motion.clear()

func orbit(delta: Vector2) -> void:
    yaw = wrapf(yaw-delta.x*0.006,-PI,PI)
    pitch = clampf(pitch+delta.y*0.006,-1.45,1.45)
    _apply()

func zoom(ratio: float) -> void:
    if ratio <= 0.0: return
    if free_mode:
        distance = clampf(distance/ratio,0.7,1800.0)
        camera.global_position -= camera.global_basis.z*log(ratio)*move_speed
    else:
        distance = clampf(distance/ratio,0.7,1800.0)
        _apply()

func pan(delta: Vector2) -> void:
    var scale_m := maxf(distance,1.0)*0.0015
    translate_view((-camera.global_basis.x*delta.x+camera.global_basis.y*delta.y)*scale_m)

func translate_view(motion: Vector3) -> void:
    var before := camera.global_position
    var after := safe_position(before,before+motion)
    if free_mode:
        camera.global_position = after
    else:
        pivot += after-before
        _apply()

func safe_position(from: Vector3, to: Vector3) -> Vector3:
    if free_mode or not enabled or from.is_equal_approx(to): return to
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = _sphere
    query.transform = Transform3D(Basis.IDENTITY,from)
    query.motion = to-from
    query.collision_mask = CAMERA_MASK
    query.margin = 0.04
    var fractions := get_world_3d().direct_space_state.cast_motion(query)
    if fractions.size() < 2: return from
    return from+(to-from)*maxf(0.0,fractions[0]-0.002)

func _apply(protect: bool = true) -> void:
    if not is_instance_valid(camera) or not enabled: return
    if free_mode:
        camera.global_basis = Basis.from_euler(Vector3(-pitch,yaw,0))
        return
    var offset := Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
    var desired := pivot+offset
    camera.global_position = safe_position(camera.global_position,desired) if protect else desired
    if camera.global_position.distance_squared_to(pivot) > 0.001:
        camera.look_at(pivot,Vector3.UP)

func _process(delta: float) -> void:
    if not enabled: return
    var axis := move_axis
    for held in _held_motion: axis += held
    if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): axis.z -= 1.0
    if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): axis.z += 1.0
    if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): axis.x -= 1.0
    if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): axis.x += 1.0
    if Input.is_physical_key_pressed(KEY_Q): axis.y -= 1.0
    if Input.is_physical_key_pressed(KEY_E): axis.y += 1.0
    if axis.length_squared() > 0.0:
        var rate := move_speed*(3.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
        translate_view(camera.global_basis*axis.limit_length(1.0)*rate*minf(delta,0.05))

func _input(event: InputEvent) -> void:
    # Releases may end over a GUI button and never reach unhandled input.
    if event is InputEventScreenTouch and not event.pressed:
        _touches.erase(event.index)
        _pinch_span = 0.0

func _unhandled_input(event: InputEvent) -> void:
    if not enabled: return
    if event is InputEventMouse and event.device == -1: return
    if event is InputEventScreenTouch:
        if event.pressed: _touches[event.index] = event.position
        else: _touches.erase(event.index)
        _pinch_span = 0.0
        if _touches.size() >= 2:
            var points := _touches.values()
            _pinch_span = (points[0] as Vector2).distance_to(points[1])
    elif event is InputEventScreenDrag and _touches.has(event.index):
        _touches[event.index] = event.position
        if _touches.size() >= 2:
            var points := _touches.values()
            var span := (points[0] as Vector2).distance_to(points[1])
            if _pinch_span > 5.0 and span > 5.0: zoom(span/_pinch_span)
            _pinch_span = span
        else:
            orbit(event.relative)
    elif event is InputEventMouseMotion and _touches.is_empty():
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) :
            pan(event.relative)
        elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
            orbit(event.relative)
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom(1.15)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom(1.0/1.15)

func hold_motion(axis: Vector3, held: bool) -> void:
    if held: _held_motion[axis] = true
    else: _held_motion.erase(axis)
