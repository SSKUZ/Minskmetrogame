extends RefCounted
## Open the original V106 skins, retaining every triangle/material in wall or leaf.
## This is a one-time, cooperative functional split, before gameplay can start.
const Budget = preload("res://modules/line/build_budget.gd")

func prepare(car: Node3D, cab: Node3D, definitions: Array) -> Array[Dictionary]:
    var result: Array[Dictionary]=[]
    var budget=Budget.new(car,1500)
    # Original V106 rear partition and external cab skin; axes are car-local.
    var portals: Array[Dictionary]=[]
    for record in definitions:
        portals.append({"name":record.name,"box":AABB(_vector(record.minimum),_vector(record.size)),"hinge":_vector(record.hinge),"threshold":_vector(record.threshold),"side":int(record.side),"angle":float(record.angle)})
    for portal in portals:
        var pivot:=Node3D.new()
        pivot.name=str(portal.name)
        car.add_child(pivot)
        pivot.position=portal.hinge
        pivot.set_meta("functional_point",{"kind":"cab_door","units":"metres","source":"original V106 skin","threshold":portal.threshold})
        var pieces:=0
        var sources: Array[Node]=car.find_children("*","MeshInstance3D",true,false)
        for node in sources:
            var instance:=node as MeshInstance3D
            if instance.mesh==null or not instance.is_visible_in_tree() or cab.is_ancestor_of(instance) or instance.skin!=null: continue
            if pivot.is_ancestor_of(instance): continue
            var pose: Transform3D=car.global_transform.affine_inverse()*instance.global_transform
            var box: AABB=pose*instance.get_aabb()
            if not box.intersects(portal.box): continue
            # Leave floor, seat upholstery and small equipment intact.
            if box.size.y<0.30 or box.position.y>2.8: continue
            if await _split(instance,pose,portal.box,pivot,budget): pieces+=1
            if not await budget.checkpoint(): return result
        if pieces==0:
            pivot.queue_free()
            continue
        result.append({"pivot":pivot,"threshold":portal.threshold,"side":portal.side,"angle":portal.angle,"open":false,"fraction":0.0})
    return result

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
        var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
        var count: int=indices.size() if not indices.is_empty() else vertices.size()
        var outside:=SurfaceTool.new()
        var inside:=SurfaceTool.new()
        outside.begin(Mesh.PRIMITIVE_TRIANGLES)
        inside.begin(Mesh.PRIMITIVE_TRIANGLES)
        var outside_count:=0
        var inside_count:=0
        for offset in range(0,count,3):
            var polygon: Array=[]
            for k in range(3):
                var i: int=indices[offset+k] if not indices.is_empty() else offset+k
                polygon.append({"v":vertices[i],"p":pose*vertices[i],"n":normals[i] if i<normals.size() else Vector3.UP,"uv":uvs[i] if i<uvs.size() else Vector2.ZERO,"uv2":uv2s[i] if i<uv2s.size() else Vector2.ZERO,"c":colors[i] if i<colors.size() else Color.WHITE})
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
        if outside_count>0:
            outside.set_material(material)
            outside.commit(wall)
        if inside_count>0:
            removed=true
            inside.set_material(material)
            inside.commit(leaf)
    if not removed: return false
    instance.mesh=wall
    instance.material_override=null
    for i in range(instance.get_surface_override_material_count()): instance.set_surface_override_material(i,null)
    var moving:=MeshInstance3D.new()
    moving.name=str(instance.name)+"OriginalDoorSurface"
    moving.mesh=leaf
    moving.layers=instance.layers
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
        for j in [0,i,i+1]:
            var vertex: Dictionary=polygon[j]
            tool.set_normal((pose.basis*vertex.n).normalized() if transformed else vertex.n)
            tool.set_uv(vertex.uv)
            tool.set_uv2(vertex.uv2)
            tool.set_color(vertex.c)
            tool.add_vertex(pose*vertex.v if transformed else vertex.v)
            count+=1
    return count

func _vector(values: Array) -> Vector3:
    return Vector3(float(values[0]),float(values[1]),float(values[2]))
