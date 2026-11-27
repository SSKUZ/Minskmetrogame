extends RefCounted
## Portable anchors captured ONLY inside authored bench constructors during CI.
## Geometry arguments are returned unchanged; no render or collision edits.
const CAPTURE:="metro_bench_capture"
const CACHE:="metro_bench_places"

static func v(a: Array) -> Vector3:
    return Vector3(float(a[0]),float(a[1]),float(a[2]))

static func a(p: Vector3) -> Array:
    return [p.x,p.y,p.z]

static func capture(owner_node: Node3D, size: Vector3, point: Vector3, floor_y: float, pose: Basis, tag: String, origin: Vector3, frame: Basis) -> Vector3:
    # Feet, narrow rails, backrests and plinths are not seating surfaces.
    var top: float=point.y+size.y*0.5-floor_y
    if size.y>0.18 or top<0.32 or top>0.65 or maxf(size.x,size.z)<0.32: return size
    var records: Dictionary=owner_node.get_meta(CAPTURE,{})
    var key: String=tag+str(origin)+str(frame)
    var transform:=Transform3D(frame,origin)
    var relative: Transform3D=transform.affine_inverse()*Transform3D(pose,point)
    var bounds: AABB=relative*AABB(-size*0.5,size)
    if records.has(key):
        records[key].bounds=(records[key].bounds as AABB).merge(bounds)
    else:
        records[key]={"bounds":bounds,"frame":transform,"floor":floor_y,"kind":"row","modules":[]}
    if size.x>0.35 and size.z>0.32 and size.z<0.65 and maxf(size.x,size.z)<1.0:
        records[key].modules.append(transform.affine_inverse()*point)
    owner_node.set_meta(CAPTURE,records)
    return size

static func curved(owner_node: Node3D, size: Vector3, point: Vector3, floor_y: float, forward: Vector3, sample: int) -> Vector3:
    if sample not in [5,15,25]: return size
    var records: Dictionary=owner_node.get_meta(CAPTURE,{})
    records["curve"+str(point)]={"kind":"single","point":Vector3(point.x,floor_y,point.z),"surface":point.y+size.y*0.5,"forward":forward}
    owner_node.set_meta(CAPTURE,records)
    return size

static func borisovsky_row(owner_node: Node3D, x: float, z: float, floor_y: float, side: int) -> void:
    # Bound to the actual CurvedOakBenchSlats cross-section (.49 m seat top).
    var records: Dictionary=owner_node.get_meta(CAPTURE,{})
    for offset in [-0.65,0.0,0.65]:
        var point:=Vector3(x+float(side)*0.04,floor_y,z+float(offset))
        records["curved_oak"+str(point)]={"kind":"single","point":point,"surface":floor_y+0.49,"forward":Vector3(float(side),0,0)}
    owner_node.set_meta(CAPTURE,records)

static func extract(node: Node3D, relative: Transform3D, platform_center_x: float) -> Array:
    var result: Array=[]
    var records: Dictionary=node.get_meta(CAPTURE,{})
    for record in records.values():
        if record.kind=="single":
            result.append(_point(relative,record.point,record.forward,float(record.surface)))
            continue
        var bounds: AABB=record.bounds
        var frame: Transform3D=record.frame
        var along_x: bool=bounds.size.x>=bounds.size.z
        var length: float=bounds.size.x if along_x else bounds.size.z
        var modules: Array=record.modules
        var count: int=modules.size() if modules.size()>1 else maxi(1,int(floor((length+0.02)/0.5)))
        var center: Vector3=frame*bounds.get_center()
        var side: float=signf((relative*center).x-platform_center_x)
        if is_zero_approx(side): side=1.0
        var forward: Vector3=frame.basis*Vector3(0,0,1) if along_x else relative.basis.inverse()*Vector3(side,0,0)
        for i in range(count):
            var local: Vector3=bounds.get_center()
            var offset: float=(float(i)+0.5)*length/float(count)-length*0.5
            if modules.size()>1: local=modules[i]
            elif along_x: local.x+=offset
            else: local.z+=offset
            var point: Vector3=frame*local
            var surface: float=(frame*Vector3(local.x,bounds.end.y,local.z)).y
            point.y=float(record.floor)
            result.append(_point(relative,point,forward,surface))
    # Captures never become a second retained scene/resource graph.
    if node.has_meta(CAPTURE): node.remove_meta(CAPTURE)
    return result

static func _point(relative: Transform3D, point: Vector3, forward: Vector3, surface: float) -> Dictionary:
    var position: Vector3=relative*point
    return {"type":"station_bench","position":a(position),"forward":a((relative.basis*forward).normalized()),
        "surface_height":(relative*Vector3(point.x,surface,point.z)).y,"eye_height":1.20}

static func runtime_places(station: Node3D) -> Array:
    if station.has_meta(CACHE): return station.get_meta(CACHE)
    var data: Dictionary=station.get_meta("metro_walk_lite_data",{})
    var places: Array=[]
    for record in data.get("bench_seats",[]):
        var point: Vector3=v(record.position)
        var forward: Vector3=v(record.forward)
        forward.y=0.0
        if forward.length_squared()<0.5: continue
        places.append({"kind":"station","anchor":weakref(station),"id":places.size(),
            "position":point,"forward":forward.normalized(),"height":float(record.surface_height),
            "eye_height":float(record.get("eye_height",1.20)),"used":false})
    station.set_meta(CACHE,places)
    return places
