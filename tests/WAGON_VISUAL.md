# Wagon visual checks

Use only `testing`. The sole photo is `reference/uruchcha-81-717.png`, copied
from the user's 5312.png attachment. Its SHA-256 is checked before rendering.
Manual bounds in the adjacent JSON file are approximate, inspectable labels.

Run `npm install --package-lock=false`, `npx playwright install chromium`, start
`python3 -m http.server 8765`, then run `npm run test:wagon`.

The existing **Wagon 3D model checks** workflow runs on relevant testing pushes
and can be launched manually on testing. It downloads the latest retained
successful testing artifact as the baseline, renders six fixed views at
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
