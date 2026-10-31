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
- Player train root: X=0, Y=0.22, Z=0.
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
