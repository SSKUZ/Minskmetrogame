#!/usr/bin/env python3
"""Clip every original GLB triangle to the full platform slab (Y/Z).
Requires: pip install numpy trimesh. GLBs: metro2/assets/v106/.
"""
from pathlib import Path
import numpy as np
import trimesh

ASSETS = Path(__file__).resolve().parents[1] / "assets" / "v106"
Y_MIN, Y_MAX = 0.9805 - 0.22, 1.1805 - 0.22
Z_MIN, Z_MAX = -12.888 - 9.603, 92.112 - 9.603
PLATFORM_EDGE_X = -1.37

def clip_polygon(poly, axis, boundary, greater):
    output = []
    for index, a in enumerate(poly):
        b = poly[(index + 1) % len(poly)]
        da = (a[axis] - boundary) * (1 if greater else -1)
        db = (b[axis] - boundary) * (1 if greater else -1)
        inside_a, inside_b = da >= -1e-10, db >= -1e-10
        if inside_a:
            output.append(a)
        if inside_a != inside_b and abs(b[axis] - a[axis]) > 1e-14:
            output.append(a + (b - a) * ((boundary - a[axis]) / (b[axis] - a[axis])))
    return output

def scan(path):
    scene = trimesh.load(path, force="scene")
    min_x = float("inf")
    source = ""
    triangle_count = 0
    wheel_vertices = []
    for node in scene.graph.nodes_geometry:
        transform, geom = scene.graph[node]
        mesh = scene.geometry[geom]
        vertices = trimesh.transform_points(mesh.vertices, transform)
        wheel_vertices.extend(vertices[np.isclose(vertices[:, 1], -0.22, atol=1e-6)].tolist())
        for start in range(0, len(mesh.faces), 100000):
            triangles = vertices[mesh.faces[start:start + 100000]]
            eligible = ((triangles[:, :, 1].max(axis=1) >= Y_MIN)
                        & (triangles[:, :, 1].min(axis=1) <= Y_MAX)
                        & (triangles[:, :, 2].max(axis=1) >= Z_MIN)
                        & (triangles[:, :, 2].min(axis=1) <= Z_MAX))
            for triangle in triangles[eligible]:
                polygon = list(triangle)
                for axis, boundary, greater in (
                    (1, Y_MIN, True), (1, Y_MAX, False),
                    (2, Z_MIN, True), (2, Z_MAX, False)
                ):
                    if not polygon:
                        break
                    polygon = clip_polygon(polygon, axis, boundary, greater)
                if polygon:
                    triangle_count += 1
                    x = min(point[0] for point in polygon)
                    if x < min_x:
                        min_x, source = x, node
    bottom = np.asarray(wheel_vertices)
    return min_x, source, triangle_count, bottom

def main():
    failures = []
    for car in range(1, 5):
        path = ASSETS / f"v106_car_{car:02}.glb"
        if not path.is_file():
            failures.append(f"missing {path}")
            continue
        x, node, triangles, bottom = scan(path)
        gap_mm = (x - PLATFORM_EDGE_X) * 1000
        xs = np.unique(np.round(bottom[:, 0], 3)) if len(bottom) else []
        print(f"car {car}: clearance {gap_mm:.6f} mm; triangles {triangles}; mesh {node}")
        print(f"  bottom vertices {len(bottom)}, x={xs}")
        if not 32.9 <= gap_mm <= 33.1:
            failures.append(f"car {car}: unexpected clearance {gap_mm:.4f} mm")
        if len(bottom) != 32 or not np.array_equal(xs, [-.96, -.84, .84, .96]):
            failures.append(f"car {car}: unexpected bottom-vertex pattern")
    for failure in failures:
        print("FAIL:", failure)
    print("PASS" if not failures else "FAIL")
    print("LIMITATION: not a wheel contact or inter-car triangle intersection test.")
    return 1 if failures else 0

if __name__ == "__main__":
    raise SystemExit(main())
