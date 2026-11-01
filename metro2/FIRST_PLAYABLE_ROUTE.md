# Metro 2.0 — first playable route (pre-APK)

Branch: `feature/metro2-first-playable-route`. Main scene: `res://scenes/station_v106_first_playable.tscn`.

- Uses the previously saved 10 m Station Base, four original/LOD1 v106 cars, existing 200 m inbound tunnel and rail geometry.
- Train starts at Z=189.603 m and travels toward decreasing Z; nominal station stop Z=9.603 m (180 m approach).
- Touch controls: hold РАЗГОН / ТОРМОЗ; release for coast; КАМЕРА cycles platform, cab, salon; ДВЕРИ + / −; СБРОС.
- Doors can open only within 5 m of the stop marker, at rest, and only if the existing door-mesh detector validates 64 leaves. When door detection fails, movement still works but door animation is disabled; DO NOT report working doors without runtime verification.
- Station platform width stays 10 m. Original GLBs, geometry and station source branch are untouched.
- Export preset points to the new scene, Android arm64, debug build path `MinskMetro2_FirstPlayable.apk`.

Before APK: run `python metro2/tools/restore_station_v106.py`, import project with Godot 4.3, check script parsing and actual cameras/door discovery, then export debug APK. **No Godot runtime verification has been performed in this branch.**
