# Block 5 — independent local GLB geometry inspection

Date: 2026-10-31. Input: the four original GLBs at /mnt/data/v106_car_01.glb ... 04.glb. An actual local Python/trimesh inspection was run. No Godot binary was available in the execution environment. No GLB modified.

## 1. Platform clearance, triangle-edge audit
Platform slab Y(world)=[0.9805,1.1805], X edge=-1.37, longitudinal Z(world)=[-12.888,92.112]; GLB placement Y=+0.22 and Z=+9.603 applied to query boundaries.

Triangle vertices and triangle-edge crossings with the platform vertical and longitudinal bounds were sampled, with glTF node transforms applied. Minimum negative-X coordinate in the band was **-1.3370000 m** for all four cars, in static-material-batch_3. Candidate clearance = **33.0 mm** for each car. Candidate triangle counts: 16271, 9480, 9480, 16219.

This improves on the previous broad vertex-only 29/33 mm estimates, but is **NOT a mathematically certified global minimum**: triangles spanning the whole query rectangle may contain an interior extremum at a clipping-corner without any vertex or edge crossing included in this implementation. Need full polygon clipping for certification. AABBs and mesh vertex extrema alone do not establish physical collision-free clearance.

## 2. Wheel-level vertices
Vertices at local Y≈-0.22 found for each car: 32 vertices, X coordinates {-0.960,-0.840,+0.840,+0.960} m. Rail centerlines are at X=±0.900 m, with rail width 0.12 m; these bottom vertex X coordinates lie at rail outer/inner edges (±0.06 m from each centerline). Z values:
- car 01: -7.350, -5.650, 5.650, 7.350
- car 02: 12.656, 14.356, 25.656, 27.356
- car 03: 32.662, 34.362, 45.662, 47.362
- car 04: 52.668, 54.368, 65.668, 67.368

This is consistent with **8 nominal wheel positions per car, 32 in the consist**, but a complete wheel surface/rail intersection test has not been performed.

## 3. Inter-car connections
Adjacent car Z-axis full bounds overlap about 0.3615 m. No mesh-level intersection certification; do not move cars based on AABBs.

## 4. Automated check
Added tools/audit_v106_surface_clearance.py to inspect triangle-edge candidate clearance and wheel-level vertices with actual GLB inputs. It needs numpy and trimesh and four original GLBs copied to metro2/assets/v106. The checked-in script has not been executed in GitHub CI; local inspection was performed separately.

## 5. Readiness
Original meshes are usable for static coordinate verification. Godot headless import, visual scene validation, GLB asset availability in GitHub, and precise mesh collision clearance are **not confirmed**. No APK or game mechanics work undertaken.
