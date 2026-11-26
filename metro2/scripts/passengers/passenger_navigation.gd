extends RefCounted
## Static furniture and dynamic body discs share one bounded visibility graph.
var obstacles: Array[Rect2]=[]
var platform:=Rect2(-10.0,-11.0,9.1,101.0)
var platform_area:=platform
var height := 1.1805

func read_station(root: Node3D, budget: RefCounted, fallback: Rect2) -> void:
    platform_area=fallback
    var slab := root.find_child("IslandPlatform",true,false) as MeshInstance3D
    if slab!=null and slab.mesh!=null:
        var box: AABB=slab.global_transform*slab.get_aabb()
        platform_area=Rect2(box.position.x,box.position.z,box.size.x,box.size.z)
        height=box.end.y
    platform=platform_area.grow(-0.30)
    for node in root.find_children("*","CollisionShape3D",true,false):
        var collider:=node as CollisionShape3D
        if not await budget.checkpoint(): return
        if collider.disabled or collider.shape==null: continue
        var size:=Vector3.ZERO
        if collider.shape is BoxShape3D: size=collider.shape.size
        elif collider.shape is CylinderShape3D: size=Vector3((collider.shape as CylinderShape3D).radius*2.0,(collider.shape as CylinderShape3D).height,(collider.shape as CylinderShape3D).radius*2.0)
        elif collider.shape is CapsuleShape3D: size=Vector3((collider.shape as CapsuleShape3D).radius*2.0,(collider.shape as CapsuleShape3D).height,(collider.shape as CapsuleShape3D).radius*2.0)
        elif collider.shape is SphereShape3D: size=Vector3.ONE*collider.shape.radius*2.0
        if size!=Vector3.ZERO: _add_box(collider.global_transform*AABB(-size*0.5,size))
    for node in root.find_children("*","GeometryInstance3D",true,false):
        if not await budget.checkpoint(): return
        if not (node as Node3D).is_visible_in_tree(): continue
        if node is MultiMeshInstance3D:
            var multi: MultiMesh=node.multimesh
            if multi==null or multi.mesh==null: continue
            var count: int=multi.instance_count if multi.visible_instance_count<0 else mini(multi.instance_count,multi.visible_instance_count)
            for i in range(count):
                if i%32==0 and not await budget.checkpoint(): return
                var pose: Transform3D=node.global_transform*multi.get_instance_transform(i)
                _add_box(pose*multi.mesh.get_aabb())
        elif node is MeshInstance3D and node.mesh!=null:
            var mesh: Mesh=node.mesh
            var pose: Transform3D=node.global_transform
            var box: AABB=pose*mesh.get_aabb()
            if not _intersects_walkway(box): continue
            if box.size.x<8.0 and box.size.z<18.0:
                _add_box(box)
                continue
            # Static stations batch columns/furniture into larger meshes. Read
            # body-height triangle footprints once, with the existing frame budget.
            for surface in range(mesh.get_surface_count()):
                var arrays: Array=mesh.surface_get_arrays(surface)
                var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
                var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
                var count: int=indices.size() if not indices.is_empty() else vertices.size()
                for i in range(0,count,3):
                    if i%192==0 and not await budget.checkpoint(): return
                    var a: Vector3=pose*vertices[indices[i] if not indices.is_empty() else i]
                    var b: Vector3=pose*vertices[indices[i+1] if not indices.is_empty() else i+1]
                    var c: Vector3=pose*vertices[indices[i+2] if not indices.is_empty() else i+2]
                    _add_box(AABB(a,Vector3.ZERO).expand(b).expand(c))

# Portable station-local rectangles derived from the original mesh/furniture.
func portable_data() -> Dictionary:
    var boxes: Array=[]
    for box in obstacles: boxes.append([box.position.x,box.position.y,box.size.x,box.size.y])
    return {"height":height,"area":[platform_area.position.x,platform_area.position.y,platform_area.size.x,platform_area.size.y],
        "walk":[platform.position.x,platform.position.y,platform.size.x,platform.size.y],"obstacles":boxes}

func read_prepared(data: Dictionary, pose: Transform3D) -> bool:
    if not data.has("area") or not data.has("walk") or not data.has("height"): return false
    if data.area.size()!=4 or data.walk.size()!=4: return false
    var local_height: float=float(data.height)
    platform_area=_prepared_rect(data.area,local_height,pose)
    platform=_prepared_rect(data.walk,local_height,pose)
    height=(pose*Vector3(0,local_height,0)).y
    if platform.size.x<=0.0 or platform.size.y<=0.0 or not is_finite(height): return false
    obstacles.clear()
    for values in data.get("obstacles",[]):
        if values.size()!=4: return false
        obstacles.append(_prepared_rect(values,local_height,pose))
    return true

func _prepared_rect(values: Array, local_height: float, pose: Transform3D) -> Rect2:
    var box: AABB=pose*AABB(Vector3(float(values[0]),local_height,float(values[1])),Vector3(float(values[2]),0,float(values[3])))
    return Rect2(box.position.x,box.position.z,box.size.x,box.size.z)

func _intersects_walkway(box: AABB) -> bool:
    return box.end.y>height+0.15 and box.position.y<height+1.65 and platform_area.intersects(Rect2(box.position.x,box.position.z,box.size.x,box.size.z).grow(0.02))

func _add_box(box: AABB) -> void:
    if not _intersects_walkway(box) or box.size.x>8.0 or box.size.z>18.0: return
    var shape:=Rect2(box.position.x,box.position.z,maxf(box.size.x,0.02),maxf(box.size.z,0.02))
    for i in range(obstacles.size()-1,-1,-1):
        if not obstacles[i].grow(0.06).intersects(shape): continue
        var combined: Rect2=shape.merge(obstacles[i])
        if combined.size.x>8.0 or combined.size.y>18.0: continue
        shape=combined
        obstacles.remove_at(i)
    obstacles.append(shape)

func free_point(point: Vector3) -> Vector3:
    point.x=clampf(point.x,platform.position.x,platform.end.x-0.001)
    point.z=clampf(point.z,platform.position.y,platform.end.y-0.001)
    point.y=height
    if not obstacles.any(func(o: Rect2): return o.grow(0.34).has_point(Vector2(point.x,point.z))): return point
    var nearest:=point
    var best:=INF
    for radius in range(1,11):
        for direction in range(16):
            var angle: float=float(direction)*TAU/16.0
            var candidate:=point+Vector3(cos(angle),0,sin(angle))*float(radius)*0.35
            if not platform.has_point(Vector2(candidate.x,candidate.z)): continue
            if obstacles.any(func(o: Rect2): return o.grow(0.34).has_point(Vector2(candidate.x,candidate.z))): continue
            var distance: float=point.distance_squared_to(candidate)
            if distance<best: best=distance;nearest=candidate
        if is_finite(best): return nearest
    return nearest


static func distance_to_segment(p: Vector2,a: Vector2,b: Vector2) -> float:
    var delta:=b-a
    var t:=clampf((p-a).dot(delta)/maxf(delta.length_squared(),0.000001),0,1)
    return p.distance_to(a+delta*t)

func clear_segment(a: Vector3,b: Vector3,people: Array=[],use_static: bool=true) -> bool:
    var start:=Vector2(a.x,a.z)
    var finish:=Vector2(b.x,b.z)
    if use_static:
        for shape in obstacles:
            var box:=shape.grow(0.32)
            if box.has_point(start) or box.has_point(finish):return false
            var corners: Array[Vector2]=[box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]
            for i in range(4):
                if Geometry2D.segment_intersects_segment(start,finish,corners[i],corners[(i+1)%4])!=null:return false
    for person in people:
        var center:=Vector2(person.position.x,person.position.z)
        var clearance: float=person.clearance
        # An agent already close to someone may back away without teleporting.
        if start.distance_to(center)<clearance and (finish-start).dot(start-center)>=0:continue
        if distance_to_segment(center,start,finish)<clearance:return false
    return true

func route(a: Vector3,b: Vector3,people: Array=[],region: Rect2=Rect2(),use_static: bool=true) -> Array[Vector3]:
    var bounds:=platform if region.size==Vector2.ZERO else region
    if not bounds.has_point(Vector2(b.x,b.z)): return []
    if clear_segment(a,b,people,use_static):return [b]
    var nodes: Array[Vector3]=[a,b]
    if use_static:
        var corridor:=Rect2(Vector2(a.x,a.z),Vector2.ZERO).expand(Vector2(b.x,b.z)).grow(1.6)
        for shape in obstacles:
            if not shape.intersects(corridor):continue
            var box:=shape.grow(0.38)
            for point in [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]:
                if bounds.has_point(point):nodes.append(Vector3(point.x,a.y,point.y))
    var nearby: Array=people.filter(func(person):return distance_to_segment(Vector2(person.position.x,person.position.z),Vector2(a.x,a.z),Vector2(b.x,b.z))<float(person.clearance)+0.25)
    nearby.sort_custom(func(left,right):return a.distance_squared_to(left.position)<a.distance_squared_to(right.position))
    for person in nearby.slice(0,6):
        var center: Vector3=person.position
        var radius: float=float(person.clearance)/cos(PI/8.0)+0.035
        for i in range(8):
            var angle:=float(i)*TAU/8.0
            var point:=Vector3(center.x+cos(angle)*radius,a.y,center.z+sin(angle)*radius)
            if bounds.has_point(Vector2(point.x,point.z)):nodes.append(point)
    var costs: Array[float]=[]
    var previous: Array[int]=[]
    var visited: Array[bool]=[]
    for i in nodes.size():costs.append(INF);previous.append(-1);visited.append(false)
    costs[0]=0.0
    for iteration in nodes.size():
        var best: int=-1
        for i in nodes.size():
            if not visited[i] and (best<0 or costs[i]<costs[best]):best=i
        if best<0 or costs[best]==INF:break
        if best==1:break
        visited[best]=true
        for i in nodes.size():
            if visited[i] or not clear_segment(nodes[best],nodes[i],people,use_static):continue
            var cost:=costs[best]+nodes[best].distance_to(nodes[i])
            if cost<costs[i]:costs[i]=cost;previous[i]=best
    var result: Array[Vector3]=[]
    if costs[1]==INF:return result
    var index:=1
    while index!=0:result.push_front(nodes[index]);index=previous[index]
    return result
