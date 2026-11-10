# TZ47 validation — 2026-11-10

Source: `918128859ec26ace688a19b067c5c51b73127568`.
Branch: `feature/metro2-modular-architecture-v47`.

## Structural checks: PASS

Godot **4.3.stable.official.77dcf97d8**, headless, isolated dependency staging (same source files and original assets, not replacement models). Dependency closure: no missing files. Editor import: exit 0, no parse/load errors. Smoke assertions: `V47_RESULT PASS failures=[]`, exit 0.

- Independent train: four original car resources, cab initialized with 26 source textures, eight existing detailed bogies, one validated door system with 64 leaves, two headlights, four saloons with 12 ceiling lights, passenger information equipment.
- Independent train creates no station, depot, tunnel or WorldEnvironment.
- Station: original Uruchye architecture and both tracks build independently.
- Depot: all four original yard/hall/track/portal builders build independently, without a game camera or UI.
- Fixed tunnel section: original lining builder and 16 m between connectors; station/section connectors align.
- Existing tunnel system binds to train/camera and reports valid coverage. Original legacy scene also initializes with four cars, cab, doors, station and 10 tunnel sections; same train bounds as the modular instance at the same spawn.
- Cab uses the same door-system instance as the train controller.
- Tracked assets, all existing scenes, project.godot and workflows are byte-for-byte unchanged. Existing route placement method body is identical after extraction into its shared helper. Four restored GLBs verified using existing manifests and SHA-256. No duplicate resources committed.
- `git diff --check`: clean.

## Full error-free runtime acceptance: NOT PASSED

Existing runtime failures reproduce in the legacy entry point and the train module:

- `saloon_advertising_v46.gd`: `surface_get_primitive_type` invoked on a `CylinderMesh`; subsequent missing `patches`; untyped arrays assigned to `Array[float]`.
- Headless checking also exposes `v106_warning_stickers.gd:105` assigning a null index array to `PackedInt32Array`, and dummy-renderer mesh-storage diagnostics.
- Advertising diagnostic counts in both instances at the original spawn are zero for all four cars. This test confirms the existing failure state, **not successful ad visibility**. All advertisement assets and the original decoration code are preserved without edits, as required by TZ47. No rendering/visual confirmation is claimed.

These failures were not repaired: advertising fixes and visual changes are explicitly excluded. Structural PASS is not a claim that the existing game has an error-free runtime.

## Remaining architectural limits

Stage 1 reuses existing scripts/resources. Train UI/camera remain coupled to its original controller; use one active player train. Route/train/pool roots require identity transform and metre scale. The existing world-Z grade profile, portal and single Uruchye tunnel gap remain in use; arbitrary curved/rotated routes and generalized station gaps are not implemented. The route supplies global environment/sun and passenger station information. New module staging in a future Web export must include `modules/`; no export or workflow change was made now.

No APK, Web build, Pages publication, visual research or TZ48 execution occurred.
