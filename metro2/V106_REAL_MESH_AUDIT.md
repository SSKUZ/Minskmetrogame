# V106 GLB mesh audit — 2026-10-31

Measured directly from the four original local GLB files using trimesh (not inferred from the Three.js compatibility profile). This is a static mesh/scene-graph inspection, not a Godot rendering test.

| Car | World-space GLB Z min | Z max | Threshold meshes | Coupler named meshes |
|---|---:|---:|---:|---:|
| 01 | -10.0550 | 10.3555 | 8 | 1 |
| 02 | 9.9940 | 30.3615 | 8 | 0 |
| 03 | 30.0000 | 50.3675 | 8 | 0 |
| 04 | 50.0060 | 70.0730 | 8 | 1 |

Each car has four thresholds on each side. All **16 platform-facing** threshold centers (X<0) match source Station Base door Z anchors after applying +9.603 m train root Z offset:

- Car 01: 3.303, 7.753, 12.153, 16.603
- Car 02: 22.964, 27.394, 31.824, 36.254
- Car 03: 42.970, 47.400, 51.830, 56.260
- Car 04: 62.621, 67.071, 71.471, 75.921

Platform-facing threshold X range is [-1.3005,-1.1855] m. Platform edge X=-1.3700 m. Thus **threshold horizontal gap = 69.5 mm**, computed from actual GLB threshold bounds. Threshold top Y=0.9605 local; train placement Y=+0.22 -> 1.1805 m, equal to platform top.

Global minimum GLB Y for each car = -0.22 m; with train placement +0.22 the minimum reaches rail-head Y=0. This alone does NOT establish individual wheel-to-rail contacts.

**Important:** neighboring car overall AABBs overlap in Z by approximately 0.3615 m, but AABB overlap does NOT prove interpenetration. A mesh-level coupler/body clearance audit is still needed.

### Caveats
- The above bounds use glTF node transforms and vertex geometry via trimesh scene.
- No Godot import, actual wheel contact geometry, or graphical screenshot was checked in this audit.
- No source GLB was edited.
