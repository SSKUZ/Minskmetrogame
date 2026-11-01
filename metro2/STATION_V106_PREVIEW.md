# Station v106 preview

Run `python metro2/tools/restore_station_v106.py` after checkout, then open `metro2/project.godot` in Godot 4.3. Main scene: `res://scenes/station_v106_preview.tscn`. GLBs are restored from the existing parts; no external or temporary file paths.

Platform: X = -10.37 .. -0.37 m, width 10.00 m, original centre X = -5.37 m. Rail axes: X = 0.992 and -11.732 m. Rail head Y = 0; platform top Y = 1.1805 m. Body clearance at the slab = 25 mm; threshold gap = 61.5 mm.

Car 01 is the saved LOD1. Cars 02–04 are the saved originals. Original GLB orientation is retained (cabs face outward). Unit scale throughout. All cars receive Y = 0.22, Z = 9.603 m. Additional Z placement for cars 02, 03, 04: 0.38151, 0.41951, 0.45751 m, giving at least 20 mm separation between full wagon bounding boxes.

Existing Godot Station Base geometry, materials and lighting are reused. The existing first_playable_route tunnel script is reused along track 1, outside the platform. No gameplay controller is attached to this static preview.

Verification: Godot 4.3 stable headless editor import and scene instantiation passed. Imported meshes: 325 / 157 / 157 / 320. All wagon lower bounds Y = 0; inter-wagon AABB gaps >= 20 mm. Existing exact-slab audit measured 33 mm with the old 1.370 m offset; using 1.362 m gives 25 mm. All four restore checksums passed. Godot mesh LOD generation, shadow meshes and vertex compression are disabled in the saved import settings.
