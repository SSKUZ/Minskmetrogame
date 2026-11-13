extends "res://modules/stations/borisovsky_trakt/station_base.gd"
## Owner photographs 6715–6732. +Z west/Vostok; -Z east/Uruchye.
## StationBase dimensions are retained as estimates, not a measured survey.
const DIR := "res://modules/stations/borisovsky_trakt/textures/"
var stone: StandardMaterial3D
var brown: StandardMaterial3D
var steel: StandardMaterial3D
var white: StandardMaterial3D
var dark: StandardMaterial3D
var wood: StandardMaterial3D
var glow: StandardMaterial3D
var chocolate: StandardMaterial3D
var _batches: Dictionary = {}

func _ready() -> void:
    super._ready()
    stone = _stone("marble.jpg", Color(0.95,0.94,0.9),0.24)
    brown = _stone("granite.jpg",Color(0.7,0.62,0.55),0.3)
    steel = _material(Color(0.58,0.61,0.62),0.85,0.24)
    white = _material(Color(0.81,0.81,0.76),0.15,0.65)
    dark = _material(Color(0.075,0.065,0.06),0.18,0.32)
    wood = _material(Color(0.53,0.30,0.10),0.0,0.45)
    chocolate = _material(Color(0.17,0.085,0.08),0.4,0.35)
    glow = _material(Color(0.93,0.96,0.91))
    glow.emission_enabled = true
    glow.emission = Color(0.92,0.96,0.89)
    glow.emission_energy_multiplier = 1.6
    var floor_node := get_node("IslandPlatform") as MeshInstance3D
    floor_node.material_override = _stone("floor.jpg",Color(0.78,0.79,0.76),0.52)
    for child in get_children():
        if child is OmniLight3D:
            child.light_color = Color(1.0,0.95,0.84)
            child.light_energy = 0.9
            child.omni_range = 15.0
    _floor_details()
    _walls()
    _ceiling()
    _supports()
    _ends()
    _equipment()
    _flush_batches()

func _stone(file: String, tint: Color, rough: float) -> StandardMaterial3D:
    var mat := _material(tint,0.05,rough)
    mat.albedo_texture = load(DIR+file)
    mat.uv1_triplanar = true
    mat.uv1_scale = Vector3(0.65,0.65,0.65)
    return mat

func _b(label: String, size: Vector3, p: Vector3, mat: Material) -> void:
    var key := label + str(mat.get_instance_id()) + str(size)
    if not _batches.has(key):
        var mesh := BoxMesh.new()
        mesh.size = size
        mesh.material = mat
        _batches[key] = {"mesh":mesh,"poses":[]}
    _batches[key].poses.append(Transform3D(Basis(),p))

func _flush_batches() -> void:
    for key in _batches:
        var data: Dictionary = _batches[key]
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = data.mesh
        mm.instance_count = data.poses.size()
        for i in range(mm.instance_count): mm.set_instance_transform(i,data.poses[i])
        var node := MultiMeshInstance3D.new()
        node.name = str(key).get_slice("(",0).validate_node_name()
        node.multimesh = mm
        add_child(node)
    _batches.clear()

func _mesh(label: String, mesh: Mesh, p: Vector3, mat: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = mesh
    node.position = p
    node.material_override = mat
    add_child(node)
    return node

func _cylinder(label: String, r: float, height: float, p: Vector3, mat: Material) -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = r
    mesh.bottom_radius = r
    mesh.height = height
    mesh.radial_segments = 24
    _mesh(label,mesh,p,mat)

func _rod(a: Vector3,b: Vector3,r: float,mat: Material) -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = r
    mesh.bottom_radius = r
    mesh.height = a.distance_to(b)
    mesh.radial_segments = 8
    var n := _mesh("Handrail",mesh,(a+b)*0.5,mat)
    var direction := (b-a).normalized()
    var axis := Vector3.UP.cross(direction)
    if axis.length_squared()>0.0001: n.basis = Basis(axis.normalized(),acos(Vector3.UP.dot(direction)))

func _torus(p: Vector3, radius: float) -> void:
    var mesh := TorusMesh.new()
    mesh.inner_radius = radius-0.025
    mesh.outer_radius = radius+0.025
    mesh.rings = 24
    mesh.ring_segments = 8
    _mesh("ColumnGuardRing",mesh,p,steel)

func _floor_details() -> void:
    for x in [-9.2,-1.54]:
        _b("FloorRibbon",Vector3(0.18,0.008,103),Vector3(x,1.185,39.612),dark)
    for x in [-10.1,-0.64]:
        _b("TactileStrip",Vector3(0.16,0.012,105),Vector3(x,1.192,39.612),_material(Color(0.83,0.57,0.09)))
    for i in range(88):
        var z := -12.3+float(i)*1.2
        _b("FloorJoint",Vector3(9.4,0.003,0.009),Vector3(-5.37,1.183,z),_material(Color(0.38,0.38,0.36)))
    for x in [-0.408, -10.332]:
        _b("EdgeStone",Vector3(0.12,0.008,105),Vector3(x,1.185,39.612),white)

func _walls() -> void:
    for side in [-1,1]:
        var x := -5.37+float(side)*9.0
        _b("TrackWallPlinth",Vector3(0.20,1.25,105),Vector3(x,0.70,39.612),brown)
        _b("TrackMarble",Vector3(0.18,2.65,105),Vector3(x,2.65,39.612),stone)
        _b("TrackUpperPlaster",Vector3(0.25,1.4,105),Vector3(x,4.65,39.612),white)
        for row in range(4):
            _b("MarbleHorizontalSeam",Vector3(0.195,0.009,105),Vector3(x,1.34+float(row)*0.66,39.612),white)
        for i in range(88):
            _b("MarbleVerticalSeam",Vector3(0.195,2.65,0.009),Vector3(x,2.65,-12.3+float(i)*1.2),white)
        _b("WallCable",Vector3(0.22,0.035,105),Vector3(x,4.02,39.612),dark)
        for y in [2.35,2.39,2.44]:
            _b("WallSteelMoulding",Vector3(0.26,0.022,105),Vector3(x,y,39.612),steel)
        for z in [12.0,66.0]:
            _picture("ActualStationLetters", "name.png", Vector2(11.8,1.0),Vector3(x-float(side)*0.14,2.94,z),-float(side)*PI/2.0,true)
        for z in [35.0,82.0]:
            _picture("MoscowLineWallDiagram","wall_map.jpg",Vector2(5.2,1.12),Vector3(x-float(side)*0.15,2.65,z),-float(side)*PI/2.0)

# Extrude an X/Y section along Z; used for the continuous curved ceiling bands.
func _profile(label: String, profile: Array[Vector2], z0: float,z1: float,mat: Material) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(profile.size()-1):
        var a := profile[i]
        var b := profile[i+1]
        for v in [Vector3(a.x,a.y,z0),Vector3(b.x,b.y,z0),Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z0),Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z1)]: st.add_vertex(v)
    st.generate_normals()
    var double_mat := mat.duplicate() as StandardMaterial3D
    double_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    _mesh(label,st.commit(),Vector3.ZERO,double_mat)

func _ceiling() -> void:
    _b("CeilingSlab",Vector3(18.2,0.18,105),Vector3(-5.37,5.7,39.612),white)
    var cornice: Array[Vector2] = []
    for i in range(13):
        var a := PI*float(i)/12.0
        cornice.append(Vector2(-5.37+1.65*cos(a),5.48-0.56*sin(a)))
    _profile("ChocolateCurvedCentralCornice",cornice,-12.888,92.112,chocolate)
    for i in range(350):
        var z := -12.8+float(i)*0.30
        _profile("ChocolateTransverseSlat",cornice,z,z+0.018,dark)
    for side in [-1,1]:
        var edge := -5.37+float(side)*4.8
        _b("GlobeLightBeam",Vector3(0.13,0.18,105),Vector3(edge,4.83,39.612),white)
        for i in range(70):
            var z := -12.0+float(i)*1.5
            var sphere := SphereMesh.new()
            sphere.radius = 0.14
            sphere.height = 0.28
            sphere.radial_segments = 12
            sphere.rings = 6
            _mesh("OpalGlobe",sphere,Vector3(edge,5.0,z),glow)
            _cylinder("GlobeSocket",0.065,0.08,Vector3(edge,4.82,z),steel)
        for i in range(44):
            var z := -12.0+float(i)*2.4
            var rib: Array[Vector2] = []
            rib.append(Vector2(-5.37+float(side)*1.4,5.53))
            rib.append(Vector2(-5.37+float(side)*4.15,5.53))
            for j in range(9):
                var a := PI/2.0*float(j)/8.0
                rib.append(Vector2(-5.37+float(side)*(4.15+0.65*sin(a)),4.88+0.65*cos(a)))
            _profile("WhiteCeilingRib",rib,z,z+0.12,white)
            _b("OverTrackTransverseBeam",Vector3(4.3,0.23,0.14),Vector3(-5.37+float(side)*6.95,5.1,z),white)
        for i in range(12):
            var x := -5.37+float(side)*(1.9+float(i)*0.22)
            _b("WhiteCeilingSlat",Vector3(0.012,0.015,105),Vector3(x,5.57,39.612),white)

func _supports() -> void:
    for i in range(16):
        var z := -5.0+float(i)*6.0
        if i%2 == 0:
            _cylinder("RoundMarbleColumn",0.43,3.95,Vector3(-5.37,3.16,z),stone)
            _cylinder("SteelColumnCapital",0.45,0.50,Vector3(-5.37,4.85,z),steel)
            _cylinder("ColumnDarkBase",0.45,0.40,Vector3(-5.37,1.38,z),dark)
            _torus(Vector3(-5.37,1.98,z),0.67)
            _torus(Vector3(-5.37,2.34,z),0.67)
        else:
            _b("MarblePier",Vector3(1.55,3.8,2.75),Vector3(-5.37,3.08,z),stone)
            _b("PierSteelTop",Vector3(1.59,0.82,2.79),Vector3(-5.37,4.57,z),steel)
            _b("PierDarkPlinth",Vector3(1.61,0.18,2.81),Vector3(-5.37,1.27,z),dark)
            for y in [1.93,2.22]:
                _b("PierChocolateStripe",Vector3(1.57,0.16,2.77),Vector3(-5.37,y,z),dark)
            for side in [-1,1]:
                _bench(-5.37+float(side)*1.12,z,side)
                _b("Downlighter",Vector3(0.12,0.02,2.2),Vector3(-5.37+float(side)*0.96,4.72,z),glow)
        if i in [2,7,12]:
            for side in [-1,1]:
                var x := -5.37+float(side)*2.3
                for face in [0,1]:
                    var file := "direction_1.jpg" if side == 1 else "direction_2.jpg"
                    _picture("TrackDirection","%s" % file,Vector2(3.5,0.70),Vector3(x,4.06,z+float(face)*0.08),PI if face==1 else 0.0)
                _b("SignSuspension",Vector3(0.035,0.85,0.035),Vector3(x,4.75,z),steel)

func _bench(x: float,z: float,side: int) -> void:
    _b("BenchStoneBase",Vector3(0.65,0.42,2.0),Vector3(x,1.39,z),dark)
    _b("BenchSteelSeat",Vector3(0.66,0.08,2.1),Vector3(x,1.72,z),steel)
    for i in range(30):
        var zz := z-0.98+float(i)*0.067
        _b("OakSeatSlat",Vector3(0.61,0.055,0.05),Vector3(x,1.78,zz),wood)
        _b("OakBackSlat",Vector3(0.055,0.66,0.05),Vector3(x-float(side)*0.29,2.09,zz),wood)
    for zz in [z-1.13,z+1.13]:
        _cylinder("HalfRoundSteelBin",0.20,0.58,Vector3(x,2.0,zz),steel)
        _cylinder("OpenBinTop",0.18,0.01,Vector3(x,2.30,zz),dark)

func _picture(label: String,file: String,size: Vector2,p: Vector3,yaw: float,transparent: bool=false) -> void:
    var mat := _material(Color.WHITE,0.0,0.8)
    mat.albedo_texture = load(DIR+file)
    if transparent: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    else:
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var quad := QuadMesh.new()
    quad.size = size
    var node := _mesh(label,quad,p,mat)
    node.rotation.y = yaw

func _ends() -> void:
    # Working west exit, broad granite flight with a distinct intermediate landing.
    var start := 85.0
    for i in range(30):
        var z := start+float(i)*0.31
        var height := float(i+1)*0.145
        _b("WestGraniteStep",Vector3(7.2,height,0.32),Vector3(-5.37,1.1805+height*0.5,z),brown)
        if i in [0,14,29]:
            _b("YellowStairNosing",Vector3(7.2,0.025,0.05),Vector3(-5.37,1.20+height,z-0.14),_material(Color(0.95,0.68,0.08)))
    for x in [-9.12,-6.60,-1.62]:
        for y in [0.72,1.06]: _rod(Vector3(x,1.1805+y,start-0.2),Vector3(x,5.54+y,start+9.3),0.025,steel)
        for i in range(7):
            var z := start+float(i)*1.5
            var y := 1.1805+(z-start)*0.468
            _rod(Vector3(x,y,z),Vector3(x,y+1.1,z),0.026,steel)
    for side in [-1,1]:
        _b("StairSideMarble",Vector3(0.25,5.4,10),Vector3(-5.37+float(side)*3.8,3.87,89.5),stone)
    _picture("WestExitDestinations","exit.jpg",Vector2(7.05,0.78),Vector3(-5.37,4.1,84.65),PI)
    _b("WestVestibuleFloor",Vector3(7.2,0.2,4),Vector3(-5.37,5.53,96.3),brown)
    _b("WestVestibuleBack",Vector3(7.5,3.0,0.2),Vector3(-5.37,7.1,98.4),stone)
    # East vestibule is closed: the documented curved screen stops below ceiling.
    var screen: Array[Vector2] = []
    for i in range(21):
        var a := PI*float(i)/20.0
        screen.append(Vector2(-5.37+3.4*cos(a),-10.7-1.6*sin(a)))
    for i in range(screen.size()-1):
        var a := screen[i]
        var b := screen[i+1]
        var mesh := BoxMesh.new()
        mesh.size = Vector3(a.distance_to(b)+0.015,3.1,0.12)
        var n := _mesh("ClosedEastVestibuleScreen",mesh,Vector3((a.x+b.x)*0.5,2.73,(a.y+b.y)*0.5),white)
        n.rotation.y = -atan2(b.y-a.y,b.x-a.x)
    for x in [0.992,-11.732]:
        for z in [-16.9,96.1]:
            _b("ShortTunnelRoof",Vector3(4.6,0.3,8),Vector3(x,4.05,z),dark)
            for side in [-1,1]: _b("ShortTunnelSide",Vector3(0.25,4.3,8),Vector3(x+float(side)*2.3,1.9,z),dark)
            _b("TunnelDarkEnd",Vector3(4.6,4.3,0.12),Vector3(x,1.9,z+(-4.0 if z<0 else 4.0)),dark)

func _text(value: String,p: Vector3,size: int,colour: Color,yaw: float=0.0) -> void:
    var label := Label3D.new()
    label.text = value
    label.font_size = size
    label.pixel_size = 0.008
    label.modulate = colour
    label.outline_size = 0
    label.position = p
    label.rotation.y = yaw
    label.no_depth_test = false
    add_child(label)

func _equipment() -> void:
    for z in [2.0,32.0,62.0,81.0]:
        for x in [-8.0,-2.74]:
            _b("PublicAddressSpeaker",Vector3(0.15,0.29,0.18),Vector3(x,5.15,z),steel)
            _b("SpeakerFace",Vector3(0.12,0.24,0.02),Vector3(x,5.15,z-0.1),dark)
    for x in [-9.5,-1.25]:
        _b("CCTVBody",Vector3(0.16,0.15,0.35),Vector3(x,4.26,83.2),white)
        _b("CCTVBracket",Vector3(0.04,0.3,0.04),Vector3(x,4.45,83.3),steel)
    # Dark existing information screens, no invented advertising or service text.
    for z in [22.0,58.0]:
        _b("InformationMonitor",Vector3(1.2,0.7,0.12),Vector3(-2.5,4.1,z),dark)
    for x in [-9.1,-1.65]:
        _b("EmergencyCallPanel",Vector3(0.24,0.45,0.05),Vector3(x,2.27,84.0),_material(Color(0.95,0.77,0.12)))
        _b("SOSButton",Vector3(0.08,0.10,0.065),Vector3(x,2.27,83.97),_material(Color(0.75,0.08,0.04)))
