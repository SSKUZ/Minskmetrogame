extends RefCounted
## 81-717.5 reference: Kun, Metrovagonmash operating manual (1993), chapter 2.
## https://djvu.online/file/hm3MBHnsxWZgp
## Photo reference: mwms.tmholding.ru/media/events/ (81-717 overhaul workshop).
## 780 mm tread diameter; 2100 mm bogie wheelbase; 1520 mm running gauge.
const Route = preload("res://scripts/depot/route_profile.gd")
const RADIUS := 0.390
const HALF_BASE := 1.050
var _cars: Dictionary = {}
var _bodies: Dictionary = {}
var _materials: Dictionary = {}
var _parts: Dictionary = {}
var _frame: ArrayMesh
var _wheels: Array[ArrayMesh] = []
var _cube: BoxMesh
var _cylinder: CylinderMesh

func _init() -> void:
    for entry in [["frame",Color("#38403f"),0.48,0.73],["edge",Color("#59615d"),0.55,0.61],["rubber",Color("#242a27"),0.0,0.94],["wheel",Color("#414844"),0.65,0.62],["tread",Color("#969e9c"),0.86,0.30],["bolt",Color("#777f79"),0.65,0.55]]:
        var material := StandardMaterial3D.new()
        material.albedo_color=entry[1]
        material.metallic=float(entry[2]); material.roughness=float(entry[3])
        _materials[entry[0]]=material
    _cube=BoxMesh.new(); _cube.size=Vector3.ONE
    _cylinder=CylinderMesh.new()
    _cylinder.top_radius=0.5; _cylinder.bottom_radius=0.5
    _cylinder.height=1.0; _cylinder.radial_segments=16
    _make_frame()
    _wheels.append(_wheel_mesh(-1.0))
    _wheels.append(_wheel_mesh(1.0))

func body_bounds(car: Node3D,fallback: AABB) -> AABB:
    if _bodies.has(car): return _bodies[car]
    var found := false
    var body := AABB()
    for node in car.find_children("*","MeshInstance3D",true,false):
        var mesh := node as MeshInstance3D
        if mesh.mesh == null: continue
        var bounds: AABB=car.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
        if bounds.size.x < 1.8 or bounds.size.y < 0.15 or bounds.get_center().y < 0.8: continue
        body=bounds if not found else body.merge(bounds)
        found=true
    if not found or body.size.z < fallback.size.z*0.75: body=fallback
    _bodies[car]=body
    return body

func half_body_gap(first: Node3D,first_full: AABB,second: Node3D,second_full: AABB) -> float:
    var a := body_bounds(first,first_full)
    var b := body_bounds(second,second_full)
    # Old full-bounds spacing includes the protruding couplers: halve the
    # actual distance between body faces, rather than just the old 250 mm term.
    return maxf(0.04,(first_full.end.z-a.end.z+b.position.z-second_full.position.z+0.25)*0.5)

func shorten_original_coupler(car: Node3D,front: bool) -> void:
    if not _bodies.has(car): return
    var body: AABB=_bodies[car]
    for node in car.find_children("*","MeshInstance3D",true,false):
        var mesh := node as MeshInstance3D
        if mesh.mesh == null: continue
        var bounds: AABB=car.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
        if bounds.end.y > 0.80 or bounds.size.z > 1.6 or bounds.size.x > 1.3: continue
        var outside := bounds.get_center().z < body.position.z+0.08 if front else bounds.get_center().z > body.end.z-0.08
        if outside:
            mesh.hide()
            mesh.set_meta("replaced_intercar_coupler",true)

func setup_car(car: Node3D,bounds: AABB,rest: Transform3D) -> PackedFloat32Array:
    if _cars.has(car): return _cars[car].supports
    var positions: Array[float] = []
    for node in car.find_children("*","MeshInstance3D",true,false):
        var mesh := node as MeshInstance3D
        if mesh.mesh == null: continue
        var box: AABB=car.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
        var c := box.get_center()
        if box.size.y < 0.57 or box.size.y > 1.05 or box.size.z < 0.57 or box.size.z > 1.05: continue
        if box.size.x > 0.45 or absf(c.x-bounds.get_center().x) < 0.50 or c.y > 0.62: continue
        var duplicate := false
        for z in positions:
            if absf(z-c.z) < 0.12: duplicate=true
        if not duplicate: positions.append(c.z)
    positions.sort()
    var centers := PackedFloat32Array()
    if positions.size() >= 4:
        centers.append((positions[0]+positions[1])*0.5)
        centers.append((positions[-2]+positions[-1])*0.5)
    else:
        centers.append(bounds.get_center().z-6.3)
        centers.append(bounds.get_center().z+6.3)
    _retire_old_geometry(car,centers,bounds.get_center().x)
    var supports := PackedFloat32Array()
    var bogies: Array[Dictionary] = []
    for center in centers:
        var support := rest*Vector3(bounds.get_center().x,0.0,center)
        supports.append(support.z)
        var root := Node3D.new()
        root.name="Detailed81_717Bogie"
        root.set_meta("bogie_visual",true)
        car.add_child(root)
        var frame := MeshInstance3D.new()
        frame.name="WeldedFrameSuspensionAndDrive"
        frame.mesh=_frame
        frame.layers=1
        root.add_child(frame)
        var wheels: Array[Node3D] = []
        for z in [-HALF_BASE,HALF_BASE]:
            for side_index in range(2):
                var side := -1.0 if side_index == 0 else 1.0
                var wheel := MeshInstance3D.new()
                wheel.name="ProfiledFlangedWheel"
                wheel.mesh=_wheels[side_index]
                wheel.position=Vector3(side*Route.RAIL_CENTER,0,z)
                wheel.layers=1
                root.add_child(wheel)
                wheels.append(wheel)
        bogies.append({"root":root,"z":support.z,"wheels":wheels})
    supports.sort()
    _cars[car]={"supports":supports,"bogies":bogies}
    return supports

func _retire_old_geometry(car: Node3D,centers: PackedFloat32Array,center_x: float) -> void:
    # Only the old low undercarriage within the two wheelbase envelopes.
    # Floor, longitudinal underframe and body geometry stay in place.
    for node in car.find_children("*","MeshInstance3D",true,false):
        var mesh := node as MeshInstance3D
        if mesh.mesh == null: continue
        var bounds: AABB=car.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
        if bounds.end.y > 0.91 or bounds.size.z > 3.7 or bounds.size.x > 2.65: continue
        if bounds.position.y < -0.40 or absf(bounds.get_center().x-center_x) > 1.5: continue
        for z in centers:
            if bounds.position.z >= z-1.85 and bounds.end.z <= z+1.85:
                mesh.hide()
                mesh.set_meta("replaced_bogie_geometry",true)
                break

func update_car(car: Node3D,train: Node3D,distance: float) -> void:
    if not _cars.has(car): return
    for bogie in _cars[car].bogies:
        var z: float=train.global_position.z+float(bogie.z)
        var pitch := -atan(Route.grade(z))
        var projected := HALF_BASE*cos(pitch)
        var a := Route.height(z-projected)
        var b := Route.height(z+projected)
        pitch=-atan2(b-a,projected*2.0)
        # Global rail datum prevents model-origin/lateral offsets and inherited
        # body pitch from moving the tread off the two running railheads.
        var root := bogie.root as Node3D
        root.global_transform=Transform3D(Basis(Vector3.RIGHT,pitch),Vector3(Route.CENTER_X,(a+b)*0.5+RADIUS,z))
        for wheel in bogie.wheels:
            (wheel as Node3D).rotation.x=fposmod((distance-Route.START_Z)/RADIUS,TAU)

func _part(mesh: Mesh,material: String,pose: Transform3D) -> void:
    if not _parts.has(material):
        var tool := SurfaceTool.new()
        tool.begin(Mesh.PRIMITIVE_TRIANGLES)
        tool.set_material(_materials[material])
        _parts[material]=tool
    (_parts[material] as SurfaceTool).append_from(mesh,0,pose)

func _box(pos: Vector3,size: Vector3,material: String = "frame",basis: Basis = Basis.IDENTITY) -> void:
    _part(_cube,material,Transform3D(basis*Basis.from_scale(size),pos))

func _cyl(pos: Vector3,radius: float,length: float,material: String = "frame",axis: Vector3 = Vector3.UP) -> void:
    var basis := Basis(Quaternion(Vector3.UP,axis.normalized()))
    _part(_cylinder,material,Transform3D(basis*Basis.from_scale(Vector3(radius*2,length,radius*2)),pos))

func _rod(a: Vector3,b: Vector3,radius: float,material: String = "frame") -> void:
    _cyl((a+b)*0.5,radius,a.distance_to(b),material,b-a)

func _spring(radius: float,height: float,wire: float) -> ArrayMesh:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var steps := 54
    var sides := 6
    for i in range(steps):
        for j in range(sides):
            for pair in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
                var t := float(pair.x)/float(steps)
                var angle := t*TAU*4.5
                var tube := float(pair.y)*TAU/float(sides)
                var radial := Vector3(cos(angle),0,sin(angle))
                var normal := radial*cos(tube)+Vector3.UP*sin(tube)
                var center := radial*radius+Vector3.UP*((t-0.5)*height)
                tool.set_normal(normal)
                tool.set_uv(Vector2(t,float(pair.y)/float(sides)))
                tool.add_vertex(center+normal*wire)
    return tool.commit()

func _make_frame() -> void:
    var primary := _spring(0.077,0.23,0.016)
    var secondary := _spring(0.135,0.27,0.022)
    for side in [-1.0,1.0]:
        var x: float=side*1.025
        # Pressed/welded box side member with raised bearing pedestals.
        _box(Vector3(x,0.33,0),Vector3(0.17,0.22,2.78))
        _box(Vector3(x,0.447,0),Vector3(0.20,0.025,2.78),"edge")
        _box(Vector3(x,0.21,0),Vector3(0.19,0.025,2.70),"edge")
        for z in [-HALF_BASE,HALF_BASE]:
            _box(Vector3(x,0.01,z),Vector3(0.27,0.24,0.30))
            _cyl(Vector3(side*1.18,0.01,z),0.115,0.055,"edge",Vector3.RIGHT)
            _cyl(Vector3(side*1.212,0.01,z),0.072,0.018,"frame",Vector3.RIGHT)
            for bolt in range(6):
                var angle := float(bolt)*TAU/6.0
                _cyl(Vector3(side*1.224,sin(angle)*0.087+0.01,z+cos(angle)*0.087),0.014,0.019,"bolt",Vector3.RIGHT)
            for dz in [-0.21,0.21]:
                var spring_pos := Vector3(x,0.19,z+dz)
                _part(primary,"frame",Transform3D(Basis.IDENTITY,spring_pos))
                _cyl(spring_pos+Vector3(0,-0.13,0),0.10,0.025,"edge")
                _cyl(spring_pos+Vector3(0,0.13,0),0.10,0.025,"edge")
            _rod(Vector3(x,0.12,z),Vector3(x,0.31,z-signf(z)*0.42),0.027,"edge")
        # Two-stage central spring bolster, hangers and dampers.
        for z in [-0.29,0.29]:
            _part(secondary,"frame",Transform3D(Basis.IDENTITY,Vector3(side*0.92,0.39,z)))
            _cyl(Vector3(side*0.92,0.24,z),0.16,0.035,"edge")
            _cyl(Vector3(side*0.92,0.54,z),0.16,0.035,"edge")
            _rod(Vector3(side*1.12,0.20,z),Vector3(side*1.12,0.59,z+0.04),0.024,"edge")
        _rod(Vector3(side*1.13,0.18,-0.48),Vector3(side*1.13,0.48,-0.17),0.040)
        _rod(Vector3(side*1.13,0.37,-0.29),Vector3(side*1.13,0.59,-0.05),0.019,"tread")
        # Brake cylinder and its longitudinal rod/linkage.
        _cyl(Vector3(side*1.12,0.20,0.64),0.075,0.38,"edge",Vector3.BACK)
        _rod(Vector3(side*1.12,0.20,0.43),Vector3(side*1.12,0.13,-0.55),0.018,"bolt")
        _rod(Vector3(side*1.17,0.13,-0.55),Vector3(side*1.17,-0.04,-0.74),0.022)
        _rod(Vector3(side*1.08,0.47,-1.30),Vector3(side*1.08,0.47,1.30),0.012,"rubber")
    for z in [-0.48,0.48]:
        _box(Vector3(0,0.32,z),Vector3(1.95,0.21,0.20))
        _box(Vector3(0,0.43,z),Vector3(1.97,0.025,0.23),"edge")
    _box(Vector3(0,0.58,0),Vector3(2.18,0.16,0.28))
    _cyl(Vector3(0,0.72,0),0.20,0.12,"edge")
    _cyl(Vector3(0,0.79,0),0.14,0.025,"rubber")
    for z in [-HALF_BASE,HALF_BASE]:
        _cyl(Vector3(0,0,z),0.075,2.30,"wheel",Vector3.RIGHT)
        var toward_center := -signf(z)
        # Frame-mounted traction motor, ribbed casing, axle gearbox and coupling.
        var motor_z: float=z+toward_center*0.40
        _cyl(Vector3(-0.15,0.17,motor_z),0.17,0.80,"frame",Vector3.RIGHT)
        for x in [-0.49,-0.34,-0.19,-0.04,0.11,0.26]:
            _cyl(Vector3(x,0.17,motor_z),0.182,0.018,"edge",Vector3.RIGHT)
        _box(Vector3(0.45,0.04,z+0.10*toward_center),Vector3(0.28,0.36,0.44))
        _cyl(Vector3(0.61,0.02,z),0.17,0.055,"edge",Vector3.RIGHT)
        _rod(Vector3(0.45,0.25,z),Vector3(0.43,0.39,z+toward_center*0.30),0.035,"edge")
        for side in [-1.0,1.0]:
            for end in [-1.0,1.0]:
                # Segmented curved shoe follows the wheel rim, not a square block.
                for segment in [-1.0,0.0,1.0]:
                    var angle: float=(0.0 if end > 0.0 else PI)+segment*0.17
                    _box(Vector3(side*Route.RAIL_CENTER,sin(angle)*0.414,z+cos(angle)*0.414),Vector3(0.09,0.075,0.035),"rubber",Basis(Vector3.RIGHT,-angle))
                _rod(Vector3(side*1.03,0.30,z+end*0.30),Vector3(side*0.95,0.03,z+end*0.43),0.025,"edge")
    _frame=ArrayMesh.new()
    for tool in _parts.values(): (tool as SurfaceTool).commit(_frame)
    _frame.resource_name="81_717MotorBogieFrame"
    _parts.clear()

func _wheel_mesh(side: float) -> ArrayMesh:
    # Axial/radial profile: deep hub, dished web, inner flange and polished tread.
    var profile := PackedVector2Array([Vector2(-0.105,0.080),Vector2(-0.105,0.15),Vector2(-0.05,0.17),Vector2(-0.026,0.29),Vector2(-0.073,0.35),Vector2(-0.073,0.407),Vector2(-0.055,0.416),Vector2(-0.032,0.402),Vector2(-0.025,0.390),Vector2(0.050,0.390),Vector2(0.070,0.383),Vector2(0.070,0.338),Vector2(0.025,0.30),Vector2(0.008,0.17),Vector2(0.095,0.15),Vector2(0.105,0.115),Vector2(0.105,0.080)])
    var wheel := ArrayMesh.new()
    for polished in [false,true]:
        var tool := SurfaceTool.new()
        tool.begin(Mesh.PRIMITIVE_TRIANGLES)
        tool.set_material(_materials["tread" if polished else "wheel"])
        for segment in range(profile.size()):
            if (segment >= 5 and segment <= 10) != polished: continue
            var next := (segment+1)%profile.size()
            var edge := profile[next]-profile[segment]
            for step in range(64):
                var corners := [Vector2i(segment,step),Vector2i(next,step),Vector2i(next,step+1),Vector2i(segment,step+1)]
                var order := [0,1,2,0,2,3] if side > 0.0 else [0,2,1,0,3,2]
                for index in order:
                    var pair: Vector2i=corners[index]
                    var p := profile[pair.x]
                    var angle := float(pair.y)*TAU/64.0
                    tool.set_normal(Vector3(-edge.y*side,edge.x*cos(angle),edge.x*sin(angle)).normalized())
                    tool.set_uv(Vector2(float(pair.y)/64.0,float(pair.x)/float(profile.size())))
                    tool.add_vertex(Vector3(p.x*side,p.y*cos(angle),p.y*sin(angle)))
        tool.commit(wheel)
    wheel.resource_name="81_717ProfiledWheel780"
    return wheel
