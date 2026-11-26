extends Node
## Loose, hash-addressed resources: unlike mounted PCKs these can be released on Web.
## File names in scene dependencies are user:// paths, identical in CI and runtime.
const Budget = preload("res://modules/line/build_budget.gd")
const MAX_RESIDENT_BYTES := 192 * 1024 * 1024
var _users: Dictionary = {}
var _files: Dictionary = {}
var _pending: Dictionary = {}
var _decoded: Dictionary = {}
var _leases: Dictionary = {}
var _consumer_tokens: Dictionary = {}
var _lease_serial := 0
var _resident_bytes := 0
const MAX_ARCHIVE_CACHE_BYTES := 24 * 1024 * 1024
var _archive_cache: Dictionary={}
var _archive_order: Array[String]=[]
var _archive_bytes := 0
var error_message := ""
signal progress(consumer_id: int, message: String)

static func shared(consumer: Node) -> Node:
    var root := consumer.get_tree().root
    var service := root.get_node_or_null("MetroStaticResourceStore")
    if service==null:
        service=load("res://modules/line/static_resource_store.gd").new()
        service.name="MetroStaticResourceStore"
        root.add_child(service)
    return service

func instantiate_chunk(description: Dictionary, consumer: Node) -> Node3D:
    error_message=""
    var reference: WeakRef=weakref(consumer)
    var reserved: Array[String]=[]
    for file in description.files+description.get("textures",[]):
        var path: String=str(file.path)
        if not _users.has(path):
            _trim_archives(int(file.bytes))
            if _resident_bytes+_archive_bytes+int(file.bytes)>MAX_RESIDENT_BYTES:
                error_message="Недостаточно свободной памяти для геометрии"
                _release_paths(reserved)
                return null
            _files[path]=file
            _resident_bytes+=int(file.bytes)
        _users[path]=int(_users.get(path,0))+1
        reserved.append(path)
    if not await _ensure_chunk(description,reference):
        _release_paths(reserved)
        return null
    if not _alive(reference):
        _release_paths(reserved)
        return null
    # Prepare one mesh/material/texture resource at a time. Scene parsing then
    # reuses these decoded resources instead of decoding an entire station graph.
    var decoding=Budget.new(self,1500)
    # Resolve source images without generic Texture2D binary hints first, as
    # required by Godot 4.3 exported CTEX mappings. Keep references only for leases.
    for file in description.get("textures",[])+description.files:
        var path: String=str(file.path)
        if path==str(description.scene) or _decoded.has(path): continue
        await decoding.checkpoint()
        if not _alive(reference):
            _release_paths(reserved)
            return null
        var resource := ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REUSE)
        if resource==null:
            error_message="Не удалось подготовить ресурс геометрии: "+path
            _release_paths(reserved)
            return null
        _decoded[path]=resource
    # One small prepared scene per frame; resource parsing cannot be preempted on Web.
    await get_tree().process_frame
    if not _alive(reference):
        _release_paths(reserved)
        return null
    var scene := ResourceLoader.load(str(description.scene),"PackedScene",ResourceLoader.CACHE_MODE_REUSE) as PackedScene
    var node: Node3D=scene.instantiate() as Node3D if scene!=null else null
    scene=null
    if node==null:
        error_message="Не удалось прочитать подготовленную геометрию: "+str(description.scene)
        _release_paths(reserved)
        return null
    var consumer_id: int=consumer.get_instance_id()
    if not _consumer_tokens.has(consumer_id):
        _consumer_tokens[consumer_id]=[]
        consumer.tree_exiting.connect(_release_consumer.bind(consumer_id),CONNECT_ONE_SHOT)
    _lease_serial+=1
    _leases[_lease_serial]={"paths":reserved,"consumer":consumer_id}
    _consumer_tokens[consumer_id].append(_lease_serial)
    node.set_meta("static_resource_token",_lease_serial)
    return node

func _ensure_chunk(description: Dictionary, reference: WeakRef) -> bool:
    for archive in description.archives:
        var files: Array=[]
        for file in description.files:
            if str(file.archive)==str(archive.file): files.append(file)
        if not await _ensure_archive(archive,files,reference): return false
    return true

func _ensure_archive(archive: Dictionary, files: Array, reference: WeakRef) -> bool:
    var key := "archive:"+str(archive.sha256)
    var waiting_since: int=Time.get_ticks_msec()
    while _pending.has(key):
        await get_tree().process_frame
        if not _alive(reference): return false
        if Time.get_ticks_msec()-waiting_since>130000:
            error_message="Не завершена совместная загрузка архива: "+str(archive.file)
            return false
    if not _alive(reference): return false
    var missing := false
    for file in files:
        if not FileAccess.file_exists(str(file.path)): missing=true;break
    if not missing: return true
    if not OS.has_feature("web"):
        error_message="Подготовленный участок отсутствует"
        return false
    _pending[key]=true
    var bytes: PackedByteArray=await _download(archive,reference)
    var success: bool=bytes.size()==int(archive.bytes) and not bytes.is_empty()
    if success:
        var writing=Budget.new(self,1500)
        for file in files:
            var path: String=str(file.path)
            var file_wait: int=Time.get_ticks_msec()
            while _pending.has(path):
                await get_tree().process_frame
                if not _alive(reference): break
                if Time.get_ticks_msec()-file_wait>130000:
                    error_message="Не завершена запись ресурса: "+path
                    success=false
                    break
            if not success: break
            if not _alive(reference): success=false;break
            if FileAccess.file_exists(path): continue
            var offset: int=int(file.offset)
            var length: int=int(file.bytes)
            if offset<0 or length<0 or offset+length>bytes.size(): success=false;break
            _pending[path]=true
            DirAccess.make_dir_recursive_absolute(path.get_base_dir())
            var partial := path+".partial"
            var output := FileAccess.open(partial,FileAccess.WRITE)
            if output==null:
                _pending.erase(path)
                success=false
                break
            for position in range(offset,offset+length,262144):
                output.store_buffer(bytes.slice(position,mini(position+262144,offset+length)))
                await writing.checkpoint()
                if not _alive(reference): break
            success=_alive(reference) and output.get_error()==OK
            output.close()
            if success: success=DirAccess.rename_absolute(partial,path)==OK
            if not success and FileAccess.file_exists(partial): DirAccess.remove_absolute(partial)
            _pending.erase(path)
            if not success: break
    _pending.erase(key)
    if not success and error_message.is_empty(): error_message="Не удалось распаковать архив: "+str(archive.file)
    return success

func _download(info: Dictionary, reference: WeakRef) -> PackedByteArray:
    var cache_key: String=str(info.sha256)
    if _archive_cache.has(cache_key):
        _archive_order.erase(cache_key)
        _archive_order.append(cache_key)
        return _archive_cache[cache_key]
    var request := HTTPRequest.new()
    var completed: Array=[]
    request.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray): completed.append([result,code,headers,body]))
    request.accept_gzip=false
    request.timeout=40.0
    request.body_size_limit=int(info.bytes)+1024
    add_child(request)
    var base: String=str(JavaScriptBridge.eval("new URL('.', window.location.href).href",true))
    var downloaded := PackedByteArray()
    for attempt in range(3):
        if not _alive(reference): break
        completed.clear()
        if request.request(base+str(info.file))!=OK:
            error_message="Не удалось запросить архив: "+str(info.file)
            continue
        var last_bytes: int=-1
        var last_change: int=Time.get_ticks_msec()
        while completed.is_empty() and _alive(reference):
            var received: int=request.get_downloaded_bytes()
            if received!=last_bytes:
                last_bytes=received
                last_change=Time.get_ticks_msec()
                var node: Node=reference.get_ref() as Node
                progress.emit(node.get_instance_id(),"Геометрия: %.1f / %.1f МБ" % [float(received)/1048576.0,float(info.bytes)/1048576.0])
            if Time.get_ticks_msec()-last_change>20000:
                error_message="Нет данных при загрузке архива: "+str(info.file)
                break
            await get_tree().process_frame
        if completed.is_empty():
            request.cancel_request()
            if not _alive(reference): break
            continue
        var reply: Array=completed[0]
        if not _alive(reference): break
        if int(reply[0])!=HTTPRequest.RESULT_SUCCESS or int(reply[1])!=200:
            error_message="Архив "+str(info.file)+" · HTTP %d, код %d" % [int(reply[1]),int(reply[0])]
            continue
        var bytes: PackedByteArray=reply[3]
        if bytes.size()!=int(info.bytes): continue
        var digest := HashingContext.new()
        digest.start(HashingContext.HASH_SHA256)
        var hashing=Budget.new(self,1500)
        for offset in range(0,bytes.size(),262144):
            digest.update(bytes.slice(offset,mini(offset+262144,bytes.size())))
            await hashing.checkpoint()
            if not _alive(reference): break
        if not _alive(reference): break
        if digest.finish().hex_encode()!=str(info.sha256): continue
        downloaded=bytes
        break
    request.queue_free()
    if downloaded.is_empty():
        if error_message.is_empty(): error_message="Не удалось загрузить архив: "+str(info.file)
    # Station fragments also share archive dependencies. Use the same bounded
    # cache as tunnel groups instead of downloading their archive repeatedly.
    elif downloaded.size()<=MAX_ARCHIVE_CACHE_BYTES:
        _trim_archives(downloaded.size())
        if _resident_bytes+_archive_bytes+downloaded.size()<=MAX_RESIDENT_BYTES:
            _archive_cache[cache_key]=downloaded
            _archive_order.append(cache_key)
            _archive_bytes+=downloaded.size()
    return downloaded

func _trim_archives(incoming: int) -> void:
    while not _archive_order.is_empty() and (_archive_bytes+incoming>MAX_ARCHIVE_CACHE_BYTES or _resident_bytes+_archive_bytes+incoming>MAX_RESIDENT_BYTES):
        var key: String=_archive_order.pop_front()
        _archive_bytes-=(_archive_cache[key] as PackedByteArray).size()
        _archive_cache.erase(key)

func release_chunk(node: Node) -> void:
    if not is_instance_valid(node): return
    release_token(int(node.get_meta("static_resource_token",0)))
    if node.has_meta("static_resource_token"): node.remove_meta("static_resource_token")

func release_token(token: int) -> void:
    if not _leases.has(token): return
    var lease: Dictionary=_leases[token]
    _leases.erase(token)
    if _consumer_tokens.has(lease.consumer): _consumer_tokens[lease.consumer].erase(token)
    _release_paths(lease.paths)

func _release_consumer(consumer_id: int) -> void:
    for token in _consumer_tokens.get(consumer_id,[]).duplicate(): release_token(int(token))
    _consumer_tokens.erase(consumer_id)
    if _consumer_tokens.is_empty():
        _archive_cache.clear()
        _archive_order.clear()
        _archive_bytes=0

func _release_paths(paths: Array) -> void:
    for path in paths:
        var count: int=int(_users.get(path,0))-1
        if count>0:
            _users[path]=count
            continue
        _users.erase(path)
        if _files.has(path): _resident_bytes-=int(_files[path].bytes)
        _files.erase(path)
        _decoded.erase(path)
        # Scene instances retain decoded Resources until disposed. Godot's cache
        # is weak; neither this service nor a PCK retains the discarded payload.
        if str(path).begins_with("user://metro-static/") and FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func _alive(reference: WeakRef) -> bool:
    var node: Node=reference.get_ref() as Node
    return is_instance_valid(node) and node.is_inside_tree() and not bool(node.get_meta("static_cancelled",false))
