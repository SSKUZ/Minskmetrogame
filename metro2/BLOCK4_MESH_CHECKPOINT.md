# Block 4 — actual GLB geometry checkpoint

Source: four original local GLB files from V106_Godot_Complete, inspected using trimesh scene-node transforms and mesh vertices. No source models modified.

## Five questions

1. **Wheels and bogies:** Each GLB has a global minimum local Y approximately -0.22 m, matching the expected rail datum after train placement Y=+0.22. But wheel meshes are largely combined into static-material-batch meshes; names do not expose individual wheels. This observation alone does NOT prove 32 wheel contacts or lateral wheel/rail alignment.
2. **Inter-car clearance:** Adjacent car full-scene Z AABBs overlap by 0.3615 m (each of three joints). This is not evidence of a collision; per-triangle intersection or targeted body/coupler checks are required.
3. **Platform-body clearance:** In the local vertical band Y=0.75..1.05 m (world Y=0.97..1.27), most outward negative-X vertices in cars 1 and 4 are X=-1.341 m, in cars 2 and 3 X=-1.337 m. Compared with platform edge X=-1.370 m, vertex-only candidate clearances are **29 mm** (head cars) and **33 mm** (middle cars). These are NOT guaranteed minimum surface clearances: triangle-edge intersections with the platform-top height band were not computed. Prior measured door threshold gap is 69.5 mm.
4. **Geometry automation:** An independent Python vertex-level mesh check is supplied with this checkpoint. The check must NOT be advertised as exact triangle/triangle collision verification.
5. **Readiness:** static source geometry is available, station and GLB references are present in GitHub, but Godot visual import/combined scene runtime and exact clearance checks are still unverified.

## Measured source local Z extents

- Car 1: [-10.0550, 10.3555]
- Car 2: [9.9940, 30.3615]
- Car 3: [30.0000, 50.3675]
- Car 4: [50.0060, 70.0730]

Canonical station placement is train root (0, 0.22, 9.603). All four car meshes remain unmodified.

## Critical limitation

Do not confuse the candidate 29–33 mm body gap with a validated continuous surface clearance. To establish actual minimum clearance, clip triangles at relevant platform height and longitudinal interval, then measure extrema. Similarly, wheel and coupler contact require mesh-subpart identification and actual intersection testing.
