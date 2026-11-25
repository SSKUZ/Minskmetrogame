extends RefCounted
## A timetable contains scalar calls only. The existing V106 remains the sole
## physical consist, including when an occupied service reverses at a terminal.
var service: Node
var pending: Dictionary={}
var terminal_call: Dictionary={}
var next_direction:=1
var serial:=0

func initialize(owner_service: Node) -> void:
    service=owner_service

func cancel() -> void:
    pending.clear()
    terminal_call.clear()

func schedule(index: int) -> void:
    serial+=1
    pending={"id":serial,"station":index,"direction":next_direction,
        "arrival_at":_now()+float(service.rules.service.interval)}

func begin_call(index: int, direction: int, visit: int) -> void:
    var next: int=index+direction
    if next>=0 and next<service.line.stations.size():
        terminal_call.clear()
        return
    if int(terminal_call.get("visit",-1))==visit: return
    terminal_call={"station":index,"incoming":direction,"outgoing":-direction,
        "visit":visit,"departure_at":_now()+float(service.rules.service.interval)}

func terminal_ready(visit: int) -> bool:
    return int(terminal_call.get("visit",-1))==visit and _now()>=float(terminal_call.departure_at)

func update() -> void:
    if not service.running or service.role!="passenger": return
    # Parenting to a car is the authoritative occupied state, including seats
    # and the driving position; a camera outside the train cannot override it.
    if is_instance_valid(service.player.aboard): return
    if not service.virtual_wait:
        var away: float=(service.player.global_position.z-float(service.train.distance))*float(service.train.cab_runtime.direction)
        if away<float(service.rules.service.retire_distance): return
        if not _outside_view(float(service.train.distance)): return
        if not service.interaction.doorway_clear(): return
        service._retire_train()
        var station: Dictionary=service.line.path.nearest_station(service.player.global_position.z)
        schedule(int(station.index))
        service.line.streamer.refresh()
        return
    var observed: Dictionary=service.line.path.nearest_station(service.player.global_position.z)
    var index: int=int(observed.index)
    if pending.is_empty() or int(pending.station)!=index: schedule(index)
    if not service.line.passengers.platform_ready(index): return
    var direction: int=int(pending.direction)
    var candidate: Dictionary=_approach(index,direction)
    if candidate.is_empty():
        direction=-direction
        candidate=_approach(index,direction)
    if candidate.is_empty(): return
    var z: float=candidate.z
    if not _outside_view(z): return
    var distance: float=absf(z-float(observed.stop_z))
    var deceleration: float=float(service.rules.service.braking_deceleration)
    var acceleration: float=float(service.rules.service.acceleration_estimate)
    var peak: float=minf(float(service.rules.service.cruise_speed),sqrt(2.0*distance/(1.0/acceleration+1.0/deceleration)))
    var used: float=peak*peak*0.5*(1.0/acceleration+1.0/deceleration)
    var travel: float=peak/acceleration+peak/deceleration+maxf(0.0,distance-used)/maxf(peak,0.1)
    if _now()<float(pending.arrival_at)-travel: return
    # Only a hidden, empty service may be placed at its distant tunnel origin.
    # Subsequent approach, stop and departure use the original train physics.
    var train: Node3D=service.train
    train.distance=z
    train.train.position.z=z
    train.track_x=0.992 if direction>0 else -11.732
    train.cab_runtime.direction=direction
    train._posed_distance=NAN
    train._place_consist()
    service._hold_cab()
    train.door_system.request_close()
    service.virtual_wait=false
    train.train.show()
    service._train_collisions(true)
    train.service_ready=true
    service.automatic.approach_station(index,direction)
    next_direction=-direction
    pending.clear()
    service.line.streamer.refresh()
    for tunnel in service.line.tunnels: tunnel.sync_to_view()

func _approach(index: int, direction: int) -> Dictionary:
    var train: Node3D=service.train
    var bounds: AABB=train._train_bounds
    var stop: float=float(service.line.stations[index].stop_z)
    var z: float=clampf(stop+float(direction)*float(service.rules.service.appearance_distance),
        service.line.path.lower_z-bounds.position.z+8.0,96.0-bounds.end.z-8.0)
    if (z-stop)*float(direction)<float(service.rules.service.minimum_approach): return {}
    for end in [z+bounds.position.z,z+bounds.end.z,z+bounds.get_center().z]:
        if service.line.path.in_station(float(end),8.0): return {}
    return {"z":z}

func _outside_view(z: float) -> bool:
    if is_instance_valid(service.player.aboard): return false
    var bounds: AABB=service.train._train_bounds
    var clearance: float=float(service.rules.service.visibility_clearance)
    # The complete consist must clear both the physical person and the current
    # inspection camera. This also protects platform/free camera views.
    for observer in [service.player.global_position,service.train.camera.global_position]:
        var closest: float=clampf(observer.z,z+bounds.position.z,z+bounds.end.z)
        if absf(closest-observer.z)<clearance: return false
    return true

func _now() -> float:
    return float(Time.get_ticks_msec())/1000.0
