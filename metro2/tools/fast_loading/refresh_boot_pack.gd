extends SceneTree
## Refresh two loader/check scripts in an existing export with native PCKPacker.
## Engine binaries and all visual resources are reused byte-for-byte.
func _initialize() -> void:
    var out := OS.get_environment("FAST_VIEWER_OUTPUT")
    var source := OS.get_environment("FAST_VIEWER_SOURCE")
    var files: Array[String] = []
    _walk("res://",files)
    var temporary := out.path_join("refreshed-boot.pck")
    var pack := PCKPacker.new()
    if pack.pck_start(temporary) != OK:
        quit(1)
        return
    for path in files:
        if path in ["res://viewers/module_pack_loader.gd","res://tools/fast_loading/verify_module_packs.gd","res://viewers/module_pack_loader.gdc","res://viewers/module_pack_loader.gd.remap","res://tools/fast_loading/verify_module_packs.gdc","res://tools/fast_loading/verify_module_packs.gd.remap"]:
            continue
        if pack.add_file(path,path) != OK:
            quit(1)
            return
    for name in ["viewers/module_pack_loader.gd","tools/fast_loading/verify_module_packs.gd"]:
        if pack.add_file("res://"+name,source.path_join(name)) != OK:
            quit(1)
            return
    if pack.flush() != OK:
        quit(1)
        return
    print("BOOT_SCRIPTS_REFRESHED; engine and module packs unchanged")
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
