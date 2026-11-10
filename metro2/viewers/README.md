# Universal module viewer — TZ48

Entry: `res://viewers/module_viewer.tscn`. Godot 4.3 / Compatibility / Web without threads. The real game's project.godot and entry point are unchanged; the viewer has a separate staged export.

Menu: full V106, cars 1–4, Uruchye, one current 16 m tunnel section, depot. Nothing is loaded on the initial menu. Static selections use the existing module catalog. The train inspection scene inherits the original V47 train component, with the existing controller/doors/bogies/cab/lighting/passenger equipment. The prior component and camera collision proxies are freed before the next component is instantiated. Train GLBs are released after switching to a static module, verified in the smoke check. No resource cache-ignore copies are used.

## Controls

- Android: one finger rotates 360 degrees; two fingers pinch to zoom. **Перемещать** changes one-finger dragging to pan. Bottom buttons move in all six directions. Portrait and landscape orientations are supported; the interface reflows when the viewport changes.
- Computer: left/right drag rotates, middle drag pans, wheel zooms; WASD/arrows move, Q/E move down/up, Shift speeds movement.
- Train: arrows focus the next/previous wagon; **Снаружи**, **Салон**, **Кабина №1** choose viewpoints. Train movement and its original interactive input are disabled for inspection; no replacement train physics is implemented.
- **FREE: OFF** protects normal camera movement with a swept sphere against temporary conservative collision bounds. Visual meshes/materials are untouched. Bounds can stop the camera early at curved/complex surfaces. **FREE: ON** deliberately allows passing through geometry for diagnostics. Saloon/cab presets explicitly enter FREE mode. Reset returns to protected external/platform/portal inspection.

## Existing decoration failures are isolated, not repaired

The shared train factory now calls its original three decoration operations through a single overridable `_decorate_consist()` hook. In the game the operations and order are identical. Only the viewer subclass overrides the hook with no operations.

The viewer always displays, for train selections:

`ADVERTISING: DISABLED — EXISTING RUNTIME ERROR`

It also displays `WARNING STICKER RESTORE: DISABLED IN VIEWER`. Existing imported warning meshes remain; the problematic runtime restore is skipped. Advertising scripts, assets and coordinates are not edited or removed. No claim of repaired advertising is made.

## Limits kept explicit

- Selecting one wagon still loads **one full four-car V47 train component** and hides the other cars and couplers. The interface states `SINGLE CAR: FULL CONSIST LOADED (V47 DEPENDENCY)`. This avoids creating another train factory or duplicating GLBs. Arrow buttons reuse that same component. Main-menu module changes release it normally.
- The original head-car cab is the cab inspection preset. On a single-car selection, the cab button selects car 1 before showing it. No new rear-cab implementation is created.
- Global viewer lighting belongs to the viewer; all module-local lights, dimensions, meshes and materials are preserved.
- Collision bounds are approximate and can obstruct tight interior movement; FREE mode is the intended diagnostic override. There is no mobile frame-rate guarantee without an on-device test.
- Godot's headless dummy renderer emits existing mesh-storage `Parameter "m" is null` diagnostics. These are separated from script failures in verification. The viewer does not execute the known failing ad/sticker code.

## Separate Web artifact

`tools/prepare_module_viewer.py --output /path/outside/metro2` creates an isolated dependency closure and Web-only preset. Restore the existing four GLBs and archived cab assets first, as in the existing build. The preparation script never edits the real game project.godot or export presets. The Web pack includes `modules/`, `viewers/`, original dependencies and recipe JSON. Exporting the complete pack does not instantiate all its modules; runtime selection remains lazy.

`.github/workflows/metro2-module-viewer-v48.yml` builds only on the V48 branch or explicit manual invocation of that branch. Permissions are read-only for repository contents. It imports, runs the focused smoke check, exports Web once and saves the Web files plus checksum/provenance as a 30-day Actions artifact. Validation logs and the dependency manifest are a second artifact. It has no publishing, release upload, Pages deployment, gh-pages writes or APK step.

Smoke check: `godot --headless --path STAGED_PROJECT --script res://tests/module_viewer_v48_smoke.gd`.
It covers empty-menu startup, all module types, four-car state, wagon focus, saloon/cab entry, mouse-independent camera methods, touch orbit/pinch, normal/free collision behavior, old subtree release and release of the train resource cache when leaving the train.

No TZ49 work is included.

## Portrait and fullscreen update

The staged viewer uses a 480-unit minimum viewport axis with expanding canvas scaling, so the 3D canvas fills portrait and landscape screens without forced landscape letterboxing. Wrapping toolbars, a scrollable module drawer and bottom movement controls adapt on resize, including fullscreen transitions. The native HTML **На весь экран** button requests fullscreen directly from the click gesture and offers an exit button. Browser refusal/unsupported fullscreen is reported in the page; the viewer remains usable inline. Orientation is not locked. Original models, camera gestures and the live game's project settings are unchanged.
