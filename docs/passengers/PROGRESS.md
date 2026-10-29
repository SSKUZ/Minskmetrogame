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

## TZ2 checkpoint 3 — physical wardrobe and grip refinement

Parent: `5cd9d779e92865749f0b8cb21050b94be14e4135`.
- Added reproducible fitted/skinned seasonal garment recipes: real coat geometry with hem, buttons and seam; hooded layers, sweaters, children's full-length tops and trousers; retained skirts, sportswear, jeans, summer shirts and the existing jacket mesh. Shared demographic identities and all six clips are preserved. Runtime elderly hair receives a neutral grey treatment.
- Rebuilt the matching medium/low models and both pose atlases. Final visual acceptance is pending the in-game captures; earlier builds with missing custom garment registration and an unjoined coat waist were rejected and corrected before saving.
- The wrist orientation follows the actual bar. A small GPU deformation curls the existing hand vertices because the accepted game-lite skeleton has no individual finger bones. This is a bounded grip silhouette, not a full anatomical finger rig; close-up review is required.
- Safe texture and skeleton sharing reduced the GPU texture counter from 1170 to 234 in the same seed/carriage scenario. This is an allocation reduction, not proof of real-device FPS.
- Extended browser script `tests/passenger-tz2-browser.mjs` captures eleven requested views, uses the real cab controller for acceleration/braking, warms the renderer, measures a 45 s window and audits eight subsequent station exchanges with GC/resource measurements.
- Existing browser suite has passed after the transition/resource changes; 43/43 Node tests passed before the additional explicit seasonal asset assertion. The extended browser run is in progress. Completion is not yet claimed.

### Browser finding before checkpoint 3 publication

The extended run successfully captured platform, alighting, boarding and carriage views with no JS/request errors, but failed its physical-grip population assertion: no standing passenger had chosen a reachable bar in the seeded real scene. Unit tests at reachable positions alone were insufficient. Navigation now receives candidate standing places derived from actual vertical rail geometry; support-preferring boarders reserve these places before legacy standing slots. Re-run the extended browser suite and inspect the hands before accepting this feature. No successful final-browser claim is made for this WIP checkpoint.

## TZ2 checkpoint 4 — real-scene validation and family seats

Verified remote parent: `cc0029759dd8c1defbc5a8296c2a2e04238bc2c3`.
- Fixed the development inspection camera so a custom interior view renders the same detailed carriage as the ordinary carriage camera. Earlier R2 custom views showed the simplified exterior interior and are rejected as grip evidence. Normal cameras are unchanged.
- Extended actual Chromium run R3 passed: 51 boardings, 8 alightings, physical rail attachment present, identities maintained under the real cab controller's acceleration/braking, desktop/mobile views and both mirror targets captured; eight subsequent station exchanges completed with no JS/shader/request errors and no repeated reopening events.
- Warm software-renderer measurement: 30 s warm-up then 48.47 s / 26 frames, 0.516 FPS, median 2000 ms and p95 3916 ms. This is SwiftShader; real-device suitability is NOT established. GPU textures in the warm view: 196. These samples must not be presented as a mobile performance pass.
- Eight-station GC samples settle around 59–60 MB JS heap; geometry/texture counts fluctuate with visible population rather than growing each station. Full data and screenshots: `artifacts/passengers/tz2-final-r3/`.
- Visual review caught separated family seats (up to 6.6 m). Added shared adjacent-seat reservations and nearby standing preference. Seeds 717, 42 and 106 now keep children near their parent; seed 717 pairs occupy adjacent seats 0.66 m apart. All 15 passenger/transition checks passed; the new explicit family test and 12-station test pass. Existing successful assertions are retained.
- Exact hand close-up in R3 remains partially hidden by the passenger's torso; corrected side-view capture and fresh family screenshots are running in `tests/passenger-details.mjs`.

Known remaining work: service throughput is too low at dense later stations (up to 247 simulated seconds in R3). Pre-stage imminent alighters inside the train while preserving full stand-up clips, door priority, collision constraints and single crossing counts; add a regression deadline. Review the corrected hand, wardrobe and family close-ups. Hardware/mobile GPU acceptance is still unavailable in this environment. Do not claim completed TZ2 yet.

## Resume after Work passengers 4

Remote parent `4dfa6664b521d7b31825c7ba2d12916ffdf68967`; intermediate WIP safely
published as `f8a953ccdc31649a957a055b68b3710465e5e368`.

- Concurrent full stand-up clips, side waiting places, ready-person door priority
  and release after the whole alighter clears the sill replace serial preparation.
- Added narrow continuous crowd escapes, train-aisle detours and final-goal
  preservation when a column corner becomes occupied. Corrected id=0 handling,
  post-projection collision validation and gradual clearing of the platform edge.
- Nonboarders keep yielding to open doorways throughout the stop.
- Corrected wrist axes and actual GPU skin curling. Two dedicated close-up views
  confirm the improvement; this remains an approximate finger deformation.
- `npm run check`: 50/50. Three crowds (717/42/106) each finish 12 stations with
  no duplicate reopening events. Seed 717 maximum 148.17 s; regression deadline
  tightened from 300 to 150 s. This is not yet a realistic short metro dwell.
- Full current details and remaining browser/mobile acceptance: RESUME-20261029.md.
