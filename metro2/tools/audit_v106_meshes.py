#!/usr/bin/env python3
"""Independent original GLB threshold audit. Requires: pip install trimesh numpy."""
from pathlib import Path
import trimesh

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "v106"
EXPECTED = [
    [3.303, 7.753, 12.153, 16.603],
    [22.964, 27.394, 31.824, 36.254],
    [42.970, 47.400, 51.830, 56.260],
    [62.621, 67.071, 71.471, 75.921],
]
OFFSET_Z = 9.603
TRAIN_Y = 0.22
EDGE_X = -1.37
TOP_Y = 1.1805
EPS = 0.001

def main():
    failures = []
    for i, anchors in enumerate(EXPECTED, 1):
        path = ASSETS / f"v106_car_{i:02}.glb"
        if not path.is_file():
            failures.append(f"missing: {path}")
            continue
        scene = trimesh.load(path, force="scene")
        thresholds = []
        for node in scene.graph.nodes_geometry:
            if "passenger-threshold" not in node.lower():
                continue
            transform, name = scene.graph[node]
            mesh = scene.geometry[name]
            bounds = trimesh.transform_points(mesh.bounds, transform)
            low = bounds.min(axis=0)
            high = bounds.max(axis=0)
            if (low[0] + high[0]) / 2 < 0:
                thresholds.append((float((low[2]+high[2])/2 + OFFSET_Z),
                                   float(low[0]), float(high[1] + TRAIN_Y)))
        thresholds.sort()
        print(f"Car {i}: {len(thresholds)} served thresholds")
        if len(thresholds) != 4:
            failures.append(f"car {i}: expected 4 served thresholds, got {len(thresholds)}")
            continue
        for actual, expected in zip(thresholds, anchors):
            z, min_x, top_y = actual
            if abs(z-expected)>EPS or abs((min_x-EDGE_X)-0.0695)>EPS or abs(top_y-TOP_Y)>EPS:
                failures.append(f"car {i}: anchor {actual} expected z={expected}")
    for problem in failures:
        print("FAIL:", problem)
    print("PASS" if not failures else "FAIL")
    return 1 if failures else 0

if __name__ == "__main__":
    raise SystemExit(main())
