extends Node
## Door leaves discovered by their imported mesh bounds; GLB originals stay untouched.
## Existing leaf parents move all child meshes together with their caution decal.
signal ready_count(count: int)
var leaves: Array[Dictionary] = []
var openness: float = 0.0
var target_open: bool = false
var validated: bool = false
var side_targets := {-1:false,1:false}
var side_open := {-1:0.0,1:0.0}
const SLIDE_METERS := 0.56
const ANIMATION_SECONDS := 1.3

func setup(consist: Node3D) -> void:
    leaves.clear()
    validated = false
    for car in consist.get_children():
        if not str(car.name).begins_with("OriginalV106Car"):
            continue
        var panels: Array[Dictionary] = []
        var decals: Array[Dictionary] = []
        _scan(car, car, panels, decals)
        var grouped: Dictionary = {}
        for item in panels:
            var center: Vector3 = item["center"]
            var key := "%s:%s" % [roundi(center.x * 10.0), roundi(center.z * 100.0)]
            if not grouped.has(key):
                grouped[key] = []
            grouped[key].append(item)
        var car_leaves: Array[Dictionary] = []
        for key in grouped:
            var group: Array = grouped[key]
            if group.size() != 1:
                continue
            var center: Vector3 = group[0]["center"]
            car_leaves.append({"parts": group, "center": center, "decals": []})
        for decal in decals:
            var decal_center: Vector3 = decal["center"]
            var best_distance := 0.65
            var best_index := -1
            for i in range(car_leaves.size()):
                var center: Vector3 = car_leaves[i]["center"]
                var distance := absf(center.z - decal_center.z) + absf(center.x - decal_center.x) * 0.05
                if signf(center.x) == signf(decal_center.x) and distance < best_distance:
                    best_distance = distance
                    best_index = i
            if best_index >= 0:
                car_leaves[best_index]["decals"].append(decal)
        if car_leaves.size() != 16:
            push_error("V106 door discovery: %s found %d/16 leaves" % [car.name, car_leaves.size()])
            leaves.clear()
            ready_count.emit(0)
            return
        for leaf in car_leaves:
            if leaf["decals"].size() != 1:
                push_error("V106 door decal mismatch in %s" % car.name)
                leaves.clear()
                ready_count.emit(0)
                return
        # Require one and only one matching leaf within the same car.
        for i in range(car_leaves.size()):
            var center: Vector3 = car_leaves[i]["center"]
            var partners: Array[int] = []
            for j in range(car_leaves.size()):
                if i == j:
                    continue
                var other: Vector3 = car_leaves[j]["center"]
                var distance := absf(other.z - center.z)
                if absf(other.x - center.x) < 0.2 and distance > 0.60 and distance < 0.80:
                    partners.append(j)
            if partners.size() != 1:
                push_error("Ambiguous door pairing in %s, leaf %d" % [car.name, i])
                leaves.clear()
                ready_count.emit(0)
                return
            var partner: Vector3 = car_leaves[partners[0]]["center"]
            car_leaves[i]["direction"] = signf(center.z - partner.z)
            car_leaves[i]["seam"] = (center.z+partner.z)*0.5
        _attach_stationary_leaf_details(car,car_leaves)
        _restore_door_stripes(car,car_leaves)
        leaves.append_array(car_leaves)
    validated = leaves.size() == 64
    ready_count.emit(leaves.size())
    if leaves.size() != 64:
        push_warning("Door controller expected 64 leaves; found %d. Animation disabled." % leaves.size())

func _scan(root: Node, car: Node3D, panels: Array[Dictionary], decals: Array[Dictionary]) -> void:
    if root is MeshInstance3D and root.mesh != null:
        var bounds: AABB = root.get_aabb()
        var size: Vector3 = bounds.size
        var to_car: Transform3D = car.global_transform.affine_inverse() * root.global_transform
        var center: Vector3 = to_car * bounds.get_center()
        if str(root.name).begins_with("passenger-door-caution"):
            decals.append({"node": root, "center": center, "origin": root.position,
                "slide_axis": root.get_parent().global_basis.inverse() * car.global_basis.z})
        elif size.x > 0.67 and size.x < 0.70 and size.y > 2.0 and size.y < 2.1 and size.z > 0.02 and size.z < 0.04 and absf(center.x) > 1.0 and absf(center.x) < 1.4:
            # Move the existing leaf parent, including skin, glass and trim.
            var leaf: Node3D = root.get_parent()
            panels.append({"node": leaf, "center": center, "bounds":to_car*bounds, "origin": leaf.position,
                "slide_axis": leaf.get_parent().global_basis.inverse() * car.global_basis.z})
    for child in root.get_children():
        _scan(child, car, panels, decals)

func _restore_door_stripes(car: Node3D, car_leaves: Array[Dictionary]) -> void:
    # Read the existing waist stripe so the door paint meets its actual height
    # and colour on both the original and LOD1 cars. No GLB is rewritten.
    var top := 1.9425
    var width := 0.105
    var paint := StandardMaterial3D.new()
    paint.albedo_color = Color(0.91,0.87,0.75)
    paint.roughness = 0.55
    for child in car.find_children("*","MeshInstance3D",true,false):
        var source := child as MeshInstance3D
        if source.mesh == null or source.mesh.get_surface_count() == 0: continue
        var bounds: AABB = car.global_transform.affine_inverse()*source.global_transform*source.get_aabb()
        if bounds.size.z < 4.0 or bounds.size.x < 2.3 or bounds.size.y < 0.07 or bounds.size.y > 0.15: continue
        if absf(bounds.get_center().y-1.89) > 0.08: continue
        var material := source.get_active_material(0) as BaseMaterial3D
        if material == null or material.albedo_color.r < 0.6 or material.albedo_color.g < 0.6: continue
        paint.albedo_color = material.albedo_color
        paint.roughness = material.roughness
        paint.metallic = material.metallic
        top = bounds.end.y
        width = bounds.size.y
        break
    paint.resource_name = "MinskDoorStripePaint"
    paint.cull_mode = BaseMaterial3D.CULL_DISABLED
    for leaf in car_leaves:
        var item: Dictionary = leaf["parts"][0]
        var parent := item["node"] as Node3D
        if parent.has_node("MinskDoorStripe"): continue
        var bounds: AABB = item["bounds"]
        var direction: float = leaf["direction"]
        var seam: float = leaf["seam"]
        var side := signf((leaf["center"] as Vector3).x)
        var outer := absf((bounds.end.z if direction > 0.0 else bounds.position.z)-seam)
        var inner := maxf(0.008,absf((bounds.position.z if direction > 0.0 else bounds.end.z)-seam))
        var bottom := bounds.position.y+0.035
        var knee := bottom+(top-bottom)*0.28
        # Photo reference: long inward diagonal, low waist, short outward foot.
        # Each half stays on its own leaf and stops at the black centre seal.
        var outline := PackedVector2Array([
            Vector2(outer,top),Vector2(outer-width*1.4,top),
            Vector2(inner,knee),Vector2(outer-width*2.7,bottom),
            Vector2(outer,bottom),Vector2(inner+width*1.65,knee),
            Vector2(outer,top-width)])
        var indices := Geometry2D.triangulate_polygon(outline)
        if indices.is_empty():
            push_error("Door stripe triangulation failed in "+str(car.name))
            continue
        var x := (bounds.end.x if side > 0.0 else bounds.position.x)+side*0.003
        var local := parent.global_transform.affine_inverse()*car.global_transform
        var normal := (local.basis.inverse().transposed()*Vector3(side,0,0)).normalized()
        var tool := SurfaceTool.new()
        tool.begin(Mesh.PRIMITIVE_TRIANGLES)
        tool.set_material(paint)
        for index in indices:
            var point := outline[index]
            tool.set_normal(normal)
            tool.add_vertex(local*Vector3(x,point.y,seam+direction*point.x))
        var stripe := MeshInstance3D.new()
        stripe.name = "MinskDoorStripe"
        stripe.mesh = tool.commit()
        stripe.mesh.resource_name = "MinskDoorChevron"
        stripe.layers = (parent.get_child(0) as MeshInstance3D).layers
        stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        stripe.set_meta("reference","Minsk 81-717: waist stripe, low chevron and outward foot")
        stripe.set_meta("passenger_door_livery",true)
        parent.add_child(stripe)

func _half(poly: Array, axis: int, edge: float, greater: bool) -> Array:
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

func _partition(poly: Array, volume: AABB) -> Dictionary:
    var outside: Array = []
    var inside: Array = poly
    for axis in range(3):
        for upper in [false,true]:
            var edge: float = volume.end[axis] if upper else volume.position[axis]
            var piece := _half(inside,axis,edge,upper)
            if piece.size() >= 3: outside.append(piece)
            inside = _half(inside,axis,edge,not upper)
            if inside.size() < 3: return {"outside":outside,"inside":[]}
    return {"outside":outside,"inside":inside}

func _emit_polygon(tool: SurfaceTool, poly: Array, inverse: Transform3D) -> int:
    var count := 0
    for k in range(1,poly.size()-1):
        var a: Vector3 = poly[0][0]
        var b: Vector3 = poly[k][0]
        var c: Vector3 = poly[k+1][0]
        if (b-a).cross(c-a).length_squared() < 0.000000000001: continue
        for vertex in [poly[0],poly[k],poly[k+1]]:
            tool.set_normal((inverse.basis.inverse().transposed()*vertex[1]).normalized())
            tool.set_uv(vertex[2])
            tool.set_color(vertex[3])
            tool.add_vertex(inverse*vertex[0])
            count += 1
    return count

func _attach_stationary_leaf_details(car: Node3D, car_leaves: Array[Dictionary]) -> void:
    var openings: Array[Dictionary] = []
    var details: Array[Dictionary] = []
    var layers: Array[int] = []
    for i in range(car_leaves.size()):
        details.append({})
        layers.append(0)
        if float(car_leaves[i]["direction"]) > 0.0: continue
        var left: Vector3 = car_leaves[i]["center"]
        for j in range(car_leaves.size()):
            var right: Vector3 = car_leaves[j]["center"]
            if float(car_leaves[j]["direction"]) <= 0.0 or absf(left.x-right.x) > 0.2 or absf(absf(right.z-left.z)-0.69) > 0.10: continue
            var center := (left+right)*0.5
            var low_x := center.x-0.045 if center.x < 0.0 else center.x-0.080
            # Inboard door trims only. Jambs lie outside this longitudinal
            # interval, the sill below it, the fixed rail/header above it.
            var volume := AABB(Vector3(low_x,1.033,center.z-0.65),Vector3(0.125,1.865,1.30))
            openings.append({"volume":volume,"split":center.z,"negative":i,"positive":j})
    var sources := car.find_children("*","MeshInstance3D",true,false)
    for child in sources:
        var source := child as MeshInstance3D
        if source.mesh == null or not source.is_visible_in_tree(): continue
        var moving_part := false
        for leaf in car_leaves:
            for item in leaf["parts"]:
                var root := item["node"] as Node
                if source == root or root.is_ancestor_of(source): moving_part = true
        if moving_part: continue
        var transform := car.global_transform.affine_inverse()*source.global_transform
        var inverse := transform.affine_inverse()
        var normal_basis := transform.basis.inverse().transposed()
        var bounds: AABB = transform*source.get_aabb()
        var relevant: Array[Dictionary] = []
        for opening in openings:
            if bounds.intersects(opening["volume"]): relevant.append(opening)
        if relevant.is_empty(): continue
        var replacement := ArrayMesh.new()
        var changed := false
        for surface in range(source.mesh.get_surface_count()):
            var arrays: Array = source.mesh.surface_get_arrays(surface).duplicate(true)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
            var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
            var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
            var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
            if indices.is_empty():
                indices.resize(vertices.size())
                for i in range(vertices.size()): indices[i] = i
            var material := source.get_active_material(surface)
            var kept := PackedInt32Array()
            var clipped := SurfaceTool.new()
            clipped.begin(Mesh.PRIMITIVE_TRIANGLES)
            var clipped_count := 0
            for triangle in range(0,indices.size(),3):
                var ids := [indices[triangle],indices[triangle+1],indices[triangle+2]]
                var a: Vector3 = transform*vertices[ids[0]]
                var b: Vector3 = transform*vertices[ids[1]]
                var c: Vector3 = transform*vertices[ids[2]]
                var low := a.min(b).min(c)
                var tri_box := AABB(low,a.max(b).max(c)-low)
                var candidates: Array[Dictionary] = []
                for opening in relevant:
                    if tri_box.intersects(opening["volume"]): candidates.append(opening)
                if candidates.is_empty():
                    kept.append_array(PackedInt32Array(ids))
                    continue
                var fallback := (b-a).cross(c-a).normalized()
                var polygon: Array = []
                for index in ids:
                    polygon.append([transform*vertices[index],(normal_basis*normals[index]).normalized() if normals.size() == vertices.size() else fallback,uvs[index] if uvs.size() == vertices.size() else Vector2.ZERO,colors[index] if colors.size() == vertices.size() else Color.WHITE])
                var remaining: Array = [polygon]
                var extracted := false
                for opening in candidates:
                    var next: Array = []
                    for piece in remaining:
                        var partition := _partition(piece,opening["volume"])
                        next.append_array(partition["outside"])
                        var inside: Array = partition["inside"]
                        if inside.size() < 3: continue
                        for positive in [false,true]:
                            var half := _half(inside,2,float(opening["split"]),positive)
                            if half.size() < 3: continue
                            var index: int = int(opening["positive"] if positive else opening["negative"])
                            if not details[index].has(material):
                                var builder := SurfaceTool.new()
                                builder.begin(Mesh.PRIMITIVE_TRIANGLES)
                                builder.set_material(material)
                                details[index][material] = {"tool":builder,"count":0}
                            var record: Dictionary = details[index][material]
                            var count := _emit_polygon(record["tool"],half,Transform3D.IDENTITY)
                            record["count"] = int(record["count"])+count
                            if count > 0:
                                extracted = true
                                layers[index] |= source.layers
                    remaining = next
                if not extracted:
                    kept.append_array(PackedInt32Array(ids))
                    continue
                changed = true
                for piece in remaining: clipped_count += _emit_polygon(clipped,piece,inverse)
            if not kept.is_empty():
                arrays[Mesh.ARRAY_INDEX] = kept
                replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
                replacement.surface_set_material(replacement.get_surface_count()-1,material)
            if clipped_count > 0:
                clipped.set_material(material)
                clipped.commit(replacement)
        if changed:
            # Retain an empty instance mesh when fully extracted, so a later
            # visibility pass cannot resurrect the old stationary geometry.
            source.mesh = replacement
            if replacement.get_surface_count() == 0: source.hide()
            else:
                for surface in range(replacement.get_surface_count()): source.set_surface_override_material(surface,null)
    for i in range(car_leaves.size()):
        var mesh := ArrayMesh.new()
        for record in details[i].values():
            if int(record["count"]) > 0: (record["tool"] as SurfaceTool).commit(mesh)
        if mesh.get_surface_count() == 0: continue
        var part := MeshInstance3D.new()
        part.name = "AttachedOriginalDoorTrim%02d" % i
        part.mesh = mesh
        part.layers = layers[i]
        car.add_child(part)
        car_leaves[i]["parts"].append({"node":part,"origin":Vector3.ZERO,"slide_axis":Vector3(0,0,1)})

func _process(delta: float) -> void:
    if not validated:
        return
    for side in [-1,1]:
        side_open[side] = move_toward(float(side_open[side]),1.0 if side_targets[side] else 0.0,delta/ANIMATION_SECONDS)
    openness = maxf(float(side_open[-1]),float(side_open[1]))
    target_open = bool(side_targets[-1]) or bool(side_targets[1])
    for leaf in leaves:
        var direction: float = leaf["direction"]
        var amount: float = side_open[-1 if (leaf["center"] as Vector3).x < 0.0 else 1]
        for item in leaf["parts"]:
            var node: Node3D = item["node"]
            node.position = item["origin"] + item["slide_axis"] * direction * SLIDE_METERS * amount
        for item in leaf["decals"]:
            var node: Node3D = item["node"]
            node.position = item["origin"] + item["slide_axis"] * direction * SLIDE_METERS * amount

func request_side(side: int, speed_mps: float) -> bool:
    if absf(speed_mps) > 0.05 or not validated:
        return false
    side_targets[side] = true
    target_open = true
    return true

func request_open(speed_mps: float) -> void:
    request_side(-1,speed_mps)
    request_side(1,speed_mps)

func request_close() -> void:
    side_targets[-1] = false
    side_targets[1] = false
    target_open = false

func can_move() -> bool:
    return not target_open and openness <= 0.001 and validated


