# Autonomous wagon refinement checkpoint

Branch: testing. Initial commit: 1b525cbf8466a9fdb447ce41673a4e78fb3f17f2 (v80).
Only reference: tests/reference/uruchcha-81-717.png, SHA-256
2b47c2a5101ad0f297b00b8fe7f50fda055bc79982063a99df3f5caf6a4cb3ea.

## v81: repeatable inspection

Extended the existing wagon workflow; no second workflow was created. Added
reference/front/side camera presets, mesh-bound diagnostics, repeat-render
determinism checking, previous-run Pixelmatch diffs, photo proportion labels
and overlays, commit-linked reports, and retained interior camera checks.

Local v81 check: six real Chromium screenshots; no JavaScript errors;
repeated reference screenshot has zero changed pixels. This is a technical
pass, not a visual acceptance. Geometry is still v80 at this checkpoint.

Baseline game unit tests: 10/12 pass. Existing failures: doors open and close
(10.53 vs 11.56) and neutral coasts for at least one minute. Do not change
game mechanics as part of the wagon-only task. Cloud UI browser has no WebGL;
use software-rendering Chromium for actual screenshots.

## Next geometry priorities

1. Close and blend the cab roof; lower and shorten the fascia/window assembly.
2. Correct six lamp sizes and reflector geometry; center the two red markers.
3. Move and articulate the yellow mirrors; raise the three-part bumper.
4. Replace the blocky coupling head with a shaped mechanical assembly.
5. Improve cobalt enamel, black trim, glass, and cab equipment visible in photo.

After each stage: syntax, visual capture, inspect images and photo diagnostics,
commit testing, wait for actual publish and visual Actions, inspect the live
page, then continue. Preserve side panels, passenger doors, and game files.
Do not claim 100% likeness or infer publication from a successful commit.

## v82: geometry pass

Closed the cab roof and removed the separate tube over the brow. Corrected
fascia height, three glazing proportions, upper marker pockets, winged emblem,
six lamp diameters/spacing, raised bumper, rounded lower apron with a real
coupling notch, and yellow mirror housings/outriggers. Side body and passenger
door geometry were preserved.

Inspected real reference/front/side screenshots, photo-bound overlays, and
previous-version diffs. All six camera checks passed; repeated capture has
zero changed pixels. Only the coupling head remains outside the coarse photo
diagnostic band; this does not establish detailed contour or material accuracy.
The blue is still too grey/matte, lamps are flat, cab arrangement is wrong,
and the coupler remains too blocky. These are the next pass priorities.

v81 publication was fetched and rendered in Chromium with version 81 checked.
Its Actions visual run 40571552011 passed and uploaded 12 evidence files.
The restricted local browser uses the trusted request context to fetch HTML;
TLS verification is retained. The next test revision also verifies the served
module SHA-256 against local source so stale publishing cannot pass as current.
