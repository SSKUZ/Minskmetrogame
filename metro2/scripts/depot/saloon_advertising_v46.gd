extends RefCounted
## TZ46: new surface-mounted saloon artwork. No legacy advertising module.
## Coordinates come from inward-facing opaque triangles of the imported model.
const PRINT_LAYERS := 1 | (1 << 4) # Camera layer 1 + existing saloon light layer 5.
const MOUNT_OFFSET := 0.008
const DIR := "res://assets/saloon_v46/"
const MAP = preload("res://assets/saloon_v46/minsk_network.svg")
const LINE = preload("res://assets/saloon_v46/moscow_line.svg")
const NOTICE = preload("res://assets/saloon_v46/passenger_notice.svg")
var _materials: Dictionary = {}
var _tools: Dictionary = {}
var _doors: Array = []
var _portrait := 0
var _banner := 0

static func decorate(game: Node3D,train: Node3D,door_system: Node) -> void:
    var module = load("res://scripts/depot/saloon_advertising_v46.gd").new()
    module._doors=door_system.get("leaves")
    var index := 0
    for node in train.get_children():
        if node is Node3D and str(node.name).begins_with("OriginalV106Car"):
            module._decorate_car(game,node as Node3D,index)
            index+=1

func _material(texture: Texture2D) -> StandardMaterial3D:
    if _materials.has(texture): return _materials[texture]
    var material := StandardMaterial3D.new()
    material.albedo_texture=texture
    material.roughness=0.88
    material.cull_mode=BaseMaterial3D.CULL_DISABLED
    material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    material.texture_repeat=false
    material.metallic=0.0
    material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    # Gentle ink visibility under the existing saloon lights; no added lights.
    material.emission_enabled=true
    material.emission_texture=texture
    material.emission=Color.WHITE
    material.emission_energy_multiplier=0.10
    _materials[texture]=material
    return material

func _decorate_car(game: Node3D,car: Node3D,index: int) -> void:
    if car.has_node("SaloonArtworkV46"): return
    var geometry := _surfaces(car)
    var patches: Array=geometry.patches
    var obstacles: Array=geometry.obstacles
    var used: Array[Dictionary] = []
    _tools.clear()
    var maps := 0
    for end in [-1.0,1.0]:
        var slot := _slot(patches,obstacles,used,Vector2(0.39,0.52),"map",end)
        if slot.is_empty():
            slot=_slot(patches,obstacles,used,Vector2(0.33,0.44),"map",end)
        if slot.is_empty():
            slot=_slot(patches,obstacles,used,Vector2(0.27,0.36),"map",end)
        if slot.is_empty():
            slot=_anchor_slot(patches,obstacles,used,Vector2(0.27,0.36),"map",end)
        if not slot.is_empty():
            _attach(slot,MAP,used)
            maps+=1
    # Two selected door headers per car, not every passenger doorway.
    var routes := 0
    for header in geometry.headers:
        if routes >= 2: break
        var slot := _header_slot(patches,obstacles,used,header,Vector2(1.22,1.22/6.0))
        if slot.is_empty():
            slot=_header_slot(patches,obstacles,used,header,Vector2(1.02,0.17))
        if not slot.is_empty():
            _attach(slot,LINE,used)
            routes+=1
    var ads := 0
    var portraits := 3 if index%2 == 0 else 2
    for i in range(5):
        var vertical := i < portraits
        var asset_id := _portrait*2+1 if vertical else _banner*2+2
        if vertical: _portrait+=1
        else: _banner+=1
        var texture := load(DIR+"ad_%02d.svg" % asset_id) as Texture2D
        var dimensions := Vector2(0.27,0.405) if vertical else Vector2(0.81,0.27)
        var slot := _slot(patches,obstacles,used,dimensions,"poster" if vertical else "banner",-1.0 if (i+index)%2 == 0 else 1.0)
        if slot.is_empty() and vertical:
            slot=_slot(patches,obstacles,used,Vector2(0.23,0.345),"poster",1.0)
        if slot.is_empty() and not vertical:
            slot=_slot(patches,obstacles,used,Vector2(0.66,0.22),"banner",1.0)
        if slot.is_empty():
            var smaller := Vector2(0.23,0.345) if vertical else Vector2(0.66,0.22)
            for side in [-1.0,1.0]:
                slot=_anchor_slot(patches,obstacles,used,smaller,"poster",side)
                if not slot.is_empty(): break
        if not slot.is_empty():
            _attach(slot,texture,used)
            ads+=1
    var notices := 0
    for header in geometry.headers:
        if notices >= 2: break
        var slot := _header_slot(patches,obstacles,used,header,Vector2(0.49,0.49*320.0/1024.0))
        if not slot.is_empty():
            _attach(slot,NOTICE,used)
            notices+=1
    var holder := Node3D.new()
    holder.name="SaloonArtworkV46"
    car.add_child(holder)
    for material in _tools:
        var mesh := MeshInstance3D.new()
        mesh.name="PrintedInteriorPanels"
        mesh.mesh=(_tools[material] as SurfaceTool).commit()
        mesh.material_override=material
        mesh.layers=PRINT_LAYERS
        mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        holder.add_child(mesh)
    var complete := ads == 5 and maps == 2 and routes == 2
    holder.set_meta("placement_complete",complete)
    print("TZ46_PLACED car=%s ads=%d maps=%d lines=%d notices=%d" % [car.name,ads,maps,routes,notices])
    if not complete:
        push_error("TZ46 incomplete interior placement in %s: ads %d/5, maps %d/2, lines %d/2. No unsupported or exterior mounting is accepted." % [car.name,ads,maps,routes])
    # Placement metadata records actual attached counts, never assumed ones.
    holder.set_meta("advertisements",ads)
    holder.set_meta("network_maps",maps)
    holder.set_meta("line_diagrams",routes)
    holder.set_meta("notices",notices)
    holder.set_meta("surface_source","original inward-facing opaque mesh triangles")
    _tools.clear()

func _surfaces(car: Node3D) -> Dictionary:
    var patches: Dictionary = {}
    var obstacles: Array[AABB] = []
    var moving: Array[Node3D] = []
    var headers: Array[Dictionary] = []
    var pairs: Dictionary = {}
    var center_z := 0.0
    var door_count := 0
    var first_door := INF
    var last_door := -INF
    for leaf in _doors:
        var root := leaf.parts[0].node as Node3D
        if not car.is_ancestor_of(root): continue
        moving.append(root)
        var box: AABB=leaf.parts[0].bounds
        obstacles.append(box.grow(0.012))
        var center: Vector3=leaf.center
        center_z+=center.z
        first_door=minf(first_door,center.z)
        last_door=maxf(last_door,center.z)
        door_count+=1
        var side := -1.0 if center.x < 0.0 else 1.0
        var key := "%d:%d" % [int(side),roundi(float(leaf.seam)*100)]
        if not pairs.has(key): pairs[key]={"bounds":box,"side":side}
        else: pairs[key].bounds=(pairs[key].bounds as AABB).merge(box)
    if door_count > 0: center_z/=float(door_count)
    var ordered: Array=pairs.values()
    ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return (a.bounds as AABB).get_center().z < (b.bounds as AABB).get_center().z)
    for i in range(ordered.size()):
        var box: AABB=ordered[i].bounds
        headers.append({"z":box.get_center().z,"y":box.end.y+0.145,"top":box.end.y,"start":box.position.z,"end":box.end.z,"side":ordered[i].side,"pair":i})
    for node in car.find_children("*","MeshInstance3D",true,false):
        var mesh := node as MeshInstance3D
        if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
        var name := str(mesh.name).to_lower()
        if name.contains("caution") or name.contains("saloonartwork") or name.contains("ticker"): continue
        var under_control := false
        for root in moving:
            if root == mesh or root.is_ancestor_of(mesh): under_control=true; break
        if under_control: continue
        var cab := car.get_node_or_null("OriginalCabIntegration")
        if cab != null and cab.is_ancestor_of(mesh): continue
        var pose := car.global_transform.affine_inverse()*mesh.global_transform
        var bounds: AABB=pose*mesh.get_aabb()
        if bounds.end.y < 1.55 or bounds.position.y > 3.25: continue
        for surface in range(mesh.mesh.get_surface_count()):
            if mesh.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: continue
            var material := mesh.get_active_material(surface) as BaseMaterial3D
            if material == null: continue
            var color := material.albedo_color
            var description := material.resource_name.to_lower()
            if mesh.mesh.get_surface_count() == 1: description+=" "+name
            var glass := description.contains("glass") or description.contains("window") or description.contains("стекл")
            var opaque := material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and color.a > 0.98
            # Paint colour is not a mounting constraint. Existing textured posters,
            # glazing and polished hardware are protected at TRIANGLE scope.
            var paint_texture := material.albedo_texture == null or (material.albedo_texture.get_width() <= 64 and material.albedo_texture.get_height() <= 64)
            var mountable := opaque and not glass and paint_texture and material.metallic < 0.65 and maxf(color.r,maxf(color.g,color.b)) > 0.06
            var arrays := mesh.mesh.surface_get_arrays(surface)
            var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
            var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
            var count := indices.size() if not indices.is_empty() else verts.size()
            for i in range(0,count-2,3):
                var ia: int=indices[i] if not indices.is_empty() else i
                var ib: int=indices[i+1] if not indices.is_empty() else i+1
                var ic: int=indices[i+2] if not indices.is_empty() else i+2
                var a: Vector3=pose*verts[ia]
                var b: Vector3=pose*verts[ib]
                var c: Vector3=pose*verts[ic]
                var low := a.min(b).min(c)
                var high := a.max(b).max(c)
                if high.y < 1.55 or low.y > 3.25: continue
                if not mountable:
                    # Never append the merged mesh's whole-car AABB here.
                    obstacles.append(AABB(low,high-low).grow(0.001))
                    continue
                # Use the geometric face, not smoothed/imported vertex normals.
                var face := (b-a).cross(c-a)
                if face.length_squared() < 0.000000001: continue
                face=face.normalized()
                var axis := 0 if absf(face.x) > 0.985 else 2 if absf(face.z) > 0.985 else -1
                if axis < 0: continue
                var center := (a+b+c)/3.0
                if door_count > 0:
                    if str(car.name) == "OriginalV106Car01" and center.z < first_door-1.8: continue
                    if str(car.name) == "OriginalV106Car04" and center.z > last_door+1.8: continue
                var normal := Vector3.ZERO
                if axis == 0:
                    if absf(center.x) < 0.80 or absf(center.x) > 1.55: continue
                    normal.x=-signf(center.x)
                else:
                    if absf(center.z-center_z) < 4.0: continue
                    normal.z=-signf(center.z-center_z)
                if high[axis]-low[axis] > 0.006: continue
                var plane: float=center[axis]
                var key := "%d:%d:%d" % [axis,roundi(plane*200),int(signf(normal[axis]))]
                var u := 2 if axis == 0 else 0
                var polygon := PackedVector2Array([Vector2(a[u],a.y),Vector2(b[u],b.y),Vector2(c[u],c.y)])
                var bottom := polygon[0].min(polygon[1]).min(polygon[2])
                var top := polygon[0].max(polygon[1]).max(polygon[2])
                var rect := Rect2(bottom,top-bottom)
                if not patches.has(key): patches[key]={"axis":axis,"plane":plane,"normal":normal,"bounds":rect,"triangles":[],"center_z":center_z,"headers":headers}
                # Mount on the passenger-facing side of any <=5 mm slab group.
                if (plane-float(patches[key].plane))*normal[axis] > 0.0: patches[key].plane=plane
                patches[key].bounds=(patches[key].bounds as Rect2).merge(rect)
                patches[key].triangles.append({"bounds":rect,"polygon":polygon})
    var result: Array=patches.values()
    for patch in result:
        var nearer: Array = []
        var axis: int=patch.axis
        var origin := 0.0 if axis == 0 else center_z
        for other in result:
            if int(other.axis) != axis: continue
            if signf(float(other.plane)-origin) != signf(float(patch.plane)-origin): continue
            var separation := (float(other.plane)-float(patch.plane))*(patch.normal as Vector3)[axis]
            if separation > 0.006: nearer.append(other.triangles)
        patch["nearer"]=nearer
        var blockers: Array[AABB] = []
        var u := 2 if axis == 0 else 0
        for box in obstacles:
            var obstacle_box: AABB=box
            if float(patch.plane) < obstacle_box.position[axis]-0.14 or float(patch.plane) > obstacle_box.end[axis]+0.14: continue
            var projected := Rect2(Vector2(obstacle_box.position[u],obstacle_box.position.y),Vector2(obstacle_box.size[u],obstacle_box.size.y))
            if (patch.bounds as Rect2).intersects(projected.grow(0.006)): blockers.append(obstacle_box)
        patch["blockers"]=blockers
    return {"patches":result,"obstacles":obstacles,"headers":headers}
func _slot(patches: Array,obstacles: Array,used: Array[Dictionary],dimensions: Vector2,kind: String,preference: float) -> Dictionary:
    var choices: Array[Dictionary] = []
    for patch in patches:
        var bounds: Rect2=patch.bounds
        if bounds.size.x < dimensions.x+0.015 or bounds.size.y < dimensions.y+0.015: continue
        if kind == "banner" and int(patch.axis) != 0: continue
        var ys: Array[float]=[2.15,2.38,1.92,2.60] if kind != "banner" else [2.98,3.04,2.88]
        ys.append(bounds.end.y-dimensions.y*0.5-0.008)
        ys.append(bounds.position.y+dimensions.y*0.5+0.008)
        ys.append(bounds.get_center().y)
        var u0 := bounds.position.x+dimensions.x*0.5+0.008
        var u1 := bounds.end.x-dimensions.x*0.5-0.008
        var us: Array[float]=[(u0+u1)*0.5,u0,u1]
        var axis: int=patch.axis
        var projected_axis := 2 if axis == 0 else 0
        for box in patch.get("blockers",obstacles):
            var obstacle: AABB=box
            if float(patch.plane) < obstacle.position[axis]-0.14 or float(patch.plane) > obstacle.end[axis]+0.14: continue
            for edge in [obstacle.position[projected_axis]-dimensions.x*0.5-0.014,obstacle.end[projected_axis]+dimensions.x*0.5+0.014]:
                if edge >= u0 and edge <= u1: us.append(edge)
        var steps := mini(90,int((u1-u0)/0.15))
        for i in range(steps): us.append(lerpf(u0,u1,float(i+1)/float(steps+1)))
        var unique_u: Dictionary = {}
        for coordinate in us: unique_u[roundi(coordinate*1000.0)]=coordinate
        us.clear()
        for coordinate in unique_u.values(): us.append(float(coordinate))
        for y in ys:
            if y-dimensions.y*0.5 < bounds.position.y or y+dimensions.y*0.5 > bounds.end.y: continue
            for u in us:
                var rect := Rect2(Vector2(u,y)-dimensions*0.5,dimensions)
                if not _fits(patch,rect,obstacles,used): continue
                var score := 0.0
                if kind == "map": score+=100.0 if int(patch.axis) == 2 else 0.0
                if int(patch.axis) == 2: score+=preference*(float(patch.plane)-float(patch.center_z))
                else: score+=3.0 if signf(float(patch.plane)) == preference else 0.0
                if int(patch.axis) == 0: score-=absf(float(patch.plane))*20.0
                score-=absf(u-(u0+u1)*0.5)*0.12
                choices.append({"patch":patch,"rect":rect,"score":score})
    if choices.is_empty(): return {}
    choices.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.score) > float(b.score))
    return choices[0]

func _header_slot(patches: Array,obstacles: Array,used: Array[Dictionary],header: Dictionary,dimensions: Vector2) -> Dictionary:
    for patch in patches:
        if int(patch.axis) != 0 or signf(float(patch.plane)) != float(header.side): continue
        var bounds: Rect2=patch.bounds
        for y in [float(header.top)+dimensions.y*0.5+0.025,bounds.end.y-dimensions.y*0.5-0.008,float(header.y)]:
            if y-dimensions.y*0.5 <= float(header.top)+0.012: continue
            var rect := Rect2(Vector2(float(header.z),y)-dimensions*0.5,dimensions)
            if _fits(patch,rect,obstacles,used): return {"patch":patch,"rect":rect}
    return {}

func _covered(triangles: Array,point: Vector2) -> bool:
    for triangle in triangles:
        if not (triangle.bounds as Rect2).grow(0.001).has_point(point): continue
        var p: PackedVector2Array=triangle.polygon
        var a := (p[1]-p[0]).cross(point-p[0])
        var b := (p[2]-p[1]).cross(point-p[1])
        var c := (p[0]-p[2]).cross(point-p[2])
        # Inclusive edges: points on the two triangles' shared diagonal are valid.
        if minf(a,minf(b,c)) >= -0.000001 or maxf(a,maxf(b,c)) <= 0.000001: return true
    return false

func _fits(patch: Dictionary,rect: Rect2,obstacles: Array,used: Array[Dictionary]) -> bool:
    if not (patch.bounds as Rect2).grow(0.001).encloses(rect): return false
    for entry in used:
        if int(entry.axis) == int(patch.axis) and absf(float(entry.plane)-float(patch.plane)) < 0.04:
            if (entry.rect as Rect2).grow(0.012).intersects(rect): return false
    var axis: int=patch.axis
    var u := 2 if axis == 0 else 0
    for box in patch.get("blockers",obstacles):
        var bounds: AABB=box
        if float(patch.plane) < bounds.position[axis]-0.14 or float(patch.plane) > bounds.end[axis]+0.14: continue
        var projected := Rect2(Vector2(bounds.position[u],bounds.position.y),Vector2(bounds.size[u],bounds.size.y)).grow(0.006)
        if projected.intersects(rect): return false
    for x in range(5):
        for y in range(5):
            var point := rect.position+rect.size*Vector2(float(x)/4.0,float(y)/4.0)
            if not _covered(patch.triangles,point): return false
            # Reject exterior faces hidden behind another solid interior panel.
            for triangles in patch.get("nearer",[]):
                if _covered(triangles,point): return false
    return true

func _anchor_slot(patches: Array,obstacles: Array,used: Array[Dictionary],dimensions: Vector2,kind: String,preference: float) -> Dictionary:
    # Deterministic fallback: original door jambs and the measured panel edges.
    # Every candidate still needs full original-triangle coverage and clearance.
    for patch in patches:
        if int(patch.axis) != 0: continue
        if signf(float(patch.plane)) != preference: continue
        for header in patch.headers:
            if float(header.side) != preference: continue
            var us: Array[float]=[float(header.z)]
            if kind != "line":
                us=[float(header.start)-dimensions.x*0.5-0.025,float(header.end)+dimensions.x*0.5+0.025]
            var ys: Array[float]=[float(header.top)+dimensions.y*0.5+0.025] if kind == "line" else [2.30,2.08,2.53]
            for u in us:
                for y in ys:
                    var rect := Rect2(Vector2(u,y)-dimensions*0.5,dimensions)
                    if _fits(patch,rect,obstacles,used): return {"patch":patch,"rect":rect}
    return {}
func _attach(slot: Dictionary,texture: Texture2D,used: Array[Dictionary]) -> void:
    var patch: Dictionary=slot.patch
    var rect: Rect2=slot.rect
    var normal: Vector3=patch.normal
    var axis: int=patch.axis
    var u := 2 if axis == 0 else 0
    var points: Array[Vector3] = []
    for point in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
        var v := Vector3.ZERO
        v[axis]=float(patch.plane)
        v[u]=point.x; v.y=point.y
        points.append(v+normal*MOUNT_OFFSET)
    # UVs preserve the art's exact aspect ratio; reverse winding for opposite walls.
    var uv := [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
    var order := [0,2,1,0,3,2]
    if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal) < 0.0: order=[0,1,2,0,2,3]
    # Make text read left-to-right while looking at either inward-facing wall.
    var horizontal := Vector3.BACK if axis == 0 and normal.x < 0.0 else Vector3.FORWARD if axis == 0 else Vector3.RIGHT if normal.z > 0.0 else Vector3.LEFT
    var flip := (points[1]-points[0]).dot(horizontal) < 0.0
    var material := _material(texture)
    if not _tools.has(material):
        var tool := SurfaceTool.new()
        tool.begin(Mesh.PRIMITIVE_TRIANGLES)
        tool.set_material(material)
        _tools[material]=tool
    var tool := _tools[material] as SurfaceTool
    for i in order:
        var tex: Vector2=uv[i]
        if flip: tex.x=1.0-tex.x
        tool.set_normal(normal)
        tool.set_uv(tex)
        tool.add_vertex(points[i])
    used.append({"axis":axis,"plane":patch.plane,"rect":rect})
