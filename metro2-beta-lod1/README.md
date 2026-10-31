# V106 vs LOD1 — isolated Android comparison

Godot 4.3. Entry: `compare.tscn`. This project does not alter `metro2` or the main scene.
One finger or left mouse drag orbits. Two fingers pan and pinch zoom. Mouse wheel and +/- zoom. ORIGINAL/LOD1/BOTH select the camera pivot. Labels and FPS remain visible.
Both supplied cars are loaded together, with identical directional and ambient lighting. Godot-generated mesh LOD switching is suppressed with high LOD bias to compare the supplied geometry. FPS measures the combined two-car scene, not individual model performance.

## Exact inputs

Binary GLBs are not tracked in this checkout. Restore to `assets/` before exporting:

- `original.glb`: original `v106_car_01.glb`, 32324584 bytes, SHA256 `40d1d00e66e2bbd4429579f82ecda65a749f5301ff38ced5b5b5193f76c20c4f`.
- `lod1.glb`: `v106_car01_lod1_mesh289_normals_fixed.glb`, 22181156 bytes, SHA256 `4d7db8f979e6688f34ac670f63476166a8129da9e455bed1eef6b9ff1f853d2c`.

The original binary is absent from the current Git branch. Build used the saved V106_Godot_Complete.zip original, verified against metro2/V106_IMPORT.md. LOD1 was obtained directly and verified against metro2/V106_LOD1_NORMALS_AUDIT_STAGE11.md. Neither model was modified or regenerated.

Export: `godot --headless --path metro2-beta-lod1 --export-debug Android /absolute/output.apk` after configuring Android SDK/JDK and 4.3 templates. Debug package: `org.minskmetro.v106compare`, ARMv7 and ARM64, landscape, OpenGL compatibility. Distinct application from Alpha01.

Build verification does not constitute acceptance on Honor Pad X9. Headless runtime reports a dummy-renderer mesh warning; actual visual appearance and tablet FPS require a device run.
