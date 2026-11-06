extends RefCounted
## Modify only the instantiated head car; never rewrite imported GLBs.
const WINDOW_LOW_Y := 2.03
const WINDOW_HIGH_Y := 2.98
const WINDOW_LOW_Z := -9.20
const WINDOW_HIGH_Z := -7.98

static func _triangle_bounds(a: Vector3,b: Vector3,c: Vector3) -> AABB:
    var low := a.min(b).min(c)
    return AABB(low,a.max(b).max(c)-low)

static func _half(poly: Array, axis: int, edge: float, greater: bool) -> Array:
    var result: Array = []
    for i in range(poly.size()):
        var a: Array = poly[i]
        var b: Array = poly[(i+1)%poly.size()]
        var av: float = a[0][axis]
        var bv: float = b[0][axis]
        var ai: bool = av >= edge if greater else av <= edge
        var bi: bool = bv >= edge if greater else bv <= edge
        if ai: result.append(a)
        if ai != bi:
            var t := (edge-av)/(bv-av)
            result.append([a[0].lerp(b[0],t),a[1].lerp(b[1],t),a[2].lerp(b[2],t),a[3].lerp(b[3],t)])
    return result

static func _subtract(poly: Array, volume: AABB) -> Array:
    var outside: Array = []
    var remaining: Array = poly
    for axis in range(3):
        for upper in [false,true]:
            var edge: float = volume.end[axis] if upper else volume.position[axis]
            var piece := _half(remaining,axis,edge,upper)
            if piece.size() >= 3: outside.append(piece)
            remaining = _half(remaining,axis,edge,not upper)
            if remaining.size() < 3: return outside
    return outside

static func apply(lead: Node3D) -> void:
    var paint: Material
    var windows := [AABB(Vector3(-1.40,WINDOW_LOW_Y,WINDOW_LOW_Z),Vector3(0.22,0.95,1.22)),AABB(Vector3(1.18,WINDOW_LOW_Y,WINDOW_LOW_Z),Vector3(0.22,0.95,1.22))]
    var right_door := AABB(Vector3(1.24,0.932,-8.93),Vector3(0.13,2.268,0.82))
    for child in lead.find_children("*","MeshInstance3D",true,false):
        var instance := child as MeshInstance3D
        if not instance.visible: continue
        var transform := lead.global_transform.affine_inverse()*instance.global_transform
        var inverse := transform.affine_inverse()
        var box: AABB = transform*instance.get_aabb()
        var metal := box.size.z > 18.0 and absf(box.position.y-0.09) < 0.01 and absf(box.end.y-3.1075) < 0.01
        if box.position.x < -1.33 and box.end.x > 1.33 and absf(box.end.z+6.99) < 0.02:
            paint = instance.get_active_material(0)
        var volumes: Array = windows.duplicate()
        volumes.append(right_door)
        if metal: volumes.append(AABB(Vector3(-1.32,0.95,-9.60),Vector3(2.64,2.35,2.0)))
        var relevant := false
        for volume in volumes:
            if box.intersects(volume): relevant = true
        if not relevant: continue
        var replacement := ArrayMesh.new()
        var changed := false
        for surface in range(instance.mesh.get_surface_count()):
            var material := instance.get_active_material(surface)
            var arrays: Array = instance.mesh.surface_get_arrays(surface).duplicate(true)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
            var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
            var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
            var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
            if indices.is_empty():
                indices.resize(vertices.size())
                for i in range(vertices.size()): indices[i] = i
            var kept := PackedInt32Array()
            var clipped := SurfaceTool.new()
            clipped.begin(Mesh.PRIMITIVE_TRIANGLES)
            var clipped_count := 0
            for triangle in range(0,indices.size(),3):
                var ids := [indices[triangle],indices[triangle+1],indices[triangle+2]]
                var a: Vector3 = transform*vertices[ids[0]]
                var b: Vector3 = transform*vertices[ids[1]]
                var c: Vector3 = transform*vertices[ids[2]]
                var tri_box := _triangle_bounds(a,b,c)
                var cuts: Array = []
                for volume in volumes:
                    if tri_box.intersects(volume): cuts.append(volume)
                if cuts.is_empty():
                    kept.append_array(PackedInt32Array(ids))
                    continue
                changed = true
                var poly: Array = []
                for id in ids:
                    poly.append([transform*vertices[id],normals[id] if normals.size() == vertices.size() else Vector3.UP,uvs[id] if uvs.size() == vertices.size() else Vector2.ZERO,colors[id] if colors.size() == vertices.size() else Color.WHITE])
                var pieces: Array = [poly]
                for volume in cuts:
                    var next: Array = []
                    for piece in pieces: next.append_array(_subtract(piece,volume))
                    pieces = next
                for piece in pieces:
                    for k in range(1,piece.size()-1):
                        for vertex in [piece[0],piece[k],piece[k+1]]:
                            clipped.set_normal(vertex[1].normalized())
                            clipped.set_uv(vertex[2])
                            clipped.set_color(vertex[3])
                            clipped.add_vertex(inverse*vertex[0])
                            clipped_count += 1
            if not kept.is_empty():
                arrays[Mesh.ARRAY_INDEX] = kept
                replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
                replacement.surface_set_material(replacement.get_surface_count()-1,material)
            if clipped_count > 0:
                clipped.set_material(material)
                clipped.commit(replacement)
        if changed:
            if replacement.get_surface_count() == 0: instance.hide()
            else:
                instance.mesh = replacement
                for surface in range(replacement.get_surface_count()): instance.set_surface_override_material(surface,null)
    # New panes occupy actual holes; all old glass, seals and wall fragments in
    # those holes were subtracted above, including large cross-boundary faces.
    var glazing := StandardMaterial3D.new()
    glazing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glazing.albedo_color = Color(0.0,0.0,0.0,0.018)
    glazing.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glazing.cull_mode = BaseMaterial3D.CULL_DISABLED
    glazing.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    var rubber := StandardMaterial3D.new()
    rubber.albedo_color = Color(0.018,0.022,0.026)
    rubber.roughness = 0.92
    for side in [-1.0,1.0]:
        var pane := MeshInstance3D.new()
        pane.name = "FullCabSideWindowLeft" if side < 0.0 else "FullCabSideWindowRight"
        var glass_mesh := QuadMesh.new()
        glass_mesh.size = Vector2(1.22,0.95)
        pane.mesh = glass_mesh
        pane.material_override = glazing
        pane.position = Vector3(side*1.29,2.505,-8.59)
        pane.rotation.y = PI*0.5
        pane.layers = 4
        pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        lead.add_child(pane)
        for rect in [AABB(Vector3(-0.018,2.008,-9.222),Vector3(0.036,0.022,1.264)),AABB(Vector3(-0.018,2.98,-9.222),Vector3(0.036,0.022,1.264)),AABB(Vector3(-0.018,2.03,-9.222),Vector3(0.036,0.95,0.022)),AABB(Vector3(-0.018,2.03,-7.98),Vector3(0.036,0.95,0.022))]:
            _box(lead,AABB(rect.position+Vector3(side*1.29,0,0),rect.size),rubber,"CabWindowGasket")
    # Close only the lower and upper parts of the former right door. There is
    # no door handle, door outline or panel through the new window opening.
    if paint != null:
        _box(lead,AABB(Vector3(1.262,0.95,-8.93),Vector3(0.07,1.08,0.82)),paint,"RightCabWallBelowWindow")
        _box(lead,AABB(Vector3(1.262,2.98,-8.93),Vector3(0.07,0.22,0.82)),paint,"RightCabWallAboveWindow")

static func _box(lead: Node3D, box: AABB, material: Material, label: String) -> void:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = box.size
    node.mesh = mesh
    node.position = box.get_center()
    node.material_override = material
    node.name = label
    node.layers = 3
    lead.add_child(node)

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
                if glass:
                    var low := Vector3(INF,INF,INF)
                    var high := Vector3(-INF,-INF,-INF)
                    for index in kept:
                        var point: Vector3 = transform*vertices[index]
                        low = low.min(point)
                        high = high.max(point)
                    var uv := PackedVector2Array()
                    uv.resize(vertices.size())
                    for index in kept:
                        var point: Vector3 = transform*vertices[index]
                        uv[index] = Vector2(inverse_lerp(low.x,high.x,point.x),1.0-inverse_lerp(low.y,high.y,point.y))
                    arrays[Mesh.ARRAY_TEX_UV] = uv
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

