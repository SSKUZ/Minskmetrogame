#!/usr/bin/env python3
"""Conservative inter-car mesh AABB broad phase, NOT triangle collision proof.
Run: python3 tools/audit_intercar_candidates.py
Dependencies: numpy, trimesh; original GLBs under assets/v106.
"""
from pathlib import Path
import numpy as np
import trimesh

ASSETS = Path(__file__).resolve().parents[1] / "assets" / "v106"

def mesh_boxes(path):
    scene = trimesh.load(path, force="scene")
    boxes = []
    for node in scene.graph.nodes_geometry:
        transform, geometry = scene.graph[node]
        # All eight corners are needed for a rotated bounding box.
        bounds = scene.geometry[geometry].bounds
        corners = np.array([[x,y,z] for x in bounds[:,0] for y in bounds[:,1] for z in bounds[:,2]])
        points = trimesh.transform_points(corners, transform)
        boxes.append((str(node), points.min(axis=0), points.max(axis=0)))
    return boxes

def main():
    paths = [ASSETS / f"v106_car_{i:02}.glb" for i in range(1,5)]
    missing = [str(path) for path in paths if not path.is_file()]
    if missing:
        print("MISSING original GLBs:", ", ".join(missing))
        return 2
    boxes = [mesh_boxes(path) for path in paths]
    for joint in range(3):
        candidates = []
        for name_a, low_a, high_a in boxes[joint]:
            for name_b, low_b, high_b in boxes[joint + 1]:
                overlap = np.minimum(high_a, high_b) - np.maximum(low_a, low_b)
                if np.all(overlap > 1e-5):
                    candidates.append((name_a, name_b, overlap))
        print(f"joint {joint+1}-{joint+2}: {len(candidates)} mesh-AABB candidates")
        for name_a, name_b, overlap in candidates:
            print(f"  {name_a} vs {name_b}: overlap XYZ {overlap.round(4)} m")
    print("NOTE: positive mesh-AABB overlap is not a triangle collision. No GLB transforms were changed.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
