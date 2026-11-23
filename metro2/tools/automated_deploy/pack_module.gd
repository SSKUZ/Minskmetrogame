extends SceneTree
## Resource import/packaging only. Never instantiate or run a game scene.
var control: Dictionary
var files: Dictionary = {}
var owned: Dictionary = {}
var foreign: Dictionary = {}

func _initialize() -> void:
    control=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("METRO_DEPLOY_CONTROL")))
    if control.mode=="unpack":
        _unpack()
    else:
        _pack()

func _unpack() -> void:
    if not ProjectSettings.load_resource_pack(str(control.pack),true):
        _fail("Cannot mount published dependency pack")
        return
    var paths: Array[String]=[]
    _walk("res://",paths)
    var kept: Array[String]=[]
    for path in paths:
        var relative: String=path.trim_prefix("res://")
        if relative in ["project.godot","export_presets.cfg"]:continue
        if ".." in relative.split("/"):
            _fail("Unsafe resource-pack path")
            return
        var target: String=str(control.destination).path_join(relative)
        DirAccess.make_dir_recursive_absolute(target.get_base_dir())
        var output := FileAccess.open(target,FileAccess.WRITE)
        if output==null:
            _fail("Cannot stage published resource "+path)
            return
        output.store_buffer(FileAccess.get_file_as_bytes(path))
        kept.append(path)
    _write(str(control.listing),JSON.stringify(kept))
    quit(0)

func _pack() -> void:
    for item in control.base_files:owned[str(item)]=true
    for item in control.foreign_files:foreign[str(item)]=true
    var removed: Dictionary={}
    for item in control.sources+control.deleted:
        var path := "res://"+str(item)
        removed[path+".remap"]=true
        if path.ends_with(".gd"):removed[path.trim_suffix(".gd")+".gdc"]=true
    for item in control.deleted:
        removed["res://"+str(item)]=true
        removed["res://"+str(item)+".import"]=true
    for item in control.base_files:
        var path := str(item)
        if removed.has(path):continue
        if not bool(control.boot) and path in ["res://project.binary","res://.godot/global_script_class_cache.cfg","res://.godot/uid_cache.bin"]:continue
        if FileAccess.file_exists(path):files[path]=path
    for item in control.sources:
        if not _expand("res://"+str(item)):return
    if bool(control.boot) and FileAccess.file_exists("res://.godot/global_script_class_cache.cfg"):
        # Keep optional-pack class_name registrations in the actual boot cache.
        files["res://.godot/global_script_class_cache.cfg"]="res://.godot/global_script_class_cache.cfg"
    # Unchanged dependencies stay in their existing required pack.
    for path in files.keys():
        if foreign.has(path) and not owned.has(path):files.erase(path)
    var packer := PCKPacker.new()
    if packer.pck_start(str(control.output))!=OK:
        _fail("Cannot create module pack")
        return
    var paths: Array=files.keys();paths.sort()
    for path in paths:
        if packer.add_file(str(path),str(files[path]))!=OK:
            _fail("Cannot package "+str(path))
            return
    if packer.flush()!=OK:
        _fail("Cannot finish module pack")
        return
    _write(str(control.resources),JSON.stringify(paths))
    quit(0)

func _expand(source: String) -> bool:
    if source.ends_with(".import") or source.ends_with(".remap"):return true
    var importer := ConfigFile.new()
    if FileAccess.file_exists(source+".import"):
        if importer.load(source+".import")!=OK:return _fail("Cannot read import mapping "+source)
        var target := str(importer.get_value("remap","path",""))
        if target.is_empty():target=str(importer.get_value("remap","path.s3tc",""))
        if target.is_empty():return _fail("Missing import target "+source)
        var remap := "user://metro-auto-"+source.sha256_text()+".remap"
        _write(remap,"[remap]\n\npath=\""+target+"\"\n")
        files[source+".remap"]=remap
        files[source+".import"]=source+".import"
        if not _imported(target):return false
        if source.ends_with(".glb") or source.ends_with(".gltf"):
            # Godot 4.3 embedded GLTF images can be absent from external dependencies.
            var stem := source.get_file().get_basename()
            for image in DirAccess.get_files_at(source.get_base_dir()):
                if str(image).begins_with(stem+"_") and str(image).get_extension() in ["png","jpg","jpeg","webp"]:
                    if not _expand(source.get_base_dir().path_join(image)):return false
            for artifact in DirAccess.get_files_at("res://.godot/imported"):
                if str(artifact).begins_with(stem+"_") and str(artifact).ends_with(".ctex"):
                    if not _imported("res://.godot/imported/"+str(artifact)):return false
        return true
    if not FileAccess.file_exists(source):return _fail("Missing staged source "+source)
    files[source]=source
    return true

func _imported(path: String) -> bool:
    if files.has(path):return true
    if not FileAccess.file_exists(path):return _fail("Missing imported artifact "+path)
    files[path]=path
    for variant in [".s3tc.ctex",".bptc.ctex",".etc2.ctex",".astc.ctex"]:
        if path.ends_with(variant):
            var canonical := path.trim_suffix(variant)+".ctex"
            if not FileAccess.file_exists(canonical):
                var alias := "user://metro-auto-alias-"+canonical.sha256_text()+".remap"
                _write(alias,"[remap]\n\npath=\""+path+"\"\n")
                files[canonical+".remap"]=alias
    for dependency in ResourceLoader.get_dependencies(path):
        var target: String=str(dependency).split("::")[-1]
        if target.begins_with("res://.godot/imported/"):
            if not _imported(target):return false
        elif target.begins_with("res://"):
            if files.has(target) or files.has(target+".remap"):continue
            if FileAccess.file_exists(target):
                if not _expand(target):return false
            elif FileAccess.file_exists(target+".remap"):
                files[target+".remap"]=target+".remap"
                var mapping := ConfigFile.new()
                if mapping.load(target+".remap")!=OK:return _fail("Cannot read existing remap "+target)
                if not _imported(str(mapping.get_value("remap","path",""))):return false
            else:return _fail("Unresolved imported dependency "+target)
    return true

func _walk(path: String,paths: Array[String]) -> void:
    var directory := DirAccess.open(path)
    if directory==null:return
    directory.include_hidden=true
    directory.list_dir_begin()
    var name := directory.get_next()
    while not name.is_empty():
        if name not in [".",".."]:
            var child := path.path_join(name)
            if directory.current_is_dir():_walk(child,paths)
            else:paths.append(child)
        name=directory.get_next()
    directory.list_dir_end()

func _write(path: String,data: String) -> void:
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var file := FileAccess.open(path,FileAccess.WRITE)
    if file==null:
        _fail("Cannot write packaging metadata")
        return
    file.store_string(data)

func _fail(message: String) -> bool:
    push_error(message)
    quit(1)
    return false
