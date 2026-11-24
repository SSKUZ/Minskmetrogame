extends "res://scripts/tunnel_lightweight_straight.gd"
## Reuse the detailed existing tunnel meshes. Warp their vertices onto the route,
## including each running/contact rail. Exact portal clipping avoids station walls.
var path: RefCounted
var _route_active: Dictionary = {}
var _pool: Array[Node3D] = []
var _source_parts: Dictionary = {}
var geometry_cache: Dictionary = {"data":{},"order":[],"pending":{}}
var _surface_cache: Dictionary = {}
var _surface_users: Dictionary = {}
var _wanted_pieces: Dictionary = {}
var _slots_signature := ""
var _building := false
var _building_key := ""
var _sample_frames: Dictionary = {}
const BuildBudget = preload("res://modules/line/build_budget.gd")
const CACHE_LIMIT := 24

func _ready() -> void:
    super._ready()
    # 1,520 mm clear gauge plus the existing 95 mm rail head.
    for i in range(_rail_clips.instance_count):
        var pose := _rail_clips.get_instance_transform(i)
        pose.origin.x=signf(pose.origin.x)*0.8075
        _rail_clips.set_instance_transform(i,pose)

func _include_slots(required: Dictionary, z0: float, z1: float) -> void:
    # Build four extra modules outside the visible field, retaining every detail.
    for slot in range(floori((z0-VISIBLE_DISTANCE-GUARD_DISTANCE-64.0)/16.0),floori((z1+VISIBLE_DISTANCE+GUARD_DISTANCE+64.0)/16.0)+1):
        required[slot]=true

func sync_to_view() -> void:
    if path==null or not is_instance_valid(_train) or not is_instance_valid(_camera): return
    var signature: String="%d:%d:%d:%d" % [
        floori((_train.global_position.z+_train_bounds.position.z-VISIBLE_DISTANCE-GUARD_DISTANCE)/16.0),
        floori((_train.global_position.z+_train_bounds.end.z+VISIBLE_DISTANCE+GUARD_DISTANCE)/16.0),
        floori((_camera.global_position.z-VISIBLE_DISTANCE-GUARD_DISTANCE)/16.0),
        floori((_camera.global_position.z+VISIBLE_DISTANCE+GUARD_DISTANCE)/16.0)]
    if signature!=_slots_signature:
        _slots_signature=signature
        var required: Dictionary={}
        _include_slots(required,_train.global_position.z+_train_bounds.position.z,_train.global_position.z+_train_bounds.end.z)
        _include_slots(required,_camera.global_position.z,_camera.global_position.z)
        _wanted_pieces.clear()
        for slot in required:
            for piece in path.tunnel_pieces(float(slot)*16.0,float(slot+1)*16.0):
                _wanted_pieces["%.4f:%.4f" % [piece.x,piece.y]]=piece
        for key in _route_active.keys():
            if _wanted_pieces.has(key): continue
            var section: Node3D=_route_active[key]
            section.hide()
            _pool.append(section)
            _route_active.erase(key)
    if not _building:
        var next: String=""
        var distance: float=INF
        for key in _wanted_pieces:
            if _route_active.has(key): continue
            var span: Vector2=_wanted_pieces[key]
            var middle: float=(span.x+span.y)*0.5
            var d: float=minf(absf(middle-_camera.global_position.z),absf(middle-_train.global_position.z))
            if d<distance:
                next=str(key)
                distance=d
        if not next.is_empty():
            _building=true
            call_deferred("_build_piece",next,_wanted_pieces[next])
    # A flight camera can leave many spares; keep a bounded spare allocation.
    if _pool.size()>6:
        var spare: Node3D=_pool.pop_back()
        for record in _source_parts.get(spare,[]):
            if not record.has("mesh"): continue
            var source: Mesh=record.mesh
            _surface_users[source]=int(_surface_users.get(source,1))-1
            if int(_surface_users[source])<=0:
                _surface_users.erase(source)
                _surface_cache.erase(source)
        _source_parts.erase(spare)
        _sections.erase(spare)
        spare.queue_free()

func _build_piece(key: String, span: Vector2) -> void:
    var section: Node3D
    if _pool.is_empty():
        section=_new_section()
        _remember_parts(section)
    else:
        section=_pool.pop_back()
    section.hide()
    _building_key=key
    # Both track instances share exact local warped meshes. Only their root
    # translations differ; do not deform the same span twice.
    while geometry_cache.pending.has(key) and not geometry_cache.data.has(key):
        await get_tree().process_frame
        if not _wanted_pieces.has(key):
            _pool.append(section)
            _building=false
            _building_key=""
            return
    if geometry_cache.data.has(key):
        _apply_geometry(section,geometry_cache.data[key])
    else:
        geometry_cache.pending[key]=get_instance_id()
        await _warp_section(section,span)
        var payload: Array=[]
        for record in _source_parts[section]:
            var node: Node3D=record.node
            if node is MeshInstance3D: payload.append(node.mesh)
            elif node is MultiMeshInstance3D: payload.append(node.multimesh)
            else: payload.append(node.transform)
        geometry_cache.data[key]=payload
        geometry_cache.pending.erase(key)
    geometry_cache.order.erase(key)
    geometry_cache.order.append(key)
    while geometry_cache.order.size()>CACHE_LIMIT:
        geometry_cache.data.erase(geometry_cache.order.pop_front())
    section.position=Vector3(center_x,0,span.x)
    section.get_node("WallLight").visible=posmod(floori(span.x/16.0),2)==0
    if _wanted_pieces.has(key):
        section.show()
        _route_active[key]=section
    else:
        _pool.append(section)
    _building=false
    _building_key=""

func _apply_geometry(section: Node3D, payload: Array) -> void:
    var records: Array=_source_parts[section]
    for i in range(records.size()):
        var node: Node3D=records[i].node
        if node is MeshInstance3D: node.mesh=payload[i]
        elif node is MultiMeshInstance3D: node.multimesh=payload[i]
        else: node.transform=payload[i]

func _remember_parts(section: Node3D) -> void:
    var records: Array[Dictionary] = []
    var inverse := section.global_transform.affine_inverse()
    for child in section.find_children("*","Node3D",true,false):
        var n := child as Node3D
        var pose := inverse*n.global_transform
        if n is MeshInstance3D:
            var mesh_node := n as MeshInstance3D
            if mesh_node.mesh==_rail: pose.origin.x=signf(pose.origin.x)*0.8075
            _surface_users[mesh_node.mesh]=int(_surface_users.get(mesh_node.mesh,0))+1
            if not _surface_cache.has(mesh_node.mesh):
                var surfaces: Array=[]
                for surface in range(mesh_node.mesh.get_surface_count()):
                    surfaces.append(mesh_node.mesh.surface_get_arrays(surface))
                _surface_cache[mesh_node.mesh]=surfaces
            records.append({"node":n,"pose":pose,"mesh":mesh_node.mesh,"arrays":_surface_cache[mesh_node.mesh],
                "normal_basis":pose.basis.inverse().transposed()})
        elif n is MultiMeshInstance3D:
            records.append({"node":n,"pose":pose,"multi":(n as MultiMeshInstance3D).multimesh})
        elif n is Light3D:
            records.append({"node":n,"pose":pose})
    # Every saved pose already includes its ancestors, so use one identity frame.
    for child in section.find_children("*","Node3D",true,false):
        (child as Node3D).transform=Transform3D.IDENTITY
    _source_parts[section]=records

func _frame(z: float) -> Transform3D:
    if not _sample_frames.has(z):
        _sample_frames[z]={"frame":path.frame_at(z,center_x),"profile":path.cross_section_at(z)}
    return _sample_frames[z].frame

func _point(local: Vector3, start: float, factor: float) -> Vector3:
    var z := start+local.z*factor
    var frame: Transform3D=_frame(z)
    var section: Vector2=_sample_frames[z].profile
    # Preserve running/contact rails and the walking datum; taper only the outer lining.
    var x: float=local.x if absf(local.x)<=1.8 else signf(local.x)*(1.8+(absf(local.x)-1.8)*(section.x-1.8)/1.35)
    var y: float=local.y if local.y<=1.2 else 1.2+(local.y-1.2)*(section.y-1.2)/5.8
    return frame*Vector3(x,y,0.0)-Vector3(center_x,0,start)

func _warp_section(section: Node3D, span: Vector2) -> void:
    var factor: float=(span.y-span.x)/16.0
    var budget=BuildBudget.new(self,2000)
    _sample_frames.clear()
    for record in _source_parts[section]:
        if not await budget.checkpoint(): return
        var n: Node3D=record.node
        var pose: Transform3D=record.pose
        if record.has("mesh"):
            var source: Mesh=record.mesh
            var warped := ArrayMesh.new()
            for s in range(source.get_surface_count()):
                var arrays: Array=record.arrays[s].duplicate(true)
                var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
                var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
                for v in range(vertices.size()):
                    if v%128==0 and not await budget.checkpoint(): return
                    var local: Vector3=pose*vertices[v]
                    vertices[v]=_point(local,span.x,factor)
                    if not normals.is_empty():
                        var frame: Transform3D=_frame(span.x+local.z*factor)
                        normals[v]=(frame.basis*record.normal_basis*normals[v]).normalized()
                arrays[Mesh.ARRAY_VERTEX]=vertices
                if not normals.is_empty(): arrays[Mesh.ARRAY_NORMAL]=normals
                arrays[Mesh.ARRAY_TANGENT]=null
                warped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
                warped.surface_set_material(s,source.surface_get_material(s))
            (n as MeshInstance3D).mesh=warped
        elif record.has("multi"):
            var original: MultiMesh=record.multi
            var multi := MultiMesh.new()
            multi.transform_format=MultiMesh.TRANSFORM_3D
            multi.mesh=original.mesh
            multi.instance_count=original.instance_count
            for i in range(original.instance_count):
                if i%64==0 and not await budget.checkpoint(): return
                var local := pose*original.get_instance_transform(i)
                var frame: Transform3D=_frame(span.x+local.origin.z*factor)
                multi.set_instance_transform(i,Transform3D(frame.basis*local.basis,_point(local.origin,span.x,factor)))
            (n as MultiMeshInstance3D).multimesh=multi
        else:
            var frame: Transform3D=_frame(span.x+pose.origin.z*factor)
            n.transform=Transform3D(frame.basis*pose.basis,_point(pose.origin,span.x,factor))
    _sample_frames.clear()

func _exit_tree() -> void:
    if geometry_cache.pending.get(_building_key,0)==get_instance_id():
        geometry_cache.pending.erase(_building_key)
    _source_parts.clear()
    _surface_cache.clear()
    _surface_users.clear()
    _sample_frames.clear()

func constrain_camera(world_position: Vector3) -> Vector3:
    if path.in_station(world_position.z,10.0): return world_position
    if world_position.z>96.0:
        world_position.y=maxf(world_position.y,path.position_at(world_position.z).y+0.35)
        return world_position
    var centre: Vector3=path.position_at(world_position.z,center_x)
    world_position.x=clampf(world_position.x,centre.x-2.95,centre.x+2.95)
    world_position.y=clampf(world_position.y,centre.y+0.15,centre.y+6.6)
    return world_position
