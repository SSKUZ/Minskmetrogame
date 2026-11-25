extends "res://audio/controllers/route_info_binding.gd"
## The TZ54.4 INFO state machine is retained. Only whole-line lifecycle is added.
var _line: Node3D
var _returning_to_depot := false
var _depot_warning_at := -1
var _depot_wait_until := -1
const DEPOT_WARNING := "line_doors_warning"

func initialize(owner_game: Node3D, world: Node) -> void:
    _line=world
    super.initialize(owner_game,world)
    if get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.disconnect(_on_node_added)
    if _button!=null: _button.position.y=145.0
    tracker.route_ids=_route.station_ids
    _refresh_markers()

func _discover(_node: Node) -> void:
    # Whole-line tracking never owns station nodes or temporary stop markers.
    pass

func _on_node_added(_node: Node) -> void:
    pass

func _refresh_markers() -> void:
    if tracker!=null and is_instance_valid(_line):
        tracker.configure(_line.path.info_points(),tracker.direction)

func _has_loaded_stop(id: String) -> bool:
    for record in _line.stations:
        if str(record.info_id)==id: return _line.streamer.is_loaded(int(record.index))
    return false

func _at_route_stop(state: Dictionary, consist: Node3D) -> bool:
    if state.is_empty(): return false
    if is_instance_valid(_line.gameplay):
        var platform: int=_line.gameplay.station_at_train()
        return platform>=0 and str(_line.stations[platform].info_id)==str(state.station_id)
    if passenger_mode or bool(state.at_station): return bool(state.at_station)
    # Manual drivers need not hit a 50 cm autopilot point to call the warning.
    # Use the complete train envelope and saved station connection limits;
    # this does not change driving, doors or passenger boarding tolerances.
    var bounds: AABB=game.get("_train_bounds")
    for record in _line.stations:
        if str(record.info_id)!=str(state.station_id): continue
        var low: float=float(record.root_z)+float(record.exit_local_z)
        var high: float=float(record.root_z)+float(record.entry_local_z)
        return consist.global_position.z+bounds.position.z>=low and consist.global_position.z+bounds.end.z<=high
    return false

func select_passenger_mode(enabled: bool) -> void:
    if is_instance_valid(_line.gameplay):
        _line.gameplay.switch_role("passenger" if enabled else "driver")
        return
    super.select_passenger_mode(enabled)
    _returning_to_depot=false
    _depot_warning_at=-1
    _depot_wait_until=-1
    if enabled and float(game.distance)>300.0:
        game.cab_runtime.direction=1
        tracker.set_direction("forward")

func press_info() -> String:
    if is_instance_valid(_line.gameplay) and passenger_mode:
        return "Информатор: автоматический режим"
    _update_context()
    if not passenger_mode and audio.info.stopped and audio.info.doors_open and not audio.info._departure_used and tracker.direction=="reverse" and audio.info.station_id=="uruchye":
        if not audio.announcer.is_busy() and audio.bank.has_event(DEPOT_WARNING):
            audio.cab_audio.press_button("info")
            audio.announcer.manual_play(DEPOT_WARNING)
            audio.info._departure_used=true
            return "Предупреждение о закрытии дверей · выезд в депо"
    return super.press_info()

func _physics_process(delta: float) -> void:
    if not _line.ready_for_service: return
    if is_instance_valid(_line.gameplay):
        if passenger_mode:
            _line.gameplay.automatic.update_info()
        else:
            _update_context()
        return
    _update_context()
    if passenger_mode and _returning_to_depot:
        _depot_leg()
        return
    if passenger_mode and not _state.is_empty() and audio.info.stopped and _auto_phase=="dwell":
        var clear: bool=_line.passengers.complete() and _line.passengers.doors_clear()
        if not clear:
            _dwell_until=maxi(_dwell_until,Time.get_ticks_msec()+500)
        if Time.get_ticks_msec()>=_dwell_until and clear:
            if str(_state.station_id)=="ploshcha_lenina" and tracker.direction=="forward":
                # Reverse only in explicitly selected passenger mode, stationary.
                _drive_request(0.0,1.0)
                game.cab_runtime.direction=-1
                tracker.set_direction("reverse")
                _update_context()
                _auto_visit=str(_state.visit_id)
                audio.info._arrival_used=true
                audio.info._doors_opened_this_visit=true
                _dwell_until=Time.get_ticks_msec()+12000
                return
            elif str(_state.station_id)=="uruchye" and tracker.direction=="reverse":
                if not audio.announcer.is_busy() and audio.bank.has_event(DEPOT_WARNING):
                    audio.announcer.manual_play(DEPOT_WARNING)
                    _returning_to_depot=true
                    _depot_warning_at=Time.get_ticks_msec()+100
                _drive_request(0.0,1.0)
                return
    if passenger_mode and _auto_phase=="warning" and not _line.passengers.doors_clear():
        _close_at=maxi(_close_at,Time.get_ticks_msec()+100)
    super._physics_process(delta)

func _on_departure_started(event_id: String, warning_seconds: float) -> void:
    if is_instance_valid(_line.gameplay): return
    super._on_departure_started(event_id,warning_seconds)
    if passenger_mode and warning_seconds>0.0:
        # Warning starts first; leaves begin moving while that recording sounds.
        _close_at=Time.get_ticks_msec()+mini(100,maxi(1,int(warning_seconds*250.0)))

func _depot_leg() -> void:
    var doors: Node=game.door_system
    if _depot_warning_at>=0:
        _drive_request(0.0,1.0)
        if Time.get_ticks_msec()>=_depot_warning_at and audio.announcer.has_audio_started(DEPOT_WARNING) and _line.passengers.doors_clear():
            doors.request_close()
            _depot_warning_at=-1
        return
    if not doors.can_move():
        _drive_request(0.0,1.0)
        return
    var remaining := 430.0-float(game.distance)
    var v := absf(float(game.speed))
    if absf(remaining)<0.5 and v<0.05:
        _drive_request(0.0,1.0)
        if _depot_wait_until<0: _depot_wait_until=Time.get_ticks_msec()+12000
        if Time.get_ticks_msec()>=_depot_wait_until:
            _returning_to_depot=false
            game.cab_runtime.direction=1
            tracker.set_direction("forward")
            _auto_phase="approach"
            _auto_visit=""
        return
    var desired := minf(8.0,sqrt(2.0*0.65*maxf(0.0,remaining-0.1)))
    _drive_request(1.0 if v<desired-0.1 else 0.0,clampf((v-desired)*0.8,0.0,1.0) if remaining>0.5 else 1.0)

func passenger_information() -> Dictionary:
    if _returning_to_depot or float(game.distance)>300.0:
        return {"current_station":"Электродепо" if float(game.distance)>300.0 else "Уручье",
            "next_station":"Электродепо" if _returning_to_depot else "Уручье","at_station":float(game.speed)<0.05}
    return super.passenger_information()
