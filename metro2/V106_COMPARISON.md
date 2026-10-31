# V106 comparison APK — TZ14

Godot 4.3, Android arm64, GL Compatibility. Main scene: `scenes/V106Comparison.tscn`.
Only one model is instantiated. Switching retains camera, lighting and renderer settings.
Automatic runtime mesh LOD selection is disabled for an equal geometry comparison.
Drag to orbit, pinch to zoom, two fingers to move the view; INTERIOR and EXTERIOR provide simple view presets.

Models are used without geometry/material edits:

- ORIGINAL: `assets/v106/v106_car_01.glb`, 591259 triangles, SHA-256 `40d1d00e66e2bbd4429579f82ecda65a749f5301ff38ced5b5b5193f76c20c4f`. Use the existing original GLB supplied with the project (see V106_IMPORT.md).
- HIGH: `assets/v106_mobile/v106_car01_mobile.glb`, SHA-256 `aed209d835f6f2a50090cbcbe283ec1467853a2d598591801196618f8ae4c48a`.
- MEDIUM: `assets/v106_mobile/medium/v106_car01_medium.glb`, 299974 triangles, SHA-256 `28304ed67e3122923accedbdf40c2fd9f57c021cb0e243dadcdbe01965fc3427`.
- LOW: `assets/v106_mobile/low/v106_car01_low.glb`, 196937 triangles, SHA-256 `733ea2a484c06fdd422172d30bc3e3030643d7c2d29a6b51522b86a67044bce4`.

For each optimized file, run its existing adjacent `restore_glb.py` only if the GLB is absent. No restoration or optimization was repeated for this build.

Export with the existing Android preset:

`godot --headless --path metro2 --editor --import --quit`

`godot --headless --path metro2 --export-debug Android /absolute/output/MinskMetro_V106_Comparison.apk`

The APK uses a development signing key. No on-device visual or performance acceptance is claimed.
The application icon is the unmodified default icon from the Godot 4.3 Android export template.
