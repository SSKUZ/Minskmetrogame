extends RefCounted
## Port of PassengerDoorChoice + PassengerBoardingController.
## Each physical door serves alighters before a single boarding passenger.
var layout: RefCounted
var navigation: RefCounted
var platform_root: Node3D
var opened := false
var exchange_active := false

func assign(agents: Array,stop_offset: float) -> void:
    var units: Dictionary={}
    for a in agents:
        if a.space!="platform" or not a.wants_board: continue
        var key: int=a.group_id if a.group_id>=0 else 10000+a.id
        if not units.has(key): units[key]=[]
        units[key].append(a)
    var loads: Dictionary={}
    var car_loads: Dictionary={}
    for d in layout.doors: loads[d.id]=0
    for group in units.values():
        var best: Dictionary={}
        var score := INF
        for d in layout.doors:
            var free: int = layout.places.filter(func(p):return p.car==d.car and not p.used).size()
            if int(car_loads.get(d.car,0))+group.size()>free: continue
            var target: Vector3=d.marker.global_position+Vector3(-1.5,0,stop_offset)
            target.y=1.1805
            var walk := 0.0
            var accessible := true
            for a in group:
                var path: Array[Vector3]=navigation.route(a.global_position,target)
                if path.is_empty(): accessible=false;break
                var previous: Vector3=a.global_position
                var length := 0.0
                for point in path: length+=previous.distance_to(point);previous=point
                walk=maxf(walk,length/a.walk_speed)
            var value: float=walk*1.2+float(loads[d.id])*2.0+float(car_loads.get(d.car,0))*0.5
            if accessible and value<score:score=value;best=d
        if best.is_empty(): continue
        for a in group:
            a.door_id=best.id;a.car=best.car
            var rank: int=loads[best.id]
            var q: Vector3=best.marker.global_position+Vector3(-1.5-float(int(rank/2))*0.35,0,stop_offset+(-1.0 if rank%2==0 else 1.0)*(1.28+float(int(rank/2))*0.65))
            q.y=1.1805
            a.follow(navigation.route(a.global_position,q),"queueing")
            best.enter.append(a)
            loads[best.id]+=1
        car_loads[best.car]=int(car_loads.get(best.car,0))+group.size()

func request_alight(agents: Array) -> void:
    for a in agents:
        if a.space!="train" or a.state not in ["riding","seated"]: continue
        var nearest: Dictionary={}
        var distance := INF
        for d in layout.doors:
            if d.car!=a.car: continue
            var score: float=absf(a.position.z-d.marker.position.z)+d.exit.size()
            if score<distance:distance=score;nearest=d
        if nearest.is_empty(): continue
        a.door_id=nearest.id
        nearest.exit.append(a)
        if a.state=="seated":
            a.state="standingUp";a.animation.play("Stand up (chair)",false)
        else:a.state="exitQueued"
        layout.release(a.slot)

func update(agents: Array,can_exchange: bool) -> void:
    if not can_exchange:
        exchange_active=false
        return
    if not exchange_active:
        refresh_waiting_bays()
        exchange_active=true
    opened=true
    for d in layout.doors:
        var active=d.active
        if active!=null:
            if active.path.is_empty():
                if active.state=="boarding":
                    active.reparent(d.car,true)
                    active.space="train"
                    active.aisle=layout.aisle_bounds(d.car)
                    d.enter.erase(active);d.active=null
                    settle(active,d,agents)
                elif active.state=="alighting":
                    active.reparent(platform_root,true)
                    active.space="platform"
                    active.slot={}
                    active.visual.position=Vector3.ZERO
                    active.state="leaving"
                    var out: Vector3=active.position+Vector3(-1.2,0,1.7)
                    out.y=1.1805
                    active.follow(navigation.route(active.position,out),"leaving")
                    d.exit.erase(active);d.active=null
            continue
        if not d.exit.is_empty():
            var a=d.exit[0]
            if a.state!="exitQueued": continue
            var seam: Vector3=d.marker.position
            var outside: Vector3=d.car.to_local(d.marker.global_position+Vector3(-1.25,0,0))
            outside.y=d.car.to_local(Vector3(0,1.1805,0)).y
            var path: Array[Vector3]=[Vector3(free_aisle_x(d.car,a.position.z,agents),a.position.y,a.position.z),Vector3(0,seam.y,seam.z),seam,outside]
            a.follow(path,"alighting");d.active=a
        elif not d.enter.is_empty():
            var a=d.enter[0]
            if a.state!="queued": continue
            var seam: Vector3=d.marker.global_position
            var approach:=seam+Vector3(-1.0,0,0)
            approach.y=1.1805
            var path: Array[Vector3]=navigation.route(a.global_position,approach)
            if path.is_empty(): continue
            path.append(seam)
            path.append(d.car.to_global(Vector3(-0.35,d.marker.position.y,d.marker.position.z)))
            a.follow(path,"boarding");d.active=a

func settle(a: Node3D,d: Dictionary,agents: Array) -> void:
    var seat_preference: bool=a.id%4!=0
    a.slot=layout.reserve(d.car,a.position.z,seat_preference)
    a.aisle=layout.aisle_bounds(d.car)
    if a.slot.is_empty():
        a.state="riding";a.animation.play("Idle");return
    var p: Vector3=a.slot.position
    var path: Array[Vector3]=[Vector3(0,a.position.y,a.position.z),Vector3(free_aisle_x(d.car,p.z,agents),p.y,p.z),p]
    a.follow(path,"settling")

func complete(agents: Array) -> bool:
    if not opened: return false
    for d in layout.doors:
        if d.active!=null or not d.enter.is_empty() or not d.exit.is_empty(): return false
    for a in agents:
        if a.state in ["boarding","alighting","queueing","queued","settling","sittingDown","standingUp","exitQueued"]: return false
    return true

func refresh_waiting_bays() -> void:
    # The driver's actual stop may differ from the predicted stop. Re-form side
    # queues around the real open doorway, leaving its central passage clear.
    for d in layout.doors:
        var rank:=0
        for a in d.enter:
            if a==d.active or a.space!="platform":continue
            var point: Vector3=d.marker.global_position
            point.x-=1.65+float(int(rank/2))*0.35
            point.z+=(-1.0 if rank%2==0 else 1.0)*(1.4+float(int(rank/2))*0.7)
            point.y=1.1805
            a.follow(navigation.route(a.global_position,point),"queueing")
            rank+=1

func free_aisle_x(car: Node3D,z: float,agents: Array) -> float:
    for other in agents:
        if other.space=="train" and other.car==car and other.state=="riding" and other.path.is_empty() and absf(other.position.z-z)<0.7 and absf(other.position.x)<0.65:
            return -signf(other.position.x)*0.35
    return 0.0
