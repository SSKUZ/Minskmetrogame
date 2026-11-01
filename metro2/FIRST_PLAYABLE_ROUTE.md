# Metro 2.0 — first playable route (pre-APK)

Branch: `feature/metro2-first-playable-route`. Main scene: `res://scenes/station_v106_first_playable.tscn`.

- Uses the previously saved 10 m Station Base, four original/LOD1 v106 cars, existing 200 m inbound tunnel and rail geometry.
- Train starts at Z=329.603 m and travels toward decreasing Z; nominal station stop Z=9.603 m (320 m approach; front beyond the existing tunnel entrance at Z=310 m).
- Touch controls: hold РАЗГОН / ТОРМОЗ; release for coast; КАМЕРА cycles platform, cab, salon; ДВЕРИ + / −; СБРОС.
- Doors can open only within 5 m of the stop marker, at rest, and only if the existing door-mesh detector validates 64 leaves. If door detection fails, movement is blocked.
- Station platform width stays 10 m. Original GLBs, geometry and station source branch are untouched.
- Export preset points to the new scene, Android arm64, debug build path `MinskMetro2_FirstPlayable.apk`.

Before APK: run `python metro2/tools/restore_station_v106.py`, import project with Godot 4.3, check script parsing and actual cameras/door discovery, then export debug APK. 

Final validation (Godot 4.3 stable, headless): four restored wagons, 64 recognized leaves and decals; held throttle, coast, braking after the tunnel and stop within 1 m; station-only opening; actual panel/decal translation and closing; movement blocked while open/closing and when detection fails; three camera transforms and fixed station camera passed. Cab camera moved forward of the opaque cab partition; forward centre ray reaches the transparent windshield. Android hardware touch and rendered camera views require device verification.
