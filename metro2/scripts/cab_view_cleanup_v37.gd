extends RefCounted
## Photo-based cab sides on instantiated end cars; original GLBs stay intact.
const WINDOW_LOW_Y := 1.92
const WINDOW_HIGH_Y := 3.08
const WINDOW_LOW_Z := -9.32
const WINDOW_HIGH_Z := -7.82

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
    # Replace the entire old side-door skin, inside AND outside. This removes
    # all old door seams/handles/small-window frames before making one blue skin.
    var sides := [AABB(Vector3(-1.40,0.34,-9.505),Vector3(0.22,2.91,1.845)),AABB(Vector3(1.18,0.34,-9.505),Vector3(0.22,2.91,1.845))]
    for child in lead.find_children("*","MeshInstance3D",true,false):
        var instance := child as MeshInstance3D
        if not instance.visible: continue
        var transform := lead.global_transform.affine_inverse()*instance.global_transform
        var inverse := transform.affine_inverse()
        var box: AABB = transform*instance.get_aabb()
        var metal := box.size.z > 18.0 and absf(box.position.y-0.09) < 0.01 and absf(box.end.y-3.1075) < 0.01
        if box.position.x < -1.33 and box.end.x > 1.33 and absf(box.end.z+6.99) < 0.02:
            paint = instance.get_active_material(0)
        var volumes: Array = sides.duplicate()
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
                if maxf(a.y,maxf(b.y,c.y)) <= 0.34:
                    kept.append_array(PackedInt32Array(ids))
                    continue
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
    if paint == null:
        var fallback := StandardMaterial3D.new()
        fallback.albedo_color = Color(0.0168,0.0844,0.1714)
        paint = fallback
    var blue := paint.duplicate() as StandardMaterial3D
    blue.cull_mode = BaseMaterial3D.CULL_DISABLED
    blue.roughness = 0.7
    var rubber := StandardMaterial3D.new()
    rubber.albedo_color = Color(0.018,0.022,0.026)
    rubber.roughness = 0.92
    rubber.cull_mode = BaseMaterial3D.CULL_DISABLED
    var glass := StandardMaterial3D.new()
    glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glass.albedo_color = Color(0.0,0.0,0.0,0.018)
    glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glass.cull_mode = BaseMaterial3D.CULL_DISABLED
    glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    for side in [-1.0,1.0]:
        _make_side(lead,side,blue,rubber,glass)

static func _emit(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
    tool.set_normal(normal)
    tool.add_vertex(a)
    tool.add_vertex(b)
    tool.add_vertex(c)

static func _quad(tool: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,d: Vector3,normal: Vector3) -> void:
    _emit(tool,a,b,c,normal)
    _emit(tool,a,c,d,normal)

static func _rect(tool: SurfaceTool,x: float,y0: float,y1: float,z0: float,z1: float,n: Vector3) -> void:
    _quad(tool,Vector3(x,y0,z0),Vector3(x,y1,z0),Vector3(x,y1,z1),Vector3(x,y0,z1),n)

static func _contour(y0: float,y1: float,z0: float,z1: float,radius: float) -> Array[Vector2]:
    var points: Array[Vector2] = []
    # XY here are longitudinal Z and height Y. Same outline on both skins.
    var corners := [Vector2(z1-radius,y1-radius),Vector2(z0+radius,y1-radius),Vector2(z0+radius,y0+radius),Vector2(z1-radius,y0+radius)]
    for corner in range(4):
        for step in range(9):
            var angle := float(corner)*PI*0.5+float(step)*PI/16.0
            points.append(corners[corner]+Vector2(cos(angle),sin(angle))*radius)
    return points

static func _node(lead: Node3D,tool: SurfaceTool,material: Material,label: String,layers: int) -> void:
    tool.set_material(material)
    var instance := MeshInstance3D.new()
    instance.name = label
    instance.mesh = tool.commit()
    instance.layers = layers
    if layers == 4: instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    lead.add_child(instance)


static func _make_side(lead: Node3D, side: float, blue: Material,rubber: Material,glass: Material) -> void:
    # 81-717: a narrow portrait window on the right, a separate cab door on
    # the left. Both skins have actual openings, not transparent wall overlays.
    if side > 0.0:
        _window_panel(lead,side,blue,rubber,glass,0.34,3.25,-9.505,-7.66,
            1.88,3.02,-9.12,-8.37,0.09,"RightCabWindow")
        _sash(lead,side,2.57,-9.10,-8.39)
        _waist_trim(lead,side,-9.505,-7.66)
    else:
        _window_panel(lead,side,blue,rubber,null,0.34,3.25,-9.505,-7.66,
            0.40,3.19,-9.30,-8.22,0.025,"DriverDoorFrame")
        var door := Node3D.new()
        door.name = "DriverEntranceDoor"
        door.set_meta("hinge_axis",Vector3.UP)
        door.set_meta("open_angle",side*PI*0.5)
        door.set_meta("exit_in_cab_frame",Vector3(-1.95,0.45,-8.75))
        lead.add_child(door)
        _window_panel(door,side,blue,rubber,glass,0.415,3.175,-9.285,-8.235,
            1.91,3.015,-9.105,-8.455,0.085,"DriverDoorWindow")
        _waist_trim(door,side,-9.27,-8.25)
        var chrome := StandardMaterial3D.new()
        chrome.albedo_color = Color(0.65,0.68,0.70)
        chrome.metallic = 0.85
        chrome.roughness = 0.28
        for x in [side*1.22,side*1.39]:
            _bar(door,Vector3(x,2.10,-9.18),Vector3(x,2.73,-9.18),0.012,chrome,"DoorGrabHandle")
            _bar(door,Vector3(x,1.78,-8.43),Vector3(x,1.78,-8.28),0.015,chrome,"DoorLatch")
        for y in [0.72,2.85]:
            _bar(door,Vector3(side*1.36,y-0.065,-8.25),Vector3(side*1.36,y+0.065,-8.25),0.019,chrome,"DoorHinge")
        var hinge := Vector3(side*1.30,0.415,-8.235)
        for child in door.get_children():
            if child is Node3D: (child as Node3D).position -= hinge
        door.position = hinge

static func _window_panel(parent: Node3D,side: float,blue: Material,rubber: Material,glass: Material,
        bottom: float,top: float,front: float,rear: float,
        y0: float,y1: float,z0: float,z1: float,radius: float,label: String) -> void:
    var inside := side*1.252
    var outside := side*1.345
    var wall := SurfaceTool.new()
    wall.begin(Mesh.PRIMITIVE_TRIANGLES)
    for face in [inside,outside]:
        var normal := Vector3(-side if face == inside else side,0,0)
        _rect(wall,face,bottom,y0,front,rear,normal)
        _rect(wall,face,y1,top,front,rear,normal)
        _rect(wall,face,y0,y1,front,z0,normal)
        _rect(wall,face,y0,y1,z1,rear,normal)
        var centers := [Vector2(z1-radius,y1-radius),Vector2(z0+radius,y1-radius),Vector2(z0+radius,y0+radius),Vector2(z1-radius,y0+radius)]
        var corners := [Vector2(z1,y1),Vector2(z0,y1),Vector2(z0,y0),Vector2(z1,y0)]
        for corner in range(4):
            for step in range(8):
                var a := float(corner)*PI*0.5+float(step)*PI/16.0
                var b := a+PI/16.0
                var v: Vector2 = centers[corner]+Vector2(cos(a),sin(a))*radius
                var w: Vector2 = centers[corner]+Vector2(cos(b),sin(b))*radius
                _emit(wall,Vector3(face,corners[corner].y,corners[corner].x),Vector3(face,v.y,v.x),Vector3(face,w.y,w.x),normal)
    var opening := _contour(y0,y1,z0,z1,radius)
    for i in range(opening.size()):
        var a := opening[i]
        var b := opening[(i+1)%opening.size()]
        var n := Vector3(0,(a.y+b.y)*0.5-(y0+y1)*0.5,(a.x+b.x)*0.5-(z0+z1)*0.5).normalized()
        _quad(wall,Vector3(inside,a.y,a.x),Vector3(outside,a.y,a.x),Vector3(outside,b.y,b.x),Vector3(inside,b.y,b.x),-n)
    _node(parent,wall,blue,label+"Steel",3)
    var seal := SurfaceTool.new()
    seal.begin(Mesh.PRIMITIVE_TRIANGLES)
    var border := _contour(y0-0.022,y1+0.022,z0-0.022,z1+0.022,radius+0.022)
    for x in [inside-side*0.002,outside+side*0.002]:
        for i in range(opening.size()):
            var j := (i+1)%opening.size()
            _quad(seal,Vector3(x,opening[i].y,opening[i].x),Vector3(x,border[i].y,border[i].x),Vector3(x,border[j].y,border[j].x),Vector3(x,opening[j].y,opening[j].x),Vector3(-side if x*side < 1.3 else side,0,0))
    _node(parent,seal,rubber,label+"Rubber",3)
    if glass != null:
        var pane := SurfaceTool.new()
        pane.begin(Mesh.PRIMITIVE_TRIANGLES)
        for i in range(opening.size()):
            var j := (i+1)%opening.size()
            _emit(pane,Vector3(side*1.29,(y0+y1)*0.5,(z0+z1)*0.5),Vector3(side*1.29,opening[i].y,opening[i].x),Vector3(side*1.29,opening[j].y,opening[j].x),Vector3(-side,0,0))
        _node(parent,pane,glass,label+"Glass",4)

static func _bar(parent: Node3D,a: Vector3,b: Vector3,radius: float,material: Material,label: String) -> void:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = a.distance_to(b)
    mesh.radial_segments = 12
    mesh.material = material
    node.mesh = mesh
    var direction := (b-a).normalized()
    var axis := Vector3.UP.cross(direction)
    if axis.length_squared() > 0.00001:
        node.basis = Basis(axis.normalized(),Vector3.UP.angle_to(direction))
    node.position = (a+b)*0.5
    node.layers = 3
    parent.add_child(node)

static func _waist_trim(parent: Node3D,side: float,z0: float,z1: float) -> void:
    var chrome := StandardMaterial3D.new()
    chrome.albedo_color = Color(0.68,0.70,0.68)
    chrome.metallic = 0.65
    chrome.roughness = 0.4
    for y in [1.62,1.69,1.76]:
        _bar(parent,Vector3(side*1.351,y,z0),Vector3(side*1.351,y,z1),0.021,chrome,"CabWaistMoulding")

static func mirror_mount(parent: Node3D,side: float,material: Material) -> void:
    # Twin bent yellow arms run from the original side mounting to the
    # mirror ahead of the windscreen. The arms never cross the cabin interior.
    for y in [2.40,2.48]:
        var a := Vector3(side*1.35,y,-9.33)
        var b := Vector3(side*1.71,y,-9.33)
        var c := Vector3(side*1.71,y,-10.39)
        var d := Vector3(side*1.45,y,-10.39)
        _bar(parent,a,b,0.012,material,"MirrorMountSide")
        _bar(parent,b,c,0.012,material,"MirrorMountForward")
        _bar(parent,c,d,0.012,material,"MirrorMountReturn")
    _bar(parent,Vector3(side*1.45,2.40,-10.39),Vector3(side*1.45,2.68,-10.39),0.012,material,"MirrorMountUpright")

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

