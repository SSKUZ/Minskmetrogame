extends SceneTree
## Repackage existing boot without instantiating its scene or touching module packs.
func _initialize() -> void:
    var source := OS.get_environment("BT_SOURCE")
    var output := OS.get_environment("BT_OUTPUT")
    var replacements: Array[String] = ["viewers/module_viewer", "modules/core/module_catalog"]
    var files: Array[String] = []
    _walk("res://",files)
    var pack := PCKPacker.new()
    if pack.pck_start(output) != OK:
        quit(1)
        return
    for path in files:
        var replace := false
        for name in replacements:
            if path in ["res://"+name+".gd","res://"+name+".gdc","res://"+name+".gd.remap"]: replace=true
        if replace: continue
        if pack.add_file(path,path) != OK:
            quit(1)
            return
    for name in replacements:
        if pack.add_file("res://"+name+".gd",source.path_join(name+".gd")) != OK:
            quit(1)
            return
    quit(0 if pack.flush() == OK else 1)

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
