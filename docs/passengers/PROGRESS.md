# Passenger modernization — checkpoint 1

Branch: `feature/passengers-realism-20261028`. No merges into any other branch.
Base / last fully verified commit: `aef6e01a10c9750582c93697536b3e56a62ac3f2`.
This checkpoint is work in progress, not the completed passenger specification.

## Implemented

- 12 textured, anatomically shaped MakeHuman demographics, children and elderly included; medium and low GLB files, 6 skeletal animation clips each.
- Deduplicated local textures (~5.7 MB), 8-angle far impostor atlases, texture budget manifest, local Three.js loaders.
- Modular simulation, spawner, column avoidance, independent waiting/walking/phone/conversation/family states.
- Per-door alighting-before-boarding queues; a single persistent passenger identity crosses the actual sill and remains aboard between stations. Threshold crossings drive counts.
- Seat reservation, sitting/standing/phone/rail poses, gait phase tied to actual distance; hand IK added after the first visual review.
- Recorded CC0 murmur and footsteps with distance, crowd-density and cab attenuation.
- Integration in the existing scene and mirrors; leading detailed carriage doorways aligned to exterior doors. Removed opaque door backing from the exterior boarding portals.
- Explicit development inspector via `?preview=station&cabInspector=1&passengerInspector=1&passengerSeed=717`.

## Verification performed

- Existing 23 Node regression tests passed before checkpoint.
- New passenger tests: 6 of 7 passed. The queue-drain test still fails for seed 42. Do not hide or weaken this failure.
- Actual Chromium/SwiftShader game booted with 24 models and no JavaScript errors. Platform and close-up screenshots were manually inspected. First-pass defects (bad model scale / atlas cropping, extended idle arms, blocky bags) were identified; scale and cropping were corrected and verified; IK and rounded accessories need a fresh game screenshot.
- Atlas generation completed for all 12 profiles after IK changes.
- Browser startup on the provided Chromium works with software WebGL. Full game screenshots can take over 30 seconds; use a 120-second screenshot timeout. No hardware-FPS claim has been established.

## Known problems / next work

1. Resolve seed-42 pedestrian deadlock around door 6; some nonboarding people and alighters block a queue goal near the column at z=-25. Resume in `PassengerNavigation.js`, `PassengerBoardingController.js`, `PassengerSpawner.js`; run `node --test tests/passengers.test.js`.
2. Check all queues for several seeds (717, 42, 106), closure during a crossing, and re-opening. Review the currently limited local steering around stationary people.
3. Add full automated browser scenario coverage and review screenshots: overview, faces, walking, groups, approach, alighting, boarding, windows, both mirrors, carriage, desktop/mobile, FPS/memory. Currently only ad-hoc browser smoke checks and asset baking exist.
4. Inspect hand IK (phone/rail/sitting) and rounded accessories in the real scene. Check skin/clothes intersections and seated hip height against the benches.
5. Review far impostor colors/lighting/fog and animated-to-impostor transitions; measure baseline vs updated game on the same software renderer. Hardware/mobile performance remains unverified.
6. Inspect/refine seasonal wardrobe coverage (currently predominantly casual shirts, suits, sportswear), camera continuity, and interior visibility through lit windows.
7. Remove unused legacy passenger implementation only after regression coverage is complete. Finish asset provenance/build instructions.

## Exact continuation

Start with `git status`, verify this branch's remote head, then read this file and run the passenger tests. Do not restart the project or replace the accepted cab/v106 work.

Main integration: `js/main.js` imports `PassengerSystem.js`; all new logic is under `js/passengers/`.
Asset source: Ara 3D Gen `dd716acd32df44f06b8968ab57c5c54428475b94`.
Build tools: `tools/passengers/`; gallery/bake harness: `tests/fixtures/passenger-assets.html`.

The commit containing this file is the first remote checkpoint. Its SHA must be verified with `git ls-remote origin refs/heads/feature/passengers-realism-20261028` after pushing. Later verified SHAs should be recorded in subsequent checkpoints.
