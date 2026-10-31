# Block 6 — verified static geometry, 2026-10-31

## Input and method
All four original GLB files were available locally and were loaded with Python trimesh. Every glTF geometry node was transformed into GLB coordinates. Every triangle whose Y/Z bounds intersected the platform slab was clipped by Sutherland–Hodgman polygon clipping against four half-planes: Y in [0.7605, 0.9605] (local), Z in [-22.491, 82.509] (local). This is the complete platform slab after accounting for train placement Y=+0.22, Z=+9.603. Minimum X of the resulting clipped polygons was measured against platform edge X=-1.37. No model was modified.

## 1. Exact slab-band clearance (for triangle surfaces)
| Car | Intersecting triangles | Minimum X | Clearance to edge |
|---|---:|---:|---:|
| 01 | 16,271 | -1.337000012 | 32.999988 mm |
| 02 | 9,480 | -1.337000012 | 32.999988 mm |
| 03 | 9,480 | -1.337000012 | 32.999988 mm |
| 04 | 16,219 | -1.337000012 | 32.999988 mm |

All minima occur in `static-material-batch_3`. This is an exact triangle-polygon clipping result within floating point precision for the tested Y/Z slab, not just vertex samples. It does NOT establish clearance outside the slab or under dynamic motion.

## 2. Wheel-level vertices and rails
Each car contains 32 vertices at local Y≈-0.22, with four distinct X coordinates: -0.96, -0.84, 0.84, 0.96. Rails centered at X=±0.9 and width 0.12 m, top Y=0. These coordinates agree at the rail-head datum after +0.22 train Y translation. This is a vertex datum check, not a wheel-rail contact mechanics or mesh intersection test.

## 3. Neighboring cars
Car AABB overlap in Z remains about 0.3615 m at each coupling. AABB overlap is not a collision proof. A triangle-triangle inter-car intersection test was not completed. Do not move cars or change couplers.

## 4. Godot scene
`StationV106Integration.tscn` references four original GLBs directly and one Station Base scene; camera and lighting are not duplicated. Placement (0,0.22,9.603) matches Three.js trainPlacement() for first track at frontZ=0 and direction=-1. Godot executable was NOT present in the local environment; headless import and rendered visual validation remain pending.

## 5. Acceptance status
- PASS: original four GLBs locally available; static slab-band clearance = 33.0 mm; bottom vertex coordinates consistent with rail datum; source placement.
- NOT VERIFIED: actual wheel-to-rail mesh contact; triangle-triangle inter-car collisions; Godot parser/runtime and screenshots; full original GLB availability in remote GitHub.
- WARNING: 33 mm is **3 mm above** a strict 20–30 mm target. Do not claim it passes that target. No geometry was modified to force compliance.
