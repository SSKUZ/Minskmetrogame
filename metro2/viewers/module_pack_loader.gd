extends Node
## Content-addressed optional packs. Browser HTTP caching handles reuse across visits.
signal progress(message: String)
var _manifest: Dictionary = {}
var _mounted: Dictionary = {}
var _textures: Dictionary = {}
var _base_url := ""
var error_message := ""

func ensure_module(key: String) -> bool:
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
        if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
            return _fail("Не удалось получить список модулей (HTTP %d, код %d)" % [int(response[1]), int(response[0])])
        var parsed = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
        if not parsed is Dictionary or not parsed.has("modules") or not parsed.has("packs"):
            return _fail("Некорректный список модулей")
        _manifest = parsed
    var id := "v106" if key == "v106" or key.begins_with("car") else key
    if not _manifest.modules.has(id):
        return _fail("Модуль отсутствует в списке: " + id)
    for pack_id in _manifest.modules[id]:
        if not _mounted.has(pack_id):
            if not await _download_pack(str(pack_id), str(_manifest.names[id])):
                return false
        # Godot 4.3 imported GLTF scenes can use a generic Texture2D hint for
        # compressed image dependencies. Resolve their real texture type first.
        var warmup: Array = _manifest.packs[pack_id].get("warmup", [])
        var prepared := 0
        for path in warmup:
            prepared += 1
            if _textures.has(path): continue
            progress.emit("Текстуры «%s»: %d/%d…" % [str(_manifest.names[id]), prepared, warmup.size()])
            var texture := load(str(path)) as Texture2D
            if texture == null: return _fail("Не удалось прочитать текстуру выбранного модуля")
            _textures[path] = texture
            await get_tree().process_frame
    progress.emit("Подготовка модуля «%s»…" % str(_manifest.names[id]))
    await get_tree().process_frame
    return true

func _download_pack(id: String, title: String) -> bool:
    var info: Dictionary = _manifest.packs[id]
    var target := "user://module-" + str(info.sha256) + ".pck"
    # A complete, verified local file may survive a browser session. Otherwise
    # the standard browser cache still reuses the same content-hashed URL.
    if FileAccess.file_exists(target):
        if FileAccess.get_sha256(target) == str(info.sha256) and ProjectSettings.load_resource_pack(target, false):
            _mounted[id] = true
            return true
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
            if await _fetch_chunk(chunk, partial, title, completed_bytes, int(info.bytes), index+1, chunks.size(), attempt):
                success = true
                break
            await get_tree().process_frame
        if not success:
            output.close()
            DirAccess.remove_absolute(target)
            return _fail("Загрузка «%s» прервана на части %d/%d; повторите выбор" % [title, index+1, chunks.size()])
        var input := FileAccess.open(partial, FileAccess.READ)
        while input.get_position() < input.get_length():
            output.store_buffer(input.get_buffer(262144))
        input.close()
        DirAccess.remove_absolute(partial)
        completed_bytes += int(chunk.bytes)
        await get_tree().process_frame
    output.close()
    progress.emit("Проверка целостности пакета «%s»…" % title)
    await get_tree().process_frame
    if FileAccess.get_sha256(target) != str(info.sha256):
        DirAccess.remove_absolute(target)
        return _fail("Пакет «%s» загружен не полностью" % title)
    if not ProjectSettings.load_resource_pack(target, false):
        DirAccess.remove_absolute(target)
        return _fail("Не удалось подключить пакет «%s»" % title)
    _mounted[id] = true
    return true

func _fetch_chunk(info: Dictionary, target: String, title: String, offset: int, total: int, part: int, parts: int, attempt: int) -> bool:
    if FileAccess.file_exists(target) and FileAccess.get_sha256(target) == str(info.sha256): return true
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
    if FileAccess.get_sha256(target) != str(info.sha256):
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
