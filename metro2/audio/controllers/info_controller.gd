extends Node
class_name MetroInfoController
## TZ54.3: one shared state machine for cab INFO and on-screen INFO.
## The owner feeds real route/door events; this module never guesses station coordinates.
signal info_result(message: String)
signal mode_changed(mode: String)
signal departure_started(event_id: String, warning_seconds: float)

const MANUAL := "manual"
const AUTO := "auto"
const ARRIVAL := "arrival"
const DEPARTURE := "next_station"

var announcer: MetroAnnouncer
var mode: String = MANUAL
var station_id: String = ""
var next_station_id: String = ""
var direction: String = "forward"
var visit_id: String = ""
var approaching: bool = false
var stopped: bool = false
var doors_open: bool = false
var doors_closed: bool = true
var _doors_opened_this_visit: bool = false
var _arrival_used: bool = false
var _departure_used: bool = false
var _service_used: bool = false
var _last_service: String = ""
var _service_events: Array[String] = []
var _busy: bool = false

func bind(target: MetroAnnouncer) -> void:
    if is_instance_valid(announcer):
        if announcer.announcement_started.is_connected(_on_started):
            announcer.announcement_started.disconnect(_on_started)
        if announcer.announcement_finished.is_connected(_on_finished):
            announcer.announcement_finished.disconnect(_on_finished)
    announcer = target
    _busy = false
    if is_instance_valid(announcer):
        announcer.announcement_started.connect(_on_started)
        announcer.announcement_finished.connect(_on_finished)

func configure_service_events(verified_event_ids: Array[String]) -> void:
    # Only normal, verified passenger notices; emergency alerts never enter this pool.
    _service_events.clear()
    for event_id in verified_event_ids:
        if event_id != "" and not _service_events.has(event_id):
            _service_events.append(event_id)

func set_mode(new_mode: String) -> void:
    if new_mode != MANUAL and new_mode != AUTO:
        return
    if mode == new_mode:
        return
    mode = new_mode
    mode_changed.emit(mode)

func set_route_context(current_id: String, following_id: String, route_direction: String, unique_visit_id: String) -> void:
    if unique_visit_id == "":
        return
    if visit_id != unique_visit_id or direction != route_direction or station_id != current_id or next_station_id != following_id:
        if is_instance_valid(announcer):
            # A route-context transition must not cut off a recording already
            # playing. Drop only obsolete queued messages; explicit stop remains.
            announcer.clear_pending()
            announcer.prepare_route(current_id,following_id,route_direction)
        _arrival_used = false
        _departure_used = false
        _service_used = false
        _doors_opened_this_visit = false
    station_id = current_id
    next_station_id = following_id
    direction = route_direction
    visit_id = unique_visit_id

func update_train_state(is_approaching: bool, is_stopped: bool, are_doors_open: bool, are_doors_closed: bool) -> void:
    approaching = is_approaching
    stopped = is_stopped
    doors_open = are_doors_open
    doors_closed = are_doors_closed
    if stopped and are_doors_open:
        _doors_opened_this_visit = true

func press_info() -> String:
    # Both physical and touch buttons MUST call this same method.
    if mode != MANUAL:
        return _result("INFO управляется автоматически")
    if _busy:
        return _result("Дождитесь окончания объявления")
    if stopped and doors_open and _doors_opened_this_visit and not _departure_used:
        return _play_route(next_station_id, DEPARTURE, false)
    if (approaching or (stopped and doors_closed)) and not _arrival_used:
        return _play_route(station_id, ARRIVAL, true)
    if _departure_used and doors_closed and not doors_open and not _service_used and not stopped:
        return _play_service()
    return _result("Сейчас нет доступного объявления")

func on_auto_approach() -> void:
    if mode == AUTO and (approaching or stopped) and not _arrival_used and not _busy:
        _play_route(station_id, ARRIVAL, true)

func on_auto_departure() -> void:
    if mode == AUTO and stopped and doors_open and _doors_opened_this_visit and not _departure_used and not _busy:
        _play_route(next_station_id, DEPARTURE, false)

func on_auto_service() -> void:
    if mode == AUTO and not stopped and doors_closed and _departure_used and not _service_used and not _busy:
        _play_service()

func _play_route(id: String, phase: String, is_arrival: bool) -> String:
    if not is_instance_valid(announcer) or not is_instance_valid(announcer.bank):
        return _result("Информатор не подключён")
    if id == "" or visit_id == "":
        return _result("Маршрут не задан")
    var event_id: String = str(announcer.route_events.get("%s|%s|%s" % [id, phase, direction], ""))
    if event_id == "" or not announcer.bank.has_event(event_id):
        return _result("Для станции нет подтверждённой записи")
    if announcer.is_busy():
        return _result("Информатор занят")
    # Do not queue or overlap. A successful start consumes this phase once per visit.
    announcer.manual_play(event_id)
    if announcer.current_event() != event_id:
        return _result("Запись не запустилась")
    if is_arrival:
        _arrival_used = true
    else:
        _departure_used = true
        departure_started.emit(event_id, float(announcer.bank.event_data(event_id).get("warning_seconds", 0.0)))
    return _result("Воспроизводится: " + event_id)

func _play_service() -> String:
    if not is_instance_valid(announcer) or not is_instance_valid(announcer.bank):
        return _result("Информатор не подключён")
    var choices: Array[String] = []
    for event_id in _service_events:
        if announcer.bank.has_event(event_id) and event_id != _last_service:
            choices.append(event_id)
    if choices.is_empty():
        for event_id in _service_events:
            if announcer.bank.has_event(event_id):
                choices.append(event_id)
    if choices.is_empty():
        return _result("Нет подтверждённых служебных записей")
    if announcer.is_busy():
        return _result("Информатор занят")
    var event_id: String = choices.pick_random()
    announcer.manual_play(event_id)
    if announcer.current_event() != event_id:
        return _result("Запись не запустилась")
    _service_used = true
    _last_service = event_id
    return _result("Служебное объявление")

func _on_started(_event_id: String) -> void:
    _busy = true

func _on_finished(_event_id: String) -> void:
    _busy = false

func _result(message: String) -> String:
    info_result.emit(message)
    return message
