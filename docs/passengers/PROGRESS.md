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

## Resume verification — 29 October 2026

- Remote checkpoint confirmed: `d5530afd4bbec0a430d940840c3c9949e548b947`; its full tree is identical to local recovery commit `7f8d13a86208606ac96bfca447a26b66864289bd`. All 103 changed paths, models, textures, sounds and tools are preserved remotely.
- Resumed from that exact remote tree, without merging or changing the cab or v106 branches.
- Passenger regression tests rerun: 6/7 pass; seed 42 still fails queue drain. This remains an explicit known failure.
- Next: capture the current passengers in the actual game before changes, then fix pedestrian deadlock and verify multiple seeded exchanges, closure/reopening and browser continuity.
- Full historical chats are not directly enumerable here. Retrieved requirements cover realism/diversity, natural movement and social activities, persistent boarding/alighting and carriage occupants, sound, mirrors, LOD/performance, modular code, regression/browser checks and screenshots. Completion is not claimed.


## Checkpoint 2 — queue recovery and baseline screenshots

Last verified remote before this checkpoint: `bc0b154f53eb7ad6d21a00d3b0eade758fb27a92`.

Implemented after recovery:
- Replaced repeated column-corner waypoints with a bounded deterministic route search.
- Sustained failure to approach a waypoint triggers a route around actual people and columns; ordinary movement and collision checks remain in force. No teleportation or disabled collisions.
- Nonboarding passengers move out of doorway lanes; end-of-platform waiting positions are now unique.
- Browser capture harness records actual scene screenshots and asset/request/error diagnostics. Baseline screenshots are under `artifacts/passengers/`.

Validation: `npm run check`: 32/32 pass. Includes all 14 seeds (0–9, 42, 106, 717, 10677) fully exchanging within 120 simulated seconds, six close/reopen timings, unique crossing counts, and collision-free column routing. Actual Chromium loaded all 24 models without JS errors or failed requests. Baseline screenshots manually reviewed: textured people, families/groups and accessories present; the first close-up is partially occluded, so a clearer portrait is still needed.

Remaining: automated browser exchange/carriage/mirror/mobile coverage, clearer faces and pose/seat QA, LOD/performance comparison and wardrobe refinement. Full specification is not complete. Resume with `tests/passenger-capture.mjs`, `PassengerAnimator.js`, `PassengerSystem.js` and the above browser scenarios. Cab and v106 files have not been changed.

## Checkpoint 3 — verified seating, closure, distant poses and browser coverage

Last verified remote parent: `17654ce5a3ae0954197e3c1893021c4a9968ce1f`.

Implemented:
- Chair clips no longer translate the pelvis backwards into the backrest. Pelvis height matches the detailed carriage; hand IK is relative to the seated pelvis. Verified using the actual shipped adult, elderly and child skeletons, then in game screenshots.
- Closing after a crossing preserves the completed crossing: alighters already on the platform leave without walking back through the train; boarders already inside continue to their allocated place.
- Separate standing/seated 8-direction atlases for all 12 profiles; distant seated passengers retain their silhouette without keeping every distant skeleton animated.
- Passenger-owned accessory geometry/materials are disposed on despawn; shared source meshes/materials are retained. Footstep bookkeeping drops removed agents.
- Automated browser scenarios: complete exchange, persistent identities after switching to carriage camera, desktop/mobile screenshots, both mirror render targets, all local model requests and JS errors, software-renderer measurements.

Final validation:
- `npm run check`: 34/34 pass. Includes 14 complete seed variations, six closure/reopening timings, exact crossing counts, real skeletal chair pose tests and all existing cab/physics regressions.
- `tests/passenger-browser.mjs`: pass. Seed 717, 8 alightings + 51 boardings, 67 onboard after exchange, unchanged identities in carriage/mobile view, 24 model variants loaded, no JS errors or failed requests.
- Current screenshots are in `artifacts/passengers/verified/`; portrait, exchange, corrected seated passengers and mobile carriage manually inspected. Both mirrors captured; left mirror includes platform pedestrians.
- Same carriage scenario: rendered triangle count reduced from 1,555,458 before distant seated atlases to 1,096,694 after. Software-renderer sample ~1.22 FPS, 212 MB reported JS heap; the no-passenger sample was slower (~0.72 FPS). These noisy short SwiftShader samples do NOT establish a reliable FPS gain or real-device suitability.

Remaining / exact continuation:
1. Real-rail grip anchors: current rail pose is a generic IK target, not an exact attachment to each physical rail. Start in `PassengerConfig.js`, `PassengerSpawner.js`, `PassengerBoardingController.js`, `PassengerAnimator.js`; derive anchors from the existing `CarriageRails.js` without altering accepted geometry.
2. Sitting/standing transitions still switch/crossfade to the idle chair pose instead of using the full sit-down/stand-up clips. Add a timed transition and recheck baggage/clothing intersections.
3. Clothing is textured but mostly casual/sports/suits, not a complete seasonal wardrobe. Faces, hands, bags and social gestures need additional visual refinement.
4. Performance remains unapproved: measure longer warmed runs and real mobile hardware, audit texture/draw-call budget, LOD transitions, mirror/window visibility and per-station memory retention.
5. Remove unused legacy passenger modules only after completing the remaining coverage. New implementation is isolated; no merges or changes to cab/v106 branches have been performed.

Reproduce: `npm run check`; `CAB_CHROMIUM=/path/to/chromium node tests/passenger-browser.mjs`; atlases: `CAB_CHROMIUM=/path/to/chromium node tools/passengers/bake-atlas.mjs`. Full specification is still work in progress.

## TZ2 checkpoint 1 — train response and physical grip

Parent verified on GitHub: `7d2613fe428ca1ebe2ac8ee3ed60190bf932b552`.
- Added a read-only km/h → m/s² adapter and damped, independently phased carriage response. Standing supported / unsupported and seated people have different response amplitudes; platform passengers do not sway with the train.
- Grip candidates are sampled from the actual TubeGeometry paths after the existing carriage transform. Unreachable rails are rejected; the chosen world-space wrist anchor stays fixed while the torso compensates motion. No carriage geometry or train physics has changed.
- Automated checks: 39/39 pass, including exact shipped adult, elderly and child skeletons, train acceleration/braking signs, asynchronous cruising sway, support attenuation and wrist lock within 2 mm.
- Browser baseline is running separately. This is an intermediate checkpoint, not completed TZ2. Next: timed sit/stand clips, social actions, accessories, long station cycles and complete fresh screenshot/performance review.

## TZ2 checkpoint 2 — seat transitions, activities and repeated stations

Verified repair parent: `1a74d13d4146e51a861d7a5e1803d64a3d9a31da`. The complete `js/main.js` blob is `719bee5a75a58dca04b42d3c89f60e1a9c3aa78f`; an earlier transport truncation was repaired immediately. Future uploads must verify every blob SHA against `git hash-object` before advancing the branch.

- Added explicit turn / 2 s sit-down / chair idle / 2 s stand-up / stabilization states using the shipped full clips. Approach points are in front of reserved seats; root motion cannot push the pelvis through the backrest. Children use the actual bench height.
- Added short independent phone/window/display/neighbor/group/parent attention and weight-shift actions separated by quiet intervals. Backpacks stay part of the same passenger and move onto the lap while seated.
- Families and companions retain a common destination; boarding no longer overwrites their assigned destination. Twelve consecutive station cycles retain the same passenger objects and appearance, exit due passengers, finish their queues, and do not duplicate crossings when doors reopen.
- The 12-station test exposes a known capacity limit: later crowds need more than 120 simulated seconds with the existing serial door controller; a finite 300 s deadline is checked. The existing initial-scene 120 s tests remain unchanged and pass.
- Crossing journals and render de-duplication sets are bounded. Accessory and cloned-skeleton resources are released. Duplicate GLB texture instances and per-material cloned skeleton palettes are shared within safe ownership boundaries.
- Tests: 43/43 passed; exact physical vertical and lower horizontal rails tested. A fresh browser run is still required for the new transitions / accessory / resource changes.

Next: inspect modern/seasonal clothing (several legacy profile names do not match their actual garment), fresh browser screenshots including locked grips and real acceleration/braking, warm long performance/memory samples and final report. Hardware/mobile GPU performance is not verified.
