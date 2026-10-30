# Metro 2.0 — Web testing track (P1)

**Status: configuration committed; Godot Web export and browser execution NOT YET VERIFIED.**

The **same Godot 4 project** is used for Android and Web. The project selects the `gl_compatibility` renderer because Godot 4 Web builds rely on WebGL 2 / Compatibility. This is a test preview, not a replacement for native Android acceptance.

## Export and preview

Prerequisites: installed Godot 4.x with matching export templates. Run from the project folder:

```bash
bash tools/export_web.sh
python3 tools/serve_web.py
```

Open `http://127.0.0.1:8000/` in a WebGL 2-capable browser. Do not use `file://`. To view from a separate phone/tablet, use an approved HTTPS hosting service or explicitly configure a LAN-accessible server with appropriate security; the included local server listens on localhost only.

## Test matrix

- Chromium desktop: startup, render, mouse drag, FPS and errors.
- Chrome Android (Honor Pad X9): startup, touch orbit, pinch zoom, FPS, WebGL context loss/recovery.
- Native APK on Honor Pad X9: **separate** 15-minute FPS/frame-time/memory/thermal test.
- Regression: exported Web and Android builds must use the same source revision and be independently validated.

## Known limits

- Web export requires WebGL 2 support; WebGL 1-only browsers are not supported.
- Browser GPU/memory behavior, threading and frame pacing differ from Android; Web FPS cannot be substituted for native Android measurements.
- Web export preset uses single-threaded defaults and disables PWA. No COOP/COEP requirement is assumed for this minimal single-threaded prototype.
- Browser playback and mobile browsers may require performance compromises or fallback content.
- No hosted preview URL exists until a build is generated and deployed.
