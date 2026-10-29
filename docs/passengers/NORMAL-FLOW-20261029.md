# Normal passenger flow — current acceptance requirements

User amendments of 29 October 2026 supersede the old dense-crowd timing criterion.
Primary target: 40–60 people naturally spread along the platform, four logical
cars, multiple doors, queue-aware reachable door choice, intact families/groups,
parallel exits/entries with exit priority. Existing temporary carriage geometry
must not be changed. Final physical V106 integration is a separate stage.

Normal exchange should usually take 10–20 seconds after full door opening; busy
normal cases may take 25–30 seconds. 30 seconds is the upper primary-test limit.
Do not change natural walking speeds or shorten animations to make it pass.
Primary acceptance must cover at least 8 consecutive stops. Huge crowds are only
optional stability stress tests, not the main performance target.

Completion requires all scheduled alighters outside and clear of doors, all
boarders admitted to this service inside and clear of the leaves, no crossing,
stuck body or unfinished entry/exit in the doorway. Riders may continue to their
places; full arrival at seats is not required. People who miss this service
remain outside and wait for the next train without blocking closure.
Expose two independent signals: passengerExchangeComplete and doorsSafeToClose.
The latter is a physical door-zone check and must never be replaced by a timer.

## Work in progress checkpoint after environment recovery

Passenger navigation fix is already preserved at ebc6c23801c2ffef0a495b383e9b55c7753f77ec
with 63 checks. The next WIP stage adds a normal 50-person/four-car simulation
profile, stratified platform placement and family-aware, queue/path-cost based
platform and exit door choice. Four logical test cars use only their existing
physical test-door anchors; no extra doors are invented in the old geometry.
The old 12-stop stress series is moved to an explicit optional script.

Current measurements still FAIL the new timing target: first 40-person runs take
38.37–43.90 s. Browser assertions still need updating for the normal profile.
Completion/safe-to-close signals and 8-stop primary acceptance are not implemented
in this WIP checkpoint. Next: advancing queues, release of safe door zones,
precise completion/late-passenger policy and primary tests. Do not claim success.
