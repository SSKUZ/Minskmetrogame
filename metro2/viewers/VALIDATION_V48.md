# TZ48 — standalone module viewer validation

Date: 2026-11-10. Branch: `feature/metro2-universal-viewer-v48`.
Base: `bf6386fb22efd2d7f0174041b130a4f2ab41465b`.
Implementation/export revision: `8fb360410bc2a7084292fccead5c8bcd44f67cdf`.

## Files

| File | Purpose |
| --- | --- |
| `viewers/module_viewer.tscn` | Standalone entry scene |
| `viewers/module_viewer.gd` | Lazy menu, module lifecycle, viewpoints, status |
| `viewers/inspection_camera.gd` | Mouse/touch/pinch/pan/keyboard camera and sphere sweep |
| `viewers/inspection_collision.gd` | Disposable conservative camera obstacles |
| `viewers/v106_inspection.gd` | V47 subclass, isolated decorators, disabled driving/input |
| `viewers/v106_inspection.tscn` | Inherited original V47 train component |
| `tools/prepare_module_viewer.py` | Isolated dependency staging and Web-only preset |
| `tests/module_viewer_v48_smoke.gd` | Focused module, camera and unload checks |
| `.github/workflows/metro2-module-viewer-v48.yml` | Artifact-only Godot 4.3 job |
| `viewers/VALIDATION_V48.md` | This result |

Existing `viewers/README.md` is updated. The only shared gameplay change is an overridable decoration hook in `scripts/v106_four_cars_preview.gd`; its original three operations/order remain identical for all existing game scenes. Existing modules, assets, original scenes, project.godot, export presets and existing workflows are unchanged.

## Checks — PASS

Godot **4.3.stable.official.77dcf97d8**. Local final-source smoke: `V48_RESULT PASS failures=[]`, exit 0. CI also imports the staged project and runs the same checks before exporting.

- Initial menu creates no game module. Station loads without train resources.
- Four-car V106, original cab, shared validated door system initialize. Original train movement/input is disabled only in inspection.
- All four wagon focus selections, individual-wagon fallback, saloon and head-cab views work.
- Orbit/zoom and synthetic Android one-finger orbit/two-finger pinch alter the camera as expected. Positions remain finite.
- The normal swept-sphere camera cannot cross a test obstacle; FREE mode deliberately can.
- Station, a single current 16 m tunnel section and depot create independently.
- Previous scene weak references become null before the next module is created; train resources leave the ResourceLoader cache after leaving the train. Only one game module is active.
- No script errors or advertising/sticker runtime errors occur in the viewer check. Existing Godot dummy-renderer mesh-storage `Parameter "m" is null` diagnostics remain in headless logs and do not terminate the viewer.
- Five original GLBs (four cars plus cab) match their restored original bytes. No duplicate model resource paths are introduced. Stage contains the `modules/` and `viewers/` dependency closure (80 files in the exported revision).
- Original gameplay code is identical after inlining the new hook. `git diff --check` is clean.

## Explicit limits

Single-car selection still loads one full four-car V47 component and hides the other cars; the interface discloses this dependency. No second train implementation is created. The cab preset is the original head-car cab; selecting it from another single-car view selects car 1.

The viewer disables only the known failing ad/sticker restoration calls. Its train status is exactly `ADVERTISING: DISABLED — EXISTING RUNTIME ERROR`; warning-sticker restoration also has a visible disabled status. Scripts, artwork and coordinates are preserved; advertising has not been fixed.

Camera obstacle bounds are conservative rather than exact triangle collision, and may stop movement early. Interior presets visibly enable FREE mode. Module-local geometry/materials/lights are unchanged; the viewer supplies its global inspection environment. The interface targets landscape mobile Web. Physical Samsung S24+ browser behavior, frame rate and visual quality have not been tested on the device.

The standalone Web pack contains all selectable assets for one initial download; only the chosen component is instantiated/decoded as a scene. There is no new network streaming system.

No APK, release upload, Pages deployment, gh-pages write, live-game replacement or TZ49 work occurred.

## Web artifact — READY, not published

[Successful Actions run 42799774204](https://github.com/SSKUZ/Minskmetrogame/actions/runs/42799774204): import/check/export/upload all succeeded. CI result: `V48_RESULT PASS failures=[]`.

[Standalone Web ZIP](https://github.com/SSKUZ/Minskmetrogame/actions/runs/42799774204/artifacts/13755179978):

- Artifact: `metro2-module-viewer-v48-8fb360410bc2a7084292fccead5c8bcd44f67cdf`.
- ZIP size: 41,025,032 bytes; retention: 30 days.
- GitHub artifact SHA-256: `9804a80222bc0391f01310ecc20ad40880b4f5a11f3b01552ae964aee02cc8ac`.
- Contains standalone `index.html`, JavaScript, WebAssembly, game pack, `build-info.json` and `SHA256SUMS`. The workflow verified nonempty HTML/PCK/WASM before upload.
- Build source is the implementation/export revision above; subsequent report-only changes do not change the viewer implementation.
- This is a downloadable build, not a published live URL. Serve the extracted directory over HTTP to run it.

[CI logs and dependency manifest](https://github.com/SSKUZ/Minskmetrogame/actions/runs/42799774204/artifacts/13756215225) are saved separately. Artifact size: 9,203 bytes.
