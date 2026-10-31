#!/usr/bin/env python3
"""Exact triangle-edge extrema within the platform slab, using original GLB mesh vertices.
Requires numpy and trimesh. Run from any directory.
"""
from pathlib import Path
import numpy as np
import trimesh

ASSETS = Path(__file__).resolve().parents[1] / "assets" / "v106"
EDGE_X = -1.37
Y_MIN, Y_MAX = 0.9805 - 0.22, 1.1805 - 0.22
Z_MIN, Z_MAX = -12.888 - 9.603, 92.112 - 9.603
RAILS_X = (-0.9, 0.9)
TOL = 0.001

def scan(path):
    scene = trimesh.load(path, force="scene")
    minimum, minimum_node, examined = float("inf"), None, 0
    contact_xz = []
    for node in scene.graph.nodes_geometry:
        matrix, geom_name = scene.graph[node]
        mesh = scene.geometry[geom_name]
        vertices = trimesh.transform_points(mesh.vertices, matrix)
        near_rail = vertices[np.abs(vertices[:, 1] + 0.22) < 1e-5]
        contact_xz.extend(near_rail[:, [0, 2]].tolist())
        for start in range(0, len(mesh.faces), 50000):
            triangles = vertices[mesh.faces[start:start+50000]]
            eligible = ((triangles[:, :, 1].max(axis=1) >= Y_MIN)
                        & (triangles[:, :, 1].min(axis=1) <= Y_MAX)
                        & (triangles[:, :, 2].max(axis=1) >= Z_MIN)
                        & (triangles[:, :, 2].min(axis=1) <= Z_MAX))
            triangles = triangles[eligible]
            examined += len(triangles)
            if not len(triangles):
                continue
            values = []
            inside = ((triangles[:, :, 1] >= Y_MIN) & (triangles[:, :, 1] <= Y_MAX)
                      & (triangles[:, :, 2] >= Z_MIN) & (triangles[:, :, 2] <= Z_MAX))
            if inside.any():
                values.append(triangles[inside][:, 0])
            for k in range(3):
                a, b = triangles[:, k, :], triangles[:, (k+1)%3, :]
                delta = b-a
                for axis, limits, other_axis, other_limits in (
                    (1, (Y_MIN,Y_MAX), 2, (Z_MIN,Z_MAX)),
                    (2, (Z_MIN,Z_MAX), 1, (Y_MIN,Y_MAX)),
                ):
                    good_denom = np.abs(delta[:,axis]) > 1e-12
                    for boundary in limits:
                        t = np.zeros(len(triangles))
                        t[good_denom] = ((boundary-a[good_denom,axis])
                                         / delta[good_denom,axis])
                        other = a[:,other_axis] + t*delta[:,other_axis]
                        valid = (good_denom & (t>=0) & (t<=1)
                                 & (other>=other_limits[0]) & (other<=other_limits[1]))
                        if valid.any():
                            values.append((a[:,0] + t*delta[:,0])[valid])
            if values:
                x = min(float(np.min(v)) for v in values)
                if x < minimum:
                    minimum, minimum_node = x, node
    contacts = np.asarray(contact_xz)
    return minimum, minimum_node, examined, contacts

def main():
    errors = []
    for car in range(1,5):
        path = ASSETS / f"v106_car_{car:02}.glb"
        if not path.exists():
            errors.append(f"missing {path}")
            continue
        min_x, node, count, contacts = scan(path)
        clearance = (min_x-EDGE_X)*1000
        x_values = np.unique(np.round(contacts[:,0], 3)) if len(contacts) else []
        z_values = np.unique(np.round(contacts[:,1], 3)) if len(contacts) else []
        print(f"car {car}: body/platform slab min clearance {clearance:.3f} mm, node {node}; {count} candidate triangles")
        print(f"  rail-head-level vertex x={x_values}, z={z_values}")
        if clearance < 0:
            errors.append(f"car {car}: platform slab penetration")
        if len(z_values) != 4 or len(x_values) != 4:
            errors.append(f"car {car}: unexpected bottom vertex pattern")
        if any(min(abs(abs(x)-abs(rail)) for rail in RAILS_X) > 0.061 for x in x_values):
            errors.append(f"car {car}: bottom vertex lateral displacement")
    print("PASS: static triangle slab clearance and bottom-vertex patterns" if not errors else "FAIL: " + "; ".join(errors))
    print("LIMITATION: no triangle-triangle coupler collision or Godot rendering validation.")
    return 1 if errors else 0

if __name__ == "__main__":
    raise SystemExit(main())
