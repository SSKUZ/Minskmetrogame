# Minsk Metro Simulator — architecture and migration

## Current structure
- `index.html`: HTML entry point only.
- `css/style.css`: extracted styling.
- `js/main.js`: legacy Three.js simulation and world construction, loaded as an ES module.
- `js/startup.js`, `js/fallback.js`: startup watchdog and canvas fallback.
- `js/core/CameraManager.js`: viewport restoration, camera selection and resize, look-angle clamps.
- `js/core/GameState.js`: immutable diagnostic snapshot exposed by `window.metroDiagnostics()`. Existing simulation variables remain the authoritative state.
- `js/train/TrainDoors.js`: exterior and carriage door animations.
- `js/passengers/PassengerMotion.js`: nearest door, easing, direction and smooth turning.
- `tests/modules.test.js`: pure JavaScript regression tests.

## Safe development
1. Keep `main` as the live GitHub Pages release. Develop on a feature branch and open a PR.
2. Run `npm run check` before merging. CI also checks pull requests.
3. Manually test all three cameras, INFO, OPEN/CLOSE, movement, passenger boarding and `?preview=station` / `?preview=approach` on a real mobile browser.
4. Do not assume that syntax checks prove the rendered 3D scene works.
5. Avoid duplicate mutable state. Passenger identity and doors should have one source of truth.

## Migration checklist
- [x] Extract styles and script entry points without changing the HTML UI.
- [x] Isolate reusable camera, door and passenger motion functions.
- [x] Add read-only state diagnostics, tests and CI.
- [ ] Separate remaining `js/main.js` into explicit train physics, stations, carriage, passenger lifecycle, audio and UI modules with dependency injection.
- [ ] Add browser integration tests and device performance benchmarks.
- [ ] Merge only after the game is visually and functionally verified.
