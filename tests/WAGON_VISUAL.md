# Wagon visual checks

Use only `testing`. The sole front photo is `reference/uruchcha-81-717.png`, copied
from the user's 5312.png attachment. Its SHA-256 is checked before rendering.
Manual bounds in the adjacent JSON file are approximate, inspectable labels.

Run `npm install --package-lock=false`, `npx playwright install chromium`, start
`python3 -m http.server 8765`, then run `npm run test:wagon`.

The existing **Wagon 3D model checks** workflow runs on relevant testing pushes
and can be launched manually on testing. It downloads the latest retained
successful testing artifact as the baseline, renders fourteen fixed views at
1536 × 934 / DPR 1, waits for built geometry and rendered frames, and uploads
the screenshots, diffs, JSON, Markdown, and an HTML gallery. The artifact name
and report contain the tested commit SHA; the report also identifies baseline
SHA and Actions run. The first run can have an incompatible older baseline;
this is reported, never silently treated as a successful pixel comparison.

`reference`, `front`, and `side` are the primary views. `outside`, `driver`, and
`salon` retain existing coverage. `?view=reference` opens the calibrated view;
`&qa=1` hides controls and grid. Rendering has no random seeds or animations.
A repeated reference capture must have zero changed pixels. Camera and
lighting identifiers are included so changes to capture conditions are visible.

Pixelmatch creates `*-diff.png`, changed-pixel counts, a changed bounding box,
and a 4 × 4 region breakdown. Counts describe changed render area. They do not
decide whether an intentional change is an improvement. Missing registered
feature meshes and JavaScript errors fail technical checks.

Photo analysis is independent of Pixelmatch. Actual mesh bounds are projected
through the reference camera and normalized to fascia width. The report lists
signed position and size residuals against the labelled photo and produces
`reference-geometry-overlay.png`: cyan is model geometry, amber is the photo
annotation aligned to the model fascia. The 0.035-fascia-width review band is
a diagnostic threshold, not a measured similarity or acceptance score.

Unknown camera intrinsics, perspective, occlusion, material response, and
station lighting limit this method. Inspect the real rendered images and the
source photo before accepting geometry changes. Bounding boxes cannot prove
correct curved contours or that equipment is visibly rendered. The workflow
collects evidence; it does not autonomously rewrite Three.js or claim likeness.
During an active development run, use this evidence for the next code change.

The optional `WAGON_CHROMIUM_EXECUTABLE`, `WAGON_LOCAL_ROOT`, and
`WAGON_ASSET_DIR` variables support restricted local environments. They are
unset in Actions. `WAGON_TARGET_URL` can target the actual published page;
`WAGON_BASELINE_DIR` and `WAGON_RESULTS_DIR` select evidence directories.
`WAGON_FETCH_HTML=1` uses the trusted Playwright request context for HTML in
local environments whose Chromium trust store lacks the proxy CA; it retains
HTTPS verification. `WAGON_EXPECT_VERSION` rejects stale live versions.
Every run records a source-module hash and verifies the served module matches
it. Local uncommitted captures are marked with `workingTreeDirty`.
The rear 78% of the side-view image is protected: with a compatible baseline,
any changed pixels there fail the front-only task's regression check. This
does not claim coverage of every surface hidden from that camera.
An additional 412 × 915 portrait capture checks that the front fascia fits
on a phone. It uses responsive framing and is separate from the six fixed
1536 × 934 comparison views.

## Stage 3: side work with a locked v84 front

The latest scope allows passenger sides/interior/roof work and freezes the
front. `tests/reference/wagon-v84.html` is the immutable original source
(e08bd05). `front-v84-lock.json` pins its hash and seven protected source
regions, including cab equipment, front roof and calibrated cameras.
`v84-control/` contains actual pre-work Chromium captures.

Every run renders the immutable v84 and candidate with the same browser,
resolution and GPU and requires zero changed pixels outside the actual three transparent front glazing meshes. Seven source hashes and exact projected bounds separately protect the glass, cab and complete front assembly. The full unmasked frontal diff remains in the report.
This replaces the earlier protected-side check, whose scope is now obsolete.
The previous-run diffs and front photo geometry diagnostics remain.

Eight additional deterministic presets: side-full, side-angle, door-close,
window-close, window-inside, door-open, roof-side, roof-join. The door-open
preset becomes a true open-door capture when moving leaves land in stage 3.
Camera presets are for inspection, not a factory dimensional survey.


Stage 3 side-source provenance is in `reference/side-stage3-sources.json`.
The AI collage is not dimensional evidence. Source photos of sides and the
mechanical manual guide review; side likeness is not a fake percentage metric.
Checks additionally cover forty volumetric seats, 26 roof scoops, normal/winding
agreement, 30/60 Hz door motion, sampled wall-pocket clearance and real window
parallax. The ordinary viewer remains live; QA holds each actual WebGL frame
only after three renders. All captures retain fixed 1536 × 934 parameters.

## Stage 4 geometry continuity

The six v88 control views are preserved by an immutable HTML fixture with
verified SHA-256. Only common inspection cameras and a read-only measuring
function are injected for those baseline captures. No train geometry is
changed. Fixed camera values are in `reference/stage4-cameras.json`.
The regular workflow now includes eighteen views plus six before-v88 frames.

`wagon-continuity.mjs` enforces geometric criteria for v90+: one roof height
per sampled X/Z point; at most 7.5 mm change over a 20 mm longitudinal run;
cap/roof and roof/wall gaps at most 0.05 mm; outer wall-plane mismatch at most
1 mm; lower-sheet mismatch at most 1.1 mm; a single exterior cab skin and
consistent outward normals. v89 explicitly reports the existing defects as
a diagnosis. This sampling does not prove absence of every possible triangle
collision. Source/position checks independently protect front equipment,
windows, door motion and the 3D saloon.

For stage 4, `front-stage4-lock.json` releases structural roof/header/corner
code under the user's current authorization. It retains six immutable front
source regions; window-bay and complete saloon blocks are independently
compared against v88. The facade/equipment triangle mask is used only for
pixel protection, with the entire unmasked front difference kept separately.
This is an explicit scope change, not a claim that the revised blue roof is
pixel-identical to v84. Registered front equipment projections must still
match v84, including the exact six-headlamp layout and blank display.

Cap-to-root tangent planes must agree within 0.1 degrees; both side exterior
planes are sampled, and the new roof/side face winding is checked. The current
and v88 world-triangle measurements appear in the run summary and JSON files.
