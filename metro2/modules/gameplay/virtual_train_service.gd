extends RefCounted
## One existing physical lease. One pending station call, never rolling virtual headways.
const Context=preload("res://modules/gameplay/dispatch_context.gd")
const Background=preload("res://modules/gameplay/dispatch_service.gd")
var service: Node
var pending: Dictionary={}
var terminal_call: Dictionary={}
var records: Dictionary={}
var slots: Array[Dictionary]=[]
var serial:=0
var _clock:=0.0
var _observed:=-1
var _enabled:=false
var _terminal: Dictionary={}
var _notices: Dictionary={}
var available:=true
var _policy: Dictionary={}
var _prefetch_targets: Dictionary={}

func initialize(owner_service: Node) -> void:
    service=owner_service
    _policy=service.rules.get("dispatch",{})
    var required: Array=["handover_departure_seconds","dwell_seconds","door_closing_lead_seconds","terminal_dwell_seconds","track_x","refresh_seconds","retry_seconds","operation_timeout_seconds","boarding_grace_seconds","shuttle"]
    for key in required:
        if not _policy.has(key): available=false
    if available:
        available=int(_policy.maximum_physical_trains)==1 and _policy.track_x.has("1") and _policy.track_x.has("-1") and float(_policy.shuttle.target_interval_seconds)>0.0
    if not available: push_error("Train dispatch: отсутствуют корректные параметры одного челночного состава")

func register_current_train() -> void:
    if not slots.is_empty(): return
    var context=Context.new()
    service.line.add_child(context)
    context.configure(service.line)
    context.train=service.train
    context.passengers=service.line.passengers
    context.gameplay=service
    context.ready_for_service=service.line.ready_for_service
    context.train.reparent(context,true)
    context.passengers.reparent(context,true)
    service.automatic.reparent(context)
    context.train.line=context
    context.train.info_binding._line=context
    context.train.info_binding.route_root=context
    context.train.info_binding.audio.bind_game(context.train,context)
    context.passengers._line=context
    var background=Background.new()
    context.add_child(background)
    background.configure(self,context)
    background.automatic=service.automatic
    background.running=false
    slots.append({"context":context,"background":background,"automatic":service.automatic,"id":"player","active":not service.virtual_wait})

func cancel() -> void:
    _enabled=false
    _prefetch_targets.clear()
    pending.clear()
    terminal_call.clear()
    records.clear()

func schedule(index: int) -> void:
    if not available:
        service.ui.notice("Нет корректных данных расписания")
        return
    register_current_train()
    _enabled=true
    _observed=index
    # Passenger startup already hides the original consist before showing the
    # player. It can immediately become the first approaching train.
    if not bool(slots[0].active): _plan(index,_outbound(index,1),_now(),"REUSABLE")

func handover(train: Node3D) -> void:
    if not available: return
    register_current_train()
    _enabled=true
    pending.clear()
    _prefetch_targets.clear()
    var slot: Dictionary=_slot(train)
    if slot.is_empty(): return
    serial+=1
    slot.id="shuttle:%d" % serial
    slot.active=true
    slot.last_call=station_at_vehicle(train,slot.context.passengers)
    slot.departure_seen=false
    records.clear()
    records[str(slot.id)]={"id":slot.id,"direction":int(slot.automatic.direction),"state":"DWELL","boarding_available":false}
    train.set_meta("dispatch_train_id",str(slot.id))
    # Existing arrival/doors/INFO logic owns the handover dwell. Departure is
    # timed below only when actual velocity first becomes nonzero.
    _prefetch(int(slot.last_call)+int(slot.automatic.direction))

func begin_call(index: int, direction: int, visit: int, train: Node3D=null) -> void:
    var actor: Node3D=train if is_instance_valid(train) else service.train
    var slot: Dictionary=_slot(actor)
    if not slot.is_empty():
        slot.last_call=index
        slot.departure_seen=false
    if not pending.is_empty() and int(pending.station)==index and pending.state=="APPROACHING":
        pending.state="ARRIVED"
        pending.actual_arrival_at=_now()
        pending.reason=""
    var following: int=index+direction
    _prefetch(following if following>=0 and following<service.line.stations.size() else index-direction)
    if following>=0 and following<service.line.stations.size(): return
    var token: int=actor.get_instance_id()
    if int(_terminal.get(token,{}).get("visit",-1))!=visit:
        _terminal[token]={"visit":visit,"ready_at":_now()+float(_policy.terminal_dwell_seconds)}

func _outbound(index: int, desired: int) -> int:
    if index<=0: return 1
    if index>=service.line.stations.size()-1: return -1
    return desired

func _plan(index: int, direction: int, departure: float, state: String) -> void:
    serial+=1
    pending={"id":"shuttle:%d" % serial,"station":index,"direction":_outbound(index,direction),
        "departed_at":departure,"arrival_at":departure+float(_policy.shuttle.target_interval_seconds),
        "state":state,"reason":"","attempts":0,"retry_at":0.0}
    _observed=index
    _prefetch_targets.clear()

func platform_shuttle_station() -> int:
    if not _enabled or service.role!="passenger" or not is_instance_valid(service.player) or not service.player.active or is_instance_valid(service.player.aboard): return -1
    return service.line.streamer.player_station_index()

func update() -> void:
    if not service.running or not available: return
    register_current_train()
    # Never allocate a second lease or generate future timetable records.
    var slot: Dictionary=slots[0]
    slot.context.ready_for_service=service.line.ready_for_service
    var train: Node3D=slot.context.train
    if service.role!="passenger": return
    if _occupied(train):
        pending.clear()
        return
    var station: int=platform_shuttle_station()
    if station<0: return
    _clock-=service.get_physics_process_delta_time()
    if _clock>0.0: return
    _clock=float(_policy.refresh_seconds)
    _observed=station
    var automatic: Node=slot.automatic
    if bool(slot.active) and automatic.phase==automatic.Phase.RUN and absf(float(train.speed))>float(_policy.shuttle.departure_speed_mps):
        if not bool(slot.get("departure_seen",false)):
            slot.departure_seen=true
            var origin: int=int(slot.get("last_call",station))
            # Only the station where the physical player is waiting owns this
            # cycle. Changing the active station cancels the former pending call.
            if origin==station:
                _plan(station,-int(automatic.direction),_now(),"CLEARING")
                service.line.streamer.refresh()
    if pending.is_empty():
        if not bool(slot.active): _plan(station,_outbound(station,1),_now(),"REUSABLE")
        else: return
    if int(pending.station)!=station:
        pending.clear()
        return
    if pending.state in ["ARRIVED","BLOCKED"]: return
    if pending.state=="CLEARING":
        pending.reason="Состав ещё покидает область наблюдения или слышимости"
        if _reusable(slot,station):
            _retire(slot)
            pending.state="REUSABLE"
        elif _now()-float(pending.departed_at)>float(_policy.shuttle.release_timeout_seconds):
            _block_call("Состав не освобождён: видимость, звук, двери или занятость. Доступен повтор отправления.")
            return
    if pending.state=="REUSABLE":
        if not service.line.streamer.is_service_ready(station) or not service.line.passengers.platform_ready(station):
            pending.reason="Подготовка платформы"
            return
        if _now()<float(pending.retry_at): return
        var candidate: Dictionary=_approach(station,int(pending.direction),train)
        if candidate.is_empty():
            _block_call("На существующей линии нет безопасной точки подхода к этой платформе")
            return
        var launch: float=float(pending.arrival_at)-float(candidate.travel_seconds)
        if _now()<launch: return
        if int(pending.attempts)>=int(_policy.maximum_spawn_attempts):
            _block_call("Не удалось подготовить безопасное прибытие. Доступен повтор.")
            return
        pending.attempts=int(pending.attempts)+1
        if not _activate(pending,slot,station,candidate):
            pending.retry_at=_now()+float(_policy.retry_seconds)
            return
    if pending.state=="APPROACHING":
        if automatic.phase==automatic.Phase.BLOCKED:
            _block_call(str(automatic.error_message))
        else:
            var distance: float=float(train.distance)
            if absf(distance-float(pending.get("progress_z",distance)))>0.5:
                pending.progress_z=distance
                pending.progress_at=_now()
            if _now()-float(pending.get("progress_at",_now()))>float(_policy.shuttle.approach_timeout_seconds):
                var problem: String=service.line.streamer.station_error(station)
                var reason: String="Нет продвижения к платформе: "+(problem if not problem.is_empty() else "ожидание готового базового пути или остановки")
                automatic._block(reason)
                _block_call(reason)
            elif _now()>float(pending.arrival_at):
                pending.reason="Состав приближается; ожидание штатной остановки"

func _block_call(reason: String) -> void:
    pending.state="BLOCKED"
    pending.reason=reason
    _notice("shuttle",reason)

func _reusable(slot: Dictionary, index: int) -> bool:
    var train: Node3D=slot.context.train
    if _occupied(train) or service.role!="passenger" or platform_shuttle_station()!=index: return false
    if not train.door_system.can_move() or not service.interaction.doorway_clear() or not slot.context.passengers.doors_clear(): return false
    for door in slot.context.passengers.layout.doors:
        if door.active!=null or not door.enter.is_empty() or not door.exit.is_empty(): return false
    # One conservative whole-consist envelope, including every posed car.
    var box: AABB=_physical_bounds(train)
    if not _outside_station_view(box,index): return false
    return _audio_quiet(train)

func _physical_bounds(train: Node3D) -> AABB:
    var box:=AABB()
    var found:=false
    for posed in train._pose_cars:
        if not is_instance_valid(posed.node): continue
        var part: AABB=posed.node.global_transform*(train._pose_cache[posed.node] as AABB)
        box=box.merge(part) if found else part
        found=true
    return box if found else service.line.path.frame_at(float(train.distance),float(train.track_x))*train._train_bounds

func _outside_station_view(box: AABB, index: int) -> bool:
    var region: AABB=service.line.streamer.station_camera_bounds(index)
    if region.size.length_squared()<1.0: return false
    var policy: Dictionary=service.line.layout.free_camera
    var allowed: AABB=region.grow(float(policy.station_exterior_margin))
    allowed.position.z=region.position.z-float(policy.station_tunnel_margin)
    allowed.size.z=region.size.z+2.0*float(policy.station_tunnel_margin)
    # Protect ALL legal station camera positions, not only its current gaze.
    # Camera far clipping proves invisibility without unprepared tunnel-ray
    # colliders, which formerly could prevent recycling indefinitely.
    var range_m: float=float(service.train.camera.far)+float(_policy.shuttle.visibility_margin_m)
    var separation:=Vector3(maxf(0.0,maxf(allowed.position.x-box.end.x,box.position.x-allowed.end.x)),
        maxf(0.0,maxf(allowed.position.y-box.end.y,box.position.y-allowed.end.y)),
        maxf(0.0,maxf(allowed.position.z-box.end.z,box.position.z-allowed.end.z)))
    if separation.length()<=range_m: return false
    for observer in [service.player.global_position,service.train.camera.global_position]:
        var nearest:=Vector3(clampf(observer.x,box.position.x,box.end.x),clampf(observer.y,box.position.y,box.end.y),clampf(observer.z,box.position.z,box.end.z))
        if observer.distance_to(nearest)<=range_m: return false
    return true

func _audio_quiet(train: Node3D) -> bool:
    var audio: Node=train.info_binding.audio
    if audio.announcer.is_busy(): return false
    var threshold: float=float(_policy.shuttle.recycle_below_db)
    for player in audio.train_audio._players:
        if player.playing and float(player.volume_db)>threshold: return false
    for channel in ["cab","doors"]:
        var player: AudioStreamPlayer=audio.effects._players.get(channel)
        if is_instance_valid(player) and player.playing and float(player.volume_db)>threshold: return false
    return true

func _retire(slot: Dictionary) -> void:
    var train: Node3D=slot.context.train
    if _occupied(train) or service.role!="passenger": return
    slot.automatic.disable()
    slot.context.passengers.retire_virtual_service()
    train.info_binding.audio.train_audio.stop_layers()
    for channel in ["cab","doors"]:
        var player: AudioStreamPlayer=train.info_binding.audio.effects._players.get(channel)
        if is_instance_valid(player): player.stop()
    train.service_ready=false
    train.train.hide()
    train.speed=0.0
    _collisions(train,false)
    slot.active=false
    service.virtual_wait=true
    records.clear()
    _terminal.erase(train.get_instance_id())
    service.line.streamer.refresh()

func _activate(data: Dictionary, slot: Dictionary, index: int, candidate: Dictionary) -> bool:
    var train: Node3D=slot.context.train
    if bool(slot.active) or _occupied(train) or platform_shuttle_station()!=index: return false
    if not _outside_station_view(candidate.bounds,index):
        data.reason="Точка подхода находится в области наблюдения"
        return false
    if train.cab_runtime.emergency:
        data.reason="Включён аварийный тормоз"
        return false
    if not train.door_system.can_move():
        data.reason="Не закрыты пассажирские двери"
        return false
    # The existing instance was hidden only after all four cars and their
    # sounds cleared the player. Never reload or instantiate V106 here.
    train.service_ready=false
    train.distance=float(candidate.z)
    train.train.position.z=train.distance
    train.track_x=float(_policy.track_x[str(candidate.direction)])
    train.cab_runtime.direction=int(candidate.direction)
    train.throttle=false
    train.brake=false
    train.cab_runtime.controller_value=0.0
    train.cab_runtime.brake_demand=0.0
    train.cab_runtime.applied_brake=0.0
    train.cab_runtime.traction_actual=0.0
    train.speed=float(candidate.speed)
    train._last_speed=train.speed
    train.info_binding.audio._last_speed=train.speed
    train.info_binding.audio._motion_sampled=false
    train._posed_distance=NAN
    train._place_consist()
    # Assert the actual posed envelope too, before showing any geometry.
    if not _outside_station_view(_physical_bounds(train),index):
        train.speed=0.0
        data.reason="Габариты состава ещё входят в область наблюдения"
        return false
    slot.id=str(data.id)
    slot.active=true
    slot.departure_seen=true
    records.clear()
    records[str(data.id)]=data
    train.set_meta("dispatch_train_id",str(data.id))
    service.virtual_wait=false
    train.info_binding.passenger_mode=true
    train.info_binding.audio.info.set_mode("auto")
    slot.automatic.approach_station(index,int(candidate.direction))
    slot.automatic.update_info()
    _collisions(train,true)
    train.train.show()
    train.service_ready=true
    data.state="APPROACHING"
    data.progress_at=_now()
    data.progress_z=float(train.distance)
    data.reason=""
    service.line.streamer.refresh()
    for tunnel in service.line.tunnels: tunnel.sync_to_view()
    return true

func _approach(index: int, direction: int, train: Node3D) -> Dictionary:
    if direction not in [1,-1]: return {}
    var incoming: int=-direction if (index==0 and direction>0) or (index==service.line.stations.size()-1 and direction<0) else direction
    var bounds: AABB=train._train_bounds
    var stop: float=float(service.line.stations[index].stop_z)
    var region: AABB=service.line.streamer.station_camera_bounds(index)
    var clearance: float=float(service.train.camera.far)+float(_policy.shuttle.visibility_margin_m)+float(service.line.layout.free_camera.station_tunnel_margin)+float(_policy.shuttle.pose_margin_m)+1.0
    # Put the nearest end of the whole train beyond the legal camera region.
    var z: float=region.end.z+clearance-bounds.position.z if incoming>0 else region.position.z-clearance-bounds.end.z
    var box:=AABB()
    var found:=false
    for probe in range(int(_policy.shuttle.spawn_probes)):
        var frame: Transform3D=service.line.path.frame_at(z,float(_policy.track_x[str(incoming)]))
        box=(frame*bounds).grow(float(_policy.shuttle.pose_margin_m))
        if box.position.z<service.line.path.lower_z+8.0 or box.end.z>96.0-8.0: return {}
        var tunnel_only:=true
        for end in [box.position.z,box.end.z,box.get_center().z]:
            if service.line.path.in_station(float(end),8.0): tunnel_only=false
        if tunnel_only and _outside_station_view(box,index):
            found=true
            break
        z+=float(incoming)*float(_policy.shuttle.spawn_probe_step_m)
    if not found: return {}
    var distance: float=(z-stop)*float(incoming)
    if distance<1.0: return {}
    var deceleration: float=float(service.rules.service.braking_deceleration)
    var speed: float=minf(float(service.rules.service.cruise_speed),sqrt(2.0*deceleration*maxf(0.0,distance-float(_policy.shuttle.braking_reserve_m))))
    # A rolling approach avoids accelerating the reused train from rest in a
    # distant tunnel. Speed is installed ONLY while fully hidden.
    var braking: float=speed*speed/(2.0*deceleration)
    var travel: float=maxf(0.0,distance-braking)/maxf(speed,0.1)+speed/deceleration
    return {"z":z,"direction":incoming,"speed":speed,"bounds":box,"travel_seconds":travel}

func adopt(car: Node3D) -> bool:
    register_current_train()
    var slot: Dictionary=slots[0]
    if not bool(slot.active) or car not in slot.context.passengers.layout.cars: return false
    pending.clear()
    _prefetch_targets.clear()
    # The character will immediately be parented to this same car; no lease,
    # camera, audio or passenger ownership transfer is necessary.
    var next: int=int(slot.automatic.target)
    if service.station_at_train()>=0: next+=int(slot.automatic.direction)
    if next>=0 and next<service.line.stations.size():
        _prefetch_targets[next]=_now()+float(_policy.shuttle.prefetch_seconds)
    return true

func streaming_requests() -> Array:
    var station: int=platform_shuttle_station()
    if station>=0: return [{"index":station,"priority":25000.0}]
    var result: Array=[]
    for slot in slots:
        if not bool(slot.active): continue
        var train: Node3D=slot.context.train
        var direction: int=int(train.cab_runtime.direction)
        var next: int=int(slot.automatic.target)
        result.append({"index":next,"priority":20000.0})
        if station_at_vehicle(train,slot.context.passengers)>=0: next+=direction
        if next>=0 and next<service.line.stations.size(): result.append({"index":next,"priority":5000.0})
    for key in _prefetch_targets.keys():
        if _now()>float(_prefetch_targets[key]): _prefetch_targets.erase(key)
        else: result.append({"index":int(key),"priority":5000.0})
    return result

func _prefetch(index: int) -> void:
    if index<0 or index>=service.line.stations.size() or platform_shuttle_station()>=0: return
    _prefetch_targets[index]=_now()+float(_policy.shuttle.prefetch_seconds)
    service.line.streamer.refresh()

func traffic_remaining(_actor: Node3D, _direction: int) -> float:
    return INF # Exactly one physical consist; it cannot collide with a second lease.

func has_blocked_dispatch() -> bool:
    return pending.get("state","")=="BLOCKED" or service.automatic.phase==service.automatic.Phase.BLOCKED

func retry_dispatch() -> void:
    if service.role!="passenger": return
    if not pending.is_empty() and pending.state=="BLOCKED":
        if bool(slots[0].active) and int(slots[0].automatic.target)==int(pending.station):
            slots[0].automatic.approach_station(int(pending.station),int(service.train.cab_runtime.direction))
            pending.state="APPROACHING"
            pending.progress_at=_now()
            pending.progress_z=float(service.train.distance)
        else:
            if service.automatic.phase==service.automatic.Phase.BLOCKED: service.automatic.retry_departure()
            pending.state="CLEARING" if bool(slots[0].active) else "REUSABLE"
        pending.attempts=0
        pending.retry_at=0.0
        # A retry keeps the original deadline; it never invents another train.
    elif service.automatic.phase==service.automatic.Phase.BLOCKED:
        service.automatic.retry_departure()
    _clock=0.0

func status_text() -> String:
    if not available: return "Нет корректных данных расписания"
    if service.role!="passenger": return ""
    if _occupied(service.train):
        return "К Площади Ленина" if int(service.automatic.direction)>0 else "К Уручью"
    var slot: Dictionary=_slot(service.train)
    if not slot.is_empty() and bool(slot.active) and service.automatic.phase==service.automatic.Phase.DWELL:
        return "Отправление примерно через %d с" % maxi(0,ceili(float(service.automatic._departure_at)-_now()))
    if pending.is_empty(): return "Ожидание отправления состава"
    var label: String="К Пл. Ленина" if int(pending.direction)>0 else "К Уручью"
    if pending.state=="ARRIVED": return label+" · посадка"
    var remaining: float=float(pending.arrival_at)-_now()
    if pending.state=="BLOCKED" or remaining<=0.0:
        return label+" · задержка: "+str(pending.get("reason","Ожидание безопасного прибытия"))
    return label+": %d с" % ceili(remaining)

func note_hidden(train: Node3D) -> void:
    if _occupied(train): return
    var slot: Dictionary=_slot(train)
    if slot.is_empty(): return
    slot.active=false
    service.virtual_wait=true

func terminal_ready(visit: int, train: Node3D=null) -> bool:
    var actor: Node3D=train if is_instance_valid(train) else service.train
    var call: Dictionary=_terminal.get(actor.get_instance_id(),{})
    return int(call.get("visit",-1))==visit and _now()>=float(call.get("ready_at",INF))


func service_for_car(car: Node3D) -> Node:
    for slot in slots:
        if bool(slot.active) and car in slot.context.passengers.layout.cars: return slot.context.gameplay
    return service if car in service.line.passengers.layout.cars else null


func boarding_cars() -> Array:
    var cars: Array=[]
    for slot in slots:
        if bool(slot.active): cars.append_array(slot.context.passengers.layout.cars)
    if slots.is_empty(): cars.assign(service.line.passengers.layout.cars)
    return cars


func station_at_vehicle(train: Node3D, passengers: Node3D) -> int:
    if absf(train.speed)>0.05: return -1
    for record in service.line.stations:
        var index: int=int(record.index)
        if not passengers.platform_ready(index): continue
        var navigation: RefCounted=passengers._platforms[index].navigation
        for door in passengers.layout.doors:
            var point: Vector3=passengers.layout.landing(door)
            if absf(door.marker.global_position.y-float(navigation.height))<0.6 and navigation.platform_area.has_point(Vector2(point.x,point.z)): return index
    return -1


func station_loaded(index: int, instance: Node3D) -> void:
    for slot in slots:
        if slot.context.passengers!=service.line.passengers:
            slot.context.passengers.add_platform(service.line.stations[index],instance)


func station_unloading(index: int, instance: Node3D) -> void:
    for slot in slots:
        if slot.context.passengers!=service.line.passengers: slot.context.passengers.remove_platform(index)
        slot.context.train.release_station(instance)


func can_unload_platform(index: int) -> bool:
    for slot in slots:
        if not slot.context.passengers.can_unload_platform(index): return false
    return true


func envelopes() -> Array:
    var result: Array=[]
    for slot in slots:
        if bool(slot.active): result.append({"train":slot.context.train,"bounds":slot.context.train._train_bounds})
    return result


func _slot(train: Node3D) -> Dictionary:
    for slot in slots:
        if slot.context.train==train: return slot
    return {}


func _occupied(train: Node3D) -> bool:
    return is_instance_valid(service.player) and is_instance_valid(service.player.aboard) and train.train.is_ancestor_of(service.player.aboard)


func _collisions(train: Node3D, enabled: bool) -> void:
    for body in train.train.find_children("*","CollisionObject3D",true,false):
        if body.has_meta("metro_native_walk"): body.collision_layer=(1<<17) if enabled else 0


func _notice(key: String, message: String) -> void:
    if _now()<float(_notices.get(key,0.0)): return
    _notices[key]=_now()+float(_policy.retry_seconds)
    service.ui.notice(message)
    push_warning("Train dispatch: "+message)


func _now() -> float:
    return float(Time.get_ticks_msec())/1000.0


func report_delay(key: String, message: String) -> void:
    _notice(key,message)

