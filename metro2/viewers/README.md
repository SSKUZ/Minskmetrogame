# Universal module viewer — current joystick navigation

Entry: `res://viewers/module_viewer.tscn`. Godot 4.3 / Compatibility / single-thread Web. Standalone viewer publication: `metro2/module-viewer-v48/`. The actual game entry point, modules and original resources are unchanged.

## Phone controls

- Bottom-left analog joystick: forward/backward and sideways relative to the camera. Looking upward/downward and moving forward flies upward/downward. Deflection controls speed; releasing stops immediately.
- One finger outside the joystick: turn the camera in place, through 360 degrees horizontally.
- Two fingers outside the joystick: pinch to move closer/farther along the viewing direction.
- The joystick captures only its own pointer. A second finger can turn the camera while the joystick remains held; the joystick pointer never becomes part of a pinch.
- Rotation/fullscreen resize, loss of window focus, module changes and reset cancel held joystick input.
- Navigation always uses free flight, including through geometry. There are no movement buttons, pan switches or FREE ON/OFF switches, and no camera collision-proxy scene is generated.
- Portrait and landscape layouts are supported. The native HTML fullscreen button requires a user click. Browser refusal is displayed without affecting inline viewing.

Computer: joystick supports mouse dragging; left/right mouse drag turns, wheel zooms; WASD/arrows move, Q/E move vertically, Shift increases speed. The menu/reset and train viewpoint buttons remain.

## Modules and preservation

The initial menu has no instantiated game module. Static selections use the existing catalog. The train scene inherits the V47 component with original cars, cab, bogies, doors, lights and passenger equipment. Its driving input is disabled only for inspection. Old module subtrees and train resources are released when selecting another module.

Single-car selection still loads one full V47 consist and hides the other cars, disclosed in the interface. The cab preset is the original head-car cab. No second train implementation or duplicate GLBs are created.

The existing failing ad/sticker restoration calls remain isolated only in the inspection subclass. The train status remains exactly `ADVERTISING: DISABLED — EXISTING RUNTIME ERROR`; warning-sticker restoration is also identified as disabled. Scripts, artwork and original coordinates are preserved. Advertising is not repaired by this task.

## Build, checks and publication

`tools/prepare_module_viewer.py` creates an isolated dependency closure and expanding 480-unit minimum-axis viewport. `tools/finalize_viewer_web.py` adds the native fullscreen button to the exported HTML.

The branch-scoped workflow verifies the module smoke check, both orientations and synthetic multitouch joystick/look/pinch/reset behavior, then exports Web once. It stages a publication commit without moving gh-pages; the final ref update is performed only after verifying the diff is confined to the viewer directory and every other site file is preserved. Actual S24+ behavior still requires an on-device check.

No main-game physics, source models, local module lighting, APK or subsequent project stage is changed. Existing headless dummy-renderer mesh-storage diagnostics are distinct from script failures.
