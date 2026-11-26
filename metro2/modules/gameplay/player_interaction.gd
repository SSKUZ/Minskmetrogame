extends Node
var service: Node
var cab_doors: Array[Dictionary]=[]
var seat: Dictionary={}
var current: Dictionary={}
var _clock:=0.0

func initialize(owner_service: Node) -> void:
    service=owner_service

func _process(_delta: float) -> void:
    if not service.running: return
    for door in cab_doors:
        var native: Node3D=door.native
        if bool(door.open)!=bool(native.open): native.set_open(bool(door.open))
        door.open=native.open
        door.fraction=native.fraction
    _clock-=_delta
    if _clock>0.0: return
    _clock=0.15
    current=_near_action()
    service.ui.interact.text=str(current.get("title","ВЗАИМОДЕЙСТВИЕ"))
    service.ui.interact.disabled=current.is_empty()

func _near_action() -> Dictionary:
    if not service.player.active: return {}
    var player: Node3D=service.player
    if service.driver_seated: return {"kind":"leave_driver","title":"ПОКИНУТЬ ПУЛЬТ"}
    if not seat.is_empty(): return {"kind":"stand","title":"ВСТАТЬ"}
    var car: Node3D=service.first_car()
    var cab: Node3D=service.train.cab_runtime
    # Native cab's original chair was moved by _fit_cab_to_v106.
    if not service._cab_ready:
        var values: Array=service.rules.cab_access[0].threshold
        var threshold:=Vector3(float(values[0]),float(values[1]),float(values[2]))
        if player.global_position.distance_to(car.to_global(threshold))<3.0:
            return {"kind":"prepare_cab","title":"КАБИНА · ПОДГОТОВКА ДВЕРЕЙ" if service._cab_busy else "КАБИНА · ПОВТОРИТЬ ПОДГОТОВКУ"}
    var driver_point: Vector3=cab.to_global(Vector3(-0.55,0.08,2.12))
    var near_workplace: bool=service._cab_ready and service.role=="driver" and player.aboard==car and player.global_position.distance_to(driver_point)<1.15
    for door in cab_doors:
        var door_car: Node3D=door.car
        var point: Vector3=door_car.to_global(door.threshold)
        var local: Vector3=door_car.to_local(player.global_position)
        var flat: Vector2=Vector2(local.x,local.z)-Vector2(door.threshold.x,door.threshold.z)
        if flat.length()>1.35 or absf(service.train.speed)>0.05: continue
        if int(door.side)!=0 and door.open and float(door.fraction)>=0.99 and player.aboard==null and absf(local.y-float(door.threshold.y))>0.35:
            return {"kind":"climb","door":door,"title":"ВОЙТИ В КАБИНУ · ПОДНЯТЬСЯ"}
        if player.global_position.distance_to(point)<2.1 and (not near_workplace or _looking_at(point)):
            return {"kind":"cab_door","door":door,"title":"ЗАКРЫТЬ ДВЕРЬ КАБИНЫ" if door.open else "ОТКРЫТЬ ДВЕРЬ КАБИНЫ"}
    if near_workplace: return {"kind":"drive","title":"ЗАНЯТЬ МЕСТО МАШИНИСТА"}
    if is_instance_valid(player.aboard):
        for place in service.line.passengers.layout.places:
            if not place.seated or place.used or place.car!=player.aboard: continue
            var target: Vector3=place.car.to_global(place.position)
            if player.global_position.distance_to(target)>0.85: continue
            if _clear_reach(player.global_position+Vector3.UP*0.65,target+Vector3.UP*0.55):
                return {"kind":"sit","place":place,"title":"СЕСТЬ"}
    return {}

func activate() -> void:
    current=_near_action()
    match str(current.get("kind","")):
        "prepare_cab":
            if service._cab_busy: service.ui.notice("Подключение готовых боковых дверей V106")
            else: service.call_deferred("_prepare")
        "drive": service.occupy_driver()
        "leave_driver": service.leave_driver()
        "stand": stand()
        "sit":
            var place: Dictionary=current.place
            if place.used: return
            place.used=true
            seat=place
            service.player.seated=true
            service.player.global_position=place.car.to_global(place.position)
            service.player.basis=Basis.IDENTITY
            service.player.eye.position.y=float(place.height)-float(place.position.y)+0.75
            service.player.capsule.disabled=true
            service.player.yaw=float(place.heading)
            service.player.pitch=0.0
        "cab_door":
            var point: Vector3=current.door.car.to_local(service.player.global_position)
            var doorway: Vector3=current.door.threshold
            if current.door.open and Vector2(point.x-doorway.x,point.z-doorway.z).length()<0.42:
                service.ui.notice("Отойдите от проёма, чтобы закрыть дверь")
            else: current.door.open=not bool(current.door.open)
        "climb":
            var door: Dictionary=current.door
            var car: Node3D=door.car
            var local: Vector3=car.to_local(service.player.global_position)
            var outer: Vector3=door.threshold+Vector3(float(door.side)*0.50,0.04,0)
            var inner: Vector3=door.threshold-Vector3(float(door.side)*0.55,-0.04,0)
            var points: Array[Vector3]=[car.to_global(Vector3(local.x,outer.y,outer.z)),car.to_global(outer),car.to_global(inner)]
            service.player.climb_door(points)

func stand() -> void:
    if seat.is_empty(): return
    var player: Node3D=service.player
    var car: Node3D=seat.car
    var point:=Vector3(float(seat.position.x)*0.25,1.033,float(seat.position.z))
    var query:=PhysicsShapeQueryParameters3D.new()
    query.shape=player.capsule.shape
    query.transform=Transform3D(car.global_basis,car.to_global(point)+car.global_basis.y*float(player.rules.height)*0.5)
    query.collision_mask=player.collision_mask
    query.exclude=[player.get_rid()]
    if not player.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
        service.ui.notice("Проход занят. Дождитесь свободного места.")
        return
    player.global_position=car.to_global(point)
    service.line.passengers.layout.release(seat)
    seat={}
    player.seated=false
    player.capsule.disabled=false
    player.eye.position.y=float(player.rules.eye_height)

func doorway_clear() -> bool:
    if service.driver_seated or not service.player.active: return true
    for door in service.line.passengers.layout.doors:
        var p: Vector3=door.car.to_local(service.player.global_position)
        var seam: Vector3=door.marker.position
        if absf(p.x-seam.x)<0.44 and absf(p.z-seam.z)<0.92 and absf(p.y-seam.y)<0.65:
            return false
    return true

func guard_doors() -> void:
    if doorway_clear(): return
    var doors: Node=service.train.door_system
    for door in service.line.passengers.layout.doors:
        var p: Vector3=door.car.to_local(service.player.global_position)
        if absf(p.x-door.marker.position.x)<0.44 and absf(p.z-door.marker.position.z)<0.92 and float(doors.side_open[int(door.side)])>0.01:
            doors.side_targets[int(door.side)]=true
            doors.target_open=true

func update_car_membership(previous: Vector3) -> void:
    var player: Node3D=service.player
    if service.driver_seated or player.seated: return
    var layout=service.line.passengers.layout
    if is_instance_valid(player.aboard):
        var local: Vector3=player.aboard.to_local(player.global_position)
        var bounds: AABB=service.train._pose_cache.get(player.aboard,AABB())
        if local.y<0.6 or local.z<bounds.position.z-0.4 or local.z>bounds.end.z+0.4:
            player.attach_car(null)
            service.line.streamer.refresh()
            return
        if absf(local.x)<1.48: return
        if not _passage(player.aboard,previous,player.global_position):
            player.global_position=previous
            player.velocity=Vector3.ZERO
            return
        player.attach_car(null)
        service.line.streamer.refresh()
    else:
        for car in layout.cars:
            var local: Vector3=car.to_local(player.global_position)
            var box: AABB=service.train._pose_cache.get(car,AABB())
            if absf(local.x)>1.35 or local.z<box.position.z or local.z>box.end.z or local.y<0.85 or local.y>1.60: continue
            if _passage(car,previous,player.global_position):
                player.attach_car(car)
                service.line.streamer.refresh()
            else:
                player.global_position=previous
                player.velocity=Vector3.ZERO
            return

func _passage(car: Node3D, from: Vector3, to: Vector3) -> bool:
    var a: Vector3=car.to_local(from)
    var b: Vector3=car.to_local(to)
    for door in service.line.passengers.layout.doors:
        if door.car!=car or not service.line.passengers.layout.usable(door): continue
        var p: Vector3=door.marker.position
        if absf(b.z-p.z)<0.73 and absf(b.y-p.y)<0.50: return true
    for door in cab_doors:
        if door.car==car and door.open and float(door.fraction)>0.95 and absf(b.z-door.threshold.z)<0.42 and absf(b.y-door.threshold.y)<0.55: return true
    return false

func _clear_reach(from: Vector3, to: Vector3) -> bool:
    var query:=PhysicsRayQueryParameters3D.create(from,to,service.player.collision_mask,[service.player.get_rid()])
    return service.player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _looking_at(point: Vector3) -> bool:
    var offset: Vector3=point-service.player.global_position
    var gaze: Vector3=-service.player.eye.global_basis.z
    offset.y=0.0
    gaze.y=0.0
    return offset.normalized().dot(gaze.normalized())>0.45

func close_cab_for_departure() -> bool:
    var clear:=true
    for door in cab_doors:
        var local: Vector3=door.car.to_local(service.player.global_position)
        if float(door.fraction)<=0.01 and not door.open: continue
        var delta: Vector3=local-door.threshold
        if not service.driver_seated and Vector2(delta.x,delta.z).length()<0.48 and absf(delta.y)<0.65:
            clear=false
            continue
        door.open=false
        if float(door.fraction)>0.01: clear=false
    return clear
