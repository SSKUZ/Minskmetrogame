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
        for path in _manifest.packs[pack_id].get("warmup", []):
            if _textures.has(path): continue
            progress.emit("Подготовка текстур модуля «%s»…" % str(_manifest.names[id]))
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
    var request := HTTPRequest.new()
    # Browser responses arrive decoded, including when downloading to a file.
    request.accept_gzip = false
    request.timeout = 180.0
    request.download_file = target
    add_child(request)
    var phase := "общих ресурсов" if id == "shared" else "модуля " + title
    var completed: Array = []
    request.request_completed.connect(func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray): completed.append([result, code, headers, body]))
    var started := request.request(_base_url + str(info.file))
    if started != OK:
        request.queue_free()
        return _fail("Не удалось начать загрузку «%s»" % title)
    while completed.is_empty():
        var received := request.get_downloaded_bytes()
        var total := int(info.bytes)
        if received > 0 and total > 0:
            progress.emit("Загрузка %s — %d%%" % [phase, mini(100, int(received * 100 / total))])
        else:
            progress.emit("Загрузка %s…" % phase)
        await get_tree().process_frame
    request.queue_free()
    var response: Array = completed[0]
    if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
        DirAccess.remove_absolute(target)
        return _fail("Ошибка сети при загрузке «%s» (HTTP %d, код %d)" % [title, int(response[1]), int(response[0])])
    if FileAccess.get_sha256(target) != str(info.sha256):
        DirAccess.remove_absolute(target)
        return _fail("Пакет «%s» загружен не полностью" % title)
    if not ProjectSettings.load_resource_pack(target, false):
        DirAccess.remove_absolute(target)
        return _fail("Не удалось подключить пакет «%s»" % title)
    _mounted[id] = true
    return true

func _fail(message: String) -> bool:
    error_message = message + ". Нажмите нужный модуль ещё раз для повторной попытки."
    progress.emit(error_message)
    return false
