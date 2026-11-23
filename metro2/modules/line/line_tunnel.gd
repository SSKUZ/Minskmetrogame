extends "res://scripts/tunnel_lightweight_straight.gd"
## Reuse the detailed existing tunnel meshes. Warp their vertices onto the route,
## including each running/contact rail. Exact portal clipping avoids station walls.
var path: RefCounted
var _route_active: Dictionary = {}
var _pool: Array[Node3D] = []
var _source_parts: Dictionary = {}

func _ready() -> void:
    super._ready()
    # 1,520 mm clear gauge plus the existing 95 mm rail head.
    for i in range(_rail_clips.instance_count):
        var pose := _rail_clips.get_instance_transform(i)
        pose.origin.x=signf(pose.origin.x)*0.8075
        _rail_clips.set_instance_transform(i,pose)

func sync_to_view() -> void:
    if path==null or not is_instance_valid(_train) or not is_instance_valid(_camera): return
    var required: Dictionary = {}
    _include_slots(required,_train.global_position.z+_train_bounds.position.z,_train.global_position.z+_train_bounds.end.z)
    _include_slots(required,_camera.global_position.z,_camera.global_position.z)
    var pieces: Dictionary = {}
    for slot in required:
        for piece in path.tunnel_pieces(float(slot)*16.0,float(slot+1)*16.0):
            pieces["%.4f:%.4f" % [piece.x,piece.y]]=piece
    for key in _route_active.keys():
        if pieces.has(key): continue
        var section: Node3D=_route_active[key]
        section.hide()
        _pool.append(section)
        _route_active.erase(key)
    for key in pieces:
        if _route_active.has(key): continue
        var section: Node3D
        if _pool.is_empty():
            section=_new_section()
            _remember_parts(section)
        else:
            section=_pool.pop_back()
        _warp_section(section,pieces[key])
        section.show()
        _route_active[key]=section

func _remember_parts(section: Node3D) -> void:
    var records: Array[Dictionary] = []
    var inverse := section.global_transform.affine_inverse()
    for child in section.find_children("*","Node3D",true,false):
        var n := child as Node3D
        var pose := inverse*n.global_transform
        if n is MeshInstance3D:
            var mesh_node := n as MeshInstance3D
            if mesh_node.mesh==_rail: pose.origin.x=signf(pose.origin.x)*0.8075
            records.append({"node":n,"pose":pose,"mesh":mesh_node.mesh})
        elif n is MultiMeshInstance3D:
            records.append({"node":n,"pose":pose,"multi":(n as MultiMeshInstance3D).multimesh})
        elif n is Light3D:
            records.append({"node":n,"pose":pose})
    # Every saved pose already includes its ancestors, so use one identity frame.
    for child in section.find_children("*","Node3D",true,false):
        (child as Node3D).transform=Transform3D.IDENTITY
    _source_parts[section]=records

func _point(local: Vector3, start: float, factor: float) -> Vector3:
    var z := start+local.z*factor
    var frame: Transform3D=path.frame_at(z,center_x)
    var section: Vector2=path.cross_section_at(z)
    # Preserve running/contact rails and the walking datum; taper only the outer lining.
    var x: float=local.x if absf(local.x)<=1.8 else signf(local.x)*(1.8+(absf(local.x)-1.8)*(section.x-1.8)/1.35)
    var y: float=local.y if local.y<=1.2 else 1.2+(local.y-1.2)*(section.y-1.2)/5.8
    return frame*Vector3(x,y,0.0)

func _warp_section(section: Node3D, span: Vector2) -> void:
    var factor: float=(span.y-span.x)/16.0
    for record in _source_parts[section]:
        var n: Node3D=record.node
        var pose: Transform3D=record.pose
        if record.has("mesh"):
            var source: Mesh=record.mesh
            var warped := ArrayMesh.new()
            for s in range(source.get_surface_count()):
                var arrays: Array=source.surface_get_arrays(s).duplicate(true)
                var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
                var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
                for v in range(vertices.size()):
                    var local: Vector3=pose*vertices[v]
                    vertices[v]=_point(local,span.x,factor)
                    if not normals.is_empty():
                        var frame: Transform3D=path.frame_at(span.x+local.z*factor,center_x)
                        normals[v]=(frame.basis*pose.basis.inverse().transposed()*normals[v]).normalized()
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
                var local := pose*original.get_instance_transform(i)
                var frame: Transform3D=path.frame_at(span.x+local.origin.z*factor,center_x)
                multi.set_instance_transform(i,Transform3D(frame.basis*local.basis,_point(local.origin,span.x,factor)))
            (n as MultiMeshInstance3D).multimesh=multi
        else:
            var frame: Transform3D=path.frame_at(span.x+pose.origin.z*factor,center_x)
            n.transform=Transform3D(frame.basis*pose.basis,_point(pose.origin,span.x,factor))
    section.get_node("WallLight").visible=posmod(floori(span.x/16.0),2)==0

func constrain_camera(world_position: Vector3) -> Vector3:
    if path.in_station(world_position.z,10.0): return world_position
    if world_position.z>96.0:
        world_position.y=maxf(world_position.y,path.position_at(world_position.z).y+0.35)
        return world_position
    var centre: Vector3=path.position_at(world_position.z,center_x)
    world_position.x=clampf(world_position.x,centre.x-2.95,centre.x+2.95)
    world_position.y=clampf(world_position.y,centre.y+0.15,centre.y+6.6)
    return world_position
