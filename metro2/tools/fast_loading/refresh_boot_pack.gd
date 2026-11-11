extends SceneTree
## Replace the two viewer loader scripts in the existing Godot 4.3 Web boot pack.
func _initialize() -> void:
    var out := OS.get_environment("FAST_VIEWER_OUTPUT")
    var source := OS.get_environment("FAST_VIEWER_SOURCE")
    var replacements: Array[String] = ["viewers/module_viewer", "viewers/module_pack_loader"]
    var files: Array[String] = []
    _walk("res://",files)
    var pack := PCKPacker.new()
    if pack.pck_start(out.path_join("refreshed-boot.pck")) != OK:
        quit(1)
        return
    for path in files:
        var replace := false
        for name in replacements:
            if path in ["res://"+name+".gd", "res://"+name+".gdc", "res://"+name+".gd.remap"]: replace=true
        if replace: continue
        if pack.add_file(path,path) != OK:
            quit(1)
            return
    for name in replacements:
        if pack.add_file("res://"+name+".gd",source.path_join(name+".gd")) != OK:
            quit(1)
            return
    if pack.flush() != OK:
        quit(1)
        return
    print("BOOT_LOADERS_UPDATED")
    quit(0)

func _walk(path: String,files: Array[String]) -> void:
    var directory := DirAccess.open(path)
    directory.include_hidden = true
    directory.list_dir_begin()
    var name := directory.get_next()
    while not name.is_empty():
        if name not in [".",".."]:
            var child := path.path_join(name)
            if directory.current_is_dir(): _walk(child,files)
            else: files.append(child)
        name = directory.get_next()
    directory.list_dir_end()
