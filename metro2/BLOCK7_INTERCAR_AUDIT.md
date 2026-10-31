# Block 7 — local source verification and inter-car broad phase

Date: 2026-10-31. No Work used. Source GLBs were read locally from /mnt/data; all four SHA-256 digests match V106_IMPORT.md:
1. 32324584 bytes, 40d1d00e66e2bbd4429579f82ecda65a749f5301ff38ced5b5b5193f76c20c4f
2. 28658552 bytes, bf3fac63153e28b9d250d437e95c2f2fd2dfc17b9c750a399bf559c34769cd5b
3. 28658552 bytes, 7160a2db252a4a641c80555acd9d0351f2f488e230068980f32eb287333676e1
4. 32305384 bytes, a0257eeca3c8f6e2959025d34dbc3934449901f823ef5668716fc3716d14a6aa

## Actual local mesh-AABB broad phase
Each of the three joints has **11 pairs of mesh-node bounding boxes with strictly positive overlap in XYZ**:
- joint 01–02: 11
- joint 02–03: 11
- joint 03–04: 11

Maximum individual AABB-overlap dimensions seen at each joint are approximately 2.684 m X, 2.572–2.581 m Y and 0.3548 m Z (these maxima are taken over different candidate pairs, not one collision volume). This proves a need for narrow-phase checking; it **does not prove triangle intersection**.

A reproducible offline tool `tools/audit_intercar_candidates.py` now lists each candidate pair, with all eight bounding-box corners transformed. Local experiment used trimesh and numpy. The committed tool has not yet run in GitHub CI.

## Next acceptance gate
1. Run narrow-phase triangle/triangle intersection only on the 11 candidate pairs per joint (33 pairs total), excluding coincident decorative layers when justified by mesh identity.
2. Run Godot 4.3 headless import with original GLBs available locally, capture logs.
3. Inspect combined scene screenshot and wheel/rail fit.
4. Do not alter any original GLB, coupling offsets, or branches other than feature/metro2-real-scene-p3-recovery.

## Known blockers
- Godot executable was not found in the local execution environment.
- Original binary GLBs are available in local files, but not stored in the GitHub repository.
- No narrow-phase collision result or rendered scene acceptance yet.
