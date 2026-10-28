# Current scope (latest user instruction)

Front exterior only: roof brow, nose corners, fascia, three front panes,
markers, six headlights, yellow mirrors, blank information panel, bumper and
coupler. Preserve passenger doors, side windows/walls beyond cab corners,
saloon, seats and ALL interior equipment. No station name on the display.

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
5. Improve cobalt enamel, black trim, glass, and external front equipment only.

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
and the coupler remains too blocky. The interior equipment is frozen under the latest user instruction; it is not a next-pass target.

v81 publication was fetched and rendered in Chromium with version 81 checked.
Its Actions visual run 40571552011 passed and uploaded 12 evidence files.
The restricted local browser uses the trusted request context to fetch HTML;
TLS verification is retained. The next test revision also verifies the served
module SHA-256 against local source so stale publishing cannot pass as current.

## v83: front-only materials and optics

Added cobalt enamel and separate front reflection lighting, concave lathed
headlight reflectors with clear lens covers, and curved red signal lenses.
Front materials are cloned and rendered in a separate layer/pass; the old
body/interior lights and shared materials remain unchanged. No interior
equipment or passenger geometry was edited.

Six-view local visual checks pass. Source-module hashes match; repeat capture
has zero changed pixels. The protected rear 78% of the side screenshot has
ZERO changed pixels relative to v82. Added this as a regression assertion.
The intentional front-lighting change is explicitly flagged in pixel reports.

v82 published source and version were fetched and rendered; visual Actions
run 40573092241 passed, compared to v81 and uploaded 18 evidence files.
Remaining front priorities: real curved roof brow rather than a flat cap,
cast coupling head/pneumatics, external wiper layout, mirror arm proportions.
All cab and saloon equipment stays frozen per the user's latest instruction.

## v84: current exterior geometry checkpoint

Rebuilt the forward roof brow as a sampled quarter-ellipse surface joined to
the roof shell. Replaced overlapping front pillar boxes/corner patches with
one continuous elliptical sheet per corner. A minimal joining exception
tapers the first 0.50 m of the upper side header; the rest of that header,
all passenger apertures and livery are preserved.

Replaced the block coupler with a beveled cast outline, two real holes, male
spigot, recessed socket, fasteners, pneumatic units and hoses. Removed the
obsolete box that had occluded the new socket. Corrected bumper divisions,
valve levers, mirror size/arms and the external central wiper. Refined front
glass and reflector materials. Information display remains blank.

Added a 412 × 915 portrait capture and responsive front-camera framing. The
six principal captures retain exactly the same 1536 × 934 presets. Protected
source checks confirm unchanged door/window/livery, saloon, cab equipment,
seat and underframe blocks. Protected side pixels and repeated-frame pixels
are asserted unchanged. Game unit checks remain 10/12, with the same two
baseline failures; game mechanics were not changed.

## Remaining differences / next permitted work

- Brow-to-existing-roof joins, panel seams and corner normals remain
  approximate. Refine these using the current photo and actual screenshots.
- Lens optics, gasket cross-sections, thin metal edges, emblem contour and
  aged metal on the coupling are simplified rather than factory CAD.
- Station reflections/illumination are approximated by fixed inspection
  lights; pixel differences from the photo do not measure likeness.
- The equipment visible through the front windows is intentionally preserved
  and differs from the photo. Do not remodel any interior equipment without
  a separate user task. Do not touch passenger side bodywork or doors.
- Coarse photo bounds may all fall inside the diagnostic band while curved
  surfaces or occlusion are still wrong. No 100% or photorealism claim.

To resume, fetch current testing and verify its actual published module hash;
use the successful Actions artifact for that model commit as the baseline.
Publication evidence is in the commit-linked reports, not implied by this
checkpoint. Continue external front-only changes and inspect every PNG.

## Stage 3 supersedes the earlier front-only scope

Latest user request (2026-10-28): rebuild passenger sides, doors, windows,
visible 3D saloon and side roof; freeze the complete front of v84. Keep main
untouched and preserve all existing game mechanics. AI collage is a livery
hint only. Use supplied real photos 5350/5353/5356 and the mechanical manual:
https://81-717.ru/Конспект%20Механика%2081.717.pdf (pages 12–15): four
sliding doorways each side, 1380 mm structural / 1208 mm clear opening,
leaves entering wall pockets. Existing model envelope remains unchanged to
respect the v84 front; it is not a new factory dimensional certification.

v85 establishes immutable v84 source + actual reference/front/mobile PNGs,
source hashes for seven front/cab blocks and runtime same-renderer front
regression. Extends the existing workflow to fourteen views. No front node
or gameplay module is changed. Next: thick corrugated side shells with real
apertures, doors sliding in pockets, transparent glazing with opening lights,
refine existing saloon, smooth side roof and directional ventilation scoops.

## v86: passenger shell, glazing and moving doors

Replaced flat walls with sampled corrugated metal skins and real rounded
apertures. Inner skin is 122 mm behind the outer sheet, with full-depth
window reveals, black gaskets, metal frames, transparent glass and transoms.
Sixteen volumetric leaves have blue outer / cream inner faces, real window
holes, attached chevrons and smooth longitudinal motion in wall pockets.
Structural door width 1.380 m; fully open clear width 1.208 m.

The original first passenger door intersected frozen cab equipment. The
passenger grid was moved 0.350 m aft; all four doorway pitches are retained,
the last window bay is shorter. This fits the locked v84 cab rather than
changing it. These positions remain model layout estimates, not factory CAD.
Cab-side paint is exterior-only: changing double-sided cab materials was
caught by the front regression and rejected. Original inward faces remain.
Removed obsolete inner doorway trim that crossed the new sliding channels;
existing benches were moved just inward for pocket clearance. Full saloon
refinement follows in v87. No gameplay JS modules were modified.

Runtime checks now compare 30/60 Hz door motion and sample five points along
the opening sweep, ray-check every window and every open doorway, and retain
the immutable v84 frontal render plus seven source hashes. Latest local
critical-view run: front zero changed pixels, eight clear windows, eight
clear open doorways and zero pocket contacts at all five sampled poses.
The local four-view smoke run exposed a test reset issue (doors left open
before the repeat capture); fixed by explicitly closing before repeating.
CI always captures all fourteen views; custom short view lists are local only.

## v87: volumetric saloon and perspective checks

Refined the existing longitudinal seating arrangement into forty individually
rounded 3D cushions and backs, seat plinth ventilation, curved blue uprights,
stainless rails, inner window reveals, floor finish, curved ceiling, ceiling
ventilation and diffuse fixtures. Added a thick glazed inter-car end door.
The original cab bench and upholstery remain. Door leaf inner skins and
paint decals use stable depth separation to avoid z-fighting at long range.

Passenger lights/materials use a separate rendering layer. Opaque passenger
surfaces render before the preserved front glazing so transparency composites
in the correct order. QA renders exactly three frames after a camera/door
change, then holds the actual WebGL frame; ordinary interaction stays live.
Camera changes and frame-counter reads are atomic in the test to avoid races.
The viewer now offers all inspection cameras and door control on phones.

Front regression now separates the unchanged front assembly from the new
passenger background visible THROUGH its three transparent panes. Seven
source hashes freeze front geometry, glass, equipment and materials; projected
bounds of every registered front part must exactly equal immutable v84.
Pixel comparison excludes ONLY the triangulated interiors of the three actual
transparent front meshes (not arbitrary rectangles). The complete unmasked
frontal diff is always retained. The v87 full local run: 0 changed exterior
pixels; 174 changed pixels behind glazing, not an exterior edit. This replaces
the overbroad full-frame equality requirement, which rejected new saloon
ceiling visible above the old cab partition. Cab source blocks are unchanged.

Local full run: fourteen views, phone framing, 0 repeated-frame changes,
all five sampled door poses clear, 30/60 Hz travel equal, eight windows and
eight open doorways clear. A real 0.18 m camera shift along the window yields
326304 changed pixels; source geometry and forty extruded seat assemblies
confirm the interior is genuinely three-dimensional. This is not a likeness
score. CI v86 run 40630907974 succeeded; published v86 module hash matched.
Next: replace the remaining old faceted/grey-blue side roof and grilles with
one smooth cobalt shell, formed haunches and opposed ventilation scoops.
