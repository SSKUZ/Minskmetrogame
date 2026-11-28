extends RefCounted
## Shared, deterministic centreline for the playable S-bend (Godot metres).
const CURVE_START_Z := 210.0
const CURVE_END_Z := 146.0
const CURVE_OFFSET := 0.65

static func offset(z: float) -> float:
    if z >= CURVE_START_Z or z <= CURVE_END_Z:
        return 0.0
    var u := (CURVE_START_Z - z) / (CURVE_START_Z - CURVE_END_Z)
    return CURVE_OFFSET * pow(sin(PI * u), 2.0)

static func derivative(z: float) -> float:
    if z >= CURVE_START_Z or z <= CURVE_END_Z:
        return 0.0
    var u := (CURVE_START_Z - z) / (CURVE_START_Z - CURVE_END_Z)
    return -CURVE_OFFSET * PI / (CURVE_START_Z - CURVE_END_Z) * sin(2.0 * PI * u)

static func heading(z: float) -> float:
    return atan2(derivative(z), 1.0)

## Samples each car at its own longitudinal centre, without assuming GLB origins.
## Car mesh pivots must be calibrated before applying these poses to imported assets.
static func car_pose(car_center_z: float, track_origin_x: float = 0.0) -> Transform3D:
    var origin := Vector3(track_origin_x + offset(car_center_z), 0.0, car_center_z)
    return Transform3D(Basis(Vector3.UP, heading(car_center_z)), origin)

static func car_poses(front_center_z: float, car_spacing: float, count: int, track_origin_x: float = 0.0) -> Array[Transform3D]:
    var poses: Array[Transform3D] = []
    if car_spacing <= 0.0 or count <= 0:
        return poses
    for i in range(count):
        poses.append(car_pose(front_center_z + float(i) * car_spacing, track_origin_x))
    return poses
