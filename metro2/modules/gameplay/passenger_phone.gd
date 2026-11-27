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
var route_label: Label
var _phone_visual: Node3D
var _phone_animation := 0.0

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
    panel.add_theme_stylebox_override("panel", _phone_style())
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
    route_label=Label.new()
    route_label.text="МЕТРО · поездка"
    route_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    feed.add_child(route_label)
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
    var bounds:=get_viewport().get_visible_rect().size / maxf(root_scale(),0.01)
    var width:=minf(bounds.x*0.78,430.0)
    var height:=minf(bounds.y*0.80,760.0)
    panel.offset_left=-width*0.5
    panel.offset_right=width*0.5
    panel.offset_top=-height*0.5
    panel.offset_bottom=height*0.5
    scroll.custom_minimum_size=Vector2(maxf(width-32.0,120.0),maxf(height-90.0,160.0))

func root_scale() -> float:
    return (get_parent() as Control).scale.x if get_parent() is Control else 1.0

func _phone_style() -> StyleBoxFlat:
    var style:=StyleBoxFlat.new()
    style.bg_color=Color("#101722")
    style.border_color=Color("#657888")
    style.set_border_width_all(6)
    style.set_corner_radius_all(24)
    style.set_content_margin_all(12)
    return style

func available() -> bool:
    return service.running and service.role=="passenger" and is_instance_valid(service.player) and service.player.active and service.train.camera_mode=="walk"

func toggle() -> void:
    if opened: close_phone()
    elif available(): open_phone()

func open_phone() -> void:
    if not available(): return
    opened=true
    _phone_animation=0.0
    panel.show()
    opener.hide()
    service.player.stick=Vector2.ZERO
    service.player.velocity=Vector3.ZERO
    service.ui.camera_touch_id=-1
    service.ui.stick.reset()
    service.ui.stick.hide()
    service.ui.interact.hide()
    _ensure_visual()
    _refresh()

func close_phone() -> void:
    opened=false
    if panel!=null: panel.hide()
    if is_instance_valid(_phone_visual): _phone_visual.hide()
    if opener!=null: opener.visible=available() if is_instance_valid(service) else false

func _process(delta: float) -> void:
    if not available():
        if opened: close_phone()
        opener.hide()
        return
    opener.visible=not opened
    if opened:
        _phone_animation=move_toward(_phone_animation,1.0,delta*3.0)
        if is_instance_valid(_phone_visual):
            _phone_visual.show()
            _phone_visual.position.y=lerpf(-0.45,-0.23,_phone_animation)
        _update_route()
        service.player.stick=Vector2.ZERO
        service.ui.stick.hide()
        service.ui.interact.hide()

func _update_route() -> void:
    if not is_instance_valid(route_label): return
    var train_speed: float=float(service.train.speed)*3.6
    var station_name: String="В пути"
    var nearest: Dictionary=service.line.path.nearest_station(float(service.line.get("distance")))
    if not nearest.is_empty(): station_name=str(nearest.get("module_id",nearest.get("index","Станция")))
    route_label.text="МЕТРО · %s\\nСкорость состава: %.0f км/ч" % [station_name,train_speed]

func _ensure_visual() -> void:
    if is_instance_valid(_phone_visual) or not is_instance_valid(service.player): return
    # Camera-relative portable geometry: a hand supporting the lower corner
    # of the large interactive screen. It is not a substitute for a rigged hand.
    _phone_visual=Node3D.new()
    _phone_visual.name="PassengerPhoneHand"
    service.player.eye.add_child(_phone_visual)
    _phone_visual.position=Vector3(0.26,-0.45,-0.48)
    var skin:=StandardMaterial3D.new()
    skin.albedo_color=Color("#b98567")
    var cuff:=StandardMaterial3D.new()
    cuff.albedo_color=Color("#343e55")
    _visual_box(_phone_visual,Vector3(0.09,0.22,0.10),Vector3(0.04,-0.10,0.0),skin)
    _visual_box(_phone_visual,Vector3(0.12,0.15,0.11),Vector3(-0.01,0.03,0.0),skin)
    _visual_box(_phone_visual,Vector3(0.13,0.13,0.14),Vector3(0.05,-0.21,0.02),cuff)

func _visual_box(parent: Node3D, size: Vector3, offset: Vector3, material: Material) -> void:
    var mesh:=BoxMesh.new()
    mesh.size=size
    mesh.material=material
    var node:=MeshInstance3D.new()
    node.mesh=mesh
    node.position=offset
    parent.add_child(node)

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
