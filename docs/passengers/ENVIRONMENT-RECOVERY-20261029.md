# Recovery after execution environment loss
Branch: feature/passengers-realism-20261028.
Remote base: 77bfdd308971e39ff93ec4c140bf28bc2503ceb7.

The local executor became unavailable while applying the next approach-preparation
change. A read-only attempt returned: "No usable execution environment is available".
The local filesystem could no longer be read for a byte-for-byte final diff.

This WIP source was reconstructed from the remote base and the recorded, previously
applied patches: connected entrance/aisle/seat-approach navigation zones, real seat
fallback when standing is full, keeping door and bench access clear, occupancy-aware
door selection, capacity guards, stable pre-arrival door choices, the close-command
guard, and strict normal-flow/component tests. It also includes the last recorded
approach-preparation proposal for validation: full stand-up clips before stopping,
one ready front alighter per door, workload estimates based on personal walking
speeds, and no change to those speeds.

No geometry, V106 branch or cab model is modified. js/main.js only consumes the
two passenger closure signals and waits for physical clearance on a close request.

Known acceptance at recovery: focused safety/routing checks passed before the
environment loss, but the normal eight-stop series was still failing the 30 s
limit. Earlier single-stop successes are not full acceptance. No new pass is
claimed for the reconstructed source until hosted CI runs it.

Hosted CI now runs the strict normal 40/50/60-person, four-car, eight-stop scenario
for seeds 717, 42 and 106, prints diagnostic state and preserves reports even on
failure. Its timer is 30 s after full aperture, with zero automatic missed-train
reclassification allowed to pass it. The old dense 12-stop series stays optional.
The 16-door fixture is a contract scenario for the future composition; rendering
still uses the unchanged temporary eight-door stand and is not V106 integration.
