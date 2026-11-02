extends SceneTree
## Block B headless checks; no APK or screenshots.
const PATH = preload("res://scripts/playable_track_path.gd")
const CONTROLLER = preload("res://scripts/first_playable_controller.gd")
const TUNNEL = preload("res://scripts/tunnel_v2.gd")

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    for z in [0.0, 9.603, 145.9, 146.0, 160.0, 178.0, 194.0, 210.0, 210.1, 329.603]:
        var x: float = PATH.offset(z)
        if x < -0.00001 or x > PATH.CURVE_OFFSET + 0.00001:
            _fail("invalid path offset at z=%s" % z)
            return
        if not is_finite(PATH.heading(z)):
            _fail("nonfinite heading at z=%s" % z)
            return
    if absf(PATH.offset(178.0) - PATH.CURVE_OFFSET) > 0.00001:
        _fail("curve peak mismatch")
        return
    for z in [146.0, 210.0]:
        if absf(PATH.offset(z)) > 0.00001 or absf(PATH.derivative(z)) > 0.00001:
            _fail("curve endpoint not tangent to straight track")
            return
    var poses: Array[Transform3D] = PATH.car_poses(170.0, 19.0, 4)
    if poses.size() != 4:
        _fail("expected four car poses")
        return
    for i in range(poses.size()):
        var expected_z: float = 170.0 + float(i) * 19.0
        if absf(poses[i].origin.z - expected_z) > 0.0001:
            _fail("car longitudinal position mismatch")
            return
        if absf(poses[i].origin.x - PATH.offset(expected_z)) > 0.0001:
            _fail("car centreline mismatch")
            return
    # Numeric integration checks without loading heavyweight GLBs.
    var dt: float = 1.0 / 60.0
    var velocity: float = 0.0
    for i in range(1500):
        velocity = minf(CONTROLLER.MAX_SPEED_MPS, velocity + CONTROLLER.ACCEL_MPS2 * dt)
    if absf(velocity - 25.0) > 0.001:
        _fail("acceleration fails to reach 90 km/h")
        return
    for i in range(750):
        velocity = maxf(0.0, velocity - CONTROLLER.BRAKE_MPS2 * dt)
    if velocity > 0.001:
        _fail("braking does not reach zero")
        return
    velocity = 25.0
    var coast_distance: float = 0.0
    for i in range(600):
        var next_velocity: float = maxf(0.0, velocity - CONTROLLER.COAST_MPS2 * dt)
        coast_distance += (velocity + next_velocity) * 0.5 * dt
        velocity = next_velocity
    if velocity < 23.7 or velocity > 23.9 or coast_distance < 240.0:
        _fail("coasting behavior outside expected range")
        return
    var tunnel = TUNNEL.new()
    for z in [120.0, 146.0, 165.0, 178.0, 190.0, 210.0, 250.0]:
        if absf(tunnel.curve_offset(z) - PATH.offset(z)) > 0.00001:
            _fail("tunnel/train centreline mismatch")
            return
    tunnel.free()
    if CONTROLLER.MAX_SPEED_MPS != 25.0:
        _fail("speed limit is not 90 km/h")
        return
    if CONTROLLER.ROUTE_END_Z != CONTROLLER.STATION_STOP_Z:
        _fail("route stop mismatch")
        return
    print("BLOCK_B_PASS: curve bounds, endpoints, tangents, tunnel alignment, speed limit and stop coordinate")
    quit(0)

func _fail(reason: String) -> void:
    push_error("BLOCK_B_FAIL: " + reason)
    quit(1)
