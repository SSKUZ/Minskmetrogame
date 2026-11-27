extends RefCounted
## Portable virtual records are separate from at most two physical V106 leases.
const Context=preload("res://modules/gameplay/dispatch_context.gd")
const Background=preload("res://modules/gameplay/dispatch_service.gd")
var service: Node
var pending: Dictionary={}
var terminal_call: Dictionary={}
var records: Dictionary={}
var slots: Array[Dictionary]=[]
var serial:=0
var _epoch:=0.0
var _clock:=0.0
var _observed:=-1
var _enabled:=false
var _spawning:=false
var _offsets: Dictionary={}
var _durations: Dictionary={}
var _terminal: Dictionary={}
var _notices: Dictionary={}
var available:=true
var _policy: Dictionary={}
var _prefetch_targets: Dictionary={}

func initialize(owner_service: Node) -> void:
    service=owner_service
    _policy=service.rules.get("dispatch",{})
    var required: Array=["handover_departure_seconds","dwell_seconds","door_closing_lead_seconds","terminal_dwell_seconds","headway_seconds","direction_offsets_seconds","track_x","maximum_physical_trains","minimum_gap_m","refresh_seconds","prepare_lead_seconds","maximum_lateness_seconds","retry_seconds","maximum_spawn_attempts","visual_prepare_timeout_seconds","operation_timeout_seconds","boarding_grace_seconds"]
    for key in required:
        if not _policy.has(key): available=false
    if not available:
        push_error("Train dispatch: отсутствуют данные расписания")
        return
    if float(_policy.headway_seconds)<=0.0 or int(_policy.maximum_physical_trains)<1 or int(_policy.maximum_physical_trains)>2 or not _policy.track_x.has("1") or not _policy.track_x.has("-1") or not _policy.direction_offsets_seconds.has("1") or not _policy.direction_offsets_seconds.has("-1"):
        available=false
        push_error("Train dispatch: некорректные направления или интервалы расписания")
        return
    _epoch=_now()
    for direction in [1,-1]:
        var indices: Array=range(service.line.stations.size())
        if direction<0: indices.reverse()
        var offsets: Dictionary={}
        var elapsed:=0.0
        var previous:=-1
        for index in indices:
            if previous>=0:
                elapsed+=float(_policy.dwell_seconds)+_travel(absf(float(service.line.stations[index].stop_z)-float(service.line.stations[previous].stop_z)))
            offsets[index]=elapsed
            previous=index
        _offsets[direction]=offsets
        _durations[direction]=elapsed+float(_policy.dwell_seconds)

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
    # A manual driver's own lease is never retired or repositioned.

func schedule(index: int) -> void:
    if not available:
        service.ui.notice("Нет корректных данных расписания")
        return
    register_current_train()
    _enabled=true
    _observed=index
    _refresh_records()

func handover(train: Node3D) -> void:
    if not available: return
    register_current_train()
    _enabled=true
    var slot: Dictionary=_slot(train)
    if slot.is_empty(): return
    serial+=1
    var id: String="handover:%d" % serial
    slot.id=id
    slot.active=true
    var index: int=station_at_vehicle(train,slot.context.passengers)
    var direction: int=int(slot.automatic.direction)
    if direction not in [1,-1]:
        _notice("direction","Не определено направление отправления")
        return
    var offset: float=float(_offsets[direction].get(index,0.0))
    records[id]=_record(id,direction,_now()-offset)
    train.set_meta("dispatch_train_id",id)
    _prefetch(index+direction)

func begin_call(index: int, direction: int, visit: int, train: Node3D=null) -> void:
    var actor: Node3D=train if is_instance_valid(train) else service.train
    var slot: Dictionary=_slot(actor)
    if not slot.is_empty() and records.has(str(slot.id)):
        var data: Dictionary=records[str(slot.id)]
        data.last_served_station=index
        data.state="DWELL"
        data.boarding_available=false
        data.next_station=index+direction
    var following: int=index+direction
    _prefetch(following if following>=0 and following<service.line.stations.size() else index-direction)
    if following>=0 and following<service.line.stations.size(): return
    var token: int=actor.get_instance_id()
    if int(_terminal.get(token,{}).get("visit",-1))!=visit:
        _terminal[token]={"visit":visit,"ready_at":_now()+float(_policy.terminal_dwell_seconds)}

func terminal_ready(visit: int, train: Node3D=null) -> bool:
    var actor: Node3D=train if is_instance_valid(train) else service.train
    var call: Dictionary=_terminal.get(actor.get_instance_id(),{})
    return int(call.get("visit",-1))==visit and _now()>=float(call.get("ready_at",INF))

func update() -> void:
    if not service.running or not available: return
    register_current_train()
    for slot in slots.duplicate():
        if not is_instance_valid(slot.context): continue
        var train: Node3D=slot.context.train
        slot.context.ready_for_service=service.line.ready_for_service
        if not bool(slot.active): continue
        _update_physical_record(slot)
        if train==service.train and service.role=="driver": continue
        if _occupied(train) or not _outside_view(train,float(train.distance)): continue
        var actor: CharacterBody3D=service.player
        if not is_instance_valid(actor) or not actor.active: continue
        var away: float=absf(actor.global_position.z-float(train.distance))
        if away<float(service.rules.service.retire_distance): continue
        if not slot.context.gameplay.interaction.doorway_clear() or not slot.context.passengers.doors_clear(): continue
        _retire(slot)
    _clock-=service.get_physics_process_delta_time()
    if _clock>0.0: return
    _clock=float(_policy.refresh_seconds)
    if not _enabled or service.role!="passenger" or not is_instance_valid(service.player) or not service.player.active: return
    if is_instance_valid(service.player.aboard): return
    _observed=service.line.streamer.player_station_index()
    if _observed<0: return
    _refresh_records()
    if not service.line.streamer.is_service_ready(_observed): return
    var candidates: Array=[]
    for id in records:
        var data: Dictionary=records[id]
        if _physical_id(str(id)) or str(data.state) in ["COMPLETE","BLOCKED"]: continue
        if int(data.get("last_served_station",-1))==_observed: continue
        var arrival: float=float(data.origin_at)+float(_offsets[int(data.direction)][_observed])
        if arrival<_now()-float(_policy.maximum_lateness_seconds): continue
        data.arrival_at=arrival
        data.next_station=_observed
        candidates.append(data)
    candidates.sort_custom(func(a: Dictionary,b: Dictionary):return float(a.arrival_at)<float(b.arrival_at))
    for data in candidates:
        if _spawning: break
        var probe: Dictionary=_approach(_observed,int(data.direction),service.train)
        if probe.is_empty():
            if float(data.arrival_at)<=_now(): _notice("direction:%s" % data.id,"Нет безопасной точки появления для направления по расписанию")
            continue
        var travel: float=_travel(absf(float(probe.z)-float(service.line.stations[_observed].stop_z)))
        if _now()<float(data.arrival_at)-travel-float(_policy.prepare_lead_seconds): continue
        _prefetch(_observed+int(data.direction))
        if Time.get_ticks_msec()<int(data.get("retry_at",0)): continue
        if int(data.get("attempts",0))>=int(_policy.maximum_spawn_attempts):
            data.state="BLOCKED"
            continue
        var free: Dictionary={}
        for slot in slots:
            if not bool(slot.active) and not _occupied(slot.context.train): free=slot;break
        if free.is_empty() and slots.size()>=int(_policy.maximum_physical_trains):
            _notice("pool","Прибытие задерживается: оба состава ещё используются")
            continue
        if not _track_clear(float(probe.z),int(data.direction),service.train):
            _notice("track","Прибытие задерживается: участок пути занят")
            continue
        if not _outside_view(service.train,float(probe.z),true,int(data.direction)):
            if float(data.arrival_at)<=_now(): _notice("visibility","Прибытие ожидает безопасного участка вне области наблюдения")
            continue
        _spawning=true
        data.attempts=int(data.get("attempts",0))+1
        _activate(data,free,_observed)
        break
    if not candidates.is_empty():
        var next: Dictionary=candidates[0]
        pending={"id":next.id,"station":_observed,"direction":next.direction,"arrival_at":next.arrival_at}

func _record(id: String, direction: int, origin: float) -> Dictionary:
    return {"id":id,"direction":direction,"track_x":float(_policy.track_x[str(direction)]),
        "segment_from":-1,"segment_to":0 if direction>0 else service.line.stations.size()-1,
        "next_station":0 if direction>0 else service.line.stations.size()-1,
        "origin_at":origin,"arrival_at":origin,"dwell_seconds":float(_policy.dwell_seconds),
        "state":"VIRTUAL","boarding_available":false,"last_served_station":-1,"attempts":0,"retry_at":0}

func _refresh_records() -> void:
    var headway: float=maxf(20.0,float(_policy.headway_seconds))
    for direction in [1,-1]:
        var phase: float=float(_policy.direction_offsets_seconds[str(direction)])
        var sequence: int=floori((_now()-_epoch-phase)/headway)
        var count: int=ceili(float(_durations[direction])/headway)+2
        for n in range(sequence-count,sequence+2):
            var id: String="%d:%d" % [direction,n]
            if not records.has(id): records[id]=_record(id,direction,_epoch+phase+float(n)*headway)
    for id in records.keys():
        if _physical_id(str(id)): continue
        var data: Dictionary=records[id]
        var age: float=_now()-float(data.origin_at)
        if age>float(_durations[int(data.direction)])+headway:
            records.erase(id)
            continue
        if str(data.state)=="BLOCKED": continue
        data.state="COMPLETE" if age>float(_durations[int(data.direction)]) else "RUN"
        data.boarding_available=false
        var indices: Array=range(service.line.stations.size())
        if int(data.direction)<0: indices.reverse()
        var previous:=-1
        for index in indices:
            var eta: float=float(data.origin_at)+float(_offsets[int(data.direction)][index])
            if _now()<=eta+float(data.dwell_seconds):
                data.segment_from=previous
                data.segment_to=index
                data.next_station=index
                data.arrival_at=eta
                data.state="DWELL" if _now()>=eta else "RUN"
                break
            previous=index

func _update_physical_record(slot: Dictionary) -> void:
    if not records.has(str(slot.id)): return
    var data: Dictionary=records[str(slot.id)]
    var automatic: Node=slot.automatic
    data.direction=int(automatic.direction)
    data.track_x=float(slot.context.train.track_x)
    data.next_station=int(automatic.target)
    data.segment_from=int(data.get("last_served_station",-1))
    data.segment_to=int(automatic.target)
    data.state="BLOCKED" if automatic.phase==automatic.Phase.BLOCKED else ("RUN" if automatic.phase==automatic.Phase.RUN else "DWELL")
    if automatic.phase==automatic.Phase.RUN:
        data.arrival_at=_now()+_travel(absf(float(slot.context.train.distance)-float(service.line.stations[int(automatic.target)].stop_z)))
    data.boarding_available=absf(slot.context.train.speed)<0.05 and bool(slot.context.train.door_system.target_open) and float(slot.context.train.door_system.openness)>=0.99 and slot.context.passengers.platform_ready(int(automatic.target))

func _activate(data: Dictionary, slot: Dictionary, index: int) -> void:
    var planned_arrival: float=float(data.arrival_at)
    if slot.is_empty(): slot=await _create_secondary()
    if slot.is_empty():
        data.retry_at=Time.get_ticks_msec()+int(float(_policy.retry_seconds)*1000.0)
        _spawning=false
        return
    var train: Node3D=slot.context.train
    var direction: int=int(data.direction)
    var launch_at: float=planned_arrival-_travel(absf(float(_approach(index,direction,train).get("z",train.distance))-float(service.line.stations[index].stop_z)))
    while _now()<launch_at:
        if not is_instance_valid(service):
            _spawning=false
            return
        if not service.is_inside_tree() or service.role!="passenger" or is_instance_valid(service.player.aboard):
            _discard_idle(slot)
            _spawning=false
            return
        await service.get_tree().process_frame
    if not is_instance_valid(service):
        _spawning=false
        return
    if not service.is_inside_tree() or service.role!="passenger" or not service.running or is_instance_valid(service.player.aboard) or index!=_observed:
        data.attempts=maxi(0,int(data.attempts)-1)
        _discard_idle(slot)
        _spawning=false
        return
    var candidate: Dictionary=_approach(index,direction,train)
    if candidate.is_empty() or not _track_clear(float(candidate.get("z",0)),direction,train) or not _outside_view(train,float(candidate.get("z",0)),true,direction):
        data.retry_at=Time.get_ticks_msec()+int(float(_policy.retry_seconds)*1000.0)
        _discard_idle(slot)
        _spawning=false
        return
    # Only a hidden and unoccupied lease may be rebound to another virtual ID.
    if _occupied(train) or bool(slot.active):
        _notice("occupied","Состав занят игроком; перенос отменён")
        _spawning=false
        return
    var authority: Node=slot.context.gameplay
    train.service_ready=false
    train.distance=float(candidate.z)
    train.route_end_distance=minf(float(train.route_end_distance),float(candidate.z))
    train.train.position.z=train.distance
    train.track_x=float(_policy.track_x[str(direction)])
    train.cab_runtime.direction=int(candidate.direction)
    train.speed=0.0
    train.cab_runtime.controller_value=-1.0
    train.cab_runtime.brake_demand=1.0
    train.door_system.request_close()
    train._posed_distance=NAN
    train._place_consist()
    slot.id=str(data.id)
    slot.active=true
    authority.virtual_wait=false
    slot.context.ready_for_service=service.line.ready_for_service
    slot.context.show()
    train.train.show()
    _collisions(train,true)
    train.service_ready=true
    train.info_binding.passenger_mode=true
    train.info_binding.audio.info.set_mode("auto")
    train.set_meta("dispatch_train_id",str(data.id))
    slot.automatic.approach_station(index,int(candidate.direction))
    data.arrival_at=planned_arrival
    data.state="ACTIVE"
    data.boarding_available=false
    service.line.streamer.refresh()
    for tunnel in service.line.tunnels: tunnel.sync_to_view()
    _spawning=false

func _create_secondary() -> Dictionary:
    if slots.size()>=int(_policy.maximum_physical_trains): return {}
    var context=Context.new()
    context.hide()
    service.line.add_child(context)
    context.configure(service.line)
    var background=Background.new()
    context.add_child(background)
    context.gameplay=background
    var script: Script=load("res://modules/line/line_train.gd") as Script
    if script==null or not script.can_instantiate():
        context.queue_free()
        _notice("visual","Не загружен существующий контроллер V106")
        return {}
    var train: Node3D=script.new()
    context.train=train
    train.line=context
    train.set_meta("dispatch_background",true)
    context.add_child(train)
    service.train.camera.make_current()
    var deadline: int=Time.get_ticks_msec()+int(float(_policy.visual_prepare_timeout_seconds)*1000.0)
    while is_instance_valid(train) and is_instance_valid(service) and (not is_instance_valid(train.info_binding) or not is_instance_valid(train._flight_ui) or train._pose_cars.size()!=4):
        train._place_consist()
        if service.role!="passenger" or (is_instance_valid(service.player) and is_instance_valid(service.player.aboard)):
            context.queue_free()
            return {}
        if Time.get_ticks_msec()>=deadline or not service.is_inside_tree():
            context.queue_free()
            _notice("visual","Не завершена подготовка состава V106; будет повторная попытка")
            return {}
        await service.get_tree().process_frame
    if not is_instance_valid(train) or not is_instance_valid(service) or not service.is_inside_tree(): return {}
    train.train.hide()
    train._ui_layer.hide()
    train.camera.clear_current()
    if is_instance_valid(train.info_binding._button): train.info_binding._button.hide()
    service.train.camera.make_current()
    train.cab_runtime.set_process_input(false)
    train.cab_runtime.set_process_unhandled_input(false)
    var passenger_script: Script=load("res://modules/line/line_passengers.gd") as Script
    if passenger_script==null or not passenger_script.can_instantiate():
        context.queue_free()
        _notice("passengers","Не загружена существующая пассажирская система")
        return {}
    var passengers: Node3D=passenger_script.new()
    context.passengers=passengers
    context.add_child(passengers)
    passengers.initialize_line(context,train)
    background.configure(self,context)
    var automatic_script: Script=load("res://modules/gameplay/automatic_service.gd") as Script
    if automatic_script==null or not automatic_script.can_instantiate():
        context.queue_free()
        _notice("automatic","Не загружен автоматический контроллер")
        return {}
    var automatic: Node=automatic_script.new()
    background.add_child(automatic)
    background.automatic=automatic
    automatic.initialize(background)
    # Register the pending lease before yielding: the existing streamer's
    # ownership check then protects platforms whose navigation is being read.
    var slot: Dictionary={"context":context,"background":background,"automatic":automatic,"id":"","active":false}
    slots.append(slot)
    for key in service.line.streamer.instances.keys():
        var instance: Node3D=service.line.station_instance(int(key))
        if is_instance_valid(instance): await passengers.add_platform(service.line.stations[int(key)],instance)
    if not background._geometry.prepare_train(background):
        slots.erase(slot)
        context.queue_free()
        _notice("collisions",background._geometry.error_message)
        return {}
    return slot

func _retire(slot: Dictionary) -> void:
    var train: Node3D=slot.context.train
    if _occupied(train) or (train==service.train and service.role=="driver"): return
    if records.has(str(slot.id)):
        var data: Dictionary=records[str(slot.id)]
        var target: int=int(slot.automatic.target)
        data.origin_at=_now()+_travel(absf(float(train.distance)-float(service.line.stations[target].stop_z)))-float(_offsets[int(data.direction)][target])
        data.state="VIRTUAL"
        data.boarding_available=false
    slot.automatic.disable()
    slot.context.gameplay.virtual_wait=true
    slot.context.passengers.retire_virtual_service()
    train.service_ready=false
    train.train.hide()
    train.speed=0.0
    train.cab_runtime.controller_value=-1.0
    train.cab_runtime.brake_demand=1.0
    _collisions(train,false)
    slot.active=false
    if train==service.train:
        service.virtual_wait=true # One hidden lease remains reusable; no new GLBs.
    else:
        _terminal.erase(train.get_instance_id())
        slots.erase(slot)
        slot.context.hide()
        slot.context.queue_free() # Release the second scene, audio, NPC and resource references.
    service.line.streamer.refresh()

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

func adopt(car: Node3D) -> bool:
    register_current_train()
    var desired: Dictionary={}
    for slot in slots:
        if bool(slot.active) and car in slot.context.passengers.layout.cars: desired=slot;break
    if desired.is_empty(): return false
    var train: Node3D=desired.context.train
    if train==service.train: return true
    if service.role!="passenger" or absf(train.speed)>0.05 or is_instance_valid(service.player.aboard): return false
    var old: Dictionary=_slot(service.train)
    if not old.is_empty():
        old.background.running=true
        old.background.virtual_wait=not bool(old.active)
        old.context.gameplay=old.background
        old.automatic.service=old.background
        old.context.train.set_meta("dispatch_background",true)
        old.context.train._ui_layer.hide()
        old.context.train._flight_ui.stick=Vector2.ZERO
        old.context.train.cab_runtime.set_process_input(false)
        old.context.train.cab_runtime.set_process_unhandled_input(false)
        old.context.train.camera.clear_current()
    desired.background.running=false
    desired.context.gameplay=service
    desired.automatic.service=service
    service.train=train
    service.line.train=train
    service.line.passengers=desired.context.passengers
    service.automatic=desired.automatic
    service.virtual_wait=false
    service._cab_ready=false
    service._cab_busy=false
    service._cab_error=""
    service.interaction.cab_points.clear()
    train.set_meta("dispatch_background",false)
    train.cab_runtime.set_process_input(true)
    train.cab_runtime.set_process_unhandled_input(true)
    train.activate_character_view(service.player.eye)
    for tunnel in service.line.tunnels: tunnel.configure(train.train,train._train_bounds,train.camera)
    service.line.streamer.refresh()
    return true

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

func streaming_requests() -> Array:
    var result: Array=[]
    for slot in slots:
        if not bool(slot.active): continue
        var train: Node3D=slot.context.train
        var direction: int=int(train.cab_runtime.direction)
        if slot.context.gameplay.role=="passenger" and slot.automatic.phase!=slot.automatic.Phase.IDLE:
            var next: int=int(slot.automatic.target)
            result.append({"index":next,"priority":20000.0})
            if station_at_vehicle(train,slot.context.passengers)>=0:
                var following: int=next+direction
                next=following if following>=0 and following<service.line.stations.size() else next-direction
            if next>=0 and next<service.line.stations.size(): result.append({"index":next,"priority":5000.0})
        var bounds: AABB=train._train_bounds
        for record in service.line.stations:
            if float(train.distance)+bounds.end.z>=float(record.low)-152.0 and float(train.distance)+bounds.position.z<=float(record.high)+152.0:
                result.append({"index":int(record.index),"priority":25000.0})
    for key in _prefetch_targets.keys():
        if _now()>float(_prefetch_targets[key]):
            _prefetch_targets.erase(key)
            continue
        result.append({"index":int(key),"priority":5000.0})
    if _enabled and pending.has("direction") and pending.has("station"):
        var next: int=int(pending.station)+int(pending.direction)
        if next>=0 and next<service.line.stations.size(): result.append({"index":next,"priority":5000.0})
    return result

func _prefetch(index: int) -> void:
    if index<0 or index>=service.line.stations.size(): return
    _prefetch_targets[index]=_now()+float(_policy.headway_seconds)
    # refresh() consumes streaming_requests; it owns all station work.
    service.line.streamer.refresh()

func _slot(train: Node3D) -> Dictionary:
    for slot in slots:
        if slot.context.train==train: return slot
    return {}

func _physical_id(id: String) -> bool:
    for slot in slots:
        if bool(slot.active) and str(slot.id)==id: return true
    return false

func _occupied(train: Node3D) -> bool:
    return is_instance_valid(service.player) and is_instance_valid(service.player.aboard) and train.train.is_ancestor_of(service.player.aboard)

func _track_clear(z: float, direction: int, actor: Node3D) -> bool:
    var x: float=float(_policy.track_x[str(direction)])
    for slot in slots:
        if not bool(slot.active): continue
        var other: Node3D=slot.context.train
        if absf(float(other.track_x)-x)>3.0: continue
        var bounds: AABB=other._train_bounds
        var margin: float=float(_policy.minimum_gap_m)+float(other.speed)*float(other.speed)/(2.0*float(service.rules.service.braking_deceleration))+absf(float(other.speed))+2.0
        if z+actor._train_bounds.end.z+margin>float(other.distance)+bounds.position.z and z+actor._train_bounds.position.z-margin<float(other.distance)+bounds.end.z: return false
    return true

func traffic_remaining(actor: Node3D, direction: int) -> float:
    var remaining:=INF
    for slot in slots:
        var other: Node3D=slot.context.train
        if not bool(slot.active) or other==actor or absf(float(other.track_x)-float(actor.track_x))>3.0: continue
        var lead: float=float(actor.distance)+(actor._train_bounds.position.z if direction>0 else actor._train_bounds.end.z)
        var rear: float=float(other.distance)+(other._train_bounds.end.z if direction>0 else other._train_bounds.position.z)
        var gap: float=(lead-rear)*float(direction)-float(_policy.minimum_gap_m)
        if int(other.cab_runtime.direction)*direction<0:
            gap-=float(other.speed)*float(other.speed)/(2.0*float(service.rules.service.braking_deceleration))+absf(float(other.speed))+2.0
        if (float(actor.distance)-float(other.distance))*float(direction)>0.0: remaining=minf(remaining,maxf(0.0,gap))
    return remaining

func _approach(index: int, direction: int, train: Node3D) -> Dictionary:
    if direction not in [1,-1]: return {}
    # At a route origin, arrive from the existing line and turn around through
    # the original terminal service. Never invent track beyond the end, change
    # the scheduled outbound direction or move a visible train across tracks.
    var incoming: int=-direction if (index==0 and direction>0) or (index==service.line.stations.size()-1 and direction<0) else direction
    var bounds: AABB=train._train_bounds
    var stop: float=float(service.line.stations[index].stop_z)
    var z: float=clampf(stop+float(incoming)*float(service.rules.service.appearance_distance),service.line.path.lower_z-bounds.position.z+8.0,96.0-bounds.end.z-8.0)
    if (z-stop)*float(incoming)<float(service.rules.service.minimum_approach): return {}
    for end in [z+bounds.position.z,z+bounds.end.z,z+bounds.get_center().z]:
        if service.line.path.in_station(float(end),8.0): return {}
    return {"z":z,"direction":incoming}

func _outside_view(train: Node3D, z: float, spawning: bool=false, direction: int=1) -> bool:
    if not spawning and _occupied(train): return false
    var bounds: AABB=train._train_bounds.grow(float(service.line.layout.free_camera.train_end_margin))
    var observers: Array[Vector3]=[]
    if is_instance_valid(service.player) and service.player.active: observers.append(service.player.global_position)
    if is_instance_valid(service.train.camera): observers.append(service.train.camera.global_position)
    for observer in observers:
        var closest: float=clampf(observer.z,z+bounds.position.z,z+bounds.end.z)
        if absf(closest-observer.z)<float(service.rules.service.visibility_clearance): return false
    # Never rebind a lease while any part of its envelope is in the active
    # camera frustum. Turning away or an already travelled bend permits reuse.
    var camera: Camera3D=service.train.camera
    if is_instance_valid(camera):
        var x: float=float(_policy.track_x[str(direction)]) if spawning else float(train.track_x)
        var frame: Transform3D=service.line.path.frame_at(z,x)
        var samples: Array[Vector3]=[bounds.get_center(),Vector3(bounds.get_center().x,bounds.get_center().y,bounds.position.z),Vector3(bounds.get_center().x,bounds.get_center().y,bounds.end.z)]
        for corner in range(8): samples.append(bounds.get_endpoint(corner))
        for local in samples:
            var point: Vector3=frame*local
            if camera.is_position_in_frustum(point):
                var query:=PhysicsRayQueryParameters3D.create(camera.global_position,point,1<<16)
                var hit: Dictionary=service.line.get_world_3d().direct_space_state.intersect_ray(query)
                if hit.is_empty(): return false
    return true

func _collisions(train: Node3D, enabled: bool) -> void:
    for body in train.train.find_children("*","CollisionObject3D",true,false):
        if body.has_meta("metro_native_walk"): body.collision_layer=(1<<17) if enabled else 0

func _travel(distance: float) -> float:
    var acceleration: float=float(service.rules.service.acceleration_estimate)
    var deceleration: float=float(service.rules.service.braking_deceleration)
    var peak: float=minf(float(service.rules.service.cruise_speed),sqrt(2.0*distance/(1.0/acceleration+1.0/deceleration)))
    var used: float=peak*peak*0.5*(1.0/acceleration+1.0/deceleration)
    return peak/acceleration+peak/deceleration+maxf(0.0,distance-used)/maxf(peak,0.1)

func _notice(key: String, message: String) -> void:
    if _now()<float(_notices.get(key,0.0)): return
    _notices[key]=_now()+float(_policy.retry_seconds)
    service.ui.notice(message)
    push_warning("Train dispatch: "+message)

func _now() -> float:
    return float(Time.get_ticks_msec())/1000.0

func _discard_idle(slot: Dictionary) -> void:
    if not is_instance_valid(service): return
    if slot.is_empty() or not is_instance_valid(slot.context) or slot.context.train==service.train or bool(slot.active): return
    slots.erase(slot)
    slot.context.queue_free()

func report_delay(key: String, message: String) -> void:
    _notice(key,message)

func has_blocked_dispatch() -> bool:
    for slot in slots:
        if slot.automatic.phase==slot.automatic.Phase.BLOCKED: return true
    for data in records.values():
        if str(data.state)=="BLOCKED": return true
    return false

func retry_dispatch() -> void:
    if service.role!="passenger": return
    for slot in slots:
        if slot.automatic.phase==slot.automatic.Phase.BLOCKED: slot.automatic.retry_departure()
    for data in records.values():
        if str(data.state)=="BLOCKED":
            data.state="VIRTUAL"
            data.attempts=0
            data.retry_at=0
    _clock=0.0

func status_text() -> String:
    if not available: return "Нет корректных данных расписания"
    if service.role!="passenger": return ""
    var slot: Dictionary=_slot(service.train)
    if not slot.is_empty() and bool(slot.active) and slot.automatic.phase==slot.automatic.Phase.DWELL:
        return "Отправление примерно через %d с" % maxi(0,ceili(float(slot.automatic._departure_at)-_now()))
    if is_instance_valid(service.player) and is_instance_valid(service.player.aboard):
        var direction: int=int(service.train.cab_runtime.direction)
        var station: int=service.station_at_train()
        if station>=0 and (station+direction<0 or station+direction>=service.line.stations.size()): direction=-direction
        return "К Площади Ленина" if direction>0 else "К Уручью"
    var times: Dictionary={1:INF,-1:INF}
    for data in records.values():
        if str(data.state) in ["COMPLETE","BLOCKED"] or int(data.get("last_served_station",-1))==_observed: continue
        var direction: int=int(data.direction)
        var eta: float=float(data.origin_at)+float(_offsets[direction].get(_observed,INF))
        if eta>=_now(): times[direction]=minf(float(times[direction]),eta)
    var text: PackedStringArray=[]
    for direction in [1,-1]:
        if is_finite(float(times[direction])):
            text.append(("К Пл. Ленина" if direction>0 else "К Уручью")+": %d с" % maxi(0,ceili(float(times[direction])-_now())))
    return " · ".join(text)

func note_hidden(train: Node3D) -> void:
    if _occupied(train): return
    var slot: Dictionary=_slot(train)
    if slot.is_empty(): return
    slot.active=false
    slot.context.gameplay.virtual_wait=true
    if records.has(str(slot.id)):
        records[str(slot.id)].state="VIRTUAL"
        records[str(slot.id)].boarding_available=false
