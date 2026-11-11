extends SceneTree
## Isolated packaged-resource check only: no scene instantiation or rendering.
func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    if load("res://viewers/module_viewer.tscn") == null:
        _fail("Boot interface dependencies missing")
        return
    var directory := OS.get_environment("FAST_VIEWER_OUTPUT")
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("module-packs.json")))
    var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("pack-resources.json")))
    # The boot export must not contain any optional module or original model.
    for id in report.entries:
        if ResourceLoader.exists("res://" + str(report.entries[id])):
            _fail("Optional scene leaked into boot: " + str(id))
            return
    var mounted: Dictionary = {}
    var textures: Dictionary = {}
    for id in manifest.modules:
        for group in manifest.modules[id]:
            var path := directory.path_join(str(manifest.packs[group].file))
            if FileAccess.get_sha256(path) != str(manifest.packs[group].sha256):
                _fail("Pack checksum mismatch: " + str(group))
                return
            if not mounted.has(group) and not ProjectSettings.load_resource_pack(path,false):
                _fail("Pack mount failed: " + str(group))
                return
            mounted[group] = true
            for source in manifest.packs[group].get("warmup", []):
                if not textures.has(source):
                    var texture := load(str(source)) as Texture2D
                    if texture == null:
                        _fail("Texture dependency missing: " + str(source))
                        return
                    textures[source] = texture
        if load("res://" + str(report.entries[id])) == null:
            _fail("Scene dependencies missing: " + str(id))
            return
        print("OPTIONAL_MODULE_RESOURCE_OK ", id)
    for source in ["res://assets/v106_lod1/v106_car01_lod1_mesh289_normals_fixed.glb", "res://assets/v106_original/car02/v106_car_02.glb", "res://assets/v106_original/car03/v106_car_03.glb", "res://assets/v106_original/car04/v106_car_04.glb"]:
        if load(source) == null:
            _fail("Model dependency missing: " + source)
            return
    # Exercise V50's dynamic artwork dependencies without opening the train.
    var mounts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/saloon_v49/mounts.json"))
    for car in mounts.values():
        for mount in car.mounts:
            if load(str(mount.asset)) == null:
                _fail("Dynamic resource missing: " + str(mount.asset))
                return
    print("PACK_LOADING_OK: boot isolated; four modules and dynamic resources resolve")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
