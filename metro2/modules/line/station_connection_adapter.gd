extends RefCounted
## Standalone stations have opaque rectangular far-end caps in batched meshes.
## Open only those full-track closures in route instances; retain source resources.

static func open_connections(station: Node3D) -> Dictionary:
    var meshes: Array[MeshInstance3D]=[]
    var caps: Array[AABB]=[]
    var inverse := station.global_transform.affine_inverse()
    for node in station.find_children("*","MeshInstance3D",true,false):
        var instance := node as MeshInstance3D
        if instance.mesh==null or not instance.visible: continue
        meshes.append(instance)
        var pose := inverse*instance.global_transform
        var bounds := pose*instance.get_aabb()
        if bounds.size.y<3.8 or bounds.size.x<3.4: continue
        for surface in range(instance.mesh.get_surface_count()):
            if not _cap_material(instance.get_active_material(surface)): continue
            var arrays: Array=instance.mesh.surface_get_arrays(surface)
            var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
            var indices: PackedInt32Array=_indices(arrays,vertices.size())
            for i in range(0,indices.size(),3):
                var a: Vector3=pose*vertices[indices[i]]
                var b: Vector3=pose*vertices[indices[i+1]]
                var c: Vector3=pose*vertices[indices[i+2]]
                var box := AABB(a,Vector3.ZERO).expand(b).expand(c)
                if box.size.z>0.002 or box.size.x<3.4 or box.size.x>4.25 or box.size.y<3.8 or box.size.y>5.7: continue
                var centre := box.get_center()
                if minf(absf(centre.x-0.992),absf(centre.x+11.732))>0.18: continue
                if box.position.y>0.35 or box.end.y<3.8 or absf(centre.z-39.612)<25.0: continue
                var merged := false
                for j in range(caps.size()):
                    if caps[j].get_center().distance_to(centre)<0.25:
                        caps[j]=caps[j].merge(box)
                        merged=true
                        break
                if not merged: caps.append(box)
    if caps.is_empty(): return {}
    for instance in meshes:
        var original := instance.mesh
        var pose := inverse*instance.global_transform
        var bounds := pose*instance.get_aabb()
        if not caps.any(func(cap: AABB) -> bool: return cap.grow(0.02).intersects(bounds)): continue
        var replacement := ArrayMesh.new()
        var changed := false
        for surface in range(original.get_surface_count()):
            var arrays: Array=original.surface_get_arrays(surface).duplicate(true)
            var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
            var indices: PackedInt32Array=_indices(arrays,vertices.size())
            var kept := PackedInt32Array()
            var candidate: bool=_cap_material(instance.get_active_material(surface))
            if not candidate: kept=indices
            for i in range(0,indices.size() if candidate else 0,3):
                var a: Vector3=pose*vertices[indices[i]]
                var b: Vector3=pose*vertices[indices[i+1]]
                var c: Vector3=pose*vertices[indices[i+2]]
                var remove := false
                for cap in caps:
                    var volume := cap.grow(0.012)
                    if volume.has_point(a) and volume.has_point(b) and volume.has_point(c):
                        remove=true
                        break
                if remove: changed=true
                else: kept.append_array(PackedInt32Array([indices[i],indices[i+1],indices[i+2]]))
            if kept.is_empty(): continue
            arrays[Mesh.ARRAY_INDEX]=kept
            replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
            var material := instance.get_surface_override_material(surface)
            replacement.surface_set_material(replacement.get_surface_count()-1,material if material!=null else original.surface_get_material(surface))
        if changed:
            instance.mesh=replacement
            for surface in range(replacement.get_surface_count()): instance.set_surface_override_material(surface,null)
            if replacement.get_surface_count()==0: instance.hide()
    station.set_meta("line_opened_far_caps",caps.size())
    var low := INF
    var high := -INF
    var low_profile := Vector2(1.925,4.455)
    var high_profile := low_profile
    for cap in caps:
        var z := cap.get_center().z
        var profile := Vector2(cap.size.x*0.5,cap.end.y)
        if z<low: low=z;low_profile=profile
        if z>high: high=z;high_profile=profile
    return {"low":low,"high":high,"low_profile":low_profile,"high_profile":high_profile}

static func _cap_material(material: Material) -> bool:
    var opaque := material as BaseMaterial3D
    return opaque!=null and opaque.albedo_texture==null and maxf(opaque.albedo_color.r,maxf(opaque.albedo_color.g,opaque.albedo_color.b))<0.25

static func _indices(arrays: Array, count: int) -> PackedInt32Array:
    if arrays[Mesh.ARRAY_INDEX]!=null and not (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
        return arrays[Mesh.ARRAY_INDEX]
    var values := PackedInt32Array()
    for i in range(count): values.append(i)
    return values
