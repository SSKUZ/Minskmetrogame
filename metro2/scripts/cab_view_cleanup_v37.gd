extends RefCounted
## Instance-only edits. Imported wagon files and the other three cars stay intact.
const Z_OLD := [-9.503,-8.754,-8.286,-6.99]
const Z_NEW := [-9.503,-9.20,-7.98,-6.99]
const Y_OLD := [0.95,2.081,2.759,3.25]
const Y_NEW := [0.95,2.03,2.98,3.25]

static func _remap(value: float, source: Array, target: Array) -> float:
    for i in range(source.size()-1):
        if value >= float(source[i])-0.0001 and value <= float(source[i+1])+0.0001:
            return lerpf(float(target[i]),float(target[i+1]),inverse_lerp(float(source[i]),float(source[i+1]),value))
    return value

static func _inside(v: Vector3, low: Vector3, high: Vector3) -> bool:
    return v.x >= low.x and v.x <= high.x and v.y >= low.y and v.y <= high.y and v.z >= low.z and v.z <= high.z

static func _discard(a: Vector3, b: Vector3, c: Vector3, metal: bool, opaque: bool) -> bool:
    # Old cabin seat frames, ladder/shelf and overhead bars share a material
    # batch with the passenger saloon. Remove only triangles inside this cab.
    if metal and _inside(a,Vector3(-1.32,0.95,-9.60),Vector3(1.32,3.30,-7.60)) and _inside(b,Vector3(-1.32,0.95,-9.60),Vector3(1.32,3.30,-7.60)) and _inside(c,Vector3(-1.32,0.95,-9.60),Vector3(1.32,3.30,-7.60)):
        return true
    # Window clipping is handled after vertex remapping, not by deleting
    # only fully enclosed triangles (which leaves large opaque polygons).
    # Remove the original right-hand door leaf and its outer rubber seal.
    # The smaller window seal remains and follows the enlarged glazing.
    for region in [AABB(Vector3(1.258,0.953,-8.886),Vector3(0.034,1.935,0.732)),AABB(Vector3(1.314,0.934,-8.906),Vector3(0.024,1.972,0.773))]:
        if opaque and _inside(a,region.position,region.end) and _inside(b,region.position,region.end) and _inside(c,region.position,region.end): return true
    return false

static func _barycentric(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
    var v0 := b-a
    var v1 := c-a
    var v2 := p-a
    var d00 := v0.dot(v0)
    var d01 := v0.dot(v1)
    var d11 := v1.dot(v1)
    var d20 := v2.dot(v0)
    var d21 := v2.dot(v1)
    var denom := d00*d11-d01*d01
    if absf(denom) < 0.00000001: return Vector3(1,0,0)
    var v := (d11*d20-d01*d21)/denom
    var w := (d00*d21-d01*d20)/denom
    return Vector3(1.0-v-w,v,w)

static func _clip_halfplane(poly: Array, axis: int, boundary: float, keep_greater: bool) -> Array:
    var result: Array = []
    if poly.is_empty(): return result
    for i in range(poly.size()):
        var a: Vector3 = poly[i]
        var b: Vector3 = poly[(i+1)%poly.size()]
        var av: float = a.y if axis == 1 else a.z
        var bv: float = b.y if axis == 1 else b.z
        var ai := av >= boundary if keep_greater else av <= boundary
        var bi := bv >= boundary if keep_greater else bv <= boundary
        if ai: result.append(a)
        if ai != bi:
            var t := (boundary-av)/(bv-av)
            result.append(a.lerp(b,t))
    return result

static func _outside_window(triangle: Array, low_y: float, high_y: float, low_z: float, high_z: float) -> Array:
    # Partition a side-wall triangle into disjoint pieces outside the opening.
    var remaining: Array = triangle
    var pieces: Array = []
    for rule in [[1,low_y,false],[1,high_y,true],[2,low_z,false],[2,high_z,true]]:
        var outside := _clip_halfplane(remaining,int(rule[0]),float(rule[1]),bool(rule[2]))
        if outside.size() >= 3: pieces.append(outside)
        remaining = _clip_halfplane(remaining,int(rule[0]),float(rule[1]),not bool(rule[2]))
        if remaining.size() < 3: break
    return pieces

static func apply(lead: Node3D) -> void:
    var paint: Material
    for child in lead.find_children("*","MeshInstance3D",true,false):
        var instance := child as MeshInstance3D
        if not instance.visible: continue
        var transform := lead.global_transform.affine_inverse()*instance.global_transform
        var inverse := transform.affine_inverse()
        var box: AABB = transform*instance.get_aabb()
        if box.position.z > -7.6 or box.end.z < -9.60 or box.position.y < 0.0: continue
        var metal := box.size.z > 18.0 and absf(box.position.y-0.09) < 0.01 and absf(box.end.y-3.1075) < 0.01
        var side := (box.position.x < -1.24 or box.end.x > 1.24) and not str(instance.name).begins_with("mirror-") and box.position.z > -9.61
        if not metal and not side: continue
        if box.position.x < -1.33 and box.end.x > 1.33 and absf(box.end.z+6.99) < 0.02:
            paint = instance.get_active_material(0)
        var replacement := ArrayMesh.new()
        var changed := false
        for surface in range(instance.mesh.get_surface_count()):
            var arrays: Array = instance.mesh.surface_get_arrays(surface).duplicate(true)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
            if indices.is_empty():
                indices.resize(vertices.size())
                for i in range(vertices.size()): indices[i] = i
            var source_material := instance.get_active_material(surface) as BaseMaterial3D
            var opaque := source_material != null and source_material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
            var kept := PackedInt32Array()
            var clipped := SurfaceTool.new()
            clipped.begin(Mesh.PRIMITIVE_TRIANGLES)
            var clipped_count := 0
            var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
            for triangle in range(0,indices.size(),3):
                var ia: int = indices[triangle]
                var ib: int = indices[triangle+1]
                var ic: int = indices[triangle+2]
                var a: Vector3 = transform*vertices[ia]
                var b: Vector3 = transform*vertices[ib]
                var c: Vector3 = transform*vertices[ic]
                if _discard(a,b,c,metal,opaque):
                    changed = true
                    continue
                var side_wall := opaque and absf(a.x) > 1.245 and absf(b.x) > 1.245 and absf(c.x) > 1.245 and signf(a.x) == signf(b.x) and signf(b.x) == signf(c.x) and maxf(absf(a.x-b.x),maxf(absf(a.x-c.x),absf(b.x-c.x))) < 0.08
                if side_wall:
                    var remapped: Array = []
                    for v in [a,b,c]:
                        var p: Vector3 = v
                        p.z = _remap(p.z,Z_OLD,Z_NEW)
                        p.y = _remap(p.y,Y_OLD,Y_NEW)
                        remapped.append(p)
                    var pieces := _outside_window(remapped,2.03,2.98,-9.20,-7.98)
                    var fully_outside := pieces.size() == 1 and (pieces[0] as Array).size() == 3
                    if not fully_outside:
                        changed = true
                        for piece in pieces:
                            for k in range(1,piece.size()-1):
                                for p in [piece[0],piece[k],piece[k+1]]:
                                    var bary := _barycentric(p,remapped[0],remapped[1],remapped[2])
                                    if uvs.size() == vertices.size():
                                        clipped.set_uv(uvs[ia]*bary.x+uvs[ib]*bary.y+uvs[ic]*bary.z)
                                    clipped.add_vertex(inverse*p)
                                    clipped_count += 1
                        continue
                kept.append(ia); kept.append(ib); kept.append(ic)
            for i in range(vertices.size()):
                var point: Vector3 = transform*vertices[i]
                if absf(point.x) > 1.24 and point.z >= -9.5031 and point.z <= -6.99 and point.y >= 0.95 and point.y <= 3.25:
                    point.z = _remap(point.z,Z_OLD,Z_NEW)
                    point.y = _remap(point.y,Y_OLD,Y_NEW)
                    vertices[i] = inverse*point
                    changed = true
            arrays[Mesh.ARRAY_VERTEX] = vertices
            arrays[Mesh.ARRAY_INDEX] = kept
            if kept.is_empty() and clipped_count == 0: continue
            if not kept.is_empty():
                replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
                replacement.surface_set_material(replacement.get_surface_count()-1,instance.get_active_material(surface))
            if clipped_count > 0:
                clipped.generate_normals()
                clipped.set_material(instance.get_active_material(surface))
                clipped.commit(replacement)
        if changed:
            if replacement.get_surface_count() == 0: instance.hide()
            else:
                instance.mesh = replacement
                for surface in range(replacement.get_surface_count()): instance.set_surface_override_material(surface,null)
    # A single transparent pane spans each enlarged side-window outline.
    # The old small glass and opaque center have been removed above.
    var glazing := StandardMaterial3D.new()
    glazing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glazing.albedo_color = Color(0.77,0.88,0.95,0.075)
    glazing.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glazing.cull_mode = BaseMaterial3D.CULL_DISABLED
    glazing.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    for side in [-1.0,1.0]:
        var pane := MeshInstance3D.new()
        pane.name = "FullCabSideWindowLeft" if side < 0.0 else "FullCabSideWindowRight"
        var glass_mesh := QuadMesh.new()
        glass_mesh.size = Vector2(1.22,0.95)
        pane.mesh = glass_mesh
        pane.material_override = glazing
        pane.position = Vector3(side*1.285,2.505,-8.59)
        pane.rotation.y = PI*0.5
        pane.layers = 3
        pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        lead.add_child(pane)
    # Fill the removed right door with matching blue wall around a broad window.
    # Covers just the former door opening, not the console, phone or exterior.
    if paint == null:
        var fallback := StandardMaterial3D.new()
        fallback.albedo_color = Color(0.137,0.322,0.451)
        fallback.roughness = 0.7
        paint = fallback
    for section in [AABB(Vector3(1.262,0.95,-9.34),Vector3(0.026,1.08,1.50)),AABB(Vector3(1.262,2.98,-9.34),Vector3(0.026,0.12,1.50)),AABB(Vector3(1.262,2.03,-9.34),Vector3(0.026,0.95,0.14)),AABB(Vector3(1.262,2.03,-7.98),Vector3(0.026,0.95,0.14))]:
        var panel := MeshInstance3D.new()
        panel.name = "RightCabWindowSurround"
        var mesh := BoxMesh.new()
        mesh.size = section.size
        panel.mesh = mesh
        panel.material_override = paint
        panel.position = section.get_center()
        panel.layers = 3
        lead.add_child(panel)

static func mirror_parts(lead: Node3D) -> Dictionary:
    var result := {-1.0:[],1.0:[]}
    for child in lead.find_children("*","MeshInstance3D",true,false):
        var source := child as MeshInstance3D
        var transform := lead.global_transform.affine_inverse()*source.global_transform
        var box: AABB = transform*source.get_aabb()
        var backing := box.size.x > 2.7 and box.position.z < -9.70 and box.end.z > -9.63 and box.position.y > 2.40 and box.end.y < 2.75
        var glass := box.size.x > 2.8 and box.size.z < 0.002 and absf(box.position.z+9.651) < 0.004 and box.position.y > 2.54
        if not backing and not glass: continue
        source.hide()
        for side in [-1.0,1.0]:
            var mesh := ArrayMesh.new()
            for surface in range(source.mesh.get_surface_count()):
                var arrays: Array = source.mesh.surface_get_arrays(surface).duplicate(true)
                var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
                var original: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
                if original.is_empty():
                    original.resize(vertices.size())
                    for i in range(vertices.size()): original[i] = i
                var kept := PackedInt32Array()
                for i in range(0,original.size(),3):
                    if (transform*vertices[original[i]]).x*side > 0.0:
                        kept.append(original[i]); kept.append(original[i+1]); kept.append(original[i+2])
                if kept.is_empty(): continue
                arrays[Mesh.ARRAY_INDEX] = kept
                mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
                mesh.surface_set_material(mesh.get_surface_count()-1,source.get_active_material(surface))
            var part := MeshInstance3D.new()
            part.mesh = mesh
            part.transform = transform
            part.name = "OriginalMirrorGlass" if glass else "OriginalMirrorBracket"
            part.set_meta("reflection",glass)
            result[side].append(part)
    return result
