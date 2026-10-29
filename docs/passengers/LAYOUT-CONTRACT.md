# Passenger adapters and scope — 29 October 2026

User amendments supersede earlier work on the temporary carriage. Develop only
passenger algorithms, appearance, animation, LOD and performance. Geometry-only
defects in its walls/panels, doors, benches or rails are limitations of the stand;
record them and continue. Do not modify the carriage, V106, cab or other branches.
Future integration into V106 is a separate acceptance stage. Do not merge.

## What changed after remote checkpoint 9655213

`PassengerLayout.js` now supplies the coordinate contract to PassengerSystem,
simulation, spawner, navigation and boarding. The existing geometry is unchanged.
`createTestPassengerLayout()` contains the temporary carriage's legacy mapping;
`createPassengerLayout()` accepts a different mapping. Geometry coordinates are
not recomputed from a car number in the passenger algorithms anymore.

Six adapter inputs:

- **Door anchors:** stable `id`, `car`, `z`; threshold, approach, inner/outer route
  and queue X positions, yielding positions, fallback standing point. Door IDs
  need not be consecutive or array indices. Only physical threshold crossings
  change passenger counts; closure/reopening retains their single identity.
- **Seat anchors per car:** stable `id`, `x/z`, `approach` point, `heading` in
  radians and `hipHeight` in metres above the floor. Full sit/rise clips use the
  supplied approach/facing and pelvis height. Families reserve these same seats.
- **Standing zones per car:** candidate `x/z` points; optional `railId` links an
  explicitly provided standing point to support. Occupied places are excluded.
- **Rail/grip anchors:** `{id, radius, points: THREE.Vector3[]}` in world space.
  The stand adapter can sample existing TubeGeometry; another adapter can provide
  points for entirely different meshes. The animation detects changed/deleted
  anchors and reacquires a reachable grip. Unavailable grips retry at 2 Hz.
- **Navigation zones:** each car supplies its aisle X, valid walking X bounds
  and an aisle rectangle. Delayed detours remain inside this supplied rectangle.
- **Collision zones:** circles `{space, car?, x, z, radius}` in the simulation
  frame. `car` restricts train obstacles; platform obstacles have no car. The
  detour and per-step collision checks consume the same supplied obstacles.

Simulation X is world X. Simulation train Z plus `train.offsetZ` is world Z;
platform Z plus the platform object's Z is world Z. Floor heights are supplied
by `train.floorY` and `platform.y`. Car, door and seat mappings are supplied when
constructing a system/simulation; their topology is not hot-swappable mid-stop.
Rail point arrays can move/remove/restore at runtime. Other remapping requires a
new adapter at setup; live seat/door relocation during an active crossing is not
implemented or claimed.

## Verification and remaining limits

New regression scenarios use a translated platform/interior and nonconsecutive
door/car IDs for three complete stations; verify exact crossing counts, priority,
reopening, identities and supplied seat reservations. Separate scenarios verify
injected train obstacles, a real child's skeleton on a 0.71 m seat and a moving,
removed/restored grip on the actual shipped adult skeleton. Existing tests cover
12 consecutive stops on the default stand and retain their deadlines.

This is a reusable adapter foundation, not finished V106 integration. Present
locomotion supports doors opening toward negative X, rectangular aisle search
zones and circular collision footprints. Rotated/right-side door routes, polygon
navigation and live seat/door remapping need additional contract work if required
by the real V106 layout. Explicitly reject unsupported orientation rather than
silently crossing a wall. Legacy standalone seating/animation helpers retain
default heights for compatibility; integrated agents always receive seat anchors.

The inherited portal-backing visibility change in `de0e2bb` predates these
amendments. It is not expanded or further tuned. No geometry-only defects will
be fixed as part of passenger work.

Browser acceptance for source `621747f` passed in GitHub Actions run
`40904371987`: 24 models, 51 boardings, 8 alightings and 67 retained onboard
identities; carriage/mobile views and both mirrors, zero JS/request errors.
Carriage, portrait and mobile screenshots were visually inspected. Summary:
`artifacts/passengers/layout-checkpoint/acceptance.json`. The current environment
has no Chromium and its download failed; actual rendering ran in CI instead.

Remaining TZ2 work: dense-stop throughput, accessory/clothing intersections and
actual Android GPU/FPS testing. Software/desktop mobile viewports never count as
real Android performance acceptance. The 0.394 FPS / 5-frame SwiftShader sample
in this run is a software-renderer diagnostic, not an optimization result.

A proposed intermediate-waypoint walking change improved an isolated 5 m walk
but introduced a seed-42 station-6 door-3 deadlock. It was rejected and fully
reverted. Its diagnostic snapshot is saved separately as
`rejected-walking-seed42.json`; it does not describe the current code. The
12-station regression now covers seeds 717, 42 and 106 separately, preserving
the same 150 s deadline. Further throughput work must pass all three.
