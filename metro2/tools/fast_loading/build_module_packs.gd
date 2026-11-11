extends SceneTree
## Run with Godot 4.3 after its editor import. Never instantiate a game scene.
var _generated: Dictionary = {}

func _initialize() -> void:
    call_deferred("_build")

func _build() -> void:
    var output := OS.get_environment("FAST_VIEWER_OUTPUT")
    var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://pack-plan.json"))
    if output.is_empty():
        _fail("FAST_VIEWER_OUTPUT is required")
        return
    DirAccess.make_dir_recursive_absolute(output)
    var expanded: Dictionary = {}
    var owners: Dictionary = {}
    for group in plan.groups:
        var files: Dictionary = {}
        for path in plan.groups[group]:
            if not _expand("res://" + str(path), files): return
        expanded[group] = files
        for path in files:
            if not owners.has(path): owners[path] = []
            owners[path].append(group)
    # Generated import artifacts can also be shared; store each virtual path once.
    var shared: Dictionary = expanded.shared
    for path in owners:
        if owners[path].size() > 1:
            for group in owners[path]:
                shared[path] = expanded[group][path]
                if group != "shared": expanded[group].erase(path)
    var manifest := {"format":1,"modules":{},"packs":{},"names":{"v106":"V106","uruchye":"Уручье","tunnel_16m":"Тоннель","depot":"Депо"}}
    var report := {"resources":{},"entries":plan.entries}
    var unique: Dictionary = {}
    for group in expanded:
        var files: Dictionary = expanded[group]
        if files.is_empty(): continue
        var temporary := output.path_join(str(group) + ".pck")
        var packer := PCKPacker.new()
        if packer.pck_start(temporary) != OK:
            _fail("Cannot create " + temporary)
            return
        var ordered: Array = files.keys()
        ordered.sort()
        for path in ordered:
            if unique.has(path):
                _fail("Duplicate resource path " + str(path))
                return
            unique[path] = group
            if packer.add_file(str(path), str(files[path])) != OK:
                _fail("Cannot pack " + str(path))
                return
        if packer.flush() != OK:
            _fail("Cannot finish pack " + str(group))
            return
        var hash := FileAccess.get_sha256(temporary)
        var filename := str(group) + "-" + hash.substr(0,20) + ".pck"
        var final := output.path_join(filename)
        if DirAccess.rename_absolute(temporary, final) != OK:
            _fail("Cannot name pack " + final)
            return
        var file := FileAccess.open(final, FileAccess.READ)
        manifest.packs[group] = {"file":filename,"sha256":hash,"bytes":file.get_length()}
        report.resources[group] = ordered
    for id in plan.entries:
        var requirements: Array = []
        if manifest.packs.has("shared"): requirements.append("shared")
        if manifest.packs.has(id): requirements.append(id)
        manifest.modules[id] = requirements
    _write(output.path_join("module-packs.json"), JSON.stringify(manifest,"  "))
    _write(output.path_join("pack-resources.json"), JSON.stringify(report,"  "))
    print("MODULE_PACKS_READY ", JSON.stringify(manifest))
    quit(0)

func _expand(source: String, files: Dictionary) -> bool:
    if source.ends_with(".import") or source.ends_with(".remap"): return true
    var importer := ConfigFile.new()
    if FileAccess.file_exists(source + ".import"):
        if importer.load(source + ".import") != OK:
            return _fail("Cannot read import mapping " + source)
        var target := str(importer.get_value("remap","path",""))
        if target.is_empty():
            target = str(importer.get_value("remap","path.s3tc",""))
        if target.is_empty():
            return _fail("Missing runtime import target " + source)
        # Use the same remap format as Godot's native exporter. Original media
        # stays unchanged in the repository; the runtime uses its imported resource.
        var remap := "[remap]\n\npath=\"" + target + "\"\n"
        var local := "user://pack-remap-" + source.sha256_text() + ".remap"
        _write(local, remap)
        files[source + ".remap"] = local
        return _add_imported(target,files)
    if not FileAccess.file_exists(source): return _fail("Missing resource " + source)
    files[source] = source
    return true

func _add_imported(path: String, files: Dictionary) -> bool:
    if files.has(path): return true
    if not FileAccess.file_exists(path): return _fail("Missing imported resource " + path)
    files[path] = path
    for dependency in ResourceLoader.get_dependencies(path):
        # 4.3 dependencies may contain uid::type::fallback-path.
        var target: String = str(dependency).split("::")[-1]
        if target.begins_with("res://"):
            if target.begins_with("res://.godot/imported/"):
                if not _add_imported(target,files): return false
            elif not _expand(target,files): return false
    return true

func _write(path: String, data: String) -> void:
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string(data)

func _fail(message: String) -> bool:
    push_error(message)
    quit(1)
    return false
