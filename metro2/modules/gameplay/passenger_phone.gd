extends Control
## Passenger-only mobile overlay. The train and world continue running.
const WEATHER_URL := "https://api.open-meteo.com/v1/forecast?latitude=53.9006&longitude=27.5590&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m&timezone=Europe%2FMinsk"
const NEWS_URL := "https://api.gdeltproject.org/api/v2/doc/doc?query=Belarus%20sourcelang%3Arussian&mode=artlist&maxrecords=12&format=json&sort=datedesc"
var service: Node
var opener: Button
var panel: PanelContainer
var scroll: ScrollContainer
var feed: VBoxContainer
var weather: Label
var news: VBoxContainer
var weather_request: HTTPRequest
var news_request: HTTPRequest
var weather_updated := 0
var news_updated := 0
var opened := false

func initialize(owner_service: Node, parent: Control) -> void:
    service=owner_service
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(self)
    opener=Button.new()
    opener.text="📱 ТЕЛЕФОН"
    opener.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    opener.offset_left=-180
    opener.offset_right=-12
    opener.offset_top=120
    opener.offset_bottom=170
    opener.pressed.connect(toggle)
    add_child(opener)
    panel=PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.mouse_filter=Control.MOUSE_FILTER_STOP
    add_child(panel)
    var column:=VBoxContainer.new()
    panel.add_child(column)
    var bar:=HBoxContainer.new()
    column.add_child(bar)
    var title:=Label.new()
    title.text="●  METRO PHONE   ·   Минск"
    title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    bar.add_child(title)
    var close:=Button.new()
    close.text="✕"
    close.pressed.connect(close_phone)
    bar.add_child(close)
    scroll=ScrollContainer.new()
    scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    feed=VBoxContainer.new()
    feed.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    scroll.add_child(feed)
    weather=Label.new()
    weather.text="ПОГОДА В МИНСКЕ\nНажмите на телефон для обновления."
    weather.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    feed.add_child(weather)
    var heading:=Label.new()
    heading.text="НОВОСТИ БЕЛАРУСИ"
    feed.add_child(heading)
    news=VBoxContainer.new()
    feed.add_child(news)
    var hint:=Label.new()
    hint.text="Данные из открытых источников. При отсутствии сети лента недоступна."
    hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    feed.add_child(hint)
    weather_request=HTTPRequest.new()
    add_child(weather_request)
    weather_request.request_completed.connect(_weather_received)
    news_request=HTTPRequest.new()
    add_child(news_request)
    news_request.request_completed.connect(_news_received)
    close_phone()
    get_viewport().size_changed.connect(_layout_phone)
    _layout_phone()

func _layout_phone() -> void:
    if panel==null: return
    var bounds:=get_viewport_rect().size
    var width:=clampf(bounds.x*0.78,230.0,430.0)
    var height:=clampf(bounds.y*0.80,250.0,760.0)
    panel.offset_left=-width*0.5
    panel.offset_right=width*0.5
    panel.offset_top=-height*0.5
    panel.offset_bottom=height*0.5
    scroll.custom_minimum_size=Vector2(width-32.0,height-90.0)

func available() -> bool:
    return service.running and service.role=="passenger" and is_instance_valid(service.player) and service.player.active and service.train.camera_mode=="walk"

func toggle() -> void:
    if opened: close_phone()
    elif available(): open_phone()

func open_phone() -> void:
    if not available(): return
    opened=true
    panel.show()
    opener.hide()
    service.player.stick=Vector2.ZERO
    service.player.velocity=Vector3.ZERO
    service.ui.camera_touch_id=-1
    service.ui.stick.reset()
    service.ui.stick.hide()
    service.ui.interact.hide()
    _refresh()

func close_phone() -> void:
    opened=false
    if panel!=null: panel.hide()
    if opener!=null: opener.visible=available() if is_instance_valid(service) else false

func _process(_delta: float) -> void:
    if not available():
        if opened: close_phone()
        opener.hide()
        return
    opener.visible=not opened
    if opened:
        service.player.stick=Vector2.ZERO
        service.ui.stick.hide()
        service.ui.interact.hide()

func _refresh() -> void:
    var now: float=Time.get_unix_time_from_system()
    if now-weather_updated>900 and weather_request.get_http_client_status()==HTTPClient.STATUS_DISCONNECTED:
        weather_request.request(WEATHER_URL)
    if now-news_updated>900 and news_request.get_http_client_status()==HTTPClient.STATUS_DISCONNECTED:
        news_request.request(NEWS_URL)

func _weather_received(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if code!=200:
        weather.text="ПОГОДА В МИНСКЕ\nНе удалось получить данные."
        return
    var data=JSON.parse_string(body.get_string_from_utf8())
    if not (data is Dictionary) or not data.has("current"): return
    var current: Dictionary=data.current
    weather.text="ПОГОДА В МИНСКЕ\n%s °C · ощущается как %s °C\nВетер: %s км/ч · осадки: %s мм\nОбновлено: %s" % [str(current.get("temperature_2m","—")),str(current.get("apparent_temperature","—")),str(current.get("wind_speed_10m","—")),str(current.get("precipitation","—")),str(current.get("time","—"))]
    weather_updated=int(Time.get_unix_time_from_system())

func _news_received(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if code!=200:
        _news_message("Новости временно недоступны.")
        return
    var data=JSON.parse_string(body.get_string_from_utf8())
    if not (data is Dictionary) or not (data.get("articles",null) is Array):
        _news_message("Источник новостей не ответил.")
        return
    for child in news.get_children(): child.queue_free()
    for article in (data.articles as Array):
        if not article is Dictionary: continue
        var headline:=str(article.get("title","")).strip_edges()
        var url:=str(article.get("url",""))
        if headline.is_empty() or not url.begins_with("https://"): continue
        var button:=Button.new()
        button.text=headline+"\n"+str(article.get("domain",""))
        button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        button.custom_minimum_size.y=74
        button.pressed.connect(func(): OS.shell_open(url))
        news.add_child(button)
    if news.get_child_count()==0: _news_message("Свежих публикаций пока нет.")
    news_updated=int(Time.get_unix_time_from_system())

func _news_message(value: String) -> void:
    for child in news.get_children(): child.queue_free()
    var label:=Label.new()
    label.text=value
    news.add_child(label)
