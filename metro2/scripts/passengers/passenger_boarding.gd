extends RefCounted
## Existing per-door queues and seat reservations; one assignment unit per frame.
var layout: RefCounted
var navigation: RefCounted
var platform_root: Node3D
var opened := false
var exchange_active := false
var _pending: Array=[]
var _stop_offset := 0.0

func assign(agents: Array,stop_offset: float) -> void:
    _stop_offset=stop_offset
    var units: Dictionary={}
    for a in agents:
        if a.space!="platform" or not a.wants_board or a.state not in ["waiting","waitingNextTrain"]: continue
        if _pending.any(func(unit):return unit.has(a)): continue
        var key: int=a.group_id if a.group_id>=0 else -a.id-1
        if not units.has(key): units[key]=[]
        units[key].append(a)
    for group in units.values(): _pending.append(group)

func _assign_one() -> void:
    if _pending.is_empty(): return
    var group: Array=_pending.pop_front()
    var group_car: Node3D
    for a in group:
        if not is_instance_valid(a) or a.space!="platform" or not a.wants_board: continue
        var choices: Array=[]
        for d in layout.doors:
            if not layout.usable(d): continue
            var target: Vector3=platform_root.to_local(layout.landing(d,1.65))+Vector3(0,0,_stop_offset)
            var score: float=a.position.distance_to(target)+float(d.enter.size())*2.0+float(d.exit.size())*3.0
            if is_instance_valid(group_car) and d.car!=group_car: score+=12.0
            choices.append({"door":d,"score":score})
        choices.sort_custom(func(left,right):return float(left.score)<float(right.score))
        for choice in choices:
            var d: Dictionary=choice.door
            var slot: Dictionary=layout.reserve(d.car,d.marker.position.z,a.id%4!=0)
            if slot.is_empty(): continue
            var target: Vector3=_queue_point(d,d.enter.size(),a)
            var path: Array[Vector3]=navigation.route(a.position,target)
            if path.is_empty(): layout.release(slot);continue
            group_car=d.car
            a.set_meta("queue_target",target)
            a.slot=slot
            a.door_id=d.id
            a.car=d.car
            a.follow(path,"queueing")
            d.enter.append(a)
            break
        # If capacity is temporarily reserved, the line retries unassigned
        # waiters after alighters have cleared. No extra passenger is admitted.

func _queue_point(d: Dictionary, rank: int, exclude: Node3D=null) -> Vector3:
    var result:=Vector3.ZERO
    for attempt in range(32):
        var place: int=rank+attempt
        var point: Vector3=layout.landing(d,1.65+float(int(place/2))*0.35)
        point+=d.car.global_basis.z.normalized()*(-1.0 if place%2==0 else 1.0)*(1.4+float(int(place/2))*0.7)
        point=platform_root.to_local(point)+Vector3(0,0,_stop_offset)
        result=navigation.free_point(point)
        var occupied:=false
        for other in layout.doors:
            for person in other.enter:
                if person==exclude: continue
                var target: Vector3=person.get_meta("queue_target",person.position)
                if target.distance_squared_to(result)<0.31: occupied=true;break
            if occupied: break
        if not occupied: return result
    return result

func cancel_waiters() -> void:
    _pending.clear()
    for d in layout.doors:
        for a in d.enter.duplicate():
            if a==d.active or a.space!="platform": continue
            layout.release(a.slot)
            a.slot={}
            a.path.clear();a.detour.clear()
            a.state="waiting"
            a.door_id=-1
            a.car=null
            a.animation.play("Idle")
            d.enter.erase(a)

func request_alight(agents: Array) -> void:
    for a in agents:
        if a.space!="train" or a.state not in ["riding","seated"]: continue
        var nearest: Dictionary={}
        var distance:=INF
        for d in layout.doors:
            if d.car!=a.car or not layout.usable(d): continue
            var score: float=absf(a.position.z-d.marker.position.z)+float(d.exit.size())
            if score<distance: distance=score;nearest=d
        # A car beyond the platform cannot discharge onto the track. Keep its
        # riders/reservations until a real door in that car becomes accessible.
        if nearest.is_empty(): continue
        a.door_id=nearest.id
        nearest.exit.append(a)
        if a.state=="seated":
            a.state="standingUp";a.animation.play("Stand up (chair)",false)
        else: a.state="exitQueued"

func can_step(a: Node3D) -> bool:
    var d: Dictionary=layout.door(a.door_id)
    return not d.is_empty() and layout.usable(d)

func update(agents: Array,can_exchange: bool) -> void:
    if not can_exchange:
        exchange_active=false
        return
    if not exchange_active:
        refresh_waiting_bays()
        exchange_active=true
    opened=true
    _assign_one()
    for d in layout.doors:
        var active=d.active
        if active!=null:
            if not layout.usable(d): continue
            if active.path.is_empty():
                if active.state=="boarding":
                    active.reparent(d.car,true)
                    active.space="train"
                    active.aisle=layout.aisle_bounds(d.car)
                    d.enter.erase(active);d.active=null
                    settle(active,d,agents)
                elif active.state=="alighting":
                    layout.release(active.slot)
                    active.reparent(platform_root,true)
                    active.space="platform"
                    active.slot={}
                    active.visual.position=Vector3.ZERO
                    active.wants_board=false
                    var out: Vector3=navigation.free_point(active.position+layout.outward(d)*0.8+d.car.global_basis.z.normalized()*1.7)
                    active.follow(navigation.route(active.position,out),"leaving")
                    if active.path.is_empty(): active.state="waitingNextTrain";active.animation.play("Idle")
                    d.exit.erase(active);d.active=null
            continue
        if not layout.usable(d): continue
        # Alighters have priority across the entire car, including passengers
        # still standing up, so boarders cannot occupy their route to the aisle.
        var car_exiting: bool=layout.doors.any(func(other):return other.car==d.car and (not other.exit.is_empty() or (other.active!=null and other.active.state=="alighting")))
        if not d.exit.is_empty():
            var a=d.exit[0]
            if a.state!="exitQueued": continue
            var seam: Vector3=d.marker.position
            var outside: Vector3=d.car.to_local(layout.landing(d))
            var path: Array[Vector3]=[Vector3(free_aisle_x(d.car,a.position.z,agents),a.position.y,a.position.z),Vector3(0,seam.y,seam.z),seam,outside]
            a.follow(path,"alighting");d.active=a
        elif not car_exiting and not d.enter.is_empty():
            var a=d.enter[0]
            if a.state!="queued" or a.slot.is_empty(): continue
            var approach: Vector3=platform_root.to_local(layout.landing(d))
            var path: Array[Vector3]=navigation.route(a.position,approach)
            if path.is_empty(): continue
            path.append(platform_root.to_local(d.marker.global_position))
            path.append(platform_root.to_local(d.car.to_global(Vector3(float(d.side)*0.35,d.marker.position.y,d.marker.position.z))))
            a.follow(path,"boarding");d.active=a

func settle(a: Node3D,d: Dictionary,agents: Array) -> void:
    if a.slot.is_empty(): a.slot=layout.reserve(d.car,a.position.z,a.id%4!=0)
    a.aisle=layout.aisle_bounds(d.car)
    if a.slot.is_empty(): a.state="riding";a.animation.play("Idle");return
    var point: Vector3=a.slot.position
    var path: Array[Vector3]=[Vector3(free_aisle_x(d.car,a.position.z,agents),a.position.y,a.position.z),Vector3(free_aisle_x(d.car,point.z,agents),point.y,point.z),point]
    a.follow(path,"settling")

func complete(agents: Array) -> bool:
    if not opened or not _pending.is_empty(): return false
    for d in layout.doors:
        if d.active!=null or not d.enter.is_empty() or not d.exit.is_empty(): return false
    for a in agents:
        if a.state in ["boarding","alighting","queueing","queued","settling","sittingDown","standingUp","exitQueued"]: return false
    return true

func refresh_waiting_bays() -> void:
    for d in layout.doors:
        var rank:=0
        for a in d.enter:
            if a==d.active or a.space!="platform": continue
            var point: Vector3=_queue_point(d,rank,a)
            a.set_meta("queue_target",point)
            var path: Array[Vector3]=navigation.route(a.position,point)
            if not path.is_empty(): a.follow(path,"queueing")
            rank+=1

func free_aisle_x(car: Node3D,z: float,agents: Array) -> float:
    for other in agents:
        if other.space=="train" and other.car==car and other.state=="riding" and other.path.is_empty() and absf(other.position.z-z)<0.7 and absf(other.position.x)<0.65:
            return -signf(other.position.x)*0.35
    return 0.0
