#!/usr/bin/env python3
"""Engine-independent station/v106 nominal geometry audit; no GLB mesh assertions."""
from math import isclose

TRAIN_LENGTH = 79.224
FRONT_OFFSET_Z = 9.603
PLACEMENT_Y = 0.22
CONTACT_LOCAL_Y = -0.22
RAIL_HEAD_Y = 0.0
PLATFORM_LENGTH = 105.0
PLATFORM_WIDTH = 8.0
PLATFORM_TOP_Y = 1.1805
EDGE_OFFSET = 1.37
THRESHOLD_ABS_X = 1.3005
THRESHOLD_LOCAL_TOP_Y = 0.9605
STOP_TOLERANCE = 0.5
TRACK_RANGE = (-180.0, 220.0)
CAR_DOORS = [
    (3.303, 7.753, 12.153, 16.603),
    (22.964, 27.394, 31.824, 36.254),
    (42.970, 47.400, 51.830, 56.260),
    (62.621, 67.071, 71.471, 75.921),
]
SOURCE_CAR_BOUNDS_Z = [
    (-10.055, 10.356),
    (9.994, 30.362),
    (30.000, 50.368),
    (50.006, 70.073),
]

def audit():
    center_z = TRAIN_LENGTH / 2
    min_z, max_z = center_z - PLATFORM_LENGTH / 2, center_z + PLATFORM_LENGTH / 2
    platform_edge = -EDGE_OFFSET
    other_edge = platform_edge - PLATFORM_WIDTH
    tracks = (0.0, other_edge - EDGE_OFFSET)
    errors = []

    def check(label, condition, details):
        print(f"{'PASS' if condition else 'FAIL'} {label}: {details}")
        if not condition:
            errors.append(label)

    check("rail/wheel vertical datum", isclose(PLACEMENT_Y + CONTACT_LOCAL_Y, RAIL_HEAD_Y, abs_tol=1e-8), f"{PLACEMENT_Y + CONTACT_LOCAL_Y:.4f} m")
    check("platform/threshold vertical datum", isclose(PLACEMENT_Y + THRESHOLD_LOCAL_TOP_Y, PLATFORM_TOP_Y, abs_tol=1e-8), f"{PLACEMENT_Y + THRESHOLD_LOCAL_TOP_Y:.4f} m")
    gap = EDGE_OFFSET - THRESHOLD_ABS_X
    check("nominal horizontal threshold gap", isclose(gap, 0.0695, abs_tol=1e-8), f"{gap * 1000:.1f} mm")
    check("track centers", isclose(tracks[1], -10.74, abs_tol=1e-8), f"{tracks}")
    check("platform edges", isclose(other_edge, -9.37, abs_tol=1e-8), f"{other_edge:.3f} .. {platform_edge:.3f} m")
    door_z = [z for car in CAR_DOORS for z in car]
    check("served door anchors", len(door_z) == 16 and all(min_z + 0.59 < z < max_z - 0.59 for z in door_z), f"{len(door_z)} anchors within [{min_z:.3f}, {max_z:.3f}]")
    check("train nominal placement", isclose(FRONT_OFFSET_Z, 9.603), f"X=0, Y={PLACEMENT_Y}, Z={FRONT_OFFSET_Z}")
    translated = [(a + FRONT_OFFSET_Z, b + FRONT_OFFSET_Z) for a, b in SOURCE_CAR_BOUNDS_Z]
    check("car bounds near canonical consist", translated[0][0] < 0 and translated[-1][1] < 81 and all(translated[i][1] >= translated[i+1][0] for i in range(3)), str(translated))
    check("track range contains train", TRACK_RANGE[0] < translated[0][0] and TRACK_RANGE[1] > translated[-1][1], str(TRACK_RANGE))
    print(f"Nominal stop tolerance: ±{STOP_TOLERANCE:.2f} m (source technical fixture).")
    print("WARNING: mesh-level door gaps, bogie positions, coupler clearance and Godot visuals NOT tested.")
    return not errors

if __name__ == "__main__":
    raise SystemExit(0 if audit() else 1)
