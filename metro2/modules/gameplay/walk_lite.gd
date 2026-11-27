extends RefCounted
## Simple invisible constraints. No mesh faces, triangulation or render edits.
const Seats=preload("res://modules/gameplay/station_seating.gd")
const Budget=preload("res://modules/line/build_budget.gd")
const WORLD:=1<<16
const TRAIN:=1<<17
var error_message:=""

static func v(a: Array) -> Vector3:
    return Vector3(float(a[0]),float(a[1]),float(a[2]))

static func array3(p: Vector3) -> Array:
    return [p.x,p.y,p.z]

static func encode(t: Transform3D) -> Array:
    return [array3(t.basis.x),array3(t.basis.y),array3(t.basis.z),array3(t.origin)]

static func decode(a: Array) -> Transform3D:
    return Transform3D(Basis(v(a[0]),v(a[1]),v(a[2])),v(a[3]))

static func box_record(box: AABB, pose: Transform3D, label: String) -> Dictionary:
    return {"kind":"box","size":array3(box.size),"pose":encode(pose*Transform3D(Basis.IDENTITY,box.get_center())),"label":label}

func describe_station(root: Node3D, navigation: Dictionary={}) -> Dictionary:
    var records: Array=[]
    var bench_seats: Array=[]
    var seen: Dictionary={}
    var nodes: Array[Node]=[root]
    var inverse: Transform3D=root.global_transform.affine_inverse()
    var budget=Budget.new(root,1500)
    var floor_found:=false
    var platform_box:=AABB()
    while not nodes.is_empty():
        var node: Node=nodes.pop_back()
        if node is Node3D and node.has_meta(Seats.CAPTURE):
            var center_x: float=-5.37
            if not navigation.is_empty():
                var area: Array=navigation.get("area",[])
                if area.size()==4: center_x=float(area[0])+float(area[2])*0.5
            bench_seats.append_array(Seats.extract(node,inverse*node.global_transform,center_x))
        if node is CollisionObject3D and node.has_meta("metro_native_walk"): continue
        nodes.append_array(node.get_children())
        if not await budget.checkpoint(): return {}
        if node is CollisionShape3D and node.shape!=null and not node.disabled:
            var native: Shape3D=node.shape
            var pose: Transform3D=inverse*node.global_transform
            var record: Dictionary={}
            var dimensions:=Vector3.ZERO
            if native is BoxShape3D:
                dimensions=native.size
                record=box_record(AABB(-dimensions*0.5,dimensions),pose,"existing_physical_box")
            elif native is CylinderShape3D or native is CapsuleShape3D:
                dimensions=Vector3(native.radius*2.0,native.height,native.radius*2.0)
                record={"kind":"capsule" if native is CapsuleShape3D else "cylinder","radius":native.radius,"height":native.height,
                    "size":array3(dimensions),"pose":encode(pose),"label":"existing_physical_column"}
            if not record.is_empty():
                var bounds: AABB=pose*AABB(-dimensions*0.5,dimensions)
                record["bounds"]=[array3(bounds.position),array3(bounds.size)]
                var key: String=str(record.pose)+str(record.size)
                if not seen.has(key):
                    seen[key]=true
                    records.append(record)
            continue
        if not node is GeometryInstance3D: continue
        var ancestor: Node=node
        var visible:=true
        while ancestor!=root:
            if ancestor is Node3D and not ancestor.visible: visible=false;break
            ancestor=ancestor.get_parent()
        if not visible: continue
        var label: String=str(root.get_path_to(node)).to_lower()
        if ["light","lamp","advert","poster","cable","wire","sign","letter","clock"].any(func(word): return label.contains(word)): continue
        var mesh: Mesh
        var poses: Array[Transform3D]=[]
        if node is MeshInstance3D and node.mesh!=null and node.skin==null:
            mesh=node.mesh
            poses.append(inverse*node.global_transform)
        elif node is MultiMeshInstance3D and node.multimesh!=null:
            mesh=node.multimesh.mesh
            var count: int=node.multimesh.instance_count if node.multimesh.visible_instance_count<0 else mini(node.multimesh.instance_count,node.multimesh.visible_instance_count)
            for i in range(count):
                poses.append(inverse*node.global_transform*node.multimesh.get_instance_transform(i))
                if i%64==0 and not await budget.checkpoint(): return {}
        else: continue
        if mesh==null: continue
        var box: AABB=mesh.get_aabb()
        var semantic: bool=["platform","floor","wall","column","pillar","bench","stair","step","landing","escalator","turnstile","fence","barrier","railing","passage","contact"].any(func(word):return label.contains(word))
        var structural: bool=(box.size.x>4.0 and box.size.z>4.0 and box.size.y<0.6) or (box.size.y>1.3 and minf(box.size.x,box.size.z)<0.8)
        if not semantic and not structural: continue
        # Large batched architecture cannot be represented by its enclosing box.
        # Its body-height furniture footprints come from prepared navigation.
        if not mesh is PrimitiveMesh and not label.contains("islandplatform") and not (box.size.y<0.35 or minf(box.size.x,box.size.z)<0.18): continue
        for pose in poses:
            if absf(pose.basis.determinant())<0.0000001: continue
            var bounds: AABB=pose*box
            if bounds.size.length()<0.08: continue
            var record: Dictionary=box_record(box,pose,label)
            if mesh is CylinderMesh:
                record["kind"]="cylinder"
                record["radius"]=maxf(mesh.top_radius,mesh.bottom_radius)
                record["height"]=mesh.height
            if label.contains("islandplatform"):
                floor_found=true
                platform_box=bounds
            var key: String=str(record.pose)+str(record.size)
            if seen.has(key): continue
            seen[key]=true
            record["bounds"]=[array3(bounds.position),array3(bounds.size)]
            if bounds.position.y>=0.10 and bounds.end.y<=0.32 and bounds.size.x<=0.18 and (absf(bounds.get_center().x-2.472)<0.12 or absf(bounds.get_center().x+13.212)<0.12):
                record["electric"]=true
            records.append(record)
    if not navigation.is_empty():
        var height: float=float(navigation.height)
        for values in navigation.get("obstacles",[]):
            var obstacle:=AABB(Vector3(float(values[0]),height+0.08,float(values[1])),Vector3(float(values[2]),1.65,float(values[3])))
            var covered:=false
            for record in records:
                var existing:=AABB(v(record.bounds[0]),v(record.bounds[1]))
                var footprint:=Rect2(existing.position.x,existing.position.z,existing.size.x,existing.size.z)
                if existing.end.y>height+0.15 and footprint.encloses(Rect2(obstacle.position.x,obstacle.position.z,obstacle.size.x,obstacle.size.z)): covered=true;break
            if covered: continue
            var record: Dictionary=box_record(obstacle,Transform3D.IDENTITY,"prepared_navigation_obstacle")
            record["bounds"]=[array3(obstacle.position),array3(obstacle.size)]
            records.append(record)
    if navigation.is_empty() and floor_found:
        var area:=Rect2(platform_box.position.x,platform_box.position.z,platform_box.size.x,platform_box.size.z)
        var walk: Rect2=area.grow(-0.30)
        var obstacles: Array=[]
        for record in records:
            var obstacle:=AABB(v(record.bounds[0]),v(record.bounds[1]))
            if obstacle.end.y<platform_box.end.y+0.15 or obstacle.position.y>platform_box.end.y+1.65: continue
            if obstacle.size.x>8.0 or obstacle.size.z>18.0: continue
            obstacles.append([obstacle.position.x,obstacle.position.z,obstacle.size.x,obstacle.size.z])
        navigation={"height":platform_box.end.y,"area":[area.position.x,area.position.y,area.size.x,area.size.y],
            "walk":[walk.position.x,walk.position.y,walk.size.x,walk.size.y],"obstacles":obstacles}
    return {"schema":1,"units":"metres","records":records,"floor_verified":floor_found,"navigation":navigation,"bench_seats":bench_seats}

func prepare_region(root: Node3D, point: Vector3, radius: float=18.0) -> bool:
    if root==null:
        error_message="Не загружена станция"
        return false
    var data: Dictionary=root.get_meta("metro_walk_lite_data",{})
    if data.is_empty() or not bool(data.get("floor_verified",false)):
        error_message="Нет подготовленного описания пола платформы"
        return false
    var local: Vector3=root.to_local(point)
    var area:=AABB(local-Vector3.ONE*radius,Vector3.ONE*radius*2.0)
    var state: Dictionary=root.get_meta("metro_walk_lite_region",{})
    # A role/camera change does not invalidate already prepared walking space.
    # Only extend it when the requested region actually exceeds that coverage.
    if not state.is_empty() and bool(state.ready) and (state.area as AABB).encloses(area):
        return true
    if state.is_empty():
        var body:=StaticBody3D.new()
        body.name="LightWalkingConstraints"
        body.collision_layer=WORLD
        body.collision_mask=0
        body.set_meta("metro_native_walk",true)
        root.add_child(body)
        state={"body":body,"parts":{},"ready":false,"area":area}
        root.set_meta("metro_walk_lite_region",state)
    var budget=Budget.new(root,1500)
    for i in range(data.records.size()):
        # Skipped records also consume main-thread time. Previously the budget
        # yielded only after creating a shape, leaving full-table scans unsliced.
        if i%128==0 and not await budget.checkpoint(): return false
        var record: Dictionary=data.records[i]
        var bounds:=AABB(v(record.bounds[0]),v(record.bounds[1]))
        if not area.intersects(bounds) or state.parts.has(i): continue
        var collision:=CollisionShape3D.new()
        if record.kind=="capsule":
            var shape:=CapsuleShape3D.new()
            shape.radius=float(record.radius)
            shape.height=float(record.height)
            collision.shape=shape
        elif record.kind=="cylinder":
            var shape:=CylinderShape3D.new()
            shape.radius=float(record.radius)
            shape.height=float(record.height)
            collision.shape=shape
        else:
            var shape:=BoxShape3D.new()
            shape.size=v(record.size).max(Vector3.ONE*0.015)
            collision.shape=shape
        var pose: Transform3D=decode(record.pose)
        var scale:=Vector3(pose.basis.x.length(),pose.basis.y.length(),pose.basis.z.length())
        if collision.shape is BoxShape3D: collision.shape.size*=scale
        elif collision.shape is CylinderShape3D or collision.shape is CapsuleShape3D:
            collision.shape.radius*=maxf(scale.x,scale.z)
            collision.shape.height*=scale.y
        collision.transform=Transform3D(pose.basis.orthonormalized(),pose.origin)
        var part: Node=collision
        if bool(record.get("electric",false)):
            var hazard:=StaticBody3D.new()
            hazard.name="OriginalContactRailLimit"
            hazard.collision_layer=1<<18
            hazard.collision_mask=0
            hazard.set_meta("metro_electric",true)
            state.body.add_child(hazard)
            hazard.add_child(collision)
            part=hazard
        else: state.body.add_child(collision)
        state.parts[i]={"node":part,"bounds":bounds}
        if not await budget.checkpoint(): return false
    for i in state.parts.keys():
        if not area.grow(radius).intersects(state.parts[i].bounds):
            state.parts[i].node.queue_free()
            state.parts.erase(i)
    state.area=area
    state.ready=true
    return true

func covers(root: Node3D, point: Vector3, margin: float=1.0) -> bool:
    if not is_instance_valid(root): return false
    if root.has_meta("metro_walk_lite_train"): return true
    var state: Dictionary=root.get_meta("metro_walk_lite_region",{})
    return not state.is_empty() and state.ready and (state.area as AABB).grow(-margin).has_point(root.to_local(point))

func _box(parent: Node3D, name: String, center: Vector3, size: Vector3) -> CollisionShape3D:
    var collision:=CollisionShape3D.new()
    collision.name=name
    var shape:=BoxShape3D.new()
    shape.size=size.max(Vector3.ONE*0.02)
    collision.shape=shape
    collision.position=center
    parent.add_child(collision)
    return collision

func prepare_train(service: Node) -> bool:
    var layout=service.line.passengers.layout
    for car in layout.cars:
        if car.has_meta("metro_walk_lite_train"): continue
        var doors: Array=layout.doors.filter(func(d):return d.car==car)
        # Static interior bounds work without the removed mesh-door scanner.
        # Cab entry/exit is handled by the independent authored-marker adapter.
        if doors.is_empty():
            var seats: Array=layout.places.filter(func(p): return p.car==car)
            var lo_static: float=-8.0
            var hi_static: float=8.0
            if not seats.is_empty():
                lo_static=INF
                hi_static=-INF
                for place in seats:
                    lo_static=minf(lo_static,float(place.position.z)-0.7)
                    hi_static=maxf(hi_static,float(place.position.z)+0.7)
            var floor_static: float=1.033
            var body_static:=AnimatableBody3D.new()
            body_static.name="LightCarConstraints"
            body_static.sync_to_physics=false
            body_static.collision_layer=TRAIN
            body_static.collision_mask=0
            body_static.set_meta("metro_native_walk",true)
            _box(body_static,"SaloonFloor",Vector3(0,floor_static-0.07,(lo_static+hi_static)*0.5),Vector3(2.7,0.14,hi_static-lo_static))
            for end in [lo_static,hi_static]:
                _box(body_static,"EndPartition",Vector3(0,floor_static+1.1,end),Vector3(2.7,2.2,0.12))
            car.add_child(body_static)
            car.set_meta("metro_walk_lite_train",{"body":body_static,"floor":floor_static,"bounds":AABB(Vector3(-1.34,floor_static,lo_static),Vector3(2.68,2.2,hi_static-lo_static)),"portals":[]})
            continue
        var lo:=INF
        var hi:=-INF
        for door in doors:
            lo=minf(lo,door.marker.position.z-0.95)
            hi=maxf(hi,door.marker.position.z+0.95)
        for place in layout.places:
            if place.car!=car: continue
            lo=minf(lo,float(place.position.z)-0.45)
            hi=maxf(hi,float(place.position.z)+0.45)
        var floor: float=float(doors[0].marker.position.y)
        var body:=AnimatableBody3D.new()
        body.name="LightCarConstraints"
        body.sync_to_physics=false
        body.collision_layer=TRAIN
        body.collision_mask=0
        body.set_meta("metro_native_walk",true)
        # Assemble the small constraint hierarchy off-tree, then attach once.
        # No meshes, passenger doors or their animations are rebuilt here.
        _box(body,"SaloonFloor",Vector3(0,floor-0.07,(lo+hi)*0.5),Vector3(2.7,0.14,hi-lo))
        for end in [lo,hi]: _box(body,"EndPartition",Vector3(0,floor+1.1,end),Vector3(2.7,2.2,0.12))
        var portals: Array=[]
        for side in [-1,1]:
            var openings: Array=doors.filter(func(d):return int(d.side)==side)
            openings.sort_custom(func(a,b):return a.marker.position.z<b.marker.position.z)
            var cursor: float=lo
            for door in openings:
                var z: float=door.marker.position.z
                if z-0.73>cursor:
                    _box(body,"SideWall",Vector3(side*1.34,floor+1.1,(cursor+z-0.73)*0.5),Vector3(0.12,2.2,z-0.73-cursor))
                var blocker: CollisionShape3D=_box(body,"PassengerDoorBlocker",Vector3(side*1.34,floor+1.1,z),Vector3(0.12,2.2,1.46))
                var bridge: CollisionShape3D=_box(body,"DoorGapSupport",Vector3(side*1.7,floor-0.06,z),Vector3(1.3,0.10,1.32))
                bridge.disabled=true
                portals.append({"door":door,"blocker":blocker,"bridge":bridge})
                cursor=z+0.73
            if hi>cursor: _box(body,"SideWall",Vector3(side*1.34,floor+1.1,(cursor+hi)*0.5),Vector3(0.12,2.2,hi-cursor))
        for place in layout.places:
            if place.car!=car or not place.seated: continue
            _box(body,"OriginalSeatLimit",Vector3(place.position.x,(floor+float(place.height))*0.5,place.position.z),Vector3(0.53,maxf(0.15,float(place.height)-floor),0.52))
        car.add_child(body)
        car.set_meta("metro_walk_lite_train",{"body":body,"floor":floor,"bounds":AABB(Vector3(-1.34,floor,lo),Vector3(2.68,2.2,hi-lo)),"portals":portals})
    update_doors(service)
    return true

func update_doors(service: Node) -> void:
    var layout=service.line.passengers.layout
    var stopped: bool=absf(float(service.train.speed))<0.05
    for car in layout.cars:
        var state: Dictionary=car.get_meta("metro_walk_lite_train",{})
        if state.is_empty(): continue
        for portal in state.portals:
            var door: Dictionary=portal.door
            var opened: bool=stopped and layout.platform_selected and layout.usable(door)
            if portal.blocker.disabled!=opened: portal.blocker.set_deferred("disabled",opened)
            if portal.bridge.disabled==opened: portal.bridge.set_deferred("disabled",not opened)
            if not opened: continue
            var outside: Vector3=car.to_local(layout.landing(door,0.80))
            var inner_x: float=float(door.side)*1.10
            var dx: float=outside.x-inner_x
            var dy: float=outside.y-float(state.floor)
            if absf(dx)<0.05: continue
            var shape: BoxShape3D=portal.bridge.shape
            shape.size=Vector3(sqrt(dx*dx+dy*dy),0.10,1.32)
            portal.bridge.position=Vector3((outside.x+inner_x)*0.5,(outside.y+float(state.floor))*0.5-0.05,door.marker.position.z)
            portal.bridge.rotation.z=atan(dy/dx)


