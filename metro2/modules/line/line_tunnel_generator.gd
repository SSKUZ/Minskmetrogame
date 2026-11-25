extends "res://scripts/tunnel_lightweight_straight.gd"
## CI-ONLY geometry source, loaded exclusively by static_world/prebuild.gd.
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
const Connections = preload("res://modules/line/station_connection_adapter.gd")
const BuildBudget = preload("res://modules/line/build_budget.gd")
const CACHE_LIMIT := 24

func _ready() -> void:
    super._ready()
    _subdivide_lining()
    # 1,520 mm clear gauge plus the existing 95 mm rail head.
    for i in range(_rail_clips.instance_count):
        var pose := _rail_clips.get_instance_transform(i)
        pose.origin.x=signf(pose.origin.x)*0.8075
        _rail_clips.set_instance_transform(i,pose)

func _subdivide_lining() -> void:
    # Retessellate the existing profile along its length. Two-metre rings match
    # the original joints and follow portal transitions without a single long quad.
    var shell := SurfaceTool.new()
    shell.begin(Mesh.PRIMITIVE_TRIANGLES)
    shell.set_smooth_group(0)
    for z in range(0,16,2):
        for j in range((PROFILE.size()-1)*4):
            var a: Vector2=_smooth_profile(float(j)/4.0)
            var b: Vector2=_smooth_profile(float(j+1)/4.0)
            for vertex in [Vector3(a.x,a.y,z),Vector3(a.x,a.y,z+2),Vector3(b.x,b.y,z),
                    Vector3(b.x,b.y,z),Vector3(a.x,a.y,z+2),Vector3(b.x,b.y,z+2)]: shell.add_vertex(vertex)
    shell.index()
    shell.generate_normals()
    _shell=shell.commit()

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
        _sample_frames[z]={"frame":path.frame_at(z,center_x),"profile":path.cross_section_at(z),"morph":path.portal_morph(z)}
    return _sample_frames[z].frame

func _point(local: Vector3, start: float, factor: float, lining: bool=false, seam: bool=false) -> Vector3:
    var z := start+local.z*factor
    var frame: Transform3D=_frame(z)
    var section: Vector2=_sample_frames[z].profile
    # Preserve running/contact rails and the walking datum; taper only the outer lining.
    var x: float=local.x if absf(local.x)<=1.8 else signf(local.x)*(1.8+(absf(local.x)-1.8)*(section.x-1.8)/1.35)
    var y: float=local.y if local.y<=1.2 else 1.2+(local.y-1.2)*(section.y-1.2)/5.8
    var morph: Dictionary=_sample_frames[z].morph
    if not morph.is_empty() and float(morph.weight)>0.0:
        var target_x: float=x
        var target_y: float=local.y
        if str(morph.shape)=="ellipse":
            var spring: float=float(morph.spring)
            if local.y>1.2:
                target_y=1.2+(local.y-1.2)*(spring-1.2)/2.05 if local.y<=3.25 else spring+(local.y-3.25)*(section.y-spring)/3.75
            if lining:
                target_x=signf(local.x)*section.x
                if local.y>3.25:
                    var rise: float=clampf((local.y-3.25)/3.75,0.0,1.0)
                    target_x*=sqrt(maxf(0.0,1.0-rise*rise))
        else:
            if local.y>1.2: target_y=1.2+minf(local.y-1.2,3.55)*(section.y-1.2)/3.55
            if lining:
                target_x=signf(local.x)*section.x if local.y<=4.75 else local.x*section.x/2.92
            if local.y>=4.75: target_y-=float(morph.crown)*pow(target_x/section.x,2.0)
        if seam:
            target_x-=signf(target_x)*0.012
            if local.y>1.2: target_y-=0.012
        x=lerpf(x,target_x,float(morph.weight))
        y=lerpf(y,target_y,float(morph.weight))
    return frame*Vector3(x,y,0.0)-Vector3(center_x,0,start)

func _warp_section(section: Node3D, span: Vector2, contacts_only: bool=false, contact_side: float=1.0) -> void:
    var factor := 1.0
    var length: float=span.y-span.x
    var offset: float=span.x-floorf(span.x/16.0)*16.0
    var clipped: bool=offset>0.0001 or length<15.9999
    var budget=BuildBudget.new(self,2000)
    _sample_frames.clear()
    for record in _source_parts[section]:
        if not await budget.checkpoint(): return
        var n: Node3D=record.node
        var pose: Transform3D=record.pose
        var contact: bool=(record.has("mesh") and record.mesh is ArrayMesh and record.mesh in _contact_meshes) or (record.has("multi") and record.multi==_insulators)
        if contacts_only and not contact: continue
        if record.has("mesh"):
            var source: Mesh=record.mesh
            var warped := ArrayMesh.new()
            for s in range(source.get_surface_count()):
                var arrays: Array=await _slice_arrays(record.arrays[s],pose,offset,length,budget) if clipped else record.arrays[s].duplicate(true)
                if arrays.is_empty(): continue
                var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
                var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
                for v in range(vertices.size()):
                    if v%128==0 and not await budget.checkpoint(): return
                    var local: Vector3=pose*vertices[v]
                    local.z-=offset
                    if contact: local.x*=contact_side
                    vertices[v]=_point(local,span.x,factor,source==_shell or source==_joints,source==_joints)
                    if not normals.is_empty():
                        var frame: Transform3D=_frame(span.x+local.z*factor)
                        var normal: Vector3=record.normal_basis*normals[v]
                        if contact: normal.x*=contact_side
                        normals[v]=(frame.basis*normal).normalized()
                arrays[Mesh.ARRAY_VERTEX]=vertices
                if not normals.is_empty(): arrays[Mesh.ARRAY_NORMAL]=normals
                arrays[Mesh.ARRAY_TANGENT]=null
                if contact and contact_side<0.0:
                    var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
                    if indices.is_empty():
                        indices.resize(vertices.size())
                        for i in range(indices.size()): indices[i]=i
                    for i in range(0,indices.size(),3):
                        var temporary: int=indices[i+1]
                        indices[i+1]=indices[i+2]
                        indices[i+2]=temporary
                    arrays[Mesh.ARRAY_INDEX]=indices
                warped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
                warped.surface_set_material(warped.get_surface_count()-1,source.surface_get_material(s))
            if source==_shell or source==_joints:
                # The portal morph changes surface directions as well as points.
                # Rebuild these normals once in CI, never during train movement.
                var corrected := ArrayMesh.new()
                for surface in range(warped.get_surface_count()):
                    var tool := SurfaceTool.new()
                    tool.create_from(warped,surface)
                    tool.generate_normals()
                    tool.commit(corrected)
                    corrected.surface_set_material(corrected.get_surface_count()-1,warped.surface_get_material(surface))
                warped=corrected
            (n as MeshInstance3D).mesh=warped
        elif record.has("multi"):
            var original: MultiMesh=record.multi
            var multi := MultiMesh.new()
            multi.transform_format=MultiMesh.TRANSFORM_3D
            multi.mesh=original.mesh
            multi.instance_count=original.instance_count
            var count := 0
            for i in range(original.instance_count):
                if i%64==0 and not await budget.checkpoint(): return
                var local := pose*original.get_instance_transform(i)
                if contact: local.origin.x*=contact_side
                if local.origin.z<offset or local.origin.z>offset+length: continue
                local.origin.z-=offset
                var frame: Transform3D=_frame(span.x+local.origin.z)
                multi.set_instance_transform(count,Transform3D(frame.basis*local.basis,_point(local.origin,span.x,factor)))
                count+=1
            multi.visible_instance_count=count
            (n as MultiMeshInstance3D).multimesh=multi
        else:
            var origin: Vector3=pose.origin
            origin.z-=offset
            var frame: Transform3D=_frame(span.x+origin.z)
            n.transform=Transform3D(frame.basis*pose.basis,_point(origin,span.x,factor))
    _sample_frames.clear()

func _slice_arrays(arrays: Array, pose: Transform3D, offset: float, length: float, budget: RefCounted) -> Array:
    # Clip triangles in the original section frame, retaining normals and UVs.
    # A partial portal tile no longer compresses 25 sleepers and every cabinet.
    var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var indices: PackedInt32Array=Connections._indices(arrays,vertices.size())
    var inverse: Transform3D=pose.affine_inverse()
    var output := SurfaceTool.new()
    output.begin(Mesh.PRIMITIVE_TRIANGLES)
    var count := 0
    for i in range(0,indices.size(),3):
        if i%192==0 and not await budget.checkpoint(): return []
        var polygon: Array=[]
        for j in range(3):
            var index: int=indices[i+j]
            var vertex: Dictionary={"p":pose*vertices[index]}
            for channel in [Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR]:
                if arrays[channel]!=null and not arrays[channel].is_empty(): vertex[channel]=arrays[channel][index]
            polygon.append(vertex)
        polygon=Connections._clip(polygon,Plane(Vector3.BACK,offset+length),true)
        polygon=Connections._clip(polygon,Plane(Vector3.FORWARD,-offset),true)
        for j in range(1,polygon.size()-1):
            if ((polygon[j].p-polygon[0].p) as Vector3).cross(polygon[j+1].p-polygon[0].p).length_squared()<0.000000000001: continue
            for vertex in [polygon[0],polygon[j],polygon[j+1]]:
                if vertex.has(Mesh.ARRAY_NORMAL): output.set_normal((vertex[Mesh.ARRAY_NORMAL] as Vector3).normalized())
                if vertex.has(Mesh.ARRAY_TEX_UV): output.set_uv(vertex[Mesh.ARRAY_TEX_UV])
                if vertex.has(Mesh.ARRAY_TEX_UV2): output.set_uv2(vertex[Mesh.ARRAY_TEX_UV2])
                if vertex.has(Mesh.ARRAY_COLOR): output.set_color(vertex[Mesh.ARRAY_COLOR])
                output.add_vertex(inverse*vertex.p)
                count+=1
    if count==0: return []
    output.index()
    return output.commit_to_arrays()

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
