# Block 8 — Godot launch readiness (no Work)

Date: 2026-10-31

## Findings and changes
1. **Actual defect found:** project.godot still pointed to the standalone V106Consist.tscn, not the combined station scene. Fixed to `res://scenes/StationV106Integration.tscn`.
2. Original four GLBs independently rechecked in local container: headers glTF 2.0, declared lengths and actual sizes match, all SHA-256 match V106_IMPORT.md.
3. Integrated scene references each GLB directly and StationBaseStatic.tscn, with one environment, one camera and one directional light. It uses train transform (0,0.22,9.603).
4. Added `tools/check_godot_project.py` to verify main scene, external scene references, expected camera/environment count, and train transform. Run `python3 tools/check_godot_project.py` from metro2 (after copying GLBs into assets/v106). Run `python3 tools/check_v106_assets.py` for hash validation.
5. Godot executable was not available in local environment; neither the script preflight nor actual Godot headless scene launch has been executed here. **Do not claim the project is engine-tested.**

## Required files before opening
Place original GLBs at `metro2/assets/v106/v106_car_01.glb` through `v106_car_04.glb`. They are not committed in the repository.

## Manual Godot acceptance
Open `metro2/project.godot` with Godot 4.3, let GLB import finish, then run F6 on `scenes/StationV106Integration.tscn` or F5 for main scene. Check output for missing assets, GDScript parse errors, shader/import errors and camera framing. Capture screenshots. Do not alter original GLBs until geometry and scene rendering are accepted.

## Open issues
- Engine/GDScript parsing not verified.
- Inter-car mesh triangle collision narrow phase not verified.
- Wheel/rail physical contact not verified.
- GLB files missing from GitHub; must be supplied locally.
