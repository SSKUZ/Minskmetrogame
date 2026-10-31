# Station Base + v106: integration checkpoint

Branch: feature/metro2-real-scene-p3-recovery

## Files
- scenes/StationBaseStatic.tscn: engine-native technical station geometry.
- scripts/station_base_static.gd: two tracks, rails, sleepers, 105 x 8 m island platform.
- scenes/V106Consist.tscn: four original GLB references.
- scenes/StationV106Integration.tscn: isolated combined scene.

## Placement
- Source track 1 center: X=0; track 2 center: X=-10.74.
- Rail head: Y=0; island platform top: Y=1.1805.
- Platform longitudinal center: Z=39.612; edges Z=-12.888 to 92.112.
- Player train root: X=0, Y=0.22, Z=9.603 (source-to-canonical front offset).
- Train GLB original world-space Z positions are retained; do NOT add car spacing.
- Y=0.22 comes from source V106_PROFILE.train.placementY and contactLocalY=-0.22.

## Important limitations
- This is a technical prototype, NOT a measured model of Malinovka.
- No visual Godot execution or wheel-to-rail mesh collision test has been run in this checkpoint.
- No GLB files are committed. Place four original files at res://assets/v106/.
- No second train is instantiated. Track 2 remains ready for later use.
- Integration scene references the four GLBs directly, avoiding duplicate cameras and lighting from the standalone V106Consist viewer. Visual camera framing still requires graphical acceptance.
- Source station also has technical stop anchors, tunnel port outlines and UI markers. These are NOT migrated yet.
- No motion, doors, passengers, physics or APK work.

## Minimal acceptance
1. Open metro2/project.godot in Godot 4.3.
2. Copy all four original GLB into metro2/assets/v106/.
3. Open res://scenes/StationV106Integration.tscn.
4. Check GDScript parsing, rail/wheel datum, platform clearance and camera.
5. Run `python3 tools/check_v106_assets.py` from the metro2 directory to verify original GLB sizes, hashes, headers and scene references.\n6. Record screenshot and any errors; do not change GLB geometry.

## Five-point geometry audit
- Source stop for track 1: frontZ=0.0, direction=-1, tolerance=±0.5 m. Train root Z=frontZ+9.603.
- Source stop for track 2: frontZ=79.224, direction=+1; requires 180-degree train yaw when a second train is added.
- Platform edges X=-9.37 and X=-1.37; top Y=1.1805; Z=-12.888..92.112.
- Nominal door threshold gap = 69.5 mm, nominal vertical step = 0 mm. These are source design values, not mesh-verified measurements.
- Run `python3 tools/audit_station_geometry.py` for nominal five-point station geometry checks.
- Actual coupler clearances, wheel contacts, door mesh gaps and rendered view remain pending a Godot runtime check.
