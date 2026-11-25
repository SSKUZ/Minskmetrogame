extends Node
## One authority, driving the existing cab/physics and the existing INFO queue.
enum Phase { IDLE, RUN, ARRIVAL, OPENING, DWELL, WARNING, CLOSING, TERMINAL }
var service: Node
var phase:=Phase.IDLE
var target:=0
var direction:=1
var visit:=0
var dwell_left:=0.0
var departure_event:=""
var _master:=0.0
var _visit_key:=""
var _warning_requested:=false
var _terminal_reversed:=false
var _warning_heard:=false
var _departed_context:=false

func initialize(owner_service: Node) -> void:
    service=owner_service
    process_priority=-5
    service.train.info_binding.audio.info.departure_started.connect(_departure_started)

func enable() -> void:
    direction=1 if int(service.train.cab_runtime.direction)>=0 else -1
    _master=float(service.train.cab_runtime.controller_value)
    var stopped: int=service.station_at_train()
    if absf(service.train.speed)<0.05 and stopped>=0:
        target=stopped
        phase=Phase.ARRIVAL
    else:
        target=_next_ahead()
        phase=Phase.RUN
    visit+=1
    _visit_key=""
    _warning_requested=false
    _warning_heard=false
    _departed_context=false
    _terminal_reversed=false

func disable() -> void:
    phase=Phase.IDLE
    departure_event=""
    _warning_requested=false
    # Cancel only queued departure work. A real recording already playing ends.
    service.train.info_binding.audio.announcer.clear_pending()

func approach_station(index: int, travel_direction: int) -> void:
    target=index
    direction=travel_direction
    service.train.cab_runtime.direction=direction
    _master=0.0
    phase=Phase.RUN
    visit+=1
    _visit_key=""
    _terminal_reversed=false
    _departed_context=false

func _next_ahead() -> int:
    var records: Array=service.line.stations
    if direction>0:
        for i in range(records.size()):
            if float(records[i].stop_z)<float(service.train.distance)-0.7: return i
        return records.size()-1
    for i in range(records.size()-1,-1,-1):
        if float(records[i].stop_z)>float(service.train.distance)+0.7: return i
    return 0

func _physics_process(delta: float) -> void:
    if not service.running or service.role!="passenger" or service.virtual_wait or phase==Phase.IDLE: return
    var train: Node3D=service.train
    var binding: Node=train.info_binding
    var info: Node=binding.audio.info
    var doors: Node=train.door_system
    if not service.line.ready_for_service or not doors.validated: return
    var record: Dictionary=service.line.stations[target]
    var remaining: float=(float(train.distance)-float(record.stop_z))*float(direction)
    var speed: float=absf(train.speed)
    update_info()
    match phase:
        Phase.RUN:
            if speed<0.05 and not service.interaction.close_cab_for_departure():
                _drive(-1.0,delta)
                return
            if remaining<125.0 and remaining> -2.0: info.on_auto_approach()
            if speed<0.045 and ((remaining<=0.8 and remaining>=-1.5) or service.station_at_train()==target):
                _drive(-1.0,delta)
                phase=Phase.ARRIVAL
                return
            var limit: float=float(service.rules.service.cruise_speed)
            var desired: float=minf(limit,sqrt(2.0*float(service.rules.service.braking_deceleration)*maxf(remaining-0.30,0.0)))
            # Holding brake beyond the datum also prevents runaway at a terminal.
            var request: float=-1.0 if remaining<=0.25 else clampf((desired-speed)*0.9,-1.0,1.0)
            if not doors.can_move(): request=-1.0
            _drive(request,delta)
        Phase.ARRIVAL:
            _drive(-1.0,delta)
            if speed>0.05: return
            if not service.line.streamer.is_loaded(target) or not service.line.passengers.platform_ready(target): return
            info.on_auto_approach()
            var nav=service.line.passengers._platforms[target].navigation
            var layout=service.line.passengers.layout
            layout.select_platform(nav.platform_area,nav.height,nav)
            var side:=0
            for door in layout.doors:
                if door.available: side=int(door.side);break
            if side==0: return
            train.cab_runtime.door_side=side
            doors.request_side(side,speed)
            phase=Phase.OPENING
        Phase.OPENING:
            _drive(-1.0,delta)
            if float(doors.openness)<0.99: return
            dwell_left=float(service.rules.service.dwell)
            _warning_requested=false
            _warning_heard=false
            departure_event=""
            phase=Phase.DWELL
        Phase.DWELL:
            _drive(-1.0,delta)
            dwell_left=maxf(0.0,dwell_left-delta)
            if dwell_left>0.0 or not service.line.passengers.complete() or not _doorway_clear(): return
            var next: int=target+direction
            if next<0 or next>=service.line.stations.size():
                phase=Phase.TERMINAL
                return
            if not _warning_requested and not binding.audio.announcer.is_busy():
                _warning_requested=true
                info.on_auto_departure()
                if departure_event.is_empty():
                    # Only the existing, identified original warning is allowed.
                    var event_id:="line_doors_warning"
                    if binding.audio.bank.has_event(event_id):
                        binding.audio.announcer.manual_play(event_id)
                        departure_event=event_id
                        info._departure_used=true
                    else:
                        _warning_requested=false
                        service.ui.notice("Нет подготовленного объявления о закрытии дверей")
                        return
                phase=Phase.WARNING
        Phase.WARNING:
            _drive(-1.0,delta)
            _warning_heard=_warning_heard or binding.audio.announcer.has_audio_started(departure_event)
            if _warning_heard and _doorway_clear():
                doors.request_close()
                phase=Phase.CLOSING
        Phase.CLOSING:
            _drive(-1.0,delta)
            if not _doorway_clear():
                phase=Phase.WARNING
                return
            if not doors.can_move(): return
            if not service.interaction.close_cab_for_departure(): return
            target+=direction
            _departed_context=true
            visit+=1
            _visit_key=""
            phase=Phase.RUN
        Phase.TERMINAL:
            _drive(-1.0,delta)
            if not service.line.passengers.complete() or not _doorway_clear(): return
            # Finish disembarkation before changing direction/destination context.
            direction=-direction
            train.cab_runtime.direction=direction
            visit+=1
            _visit_key=""
            dwell_left=float(service.rules.service.dwell)
            _warning_requested=false
            _warning_heard=false
            departure_event=""
            _terminal_reversed=true
            phase=Phase.DWELL

func update_info() -> void:
    if phase==Phase.IDLE or not is_instance_valid(service): return
    var binding: Node=service.train.info_binding
    var info: Node=binding.audio.info
    var record: Dictionary=service.line.stations[target]
    var remaining: float=(float(service.train.distance)-float(record.stop_z))*float(direction)
    var doors: Node=service.train.door_system
    if phase==Phase.RUN and remaining>125.0 and _departed_context:
        info.update_train_state(false,false,false,doors.can_move())
        info.on_auto_service()
        return
    _departed_context=false
    var next: int=target+direction
    var key: String="service:%d:%d:%d" % [visit,target,direction]
    binding.tracker.set_direction("forward" if direction>0 else "reverse")
    info.set_route_context(str(record.info_id),str(service.line.stations[next].info_id) if next>=0 and next<service.line.stations.size() else "",binding.tracker.direction,key)
    if _visit_key!=key:
        _visit_key=key
        if _terminal_reversed: info._arrival_used=true
    var speed: float=absf(service.train.speed)
    var stopped: bool=service.station_at_train()==target and speed<0.05
    info.update_train_state(phase==Phase.RUN and remaining<125.0 and remaining>=-2.0,stopped,bool(doors.target_open) and float(doors.openness)>=0.99,doors.can_move())
    binding._state={"station_id":record.info_id,"next_station_id":info.next_station_id,"visit_id":key,"at_station":stopped,"platform_side":service.train.cab_runtime.door_side}

func _doorway_clear() -> bool:
    return service.line.passengers.doors_clear() and service.interaction.doorway_clear()

func _drive(request: float, delta: float) -> void:
    # Preserve applied brake/velocity on handover; command the original cab only.
    if service.train.cab_runtime.emergency: request=-1.0
    _master=move_toward(_master,request,delta*1.5)
    var binding: Node=service.train.info_binding
    binding.applying_auto_input=true
    service.train.cab_runtime.command("master",_master)
    binding.applying_auto_input=false

func _departure_started(event_id: String, _seconds: float) -> void:
    if service.role=="passenger" and phase==Phase.DWELL: departure_event=event_id
