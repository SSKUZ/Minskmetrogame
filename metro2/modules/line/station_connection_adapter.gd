extends RefCounted
## Route-only, build-time cuts. Standalone architecture and shared source meshes
## remain intact. Both batched surfaces and MultiMesh instances use the same cut.
const TRACKS := [0.992,-11.732]

static func open_connections(station: Node3D, budget: RefCounted = null) -> Dictionary:
    var datum: Dictionary=station.get_meta("metro_line_datum",{})
    if datum.is_empty(): return {}
    var low: float=float(datum.low_local_z)
    var high: float=float(datum.high_local_z)
    var volumes: Array[Dictionary]=[]
    for x in TRACKS:
        # The line owns geometry outside these exact station boundaries.
        if bool(datum.get("trim_external_portals",false)):
            var width: float=maxf(float(datum.low_profile[0]),float(datum.high_profile[0]))+0.30
            volumes.append(_box_volume(AABB(Vector3(x-width,-0.65,low-16.0),Vector3(width*2.0,8.9,16.0)),false))
            volumes.append(_box_volume(AABB(Vector3(x-width,-0.65,high),Vector3(width*2.0,8.9,16.0)),false))
        for end in [low,high]:
            var profile: Array=datum.low_profile if end==low else datum.high_profile
            volumes.append(_opening(x,end,Vector2(float(profile[0]),float(profile[1])),datum))
    var inverse: Transform3D=station.global_transform.affine_inverse()
    var nodes: Array[Node]=station.find_children("*","GeometryInstance3D",true,false)
    var changed := 0
    for node in nodes:
        if budget!=null and not await budget.checkpoint(): return {}
        if not (node as Node3D).is_visible_in_tree(): continue
        if node is MeshInstance3D:
            var instance := node as MeshInstance3D
            if instance.mesh==null: continue
            var materials: Array[Material]=[]
            for surface in range(instance.mesh.get_surface_count()): materials.append(instance.get_active_material(surface))
            var pose: Transform3D=inverse*instance.global_transform
            var replacement: ArrayMesh=await _cut_mesh(instance.mesh,pose,materials,volumes,datum,budget)
            if replacement!=null:
                instance.mesh=replacement
                for surface in range(replacement.get_surface_count()): instance.set_surface_override_material(surface,null)
                if replacement.get_surface_count()==0: instance.hide()
                changed+=1
        elif node is MultiMeshInstance3D:
            var instance := node as MultiMeshInstance3D
            var original: MultiMesh=instance.multimesh
            if original==null or original.mesh==null: continue
            var retained: Array[int]=[]
            for i in range(original.instance_count):
                if budget!=null and not await budget.checkpoint(): return {}
                var local: Transform3D=original.get_instance_transform(i)
                var pose: Transform3D=inverse*instance.global_transform*local
                var materials: Array[Material]=[]
                for surface in range(original.mesh.get_surface_count()):
                    materials.append(instance.material_override if instance.material_override!=null else original.mesh.surface_get_material(surface))
                var replacement: ArrayMesh=await _cut_mesh(original.mesh,pose,materials,volumes,datum,budget)
                if replacement==null:
                    retained.append(i)
                    continue
                changed+=1
                if replacement.get_surface_count()==0: continue
                # Preserve instance colours/custom data as well as the transform.
                var part := MultiMeshInstance3D.new()
                part.name=str(instance.name)+"_OpenPortal%d" % i
                part.transform=instance.transform
                part.layers=instance.layers
                part.cast_shadow=instance.cast_shadow
                part.material_override=instance.material_override
                part.multimesh=_copy_instances(original,[i],replacement)
                instance.get_parent().add_child(part)
            if retained.size()!=original.instance_count:
                instance.multimesh=_copy_instances(original,retained,original.mesh)
                if retained.is_empty(): instance.hide()
    station.set_meta("line_opened_portal_meshes",changed)
    return {"low":low,"high":high,"low_profile":datum.low_profile,"high_profile":datum.high_profile}

static func _copy_instances(source: MultiMesh, indices: Array[int], mesh: Mesh) -> MultiMesh:
    var result := MultiMesh.new()
    result.transform_format=source.transform_format
    result.use_colors=source.use_colors
    result.use_custom_data=source.use_custom_data
    result.mesh=mesh
    result.instance_count=indices.size()
    for i in range(indices.size()):
        result.set_instance_transform(i,source.get_instance_transform(indices[i]))
        if source.use_colors: result.set_instance_color(i,source.get_instance_color(indices[i]))
        if source.use_custom_data: result.set_instance_custom_data(i,source.get_instance_custom_data(indices[i]))
    return result

static func _box_volume(box: AABB, cap: bool) -> Dictionary:
    var planes: Array[Plane]=[]
    for axis in range(3):
        var normal := Vector3.ZERO
        normal[axis]=1.0
        planes.append(Plane(normal,box.end[axis]))
        planes.append(Plane(-normal,-box.position[axis]))
    return {"bounds":box,"planes":planes,"cap":cap}

static func _opening(x: float, z: float, profile: Vector2, datum: Dictionary) -> Dictionary:
    var volume: Dictionary=_box_volume(AABB(Vector3(x-profile.x,-0.6,z-0.25),Vector3(profile.x*2.0,profile.y+0.6,0.5)),true)
    var shape: String=str(datum.get("portal_shape","round"))
    var spring: float=float(datum.get("portal_spring_y",2.3))
    var crown: float=float(datum.get("portal_crown_m",0.0))
    if shape=="ellipse" or crown>0.0:
        for i in range(48):
            var a: Vector2
            var b: Vector2
            if shape=="ellipse":
                var ta: float=PI-float(i)*PI/48.0
                var tb: float=PI-float(i+1)*PI/48.0
                a=Vector2(x+profile.x*cos(ta),spring+(profile.y-spring)*sin(ta))
                b=Vector2(x+profile.x*cos(tb),spring+(profile.y-spring)*sin(tb))
            else:
                var xa: float=-1.0+float(i)*2.0/48.0
                var xb: float=-1.0+float(i+1)*2.0/48.0
                a=Vector2(x+profile.x*xa,profile.y-crown*xa*xa)
                b=Vector2(x+profile.x*xb,profile.y-crown*xb*xb)
            var normal: Vector3=Vector3(a.y-b.y,b.x-a.x,0.0).normalized()
            volume.planes.append(Plane(normal,normal.dot(Vector3(a.x,a.y,z))))
    return volume

static func _cut_mesh(mesh: Mesh, pose: Transform3D, materials: Array[Material], volumes: Array[Dictionary], datum: Dictionary, budget: RefCounted) -> ArrayMesh:
    if absf(pose.basis.determinant())<0.0000000001: return null
    var bounds: AABB=pose*mesh.get_aabb()
    if not volumes.any(func(v: Dictionary): return v.bounds.grow(0.001).intersects(bounds)): return null
    var result := ArrayMesh.new()
    var lining: bool=(bounds.size.x>3.0 and bounds.size.y>3.0) or (bounds.size.z>1.0 and ((bounds.size.y>3.0 and bounds.size.x<0.5) or (bounds.size.x>3.0 and bounds.size.y<0.5)))
    var changed := false
    var inverse: Transform3D=pose.affine_inverse()
    var normal_basis: Basis=pose.basis.inverse().transposed()
    for surface in range(mesh.get_surface_count()):
        if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return null
        var arrays: Array=mesh.surface_get_arrays(surface)
        var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
        var indices: PackedInt32Array=_indices(arrays,vertices.size())
        var output := SurfaceTool.new()
        output.begin(Mesh.PRIMITIVE_TRIANGLES)
        var emitted := 0
        for i in range(0,indices.size(),3):
            if i%192==0 and budget!=null and not await budget.checkpoint(): return null
            var polygon: Array[Dictionary]=[]
            for j in range(3):
                var index: int=indices[i+j]
                var vertex: Dictionary={"p":pose*vertices[index]}
                for channel in [Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR]:
                    if arrays[channel]!=null and not arrays[channel].is_empty(): vertex[channel]=arrays[channel][index]
                if arrays[Mesh.ARRAY_TANGENT]!=null and not arrays[Mesh.ARRAY_TANGENT].is_empty():
                    var t: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
                    vertex[Mesh.ARRAY_TANGENT]=Vector4(t[index*4],t[index*4+1],t[index*4+2],t[index*4+3])
                if lining and vertex.has(Mesh.ARRAY_NORMAL):
                    var n: Vector3=normal_basis*vertex[Mesh.ARRAY_NORMAL]
                    var snapped: Vector3=_snap(vertex.p,n.normalized(),datum)
                    if snapped.distance_squared_to(vertex.p)>0.00000001: changed=true;vertex.p=snapped
                polygon.append(vertex)
            var triangle_bounds: AABB=AABB(polygon[0].p,Vector3.ZERO).expand(polygon[1].p).expand(polygon[2].p)
            var face: Vector3=(polygon[1].p-polygon[0].p).cross(polygon[2].p-polygon[0].p)
            var pieces: Array=[polygon]
            for volume in volumes:
                if not volume.bounds.grow(0.001).intersects(triangle_bounds): continue
                if bool(volume.cap) and (not _cap_material(materials[surface]) or absf(face.normalized().z)<0.6 or triangle_bounds.size.y<1.5 or triangle_bounds.size.x<0.7): continue
                if not bool(volume.cap):
                    if triangle_bounds.position.x<float(volume.bounds.position.x)-0.001 or triangle_bounds.end.x>float(volume.bounds.end.x)+0.001: continue
                    var centre_x: float=float(volume.bounds.get_center().x)
                    var inner_width: float=float(volume.bounds.size.x)*0.5-0.30
                    var roof_or_end: bool=triangle_bounds.size.x>3.0 and absf(triangle_bounds.get_center().x-centre_x)<0.5
                    var side_wall: bool=triangle_bounds.size.x<0.5 and triangle_bounds.size.y>3.0 and absf(absf(triangle_bounds.get_center().x-centre_x)-inner_width)<0.30
                    if not roof_or_end and not side_wall: continue
                var next: Array=[]
                for piece in pieces:
                    var cut: Array=_subtract(piece,volume.planes)
                    if cut.size()!=1 or cut[0]!=piece: changed=true
                    next.append_array(cut)
                pieces=next
            for piece in pieces:
                for j in range(1,piece.size()-1):
                    if ((piece[j].p-piece[0].p) as Vector3).cross(piece[j+1].p-piece[0].p).length_squared()<0.000000000001: continue
                    for vertex in [piece[0],piece[j],piece[j+1]]:
                        if vertex.has(Mesh.ARRAY_NORMAL): output.set_normal((vertex[Mesh.ARRAY_NORMAL] as Vector3).normalized())
                        if vertex.has(Mesh.ARRAY_TEX_UV): output.set_uv(vertex[Mesh.ARRAY_TEX_UV])
                        if vertex.has(Mesh.ARRAY_TEX_UV2): output.set_uv2(vertex[Mesh.ARRAY_TEX_UV2])
                        if vertex.has(Mesh.ARRAY_COLOR): output.set_color(vertex[Mesh.ARRAY_COLOR])
                        if vertex.has(Mesh.ARRAY_TANGENT):
                            var t: Vector4=vertex[Mesh.ARRAY_TANGENT]
                            output.set_tangent(Plane(Vector3(t.x,t.y,t.z).normalized(),t.w))
                        output.add_vertex(inverse*vertex.p)
                        emitted+=1
        if emitted>0:
            output.index()
            output.commit(result)
            result.surface_set_material(result.get_surface_count()-1,materials[surface])
    return result if changed else null

static func _snap(point: Vector3, normal: Vector3, datum: Dictionary) -> Vector3:
    for end in [float(datum.low_local_z),float(datum.high_local_z)]:
        var profile: Array=datum.low_profile if end==float(datum.low_local_z) else datum.high_profile
        for x in TRACKS:
            if absf(point.x-x)>float(profile[0])+0.20 or absf(point.z-end)>12.0: continue
            if point.y>=0.5 and absf(point.z-end)<0.20: point.z=end
            # Some existing rectangular throats stop their side walls below
            # their roof. Close that portal seam without touching station halls.
            if str(datum.get("portal_shape","round"))=="rectangle" and absf(normal.x)>0.8 and absf(normal.y)<0.2:
                if absf(absf(point.x-x)-float(profile[0]))<0.18 and point.y>float(profile[1])-0.50 and point.y<float(profile[1]): point.y=float(profile[1])
    return point

static func _subtract(polygon: Array, planes: Array) -> Array:
    var inside: Array=polygon
    var outside: Array=[]
    for plane in planes:
        var part: Array=_clip(inside,plane,false)
        if part.size()>=3: outside.append(part)
        inside=_clip(inside,plane,true)
        if inside.size()<3: break
    return outside

static func _clip(polygon: Array, plane: Plane, keep_inside: bool) -> Array:
    var result: Array=[]
    if polygon.is_empty(): return result
    var previous: Dictionary=polygon[-1]
    var d0: float=plane.distance_to(previous.p)
    var previous_in: bool=d0<=0.0 if keep_inside else d0>0.0
    for current in polygon:
        var d1: float=plane.distance_to(current.p)
        var current_in: bool=d1<=0.0 if keep_inside else d1>0.0
        if previous_in!=current_in:
            var weight: float=d0/(d0-d1)
            var vertex: Dictionary={}
            # Position uses a String key; mesh channels use integer keys.
            # Vector and Color attributes share lerp(), so preserve each value's
            # native type without comparing unlike Dictionary key types.
            for key in previous:
                vertex[key]=previous[key].lerp(current[key],weight)
            result.append(vertex)
        if current_in: result.append(current)
        previous=current;d0=d1;previous_in=current_in
    return result

static func _cap_material(material: Material) -> bool:
    var opaque := material as BaseMaterial3D
    return opaque!=null and opaque.albedo_texture==null and maxf(opaque.albedo_color.r,maxf(opaque.albedo_color.g,opaque.albedo_color.b))<0.25

static func _indices(arrays: Array, count: int) -> PackedInt32Array:
    if arrays[Mesh.ARRAY_INDEX]!=null and not (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty(): return arrays[Mesh.ARRAY_INDEX]
    var result := PackedInt32Array()
    for i in range(count): result.append(i)
    return result
