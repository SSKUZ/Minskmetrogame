extends Node
## Content-addressed optional packs. Browser HTTP caching handles reuse across visits.
signal progress(message: String)
var _manifest: Dictionary = {}
var _mounted: Dictionary = {} # Godot 4.3 has no PCK unmount API.
var _loading_module := false
var _textures: Dictionary = {}
var _base_url := ""
var error_message := ""

func ensure_module(key: String, consumer: Node = null) -> bool:
    var consumer_ref: WeakRef=weakref(consumer) if consumer!=null else null
    # Serialize viewer switches and station requests, including shared pack files.
    while _loading_module:
        if not _consumer_alive(consumer_ref): return false
        await get_tree().process_frame
    if not _consumer_alive(consumer_ref): return false
    _loading_module=true
    var result: bool=await _ensure_module(key,consumer_ref)
    _loading_module=false
    return result

func _ensure_module(key: String, consumer_ref: WeakRef) -> bool:
    error_message = ""
    if not OS.has_feature("web"):
        return true
    if _base_url.is_empty():
        _base_url = str(JavaScriptBridge.eval("new URL('.', window.location.href).href", true))
    if _manifest.is_empty():
        progress.emit("Получение списка модулей…")
        var request := HTTPRequest.new()
        # Web Fetch already decodes Content-Encoding; do not decompress twice.
        request.accept_gzip = false
        request.timeout = 30.0
        add_child(request)
        var started := request.request(_base_url + "module-packs.json", PackedStringArray(["Cache-Control: no-cache"]))
        if started != OK:
            request.queue_free()
            return _fail("Не удалось запросить список модулей")
        var response: Array = await request.request_completed
        request.queue_free()
        if not _consumer_alive(consumer_ref): return false
        if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
            return _fail("Не удалось получить список модулей (HTTP %d, код %d)" % [int(response[1]), int(response[0])])
        var parsed = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
        if not parsed is Dictionary or not parsed.has("modules") or not parsed.has("packs"):
            return _fail("Некорректный список модулей")
        _manifest = parsed
    var id := "v106" if key == "v106" or key.begins_with("car") else key
    if not _manifest.modules.has(id):
        return _fail("Модуль отсутствует в списке: " + id)
    # Mount the selected module's complete dependency set before resolving any
    # image mappings. A later required pack may own an earlier pack's texture.
    # Streaming stations remain separate requests, outside this dependency set.
    for pack_id in _manifest.modules[id]:
        if not _consumer_alive(consumer_ref):
            release_module_resources(id)
            return false
        if not _mounted.has(pack_id):
            if not await _download_pack(str(pack_id), str(_manifest.names[id]), consumer_ref):
                release_module_resources(id)
                return false
    # Prepared station fragments resolve only their own material dependencies.
    # Eagerly warming every decorative texture defeats geometry-first streaming.
    var prepared_station := false
    var prepared_index := "res://modules/stations/"+id+"/prebuilt/index.json"
    if FileAccess.file_exists(prepared_index):
        var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(prepared_index))
        prepared_station=data is Dictionary and not bool(data.get("legacy",false))
    for pack_id in _manifest.modules[id]:
        if prepared_station: continue
        # Godot 4.3 imported GLTF scenes can use a generic Texture2D hint for
        # compressed image dependencies. Resolve their real texture type first.
        var warmup: Array = _manifest.packs[pack_id].get("warmup", [])
        var prepared := 0
        for path in warmup:
            if not _consumer_alive(consumer_ref):
                release_module_resources(id)
                return false
            prepared += 1
            if _textures.has(path): continue
            var texture_path: String=str(path)
            # Older manifests also listed .import settings copied into a pack
            # for CI. A sidecar without its exported source/.remap is not an
            # owned runtime image (e.g. V106's optional Uruchye artwork).
            # Do not load a remote station just to warm its unrelated texture.
            if _import_settings_only(texture_path): continue
            progress.emit("Текстуры «%s»: %d/%d…" % [str(_manifest.names[id]), prepared, warmup.size()])
            var texture := ResourceLoader.load(texture_path) as Texture2D
            if texture == null:
                release_module_resources(id)
                return _fail("Не удалось прочитать текстуру: %s · пакет %s" % [texture_path,str(pack_id)])
            _textures[path] = texture
            await get_tree().process_frame
    progress.emit("Подготовка модуля «%s»…" % str(_manifest.names[id]))
    await get_tree().process_frame
    return true

func _import_settings_only(path: String) -> bool:
    return FileAccess.file_exists(path+".import") and not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".remap")

func release_module_resources(key: String) -> void:
    # Dropping our strong references does not free resources still owned by a
    # train, station or another scene. Godot's Resource cache itself is weak.
    # Mounted PCK files are retained by Godot 4.3. This releases decoded Resource
    # references, not the browser's mounted pack storage or HTTP cache.
    if not _manifest.get("modules",{}).has(key): return
    for id in _manifest.modules[key]:
        for path in _manifest.packs[id].get("warmup",[]):
            _textures.erase(path)

func retain_only_module_resources(key: String) -> void:
    var keep: Dictionary={}
    if _manifest.get("modules",{}).has(key):
        for id in _manifest.modules[key]:
            for path in _manifest.packs[id].get("warmup",[]): keep[path]=true
    for path in _textures.keys():
        if not keep.has(path): _textures.erase(path)
    _train_models.clear()

func _consumer_alive(consumer: WeakRef) -> bool:
    if consumer==null: return true
    var node: Node=consumer.get_ref() as Node
    return is_instance_valid(node) and node.is_inside_tree()

func _download_pack(id: String, title: String, consumer: WeakRef = null) -> bool:
    var info: Dictionary = _manifest.packs[id]
    var target := "user://module-" + str(info.sha256) + ".pck"
    # A complete, verified local file may survive a browser session. Otherwise
    # the standard browser cache still reuses the same content-hashed URL.
    if FileAccess.file_exists(target):
        if await _verified_file(target,str(info.sha256),consumer) and ProjectSettings.load_resource_pack(target, false):
            _mounted[id] = true
            return true
        if not _consumer_alive(consumer): return false
        DirAccess.remove_absolute(target)
    var chunks: Array = info.get("chunks", [])
    if chunks.is_empty(): chunks = [{"file":info.file,"bytes":info.bytes,"sha256":info.sha256}]
    var output := FileAccess.open(target, FileAccess.WRITE)
    if output == null: return _fail("Недостаточно памяти для пакета «%s»" % title)
    var completed_bytes := 0
    for index in range(chunks.size()):
        var chunk: Dictionary = chunks[index]
        var partial := "user://download-" + str(chunk.sha256) + ".part"
        var success := false
        for attempt in range(3):
            if not _consumer_alive(consumer): break
            if await _fetch_chunk(chunk, partial, title, completed_bytes, int(info.bytes), index+1, chunks.size(), attempt, consumer):
                success = true
                break
            await get_tree().process_frame
        if not success:
            output.close()
            DirAccess.remove_absolute(target)
            return _fail("Загрузка «%s» прервана на части %d/%d; повторите выбор" % [title, index+1, chunks.size()])
        var input := FileAccess.open(partial, FileAccess.READ)
        var copied_at: int=Time.get_ticks_usec()
        while input.get_position() < input.get_length():
            if not _consumer_alive(consumer):
                input.close()
                output.close()
                DirAccess.remove_absolute(target)
                return false
            output.store_buffer(input.get_buffer(262144))
            if Time.get_ticks_usec()-copied_at>=2000:
                await get_tree().process_frame
                copied_at=Time.get_ticks_usec()
        input.close()
        DirAccess.remove_absolute(partial)
        completed_bytes += int(chunk.bytes)
        await get_tree().process_frame
    output.close()
    progress.emit("Проверка целостности пакета «%s»…" % title)
    await get_tree().process_frame
    if not await _verified_file(target,str(info.sha256),consumer):
        DirAccess.remove_absolute(target)
        return _fail("Пакет «%s» загружен не полностью" % title)
    if not ProjectSettings.load_resource_pack(target, false):
        DirAccess.remove_absolute(target)
        return _fail("Не удалось подключить пакет «%s»" % title)
    _mounted[id] = true
    return true

func _verified_file(path: String, digest: String, consumer: WeakRef) -> bool:
    var input := FileAccess.open(path,FileAccess.READ)
    if input==null: return false
    var hash := HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    var slice_started: int=Time.get_ticks_usec()
    while input.get_position()<input.get_length():
        if not _consumer_alive(consumer):
            input.close()
            return false
        hash.update(input.get_buffer(262144))
        if Time.get_ticks_usec()-slice_started>=2000:
            await get_tree().process_frame
            slice_started=Time.get_ticks_usec()
    input.close()
    return hash.finish().hex_encode()==digest

func _fetch_chunk(info: Dictionary, target: String, title: String, offset: int, total: int, part: int, parts: int, attempt: int, consumer: WeakRef = null) -> bool:
    if FileAccess.file_exists(target) and await _verified_file(target,str(info.sha256),consumer): return true
    var request := HTTPRequest.new()
    request.accept_gzip=false
    request.timeout=60.0
    request.body_size_limit=int(info.bytes)+1024
    request.download_file=target
    add_child(request)
    var completed: Array = []
    request.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray): completed.append([result,code]))
    var url: String = _base_url + str(info.file)
    if attempt>0: url += "?retry=%d" % Time.get_ticks_msec()
    var started := request.request(url)
    if started != OK:
        request.queue_free()
        return false
    var last_bytes := -1
    var last_change := Time.get_ticks_msec()
    while completed.is_empty():
        if not _consumer_alive(consumer):
            request.cancel_request()
            request.queue_free()
            DirAccess.remove_absolute(target)
            return false
        var received := request.get_downloaded_bytes()
        if received != last_bytes:
            last_bytes=received
            last_change=Time.get_ticks_msec()
        var stalled := Time.get_ticks_msec()-last_change
        progress.emit("Загрузка %s: %d%% · часть %d/%d · %.1f/%.1f МБ%s" % [title,mini(100,int((offset+received)*100/ maxi(1,total))),part,parts,float(offset+received)/1048576.0,float(total)/1048576.0," · повтор %d" % (attempt+1) if attempt>0 else ""])
        if stalled>20000:
            print("V106_DOWNLOAD_STALL part=",part," bytes=",received," attempt=",attempt+1)
            request.cancel_request()
            request.queue_free()
            DirAccess.remove_absolute(target)
            return false
        await get_tree().process_frame
    request.queue_free()
    if int(completed[0][0]) != HTTPRequest.RESULT_SUCCESS or int(completed[0][1]) != 200:
        DirAccess.remove_absolute(target)
        return false
    if not await _verified_file(target,str(info.sha256),consumer):
        DirAccess.remove_absolute(target)
        return false
    return true

func _fail(message: String) -> bool:
    error_message = message + ". Нажмите нужный модуль ещё раз для повторной попытки."
    progress.emit(error_message)
    return false

# Strong references keep warmed models in cache until the scene owns them.
var _train_models: Array[Resource] = []

func prepare_train_scene(path: String) -> PackedScene:
    var paths: Array[String] = [
        "res://assets/cab_r21/cab_r21.glb",
        "res://assets/v106_lod1/v106_car01_lod1_mesh289_normals_fixed.glb",
        "res://assets/v106_original/car02/v106_car_02.glb",
        "res://assets/v106_original/car03/v106_car_03.glb",
        "res://assets/v106_original/car04/v106_car_04.glb"
    ]
    var titles: Array[String] = ["кабина", "вагон 1", "вагон 2", "вагон 3", "вагон 4"]
    _train_models.clear()
    for i in range(paths.size()):
        progress.emit("V106: подготовка %s (%d/%d)…" % [titles[i], i+1, paths.size()])
        # Two frames allow the renderer to display the new stage before loading.
        await get_tree().process_frame
        await get_tree().process_frame
        var start := Time.get_ticks_msec()
        var model := ResourceLoader.load(paths[i], "PackedScene")
        print("V106_LOAD_STAGE ", titles[i], " ", Time.get_ticks_msec()-start, " ms")
        if model == null:
            _fail("Не удалось загрузить: " + titles[i])
            return null
        _train_models.append(model)
    progress.emit("V106: подготовка сцены и рекламы…")
    await get_tree().process_frame
    await get_tree().process_frame
    var scene := ResourceLoader.load(path, "PackedScene") as PackedScene
    if scene == null: _fail("Не удалось подготовить сцену состава V106")
    return scene
