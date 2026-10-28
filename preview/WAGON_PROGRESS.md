# Current scope — stage 5

Current checkpoint: v105 on testing, based on v101 (744a21c). The task now
includes four cars 81-717 / 81-714 / 81-714 / reversed 81-717. Preserve the
existing head-car detail. Work progressively: warning markings, real end
walls, intermediate-car components, consist assembly, then performance and
browser review. Never change main or unrelated gameplay/physics.

## v102 — confirmed warning failure and real 3D repair

Chromium reproduced the v101 texture failure: clearRect was called with two
arguments, while four are required. The broad optional-error handler swallowed
that exception; the verified v101 creates zero warning meshes. Historical
object counters therefore do not establish visibility. Preserved exact v101
source and SHA in tests/reference/wagon-v101.html and stage5-v101.json.
Fixed texture initialization, removed the DOM fallback and broad exception,
enabled depth testing, corrected both-side UV orientation and placed 0.240 x
0.150 m shields 1.2 mm above the flat metal between ribs (Y 1.385–1.535 m).
Each marking is fixed beside the door, not on a sliding leaf or threshold.
One shared texture/material serves all sixteen. Real supplied side photographs
02-5350.jpg, 03-5353.jpg and 04-5356.jpg remain available and were inspected.

Local browser verification: old 18 views and six v88 controls pass; the new
five-view warning check passes with actual yellow pixels at all eight places
on each side, readable unmirrored closeups and an oblique view. No JS/console
errors. The front-equipment protection still has zero changed pixels.
The existing workflow now explicitly runs the visual warning test.

## v103 — reusable classic end wall

Added preview/train-components.js: formed blue outer end sheet with cream
inner lining, a thick hinged central door, two fixed end panes, real clear
glazing, rubber/metal frames, hinges, handle, vertical handrails, threshold,
pressed lower ribs and an automatic coupling with cast outline/openings and
air-hose loops. The head's old incomplete rear bulkhead is replaced once.
The existing curved rear crown closes its top; there is no invented modern
bellows. Source/photo provenance is in tests/reference/stage5-sources.json.
Only the last four ceiling fitting parts are clipped to the inner end line:
the originals projected through the new external sheet. Other saloon and
passenger aperture positions are unchanged.
Local six-view check passes (reference, front, two rear views, full side,
open door), plus the original v88 control set and front-equipment locks.
Actual end screenshots show three glazed openings and exposed coupling; no
ceiling fitting now protrudes through the end. v102 published source/hash
and both-side warning images were separately checked in Chromium.

## v104 — independent 81-714 and component library

Added preview/train-factory.js. The intermediate uses the existing passenger
bay, door and warning builders; a symmetric four-door grid; five window bays
per side; a full passenger floor/ceiling; two real end modules; and 44 actual
volumetric cushions/backs. No cab partition, controls, nose fascia or mirrors
are copied into it. Two bogies/eight wheels use the shared underframe template.
The existing six-seat and two-seat bench modules and four-part vent modules
reuse BufferGeometry/Material/Texture identities. The intermediate is neither
a stretched head nor a fourfold HTML copy. Two independent sliding registries
can already be rebound by cloneCar; assembleConsist accepts variable lengths.

Local intermediate browser check passes seven views, 44 seats, 10 side panes,
16 leaves, 16 visible warning shields, 8 wheels and 2 end walls. All 16 leaves
open and close, with a 1.208 m clear doorway. Both-side warning pixel tests
also pass. Head reference/front/side/open-door/saloon captures retain the
source locks and zero equipment pixel changes. Original calibrated head
construction remains; only its parts are offered through captureBuild.

A live v103 browser check exposed missing sibling-module publication. A
separate testing commit fixes the existing deploy workflow to copy all viewer
assets beside wagon.html; main production is still only read. Local success
was not treated as proof of a working published viewer.

## v105 — four outward-ended cars and real joined couplings

Assembled 81-717 / 81-714 / 81-714 / 81-717 using reusable templates and
shared GPU resources. Car centres are Z 0, 20.006, 40.012 and 60.018 m;
all have X/Y 0 and scale 1. The final head is rotated pi, with its cab outward.
Actual transformed shell bounds give three 0.800001 m gaps. Actual vertices
of opposing cast coupling faces meet to within about 6e-9 m; normals oppose.
The air-loop terminals are joined once, with a separate electrical cable.
No modern sealed inter-car tunnel or duplicate coupling is added.

Added whole-train/tail/inter-car cameras, a single/intermediate/consist selector
and per-car inspection. Original calibrated head presets remain in single-car
QA. Distant train cameras use a 1 m near plane to prevent the old 0.03 m near
plane from causing depth quantisation at 112 m. The reversed cab gets an
isolated, rotated copy of the existing front light rig, leaving the first
cab's calibration unchanged.

Local checks pass: 25 train/intermediate views including phone framing;
actual 64 warning pixel patches across eight individual side images; 168
volumetric seats, 32 wheels, 64 moving leaves; 6 lamps and 3 front panes on
each head, no cab equipment on intermediates; all four door sets open/close.
Original head reference/front/side/saloon/open-door checks retain zero changed
protected equipment pixels. v102, v103 and v104 visual Actions succeeded;
the repaired v103 and independent v104 publications were actually rendered.
Next checkpoint measures and reduces static draw calls without dropping
triangles or changing moving doors/glazing.

All earlier stage-4 and stage-3 notes below are historical.

# Current scope — stage 4

Current candidate: v91, testing only, based on confirmed v88. The current user
authorizes roof/corner/side-sheet restructuring and modest crown correction
to make a coherent body. Preserve the recognizable v84 front equipment and
its source hashes: black fascia, three panes, two red markers, six lamps
(1 + 4 + 1), mirrors, apron, bumper, coupler and blank display. Passenger
apertures, sliding leaves, saloon and cab equipment remain fixed to v88.
Never change main or gameplay modules.

All earlier checkpoints below are historical. Stage 4 supersedes the rigid
structural roof/corner freeze; its measurements, explicit source-lock scope
and latest checkpoint are at the end of this file.

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


## v88: final stage-3 geometry and material checkpoint

Replaced the remaining faceted passenger roof with a dense curved shell that
starts at the exact back station of the locked front roof. Added formed side
haunches, metallic panel seams, closed rear crown, rain edge and 26 curved
ventilation scoops with opposed recessed mouths. The v84 forward roof source
is unchanged. Corrected the winding of positive-side wall triangles to match
the supplied lighting normals (the mismatch made the body almost black).
Added an automated normal/winding agreement check. Corrected the rear belt
and sill centres so neither overhangs the body. Stable exterior cab-paint
depth bias removes long-distance moire without moving cab geometry.

Full local v88 run passed all 14 views and the phone; repeat 0 changed pixels.
Protected front exterior: 0; complete front frame: 185 changed pixels, all
inside actual transparent glazing. Seven pinned source blocks and exact
front projected bounds pass. Door sweeps (five sampled poses), open-door and
window rays: 0 detected contacts/blockages. Counts: eight passenger windows,
sixteen leaves, forty volumetric seats, twenty-six roof scoops; inverted wall
normal samples: zero. v87 Actions run 40632018428 succeeded. The existing
unit suite remains 10/12 with the same two original failures; gameplay JS
and its tests were not modified. Final publication verification follows the
commit; never infer deployment solely from a successful commit.

Remaining limits / next justified work:
- The fixed v84 envelope, 350 mm aft shift of the passenger grid and short
  rear window bay should be checked against a factory drawing before any
  claim of exact production dimensions. The frozen cab was fitted, not moved.
- The roof transition into v84 remains an approximation constrained by the
  protected forward shell. No nose geometry was corrected to fit the sides.
- Window opening-light hardware, door rollers/drive details, panel welds,
  real-world wear and exact upholstery finishes remain simplified.
- Reflections are fixed studio approximations, not a scanned Minsk station.
- Door contact rays sample selected heights/positions, not a continuous
  collision solver. Parallax pixels prove changing rendered perspective,
  not photo likeness. Inspect actual images for acceptance.
- This is the isolated wagon viewer. Game train/passenger/physics modules
  were deliberately left intact, so the new prototype is not automatically
  substituted into the gameplay carriage builder.

To resume: fetch testing, verify the published module hash and successful
commit-linked Actions artifact, retain all v84 front locks, and use the current
14-view artifact as baseline. Do not re-enable the obsolete protected-side
rule; sides and saloon are now the permitted area.

## Stage 4 overrides the earlier rigid roof freeze

User now authorizes coherent body proportions and roof/side transition repair,
while preserving the characteristic front, six lamps (1 + 4 + 1), mirrors,
bumper, coupling, three panes and blank display. Main/gameplay stay untouched.

v88 diagnostics (actual transformed Three.js triangles, not guesses): crown
3.731743 m at the cab versus 3.608750 m over the main body; edge-line drop
300 mm over 550 mm; cab/body exterior-plane difference 14.900 mm per side;
18 mm difference of lower sheet edges; about 12.134 mm between roof and wall
edge lines. Four upper roof surface meshes coexist, including an obsolete
16-vertex roof under the cab. A 9 × 148 X/Z sample grid finds 585 samples
with multiple roof heights, and a 13.729 mm rise/drop over a 20 mm run.
The exterior cab also has two nearly coincident blue skins.

v89 changes diagnostics/cameras only. Immutable v88 source/hash are in
`tests/reference/wagon-v88.html` and `stage4-v88.json`; six original v88
screenshots are regenerated in every workflow artifact using the identical
camera profile. Added quarter-45, roof-overview, cab-roof-join, cab-wall-join;
retained all fourteen previous views. Local seven-view check passed; all six
v89/v88 control-image diffs are zero. Geometry diagnostics are explicitly
"diagnostic-only" for v89, not a visual acceptance of its known defects.

Chosen repair: replace stacked roof sheets/header blocks with one compatible
surface family and a real upper sidewall. Keep the front equipment in place.
First address topology and tangency, then reassess the crown balance against
Uruchcha and real side/oblique photographs; no arbitrary uniform cab scaling.
For v90+ the new continuity checks become mandatory. Existing source locks
on structural roof/header/corner code need an explicit stage-4 scope update;
the immutable v84/v88 historical fixtures and front-equipment locks remain.

## v90: coherent roof, nose corners and real side sheets

Replaced the obsolete inner roof, raised cab roof patch, box headers and
floating exterior cab-paint copies with compatible surfaces. A broad rounded
cross section is shared by the rolled nose brow and the main roof; boundary
positions and analytic tangent planes match. Both render with the same enamel
and lighting. Roof eaves and sidewall tops use one edge curve. The cap and
nose corner footprint are coordinated, removing the old holes and horns.
Cab side sheets are actually extruded between their inner and exterior
planes, with a real rounded access-door aperture and a thick glazed leaf.
Exterior paint is a surface material, not a second nearly coincident wall.
The cab/body outer planes and lower edges now coincide. Passenger aperture,
door-home and saloon source/placement are separately frozen against v88.

The stage-4 source lock explicitly releases the old structural roof/header
and blue corner code as authorized by the current task. Six source regions
still pin fascia, three panes, all front equipment, apron, cab equipment and
front cameras to v84. Their projected geometry is unchanged. Pixel protection
covers the actual facade/equipment triangles, while every whole-image change
(including the authorized blue envelope) is retained in the diffs.

Full local v90 pass: eighteen views, six v88 controls, phone and perspective;
0 equipment pixel changes; 0 repeated-frame changes; 0 door-pocket contacts
at five sampled poses; 0 blocked window/open-door sample rays. Continuity:
roof overlap samples 585 -> 0; maximum rise/drop per 20 mm 13.729 -> 5.520 mm;
roof/brow positional gap 0; tangent-plane difference 0.000034 degrees;
roof/wall boundary gap about 0.00012 mm; cab/body plane mismatch 14.900 -> 0 mm;
lower-body mismatch 18 -> 0 mm; nearly coincident outer cab skins 2 -> 1.
These values are numerical model measurements, not manufacturing tolerances.

Visual review confirms the box-like roof join and surface holes are removed.
The crown heights were intentionally left at about 3.732 / 3.608 m in this
first topology pass. Next: balance only the upper crown against real front
and side photos. Keep fascia, lights, glazing, doors and saloon in place.

## v91: balanced crown and final stage-4 inspection

Compared the coherent v90 shell to the real Uruchcha front and supplied real
side/oblique photographs. Lowered only the blue front crown from 3.731743 to
3.690000 m and raised the main crown from 3.608000 to 3.653999 m (same sampled
main-roof region in both controls). Crown difference is now 36.001 mm rather
than 123.743 mm. No uniform cab scaling was used. Equipment, front-window
positions and all passenger apertures/interior coordinates are unchanged.
The body length remains 19.206 m and nominal width 2.670 m; actual flat side
planes now share width 2.646 m. Front/main eaves transition 3.250 -> 3.170 m
smoothly over 2.483 m instead of the former 300 mm drop over 550 mm.
Reduced the longitudinal roof bow from 8 to 4 mm. The original twenty-six
vent hoods ride the new surface. Four inspection views are also selectable
in the ordinary viewer, with responsive portrait framing.

Full local v91 check: 18 views plus six immutable v88 controls, with all prior
front/interior cameras retained. Roof overlap samples: 0; maximum height
change over a 20 mm run: 5.044 mm; brow/main boundary gap: 0; tangent-plane
angle: 0.000036 degrees; roof/side boundary gap: about 0.00012 mm. Exterior
plane and lower-edge mismatches: 0. One actual exterior cab skin per side;
no inverted structural faces. Added a 50 mm crown-balance regression limit.
Protected front-equipment pixels: 0 changes. Repeat frame: 0 changes.
Doors pass five sampled motion poses, 30/60 Hz timing, pocket and aperture
rays. Window and leaf layout exactly matches v88; saloon and passenger-window
builder source hashes match v88. These are finite geometry checks, not a
continuous collision proof or a measure of photographic likeness.

v89 Actions 40637620275 and v90 Actions 40639300733 succeeded; their separate
publication workflows succeeded and their actual published modules were
fetched, version/hash checked and rendered. Final v91 CI/live evidence is
generated after this commit; do not infer deployment solely from committing.

Remaining limitations: panel welds, small trim/vent edges, finishes and the
underframe remain simplified; the existing interior is deliberately retained.
This is a photo-guided viewer model, not a factory-CAD reconstruction. Fixed
studio lighting does not reproduce a Minsk station. Stage 3's isolated-viewer
scope still applies: no gameplay carriage builder, physics or controls were
replaced. The pre-existing game-unit baseline remains 10/12 with the same
two failures documented above. Inspect actual before/after images as well
as metrics; retain the immutable v88 fixture and front-equipment locks.
