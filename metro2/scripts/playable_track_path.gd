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
