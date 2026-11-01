# V106 GitHub asset audit — 2026-11-01

## Verified root cause

The four exported original GLBs were available in a previous Work/local Godot environment, **not committed into GitHub**. Evidence: `metro2/V106_IMPORT.md` explicitly states "GitHub text-only fallback: models are NOT included in this commit" and explains local Git push authentication failure. `metro2-beta-lod1/README.md` confirms the original GLB was supplied from `V106_Godot_Complete.zip` for the comparison APK, while its binary was absent from the Git checkout. `metro2/BLOCK4_MESH_CHECKPOINT.md` confirms all four original files were available locally for geometry analysis. This proves local use, not repository persistence.

## Checked GitHub branches

`main`, `testing`, `integration/consist-v106`, `feature/metro2-real-scene-p3`, `feature/metro2-real-scene-p3-recovery`, `feature/metro2-v106-comparison-apk`, `feature/metro2-first-playable`, `feature/metro2-godot-p1`, `feature/metro2-v106-aggressive-lod`, `planning/metro-2-roadmap`, `gh-pages`, `archive/project-history` (comparisons and/or direct path lookups). This is a targeted branch/path audit, **not a complete recursive Git-object scan**. A repository-wide search of the default branch for original GLB names and archive name found no hits. Prior workflow artifacts, deleted objects and external Work environments remain unverified.

## Canonical assets

- Original car01: 32324584 bytes, SHA256 40d1d00e66e2bbd4429579f82ecda65a749f5301ff38ced5b5b5193f76c20c4f.
- Original car02: 28658552 bytes, SHA256 bf3fac63153e28b9d250d437e95c2f2fd2dfc17b9c750a399bf559c34769cd5b.
- Original car03: 28658552 bytes, SHA256 7160a2db252a4a641c80555acd9d0351f2f488e230068980f32eb287333676e1.
- Original car04: 32305384 bytes, SHA256 a0257eeca3c8f6e2959025d34dbc3934449901f823ef5668716fc3716d14a6aa.
- Approved car01 LOD1 from comparison APK: 22181156 bytes, SHA256 4d7db8f979e6688f34ac670f63476166a8129da9e455bed1eef6b9ff1f853d2c. Persisted in `metro2/assets/v106_lod1/parts/` on first-playable.
- Cab: persisted in `metro2/assets/cab/parts/` on first-playable.

## Active project policy

**Keep:** `main`, `testing`, `cab-development`, `integration/consist-v106`, station/passenger branches, `planning/metro-2-roadmap`, approved LOD1, original source models, cab, Godot scripts/scenes, Three.js source for reproducible recovery.

**Reject for game builds:** `metro2/assets/v106_mobile/` Mobile/Medium/Low from aggressive optimization; reported damaged by owner. Do not re-enable or silently substitute them.

**Cleanup postponed:** Deleting old branches or aggressive-model parts before complete archive/commit/workflow artifact audit risks destroying the only recoverable source or provenance. Keep the rejected assets isolated until a verified backup and exact deletion inventory exist.

## Current blocker and recovery

`metro2/scenes/WebPreviewOptimizedCar.tscn` references approved LOD1 for car01 and original GLBs for car02–04. Source GLBs include **baked longitudinal placement** (Z ranges car01 -10.055..10.3555, car02 9.994..30.3615, car03 30..50.3675, car04 50.006..70.073), so do not add extra 20 m per-car offsets. Web workflow must fail until all three missing binaries exist; it must not publish four cloned head cars.

Find the previous `V106_Godot_Complete.zip` or APK build environment/artifact, extract the exact original car02–04, verify hashes, and store them durably as chunks with restore script and manifest. Only then run the Godot import and verify door leaves, visual appearance, and Web publication. **No re-export or re-optimization.**
