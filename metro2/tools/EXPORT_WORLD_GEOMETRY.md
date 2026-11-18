# Universal geometry exporter — Godot 4.3

Run from the repository root with Godot 4.3 installed. Use an **absolute** output path, outside the repository when possible.

```sh
godot --headless --path metro2 --script res://tools/export_world_geometry.gd -- --scene res://scenes/stations/uruchye_station_module.tscn --out /tmp/metro-exports/uruchye.glb
godot --headless --path metro2 --script res://tools/export_world_geometry.gd -- --scene res://scenes/depot/depot_world_module.tscn --out /tmp/metro-exports/depot.glb
```

The script instantiates the scene, waits two frames for procedural geometry, expands MultiMesh instances, collects MeshInstance3D meshes, exports a GLB and a JSON report. Does not alter the source scenes. A flat PBR approximation replaces Godot-only shader materials; the report lists replacements. Does **not** bake shader textures, terrain effects, lights, collisions, animation, scripts or gameplay. Large modules may be expensive to export and should be split into chunks.

**Status:** implementation saved in GitHub; not executed in Godot or imported into Roblox Studio yet. GLB is an interchange format; convert/validate through a supported Roblox import pipeline (e.g. Blender to FBX) before claiming compatibility. Verify dimensions, normals, UV, material appearance, mesh limits and collisions in Roblox Studio. Keep generated GLB/FBX outside git until sizes and licensing are checked.

Every future module should be independently loadable and exportable. Record source revision, mesh counts, shader substitutions, export file hashes and Roblox import results for release readiness.
