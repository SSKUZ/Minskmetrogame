extends SceneTree
# Run with Godot 4.3 after extracting Alpha01 APK resources into this Godot project.
# godot --headless --path metro2 --script res://tools/recover_v106_imported_scn.gd
# The original .glb hashes cannot be reproduced by exporting imported Godot scenes.
const ORIGINAL_IMPORTS := [
    "res://.godot/imported/v106_car_01.glb-1708ec012460fac11c4ba0cfc7b79616.scn",
    "res://.godot/imported/v106_car_02.glb-f7a389cf7fa528b6391bbbc271da6cce.scn",
    "res://.godot/imported/v106_car_03.glb-d7e2778ad4baeaa4581f14d3ef008b98.scn",
    "res://.godot/imported/v106_car_04.glb-58654758a2bff31fc31e8dbdffa5cdd1.scn",
]
func _initialize() -> void:
    var output := "res://assets/v106_recovered"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    for i in range(ORIGINAL_IMPORTS.size()):
        var source: PackedScene = load(ORIGINAL_IMPORTS[i]) as PackedScene
        if source == null:
            push_error("Missing APK-imported scene: " + ORIGINAL_IMPORTS[i])
            quit(1)
            return
        var node := source.instantiate()
        if not node is Node3D:
            push_error("Imported scene root is not Node3D: " + ORIGINAL_IMPORTS[i])
            quit(1)
            return
        var document := GLTFDocument.new()
        var state := GLTFState.new()
        var err := document.append_from_scene(node, state)
        if err != OK:
            push_error("append_from_scene failed for car %d: %d" % [i+1, err])
            quit(1)
            return
        var path := "%s/v106_car_%02d_recovered.glb" % [output, i+1]
        err = document.write_to_filesystem(state, path)
        if err != OK:
            push_error("GLB write failed: " + path + " code " + str(err))
            quit(1)
            return
        print("EXPORTED ", path)
        node.free()
    quit(0)
