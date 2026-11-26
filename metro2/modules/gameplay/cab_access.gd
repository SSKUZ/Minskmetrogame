extends RefCounted
## Open the original V106 skins, retaining every triangle/material in wall or leaf.
## Cooperative functional split; safe depot walking does not wait for this job.
const Budget = preload("res://modules/line/build_budget.gd")
var error_message:=""
var _budget: RefCounted
var _originals: Array[Dictionary]=[]
var _pivots: Array[Node3D]=[]
var _cancelled:=false

func cancel() -> void:
    _cancelled=true
    if _budget!=null: _budget.cancel()
    # A failed/interrupted split is transactional: retain the original skins.
    for index in range(_originals.size()-1,-1,-1):
        var record: Dictionary=_originals[index]
        if not is_instance_valid(record.node): continue
        record.node.mesh=record.mesh
        record.node.material_override=record.material
        for i in range(record.overrides.size()):
            record.node.set_surface_override_material(i,record.overrides[i])
    for pivot in _pivots:
        if is_instance_valid(pivot):
            pivot.hide()
            pivot.queue_free()
    _originals.clear()
    _pivots.clear()


func prepare(car: Node3D, cab: Node3D, definitions: Array) -> Array[Dictionary]:
    if car.has_meta("metro_cab_access_result"): return car.get_meta("metro_cab_access_result")
    var result: Array[Dictionary]=[]
    var budget=Budget.new(car,1500)
    _budget=budget
    # Original V106 rear partition and external cab skin; axes are car-local.
    var portals: Array[Dictionary]=[]
    for record in definitions:
        portals.append({"name":record.name,"box":AABB(_vector(record.minimum),_vector(record.size)),"hinge":_vector(record.hinge),"threshold":_vector(record.threshold),"side":int(record.side),"angle":float(record.angle)})
    for portal in portals:
        var pivot:=Node3D.new()
        pivot.name=str(portal.name)
        car.add_child(pivot)
        _pivots.append(pivot)
        pivot.position=portal.hinge
        pivot.set_meta("functional_point",{"kind":"cab_door","units":"metres","source":"original V106 skin","threshold":portal.threshold})
        var pieces:=0
        var sources: Array[Node]=car.find_children("*","MeshInstance3D",true,false)
        for node in sources:
            var instance:=node as MeshInstance3D
            if instance.mesh==null or not _visible_in_car(instance,car) or cab.is_ancestor_of(instance) or instance.skin!=null: continue
            if _pivots.any(func(door): return is_instance_valid(door) and door.is_ancestor_of(instance)): continue
            var pose: Transform3D=car.global_transform.affine_inverse()*instance.global_transform
            var box: AABB=pose*instance.get_aabb()
            if not box.intersects(portal.box): continue
            # Leave floor, seat upholstery and small equipment intact.
            if box.size.y<0.30 or box.position.y>2.8: continue
            if await _split(instance,pose,portal.box,pivot,budget): pieces+=1
            if not await budget.checkpoint(): return []
        if pieces==0:
            pivot.queue_free()
            continue
        result.append({"pivot":pivot,"threshold":portal.threshold,"side":portal.side,"angle":portal.angle,"open":false,"fraction":0.0})
    if _cancelled: return []
    if result.is_empty():
        error_message="Не найдены доступные двери кабины V106"
        cancel()
        return []
    car.set_meta("metro_cab_access_result",result)
    _originals.clear()
    _pivots.clear()
    return result

func _visible_in_car(node: Node3D, car: Node3D) -> bool:
    var current: Node=node
    while current!=car:
        if current is Node3D and not current.visible: return false
        current=current.get_parent()
    return true

func _split(instance: MeshInstance3D, pose: Transform3D, opening: AABB, pivot: Node3D, budget: RefCounted) -> bool:
    var source: Mesh=instance.mesh
    var wall:=ArrayMesh.new()
    var leaf:=ArrayMesh.new()
    var removed:=false
    for surface in range(source.get_surface_count()):
        if source is ArrayMesh and source.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return false
        var arrays: Array=source.surface_get_arrays(surface)
        var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
        var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
        var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
        var uv2s: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2]!=null else PackedVector2Array()
        var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
        var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT]!=null else PackedFloat32Array()
        var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
        var count: int=indices.size() if not indices.is_empty() else vertices.size()
        var outside:=SurfaceTool.new()
        var inside:=SurfaceTool.new()
        outside.begin(Mesh.PRIMITIVE_TRIANGLES)
        inside.begin(Mesh.PRIMITIVE_TRIANGLES)
        var outside_count:=0
        var untouched:=PackedInt32Array()
        var inside_count:=0
        for offset in range(0,count,3):
            if offset%192==0 and not await budget.checkpoint(): return false
            var ids: Array[int]=[]
            var points: Array[Vector3]=[]
            for k in range(3):
                var index: int=indices[offset+k] if not indices.is_empty() else offset+k
                ids.append(index)
                points.append(pose*vertices[index])
            var triangle:=AABB(points[0],Vector3.ZERO).expand(points[1]).expand(points[2])
            # Most of the original body is far outside a door. Retain its native
            # indexed arrays instead of clipping/rebuilding every triangle.
            if triangle.end.x<opening.position.x or triangle.position.x>opening.end.x or triangle.end.y<opening.position.y or triangle.position.y>opening.end.y or triangle.end.z<opening.position.z or triangle.position.z>opening.end.z:
                for index in ids: untouched.append(index)
                continue
            var polygon: Array=[]
            for k in range(3):
                var i: int=ids[k]
                polygon.append({"v":vertices[i],"p":pose*vertices[i],"n":normals[i] if i<normals.size() else Vector3.UP,"uv":uvs[i] if i<uvs.size() else Vector2.ZERO,"uv2":uv2s[i] if i<uv2s.size() else Vector2.ZERO,"c":colors[i] if i<colors.size() else Color.WHITE})
                if tangents.size()>i*4+3:
                    polygon[-1]["t"]=Vector4(tangents[i*4],tangents[i*4+1],tangents[i*4+2],tangents[i*4+3])
            for axis in range(3):
                for high in [false,true]:
                    if polygon.is_empty(): break
                    var edge: float=opening.end[axis] if high else opening.position[axis]
                    var halves: Array=_cut(polygon,axis,edge,high)
                    outside_count+=_triangles(outside,halves[1],Transform3D.IDENTITY,false)
                    polygon=halves[0]
            if not polygon.is_empty():
                inside_count+=_triangles(inside,polygon,Transform3D(pose.basis,pose.origin-pivot.position),true)
            if offset%192==0 and not await budget.checkpoint(): return false
        var material: Material=instance.get_active_material(surface)
        if not untouched.is_empty():
            var kept: Array=arrays.duplicate()
            kept[Mesh.ARRAY_INDEX]=untouched
            wall.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,kept)
            wall.surface_set_material(wall.get_surface_count()-1,material)
        if outside_count>0:
            outside.set_material(material)
            outside.commit(wall)
        if inside_count>0:
            removed=true
            inside.set_material(material)
            inside.commit(leaf)
    if not removed: return false
    if _cancelled: return false
    var overrides: Array[Material]=[]
    for i in range(instance.get_surface_override_material_count()): overrides.append(instance.get_surface_override_material(i))
    _originals.append({"node":instance,"mesh":instance.mesh,"material":instance.material_override,"overrides":overrides})
    for i in range(instance.get_surface_override_material_count()): instance.set_surface_override_material(i,null)
    instance.mesh=wall
    instance.material_override=null
    var moving:=MeshInstance3D.new()
    moving.name=str(instance.name)+"OriginalDoorSurface"
    moving.mesh=leaf
    moving.layers=instance.layers
    moving.cast_shadow=instance.cast_shadow
    moving.material_overlay=instance.material_overlay
    pivot.add_child(moving)
    return true

func _cut(polygon: Array, axis: int, edge: float, high: bool) -> Array:
    var inside: Array=[]
    var outside: Array=[]
    for i in range(polygon.size()):
        var a: Dictionary=polygon[i]
        var b: Dictionary=polygon[(i+1)%polygon.size()]
        var da: float=(edge-float(a.p[axis])) if high else (float(a.p[axis])-edge)
        var db: float=(edge-float(b.p[axis])) if high else (float(b.p[axis])-edge)
        if da>=0.0: inside.append(a)
        else: outside.append(a)
        if (da<0.0)==(db<0.0): continue
        var t: float=da/(da-db)
        var intersection: Dictionary={}
        for key in a: intersection[key]=a[key].lerp(b[key],t)
        inside.append(intersection)
        outside.append(intersection)
    return [inside,outside]

func _triangles(tool: SurfaceTool, polygon: Array, pose: Transform3D, transformed: bool) -> int:
    var count:=0
    for i in range(1,polygon.size()-1):
        var a: Vector3=polygon[0].v
        var b: Vector3=polygon[i].v
        var c: Vector3=polygon[i+1].v
        if (b-a).cross(c-a).length_squared()<0.000000000001: continue
        for j in [0,i,i+1]:
            var vertex: Dictionary=polygon[j]
            tool.set_normal((pose.basis.inverse().transposed()*vertex.n).normalized() if transformed else vertex.n)
            tool.set_uv(vertex.uv)
            tool.set_uv2(vertex.uv2)
            tool.set_color(vertex.c)
            if vertex.has("t"):
                var t: Vector4=vertex.t
                var axis:=Vector3(t.x,t.y,t.z)
                if transformed: axis=(pose.basis*axis).normalized()
                tool.set_tangent(Plane(axis,t.w*(-1.0 if transformed and pose.basis.determinant()<0.0 else 1.0)))
            tool.add_vertex(pose*vertex.v if transformed else vertex.v)
            count+=1
    return count

func _vector(values: Array) -> Vector3:
    return Vector3(float(values[0]),float(values[1]),float(values[2]))
