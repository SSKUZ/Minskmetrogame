extends Node
const Geometry = preload("res://modules/gameplay/world_geometry.gd")
var service: Node
var cab_points: Array[Dictionary]=[]
var seat: Dictionary={}
var current: Dictionary={}
var _clock:=0.0

func initialize(owner_service: Node) -> void:
    service=owner_service

func _process(delta: float) -> void:
    if not service.running or service.direct_driver or not is_instance_valid(service.player): return
    _clock-=delta
    if _clock>0.0: return
    _clock=0.15
    # Cab access geometry is optional for platform startup. Build its authored
    # interaction points only when a walking player actually approaches the
    # stopped train; never block the role menu or passenger spawn on this work.
    if not service._cab_ready and not service._cab_busy and service._cab_error.is_empty() and service.train.train.visible and absf(service.train.speed)<0.05:
        var cab: Node3D=service.train.cab_runtime
        if is_instance_valid(cab) and service.player.global_position.distance_to(cab.global_position)<12.0:
            service.call_deferred("prepare_cab_access_points")
    current=_near_action()
    service.ui.interact.text=str(current.get("title","ВЗАИМОДЕЙСТВИЕ"))
    service.ui.interact.disabled=current.is_empty()

func _near_action() -> Dictionary:
    if service.direct_driver or not is_instance_valid(service.player) or not service.player.active: return {}
    var player: Node3D=service.player
    if service.driver_seated: return {"kind":"leave_driver","title":"ПОКИНУТЬ ПУЛЬТ"}
    if not seat.is_empty(): return {"kind":"stand","title":"ВСТАТЬ"}
    var car: Node3D=service.first_car()
    var cab: Node3D=service.train.cab_runtime
    var driver_point: Vector3=cab.to_global(Vector3(-0.55,0.08,2.12))
    var near_workplace: bool=service._cab_ready and service.role=="driver" and player.aboard==car and player.global_position.distance_to(driver_point)<1.15
    var inside: Dictionary=inside_cab()
    if not inside.is_empty():
        if near_workplace and not _looking_at(inside.entry.global_position):
            return {"kind":"drive","title":"ЗАНЯТЬ МЕСТО МАШИНИСТА"}
        return {"kind":"exit_cab","title":"ВЫЙТИ ИЗ КАБИНЫ"}
    if player.aboard==null and service.train.train.visible:
        for point in cab_points:
            var offset: Vector3=player.global_position-point.entry.global_position
            if Vector2(offset.x,offset.z).length()>float(point.rules.horizontal_range) or absf(offset.y)>float(point.rules.vertical_range): continue
            return {"kind":"enter_cab","cab":point,"title":"ВОЙТИ В КАБИНУ"}
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
        "enter_cab": enter_cab(current.cab)
        "exit_cab": exit_cab()

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
    if service.direct_driver or not is_instance_valid(service.player) or service.driver_seated or not service.player.active: return true
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
        var car: Node3D=player.aboard
        var state: Dictionary=car.get_meta("metro_walk_lite_train",{})
        if state.is_empty():
            player.global_position=previous
            player.velocity=Vector3.ZERO
            return
        var local: Vector3=car.to_local(player.global_position)
        var box: AABB=state.bounds
        var passage: bool=_passage(car,previous,player.global_position)
        if absf(local.x)>1.50 and passage:
            player.attach_car(null)
            service.line.streamer.refresh()
            return
        # Never detach because of a transient floor/transform discrepancy.
        # The car parent is the sole carrier; moving-platform transport is off.
        var radius: float=float(service.rules.walking.radius)
        var corrected: Vector3=local
        if not passage: corrected.x=clampf(local.x,box.position.x+radius,box.end.x-radius)
        corrected.z=clampf(local.z,box.position.z+radius,box.end.z-radius)
        if local.y<float(state.floor)-0.15:
            corrected.y=float(state.floor)+0.04
            player.velocity=Vector3.ZERO
        if not corrected.is_equal_approx(local): player.position=corrected
    else:
        for car in layout.cars:
            var state: Dictionary=car.get_meta("metro_walk_lite_train",{})
            if state.is_empty(): continue
            var local: Vector3=car.to_local(player.global_position)
            var box: AABB=state.bounds
            if absf(local.x)>1.10 or local.z<box.position.z or local.z>box.end.z or absf(local.y-float(state.floor))>0.60: continue
            if _passage(car,previous,player.global_position):
                player.attach_car(car)
                service.line.streamer.refresh()
            else:
                player.global_position=previous
                player.velocity=Vector3.ZERO
            return

func _passage(car: Node3D, from: Vector3, to: Vector3) -> bool:
    if absf(float(service.train.speed))>0.05: return false
    var a: Vector3=car.to_local(from)
    var b: Vector3=car.to_local(to)
    var layout=service.line.passengers.layout
    for door in layout.doors:
        if door.car!=car or not layout.usable(door) or not layout.platform_selected: continue
        var p: Vector3=door.marker.position
        if absf(b.z-p.z)>0.70 or absf(b.y-p.y)>0.60: continue
        if signf(b.x)!=float(door.side) or maxf(absf(a.x),absf(b.x))<1.1: continue
        var landing: Vector3=layout.landing(door,0.8)
        for record in service.line.stations:
            var index: int=int(record.index)
            if not service.line.passengers.platform_spawn_ready(index): continue
            var station: Node3D=service.line.station_instance(index)
            if service._geometry.covers(station,landing,0.5): return true
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
    # Original side doors remain closed; instant access has no door animation.
    return true

func inside_cab() -> Dictionary:
    if service.direct_driver or not is_instance_valid(service.player): return {}
    var player: Node3D=service.player
    if not is_instance_valid(player.aboard): return {}
    for point in cab_points:
        if point.car==player.aboard and (point.zone as AABB).has_point(point.car.to_local(player.global_position)):
            return point
    return {}

func enter_cab(point: Dictionary) -> void:
    if service.direct_driver or not is_instance_valid(service.player) or not service.running or not service.player.active or service.player.aboard!=null: return
    if point.entry.global_position.z>96.0:
        service.ui.notice("Пеший доступ в депо отключён. Для осмотра используйте полёт.")
        return
    if absf(float(service.train.speed))>float(point.rules.max_speed):
        service.ui.notice("Войти в кабину можно только после остановки")
        return
    var offset: Vector3=service.player.global_position-point.entry.global_position
    if Vector2(offset.x,offset.z).length()>float(point.rules.horizontal_range) or absf(offset.y)>float(point.rules.vertical_range): return
    var target: Vector3=_safe_cab_position(point,true)
    if not is_finite(target.y):
        service.ui.notice("В кабине пока нет свободной подготовленной точки входа")
        return
    _transfer(point.car,target,service.player.eye.global_basis)

func exit_cab() -> void:
    if service.direct_driver: return
    var point: Dictionary=inside_cab()
    if point.is_empty() or not service.running: return
    if absf(float(service.train.speed))>float(point.rules.max_speed):
        service.ui.notice("Выход из кабины запрещён во время движения")
        return
    var target: Vector3=_safe_cab_position(point,false)
    if not is_finite(target.y):
        service.ui.notice("Безопасный выход недоступен: нужна готовая платформа или пол депо")
        return
    var view: Basis=service.train.camera.global_basis
    if service.driver_seated: service.leave_driver()
    _transfer(null,target,view)

func _safe_cab_position(point: Dictionary, interior: bool) -> Vector3:
    var car: Node3D=point.car
    var marker: Marker3D=point.interior if interior else point.exterior
    var candidates: Array[Vector3]=[marker.global_position]
    var alternatives: Array=point.interior_alternatives if interior else point.exterior_alternatives
    for local in alternatives: candidates.append(car.to_global(local))
    var player: CharacterBody3D=service.player
    for candidate in candidates:
        # Only inspect already prepared physics. Interaction never loads models
        # or starts a collision/geometry preparation operation.
        if interior and not service._geometry.covers(car,candidate,0.5): continue
        var mask: int=Geometry.TRAIN if interior else Geometry.WORLD
        var ray:=PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*(0.75 if interior else 2.0),candidate-Vector3.UP*(0.4 if interior else 3.0),mask,[player.get_rid()])
        var hit: Dictionary=player.get_world_3d().direct_space_state.intersect_ray(ray)
        if hit.is_empty() or (hit.normal as Vector3).dot(Vector3.UP)<0.65: continue
        var surface_owner: Node=hit.collider as Node
        var floor: Vector3=hit.position
        if interior:
            if not is_instance_valid(surface_owner) or not car.is_ancestor_of(surface_owner) or absf(floor.y-candidate.y)>0.28: continue
        elif not _exterior_surface(floor,surface_owner): continue
        var query:=PhysicsShapeQueryParameters3D.new()
        query.shape=player.capsule.shape
        query.transform=Transform3D(Basis.IDENTITY,floor+Vector3.UP*(float(player.rules.height)*0.5+0.06))
        query.collision_mask=player.collision_mask
        query.exclude=[player.get_rid()]
        if not player.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
        return floor
    return Vector3(marker.global_position.x,NAN,marker.global_position.z)

func _exterior_surface(floor: Vector3, owner: Node) -> bool:
    if not is_instance_valid(owner): return false
    if floor.z>96.0: return false
    for record in service.line.stations:
        var index: int=int(record.index)
        if not service.line.passengers.platform_spawn_ready(index): continue
        var station: Node3D=service.line.station_instance(index)
        if not is_instance_valid(station) or not station.is_ancestor_of(owner): continue
        var nav: RefCounted=service.line.passengers._platforms[index].navigation
        var area: Rect2=nav.platform.grow(-float(service.rules.walking.radius)-0.05)
        if area.has_point(Vector2(floor.x,floor.z)) and absf(floor.y-float(nav.height))<0.25: return true
    return false

func _transfer(car: Node3D, floor: Vector3, view: Basis) -> void:
    var player: CharacterBody3D=service.player
    player.attach_car(car)
    player.global_position=floor+Vector3.UP*0.04
    player.velocity=Vector3.ZERO
    player.stick=Vector2.ZERO
    player._climb.clear()
    player._safe_position=player.global_position
    var local_view: Basis=player.global_basis.inverse()*view
    player.yaw=local_view.get_euler().y
    player.pitch=local_view.get_euler().x
    player._eye_pose()
    player.capsule.set_deferred("disabled",false)
    service.train.activate_character_view(player.eye)
    service.line.streamer.refresh()
