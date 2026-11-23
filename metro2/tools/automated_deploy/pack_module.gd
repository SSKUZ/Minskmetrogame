extends SceneTree
## Resource import/packaging only. Never instantiate or run a game scene.
var control: Dictionary
var files: Dictionary = {}
var owned: Dictionary = {}
var foreign: Dictionary = {}
var import_texture_cache: Array[Resource] = []

func _initialize() -> void:
    control=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("METRO_DEPLOY_CONTROL")))
    if control.mode=="unpack":
        _unpack()
    elif control.mode=="prepare":
        if _prepare_imported_scenes(): quit(0)
    else:
        _pack()

func _prepare_imported_scenes() -> bool:
    # Resource preparation only. Never instantiate or run a game scene.
    var paths: Array[String] = []
    _walk("res://",paths)
    var reimporting: Dictionary = {}
    if control.mode=="prepare":
        # Raw GLBs copied into this stage need the mandatory editor import first.
        # Do not load their stale cached scenes before external PNG/JPG sources
        # have been imported. Only discard cache files backed by those raw sources.
        for path in paths:
            if path.get_extension().to_lower() not in ["glb","gltf"]: continue
            var mapping := ConfigFile.new()
            if mapping.load(path+".import")!=OK: continue
            var artifact := str(mapping.get_value("remap","path",""))
            if not artifact.begins_with("res://.godot/imported/") or not artifact.ends_with(".scn"): continue
            reimporting[artifact]=true
            if FileAccess.file_exists(artifact):
                if DirAccess.remove_absolute(ProjectSettings.globalize_path(artifact))!=OK:
                    return _fail("Cannot refresh cached scene for saved raw model "+path)
    for path in paths:
        if not path.ends_with(".ctex"): continue
        var texture := ResourceLoader.load(path,"CompressedTexture2D") as CompressedTexture2D
        if texture==null: return _fail("Cannot prepare saved compressed texture "+path)
        import_texture_cache.append(texture)
    for path in paths:
        if not path.ends_with(".remap") and not path.ends_with(".import"): continue
        var source := path.trim_suffix(".remap").trim_suffix(".import")
        if source.get_extension().to_lower() not in ["png","jpg","jpeg","webp","svg"]: continue
        var mapping := ConfigFile.new()
        if mapping.load(path)!=OK: return _fail("Cannot read image mapping "+path)
        var target := str(mapping.get_value("remap","path",mapping.get_value("remap","path.s3tc","")))
        if target.is_empty() or not FileAccess.file_exists(target):
            # A newly staged source image is handled by the editor import below.
            if FileAccess.file_exists(source): continue
            return _fail("Missing saved image target "+source)
        var texture := ResourceLoader.load(source) as Texture2D
        if texture==null: return _fail("Cannot resolve saved image mapping "+source)
        import_texture_cache.append(texture)
    for path in paths:
        if not path.begins_with("res://.godot/imported/") or not path.ends_with(".scn") or reimporting.has(path): continue
        var scene := ResourceLoader.load(path,"PackedScene") as PackedScene
        if scene==null: return _fail("Cannot prepare saved model scene "+path)
        if ResourceSaver.save(scene,path)!=OK: return _fail("Cannot retain imported model scene "+path)
        if not _clear_compressed_texture_hints(path): return false
    return true

func _clear_compressed_texture_hints(path: String) -> bool:
    # ResourceSaver above writes an uncompressed RSRC binary (flags=0).
    # Layout: Godot 4.3 core/io/resource_format_binary.cpp::ResourceLoaderBinary::open.
    # Clear generic image hints for source PNG/JPG mappings as well as direct
    # CTEX paths. Exported model scenes retain their original source-image paths.
    # Keep the encoded string length and all offsets unchanged: geometry,
    # materials, hierarchy, animation data and texture bytes are not rewritten.
    var binary := FileAccess.open(path,FileAccess.READ_WRITE)
    if binary==null: return _fail("Cannot open imported resource metadata "+path)
    if binary.get_buffer(4).get_string_from_ascii()!="RSRC":
        return _fail("Expected uncompressed Godot binary after native save: "+path)
    var endian := binary.get_32()
    binary.get_32() # Legacy real64 field.
    var major := binary.get_32()
    binary.get_32() # Minor version.
    var format_version := binary.get_32()
    if endian!=0 or major!=4 or format_version<4 or format_version>6:
        return _fail("Unsupported imported resource metadata layout: "+path)
    if _binary_string(binary)!="PackedScene":
        return _fail("Expected imported PackedScene: "+path)
    binary.get_64() # Import metadata offset.
    var flags := binary.get_32()
    binary.get_64() # Resource UID field is present even when UID flag is unset.
    if (flags&8)!=0: _binary_string(binary) # Optional script class.
    binary.seek(binary.get_position()+44) # Eleven reserved uint32 fields.
    var string_count := binary.get_32()
    for i in range(string_count): _binary_string(binary)
    var external_count := binary.get_32()
    var corrected := 0
    for i in range(external_count):
        var type_size := binary.get_32()
        var type_position := binary.get_position()
        var type_name := _binary_text(binary.get_buffer(type_size))
        var dependency := _binary_string(binary)
        if (flags&2)!=0: binary.get_64()
        var resume := binary.get_position()
        if type_name=="Texture2D" and dependency.get_extension().to_lower() in ["ctex","png","jpg","jpeg","webp","svg"]:
            binary.seek(type_position)
            # get_unicode_string reads the stored byte count, then parses a
            # NUL-terminated UTF-8 string. A zero-filled fixed-width slot is an
            # empty optional hint; ResourceLoader infers CompressedTexture2D.
            for byte in range(type_size): binary.store_8(0)
            binary.seek(resume)
            corrected+=1
    binary.flush()
    if binary.get_error()!=OK: return _fail("Cannot normalize imported texture hints: "+path)
    binary.close()
    print("NORMALIZED_IMAGE_HINTS ",path," count=",corrected)
    return true

func _binary_string(binary: FileAccess) -> String:
    var length := binary.get_32()
    return _binary_text(binary.get_buffer(length))

func _binary_text(bytes: PackedByteArray) -> String:
    var nul := bytes.find(0)
    return bytes.slice(0,nul).get_string_from_utf8() if nul>=0 else bytes.get_string_from_utf8()

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
    if not _prepare_imported_scenes(): return
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
