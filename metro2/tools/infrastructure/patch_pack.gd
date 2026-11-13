extends SceneTree
## Resource repackaging only. No scene is instantiated.
func _initialize() -> void:
    var input := OS.get_environment("PATCH_INPUT")
    var output := OS.get_environment("PATCH_OUTPUT")
    var source := OS.get_environment("PATCH_SOURCE")
    var mode := OS.get_environment("PATCH_MODE")
    var replacements: Array = JSON.parse_string(OS.get_environment("PATCH_FILES"))
    if not ProjectSettings.load_resource_pack(input,true):
        quit(1)
        return
    var files: Array[String] = []
    _walk("res://",files)
    var pack := PCKPacker.new()
    if mode=="pack" and pack.pck_start(output)!=OK:
        quit(1)
        return
    for path in files:
        var name := path.trim_prefix("res://")
        if name in ["project.godot","export_presets.cfg"]: continue
        var replace := false
        for item in replacements:
            var stem: String=str(item).trim_suffix(".gd")
            if name in [stem+".gd",stem+".gdc",stem+".gd.remap"]: replace=true
        if replace: continue
        if mode=="unpack":
            var target := output.path_join(name)
            DirAccess.make_dir_recursive_absolute(target.get_base_dir())
            var f := FileAccess.open(target,FileAccess.WRITE)
            f.store_buffer(FileAccess.get_file_as_bytes(path))
        elif pack.add_file(path,path)!=OK:
            quit(1)
            return
    for item in replacements:
        var name := str(item)
        if mode=="unpack":
            var target := output.path_join(name)
            DirAccess.make_dir_recursive_absolute(target.get_base_dir())
            DirAccess.copy_absolute(source.path_join(name),target)
        elif pack.add_file("res://"+name,source.path_join(name))!=OK:
            quit(1)
            return
    if mode=="pack" and pack.flush()!=OK:
        quit(1)
        return
    quit(0)

func _walk(path: String,files: Array[String]) -> void:
    var directory := DirAccess.open(path)
    directory.include_hidden=true
    directory.list_dir_begin()
    var name := directory.get_next()
    while not name.is_empty():
        if name not in [".",".."]:
            var child := path.path_join(name)
            if directory.current_is_dir(): _walk(child,files)
            else: files.append(child)
        name=directory.get_next()
    directory.list_dir_end()
