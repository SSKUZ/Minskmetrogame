# V106 Stage 7 — isolated geometric LOD experiment

Date: 2026-10-31. Source: local `v106_mobile_weld_test/car01.glb`, mesh #289, material-batched static geometry.

An independent Python/VTK 9.6.2 experiment read mesh #289 from the GLB and ran `vtkQuadricDecimation` on an **isolated copy**, targeting 35% reduction.

- Input: **86,720** triangles.
- Cleaned: **86,720** triangles.
- Output: **56,368** triangles.
- Removed: **30,352** triangles (**35.0%** of this mesh).
- Artifact: `v106_mesh289_lod1_experiment.ply` (local prototype, not committed to GitHub).
- Script: `metro2/tools/v106_lod1_mesh289_experiment.py`.

**CRITICAL:** PLY is geometry-only: it does **not** preserve original glTF materials, texture coordinates, normals, doors, decals or mesh hierarchy. This is an **experimental isolated mesh** and is **not** ready for the game. A reduction in triangle count is confirmed, **visual quality is NOT confirmed**. The original GLBs and game scene remain unchanged. There is no measured APK/FPS improvement.

Next: compare rendered mesh 289 against original from multiple viewpoints; build a GLB-preserving simplification pipeline (UV/normals/material-aware), test Godot import and close-up visuals before applying to any car. No edits to gloss or textures until explicitly approved.
