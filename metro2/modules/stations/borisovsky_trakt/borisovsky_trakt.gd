extends "res://modules/stations/borisovsky_trakt/station_base.gd"
## Owner photographs 6715–6732. +Z west/Vostok; -Z east/Uruchye.
## StationBase dimensions are retained as estimates, not a measured survey.
const DIR := "res://modules/stations/borisovsky_trakt/textures/"
const ART := "res://modules/stations/borisovsky_trakt/art_v69/"
const CX := -5.37
const FY := 1.1805
const Z0 := -12.888
const Z1 := 92.112
const MID := 39.612
# +X edge: +Z west/Vostok/centre (route 2). -X edge: -Z east/Uruchye (route 1).
# One binding supplies both wall maps and every face of the hanging boards.
const PLATFORM_ROUTES := {
    -1: {"wall": "wall_toward_uruchye.svg", "board": "direction_1.svg"},
    1: {"wall": "wall_toward_malinovka.svg", "board": "direction_2.svg"}
}
var floor_dark: StandardMaterial3D
var stairs: StandardMaterial3D
var bronze: StandardMaterial3D
var letter_face: StandardMaterial3D
var marble_tiles: Array[StandardMaterial3D] = []
var stone: StandardMaterial3D
var brown: StandardMaterial3D
var steel: StandardMaterial3D
var white: StandardMaterial3D
var dark: StandardMaterial3D
var wood: StandardMaterial3D
var glow: StandardMaterial3D
var chocolate: StandardMaterial3D
var _batches: Dictionary = {}
var _profiles: Dictionary = {}

func _ready() -> void:
    super._ready()
    stone = _photo_stone("column_marble.jpg", Color.WHITE,0.28,Vector3(0.85,0.72,0.85))
    for i in range(4):
        var shade := 0.96+float(i)*0.015
        marble_tiles.append(_photo_stone("wall_marble.jpg" if i%2==0 else "wall_marble_alt.jpg",Color(shade,shade,shade),0.31,Vector3(0.75,1.2,0.75)))
    brown = _photo_stone("red_granite.jpg",Color.WHITE,0.38,Vector3(1.0,1.0,1.0))
    floor_dark = _photo_stone("floor_dark.jpg",Color.WHITE,0.24,Vector3(1.1,1.1,1.1))
    stairs = _photo_stone("stair_granite.jpg",Color.WHITE,0.55,Vector3(0.6,1.3,0.6))
    bronze = _material(Color("#514031"),0.74,0.32)
    letter_face = _material(Color("#baac91"),0.50,0.42)
    steel = _material(Color(0.58,0.61,0.62),0.85,0.24)
    white = _material(Color(0.81,0.81,0.76),0.15,0.65)
    dark = _material(Color(0.075,0.065,0.06),0.18,0.32)
    wood = _photo_stone("seat_oak.jpg",Color.WHITE,0.44,Vector3(1.5,1.5,1.5))
    chocolate = _material(Color("#493239"),0.42,0.36)
    glow = _material(Color(0.93,0.96,0.91))
    glow.emission_enabled = true
    glow.emission = Color(0.92,0.96,0.89)
    glow.emission_energy_multiplier = 1.6
    var floor_node := get_node("IslandPlatform") as MeshInstance3D
    floor_node.material_override = _photo_stone("floor_pale.jpg",Color.WHITE,0.38,Vector3(0.75,0.75,0.75))
    for label in ["SafetyEdgeTrack1","SafetyEdgeTrack2","TrainStopMarker"]:
        (get_node(label) as MeshInstance3D).hide()
    for child in get_children():
        if child is OmniLight3D:
            child.light_color = Color(1.0,0.98,0.92)
            child.light_energy = 1.35
            child.omni_range = 18.0
    _floor_details()
    _walls()
    _ceiling()
    _supports()
    _ends()
    _equipment()
    _finish_details()
    _flush_batches()

func _photo_stone(file: String, tint: Color, rough: float, scale_uv: Vector3) -> StandardMaterial3D:
    var mat := _material(tint,0.0,rough)
    mat.albedo_texture = load(ART+file)
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    mat.uv1_world_triplanar = true
    mat.uv1_triplanar = true
    mat.uv1_scale = scale_uv
    return mat

func _instance(kind: String, label: String, pose: Transform3D, mat: Material) -> void:
    var key := kind+str(mat.get_instance_id())
    if not _batches.has(key):
        var mesh: PrimitiveMesh
        if kind in ["cylinder","stud"]:
            var c := CylinderMesh.new()
            c.top_radius=0.5;c.bottom_radius=0.5;c.height=1.0;c.radial_segments=8 if kind=="stud" else 32
            mesh=c
        elif kind=="sphere":
            var sphere := SphereMesh.new()
            sphere.radius=0.5;sphere.height=1.0;sphere.radial_segments=16;sphere.rings=8
            mesh=sphere
        else:
            mesh=BoxMesh.new();(mesh as BoxMesh).size=Vector3.ONE
        mesh.material=mat
        _batches[key]={"mesh":mesh,"poses":[],"label":label}
    _batches[key].poses.append(pose)

func _b(label: String, size: Vector3, p: Vector3, mat: Material) -> void:
    _instance("box",label,Transform3D(Basis.from_scale(size),p),mat)

func _beam(label: String,a: Vector3,b: Vector3,width: float,height: float,mat: Material) -> void:
    var direction := (b-a).normalized()
    var up := Vector3.UP if absf(direction.dot(Vector3.UP))<0.99 else Vector3.RIGHT
    _instance("box",label,Transform3D(Basis.looking_at(direction,up)*Basis.from_scale(Vector3(width,height,a.distance_to(b))),(a+b)*0.5),mat)

func _flush_batches() -> void:
    for key in _batches:
        var data: Dictionary = _batches[key]
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = data.mesh
        mm.instance_count = data.poses.size()
        for i in range(mm.instance_count): mm.set_instance_transform(i,data.poses[i])
        var node := MultiMeshInstance3D.new()
        node.name = str(data.label)+"Instances"
        node.multimesh = mm
        add_child(node)
    _batches.clear()
    for key in _profiles:
        var data: Dictionary = _profiles[key]
        var surface: SurfaceTool = data.surface
        surface.generate_normals()
        _mesh(str(data.label),surface.commit(),Vector3.ZERO,data.material)
    _profiles.clear()

func _mesh(label: String, mesh: Mesh, p: Vector3, mat: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = mesh
    node.position = p
    node.material_override = mat
    add_child(node)
    return node

func _cylinder(label: String, r: float, height: float, p: Vector3, mat: Material) -> void:
    _instance("stud" if label=="TactileStud" else "cylinder",label,Transform3D(Basis.from_scale(Vector3(r*2.0,height,r*2.0)),p),mat)

func _rod(a: Vector3,b: Vector3,r: float,mat: Material) -> void:
    var direction := (b-a).normalized()
    var axis := Vector3.UP.cross(direction)
    var basis := Basis.IDENTITY
    if axis.length_squared()>0.0001: basis=Basis(axis.normalized(),acos(clampf(Vector3.UP.dot(direction),-1.0,1.0)))
    _instance("cylinder","MetalHandrail",Transform3D(basis*Basis.from_scale(Vector3(r*2.0,a.distance_to(b),r*2.0)),(a+b)*0.5),mat)

func _torus(p: Vector3, radius: float) -> void:
    var mesh := TorusMesh.new()
    mesh.inner_radius = radius-0.025
    mesh.outer_radius = radius+0.025
    mesh.rings = 24
    mesh.ring_segments = 8
    _mesh("ColumnGuardRing",mesh,p,steel)

func _floor_details() -> void:
    # Video 181/331: one broad polished central ribbon, pale circulation lanes.
    _b("CentralDarkGraniteField",Vector3(3.35,0.008,105),Vector3(CX,FY+0.004,MID),floor_dark)
    var joint := _material(Color("#797b73"),0.0,0.8)
    for i in range(89):
        var z := Z0+float(i)*1.20
        _b("FloorTileJoint",Vector3(9.96,0.002,0.003),Vector3(CX,FY+0.011,z),joint)
    for x in [-9.12,-7.71,-3.03,-1.62]:
        _b("PaleFloorLongJoint",Vector3(0.003,0.002,105),Vector3(float(x),FY+0.011,MID),joint)
    var tactile := _material(Color("#c49634"),0.0,0.78)
    for side in [-1.0,1.0]:
        var x: float = CX+side*4.70
        _b("YellowTactilePaving",Vector3(0.18,0.012,105),Vector3(x,FY+0.006,MID),tactile)
        for row in [-0.055,0.0,0.055]:
            # Narrow raised rows retain the dotted character without thousands of meshes.
            for i in range(1050):
                _cylinder("TactileStud",0.012,0.006,Vector3(x+float(row),FY+0.015,Z0+float(i)*0.10),tactile)
        _b("PlatformEdgeCoping",Vector3(0.15,0.006,105),Vector3(CX+side*4.92,FY+0.003,MID),stairs)
    for z in [1.0,25.0,49.0,73.0]:
        _cylinder("AccessCoverRim",0.30,0.007,Vector3(CX+0.62,FY+0.013,float(z)),steel)
        _cylinder("AccessCoverLid",0.268,0.009,Vector3(CX+0.62,FY+0.018,float(z)),_material(Color("#8d9691"),0.58,0.5))
        _b("AccessCoverHandle",Vector3(0.16,0.007,0.022),Vector3(CX+0.62,FY+0.025,float(z)),dark)
    for z in [7.0,31.0,55.0,79.0]:
        _cylinder("RoundFloorDrain",0.088,0.008,Vector3(CX+0.72,FY+0.014,float(z)),dark)
        for j in range(5):
            _b("DrainGrille",Vector3(0.13,0.009,0.006),Vector3(CX+0.72,FY+0.019,float(z)-0.05+float(j)*0.025),steel)

func _walls() -> void:
    var seam := _material(Color("#97978b"),0.0,0.9)
    for side in [-1.0,1.0]:
        var x: float = CX+side*9.0
        _b("BlackWallFoot",Vector3(0.24,0.18,105),Vector3(x,0.08,MID),dark)
        _b("RedGraniteTrackPlinth",Vector3(0.20,1.20,105),Vector3(x,0.76,MID),brown)
        _b("MarbleBacking",Vector3(0.18,2.64,105),Vector3(x,2.68,MID),marble_tiles[0])
        # Individual slab faces retain genuine joints and small stone-to-stone differences.
        for row in range(4):
            for i in range(88):
                var za := Z0+float(i)*1.20
                var zb := minf(za+1.20,Z1)
                if zb<=za:continue
                _b("IndividualMarbleSlab",Vector3(0.012,0.656,zb-za-0.004),Vector3(x-side*0.098,1.69+float(row)*0.66,(za+zb)*0.5),marble_tiles[(i*7+row*3)%4])
        _b("UpperTrackPlaster",Vector3(0.22,1.62,105),Vector3(x,4.81,MID),white)
        _b("PlasterShadowJoint",Vector3(0.235,0.015,105),Vector3(x,4.02,MID),seam)
        _rod(Vector3(x-side*0.13,4.035,Z0),Vector3(x-side*0.13,4.035,Z1),0.013,dark)
        for i in range(55):
            _b("BlackCableSaddle",Vector3(0.045,0.065,0.028),Vector3(x-side*0.14,4.04,Z0+float(i)*1.95),dark)
        for z in [12.0,66.0]:
            _wall_name(side,x,float(z))
        for z in [35.0,82.0]:
            var asset: String = PLATFORM_ROUTES[int(side)]["wall"]
            _picture("MoscowLineWallDiagram",asset,Vector2(5.35,0.973),Vector3(x-side*0.145,2.73,float(z)),-side*PI/2.0,true)
        # Leave clear breaks around the two wall diagrams.
        for z in [-7.5,44.0]:
            _wall_ornament(side,x,float(z),8.3)
        _wall_ornament(side,x,88.7,6.5)

func _wall_name(side: float,x: float,z: float) -> void:
    var root := Node3D.new();root.name="RaisedBelarusianStationName"
    root.position=Vector3(x-side*0.15,2.96,z);root.rotation.y=-side*PI/2.0;add_child(root)
    var font: Font=preload("res://modules/stations/borisovsky_trakt/art_v69/station_name.ttf")
    var value := "БАРЫСАЎСКІ ТРАКТ"
    var nominal := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,100).x*0.006
    for layer in range(2):
        var mesh := TextMesh.new();mesh.font=font;mesh.text=value;mesh.font_size=100;mesh.pixel_size=0.006
        mesh.depth=0.055 if layer==0 else 0.023;mesh.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
        mesh.material=bronze if layer==0 else letter_face
        var node := MeshInstance3D.new();node.mesh=mesh;node.position.z=0.0 if layer==0 else 0.038
        node.scale=Vector3(7.9/maxf(nominal,0.01)*(1.023 if layer==0 else 1.0),1.025 if layer==0 else 1.0,1.0)
        root.add_child(node)
    _wall_ornament(side,x,z,9.7)

func _wall_ornament(side: float,x: float,z: float,length: float) -> void:
    # Photo 6726: straight, parallel polished strips; no stagger or bent-up tips.
    var face := x-side*0.15
    for j in range(3):
        var y := 2.43+float(j)*0.047
        var a := Vector3(face,y,z-length*0.5)
        var b := Vector3(face,y,z+length*0.5)
        _beam("InterruptedMetalWallBlade",a,b,0.028,0.023,steel)

func _profile(label: String, profile: Array[Vector2], z0: float,z1: float,mat: Material) -> void:
    var key := label+str(mat.get_instance_id())
    if not _profiles.has(key):
        var surface := SurfaceTool.new()
        surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        var double_mat := mat.duplicate() as StandardMaterial3D
        double_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        _profiles[key] = {"label":label,"surface":surface,"material":double_mat}
    var st: SurfaceTool = _profiles[key].surface
    for i in range(profile.size()-1):
        var a := profile[i]
        var b := profile[i+1]
        for v in [Vector3(a.x,a.y,z0),Vector3(b.x,b.y,z0),Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z0),Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z1)]: st.add_vertex(v)
    if profile.size()>3 and profile[0].is_equal_approx(profile[-1]):
        var polygon := PackedVector2Array(profile)
        polygon.resize(polygon.size()-1)
        var triangles := Geometry2D.triangulate_polygon(polygon)
        for k in range(0,triangles.size(),3):
            for j in [0,1,2]:
                var a := polygon[triangles[k+j]]
                st.add_vertex(Vector3(a.x,a.y,z0))
            for j in [2,1,0]:
                var a := polygon[triangles[k+j]]
                st.add_vertex(Vector3(a.x,a.y,z1))

func _ceiling() -> void:
    # Keep the rising west stair opening clear of the low platform roof.
    var finish := 84.8
    var length := finish-Z0
    var middle := (finish+Z0)*0.5
    _b("PlatformCeilingSlab",Vector3(10.1,0.16,length),Vector3(CX,5.73,middle),white)
    for side in [-1.0,1.0]:
        _b("OverTrackCeiling",Vector3(4.0,0.16,105),Vector3(CX+side*7.0,5.73,MID),white)
    # Flat central underside with rounded side returns, not a suspended half-pipe.
    var cornice: Array[Vector2]=[Vector2(CX-2.03,5.64)]
    for j in range(9):
        var a := PI-float(j)*PI/16.0
        cornice.append(Vector2(CX-1.70+0.33*cos(a),5.63-0.33*sin(a)))
    cornice.append(Vector2(CX+1.70,5.30))
    for j in range(9):
        var a := -PI/2.0+float(j)*PI/16.0
        cornice.append(Vector2(CX+1.70+0.33*cos(a),5.63+0.33*sin(a)))
    _profile("MaroonFlatSoffitRoundedFascias",cornice,Z0,finish,chocolate)
    var groove := _material(Color("#231a1d"),0.2,0.52)
    for i in range(820):
        var z := Z0+float(i)*0.12
        if z>finish:break
        _profile("CentralCeilingSlatGrooves",cornice,z,z+0.009,groove)
    for x in [CX-1.1,CX+1.1]:
        for i in range(32):
            var z := Z0+1.1+float(i)*3.0
            if z+1.10>finish:continue
            _b("CentralTubeHousing",Vector3(0.10,0.04,2.12),Vector3(float(x),5.267,z),steel)
            _b("LongitudinalFluorescentTube",Vector3(0.040,0.028,1.98),Vector3(float(x),5.237,z),glow)
    for side in [-1.0,1.0]:
        var edge: float = CX+side*4.8
        _b("WhiteGlobeCorniceBeam",Vector3(0.14,0.19,105),Vector3(edge,4.92,MID),white)
        for i in range(70):
            var z := -12.0+float(i)*1.5
            _instance("sphere","OpalGlobe",Transform3D(Basis.from_scale(Vector3(0.29,0.29,0.29)),Vector3(edge,5.08,z)),glow)
            _cylinder("GlobeMetalSocket",0.065,0.10,Vector3(edge,4.89,z),steel)
        for i in range(44):
            var z := Z0+float(i)*2.4
            var rib: Array[Vector2]=[Vector2(CX+side*2.02,5.65),Vector2(CX+side*4.15,5.65)]
            for j in range(10):
                var a := float(j)*PI/18.0
                rib.append(Vector2(CX+side*(4.15+0.65*sin(a)),5.0+0.65*cos(a)))
            if z<finish:_profile("WhiteCurvedPlatformCeilingRib",rib,z,minf(z+0.13,finish),white)
            _b("WhiteTrackTransverseBeam",Vector3(4.15,0.24,0.13),Vector3(CX+side*6.96,5.17,z),white)
        for i in range(11):
            var x: float = CX+side*(2.2+float(i)*0.20)
            _b("WhiteLongitudinalCeilingSlat",Vector3(0.009,0.012,length),Vector3(x,5.632,middle),steel)
    # Enclosed, higher stair hall: the stair flight now reaches visible space.
    _b("RaisedExitHallRoof",Vector3(7.8,0.16,14.3),Vector3(CX,8.12,91.95),white)
    _b("StairOpeningTransom",Vector3(7.8,0.25,0.16),Vector3(CX,7.96,85.0),white)
    for z in [88.0,91.0,94.0,97.0]:
        _b("StairHallTube",Vector3(5.6,0.045,0.06),Vector3(CX,8.0,float(z)),glow)

func _supports() -> void:
    for i in range(16):
        var z := -5.0+float(i)*6.0
        if z>82.0:continue
        if i%2==0:
            _cylinder("RoundMarbleColumn",0.43,3.57,Vector3(CX,3.075,z),stone)
            _cylinder("RoundColumnBlackFoot",0.445,0.23,Vector3(CX,FY+0.115,z),dark)
            _cylinder("ColumnSteelCapital",0.45,0.46,Vector3(CX,5.08,z),steel)
            _cylinder("WideCapitalTopPlate",0.64,0.035,Vector3(CX,5.294,z),dark)
            _cylinder("ColumnPolishedMetalBelt",0.447,0.26,Vector3(CX,2.12,z),steel)
            for y in [1.96,2.29]:
                _torus(Vector3(CX,float(y),z),0.575)
                for a in [0.0,PI/2.0,PI,PI*1.5]:
                    _rod(Vector3(CX+0.44*cos(float(a)),float(y),z+0.44*sin(float(a))),Vector3(CX+0.575*cos(float(a)),float(y),z+0.575*sin(float(a))),0.018,steel)
            var joint := _material(Color("#a09d8c"),0.0,0.8)
            for y in [2.66,3.32,3.98]:
                _cylinder("ColumnMarbleCourseJoint",0.431,0.003,Vector3(CX,float(y),z),joint)
        else:
            _b("WideMarblePierCore",Vector3(1.55,4.05,2.55),Vector3(CX,3.205,z),stone)
            _b("PierSteelHead",Vector3(1.60,0.87,2.62),Vector3(CX,4.77,z),steel)
            _b("PierBlackFoot",Vector3(1.61,0.18,2.62),Vector3(CX,FY+0.09,z),floor_dark)
            for y in [1.98,2.33]:
                _b("PierTwoDarkStoneBands",Vector3(1.575,0.16,2.58),Vector3(CX,float(y),z),floor_dark)
            for side in [-1,1]:
                _bench(CX+float(side)*1.105,z,side)
                _b("BenchLightCanopy",Vector3(0.75,0.09,2.88),Vector3(CX+float(side)*1.07,5.17,z),dark)
                for dz in [-0.88,0.0,0.88]:
                    var lamp := Vector3(CX+float(side)*1.03,5.115,z+float(dz))
                    _cylinder("CanopyRoundLampRim",0.14,0.03,lamp,steel)
                    _cylinder("CanopyRoundDiffuser",0.118,0.033,lamp-Vector3(0,0.012,0),glow)
    # Boards sit between column bays; none pass through marble supports.
    for z in [4.0,34.0,64.0]:
        for side in [-1.0,1.0]:
            var x: float = CX+side*2.55
            var file: String = PLATFORM_ROUTES[int(side)]["board"]
            var size := Vector2(3.45,0.712)
            _b("DirectionBoardSteelCase",Vector3(size.x+0.08,size.y+0.08,0.075),Vector3(x,4.30,float(z)),steel)
            for face in [-1.0,1.0]:
                _picture("BilingualDirectionBoard",file,size,Vector3(x,4.30,float(z)+face*0.043),0.0 if face>0.0 else PI)
            for dx in [-1.54,1.54]:
                _b("DirectionBoardHanger",Vector3(0.034,0.65,0.034),Vector3(x+float(dx),5.02,float(z)),steel)

func _bench(x: float,z: float,side: int) -> void:
    _b("BenchStonePlinth",Vector3(0.62,0.37,2.05),Vector3(x,FY+0.185,z),floor_dark)
    for i in range(32):
        var zz := z-1.01+float(i)*0.065
        # Bent wood slats: upright back, rounded shoulder, seat and rolled front.
        var section: Array[Vector2]=[]
        for uv in [Vector2(-0.28,0.45),Vector2(-0.28,0.97),Vector2(-0.25,1.01),Vector2(-0.20,0.99),Vector2(-0.19,0.94),Vector2(-0.19,0.55),Vector2(-0.14,0.49),Vector2(0.22,0.49),Vector2(0.30,0.46),Vector2(0.33,0.40),Vector2(0.31,0.33),Vector2(0.25,0.34),Vector2(0.24,0.40),Vector2(-0.20,0.40),Vector2(-0.28,0.45)]:
            section.append(Vector2(x+float(side)*uv.x,FY+uv.y))
        _profile("CurvedOakBenchSlats",section,zz,zz+0.052,wood)
    for zz in [z-1.06,z+1.06]:
        _b("BenchSteelEndCheek",Vector3(0.64,0.09,0.07),Vector3(x,FY+0.40,float(zz)),steel)
    # Photo 6720: a half-cylinder litter basket on the adjacent pier end.
    var bx := CX+float(side)*0.59
    var bz := z-1.37
    _cylinder("PierBinSteelShell",0.23,0.58,Vector3(bx,FY+0.94,bz),steel)
    _cylinder("PierBinDarkOpenTop",0.203,0.012,Vector3(bx,FY+1.235,bz),dark)

func _picture(label: String,file: String,size: Vector2,p: Vector3,yaw: float,transparent: bool=false) -> void:
    var mat := _material(Color.WHITE,0.0,0.8)
    mat.albedo_texture = load((ART if file.ends_with(".svg") else DIR)+file)
    mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if transparent: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    var quad := QuadMesh.new()
    quad.size = size
    var node := _mesh(label,quad,p,mat)
    node.rotation.y = yaw

func _ends() -> void:
    # Working west exit, broad granite flight with a distinct intermediate landing.
    var start := 85.0
    var landing := 1.24
    for i in range(30):
        var z := start+float(i)*0.31+(landing if i>=15 else 0.0)
        var height := float(i+1)*0.145
        _b("WestGraniteStep",Vector3(7.2,height,0.32),Vector3(-5.37,1.1805+height*0.5,z),stairs)
        if i in [0,14,29]:
            _b("YellowStairNosing",Vector3(7.2,0.025,0.05),Vector3(-5.37,1.20+height,z-0.14),_material(Color(0.95,0.68,0.08)))
    _b("IntermediateStairLanding",Vector3(7.2,0.16,landing),Vector3(-5.37,1.1805+15.0*0.145-0.08,start+14.5*0.31+landing*0.5),stairs)
    for x in [-9.12,-6.60,-1.62]:
        for offset in [0.72,1.06]:
            var y: float=1.1805+float(offset)
            var a := Vector3(x,y,start-0.2)
            var b := Vector3(x,y+2.175,start+14.5*0.31)
            var c := b+Vector3(0,0,landing)
            var d := Vector3(x,y+4.35,start+29.5*0.31+landing)
            _rod(a,b,0.025,steel)
            _rod(b,c,0.025,steel)
            _rod(c,d,0.025,steel)
            _rod(a-Vector3(0,0,0.4),a,0.025,steel)
        for i in range(9):
            var u := float(i)/8.0
            var z: float=start+u*(9.3+landing)
            var rise: float=clampf((z-start)/0.31,0.0,15.0)*0.145 if z<start+14.5*0.31 else 2.175 if z<start+14.5*0.31+landing else 2.175+(z-start-14.5*0.31-landing)*0.145/0.31
            _rod(Vector3(x,1.1805+rise,z),Vector3(x,2.2805+rise,z),0.026,steel)
    for side in [-1,1]:
        _b("StairSideMarble",Vector3(0.25,6.94,14.3),Vector3(-5.37+float(side)*3.8,4.65,91.95),stone)
        _b("StairSideRedGranite",Vector3(0.27,1.2,14.3),Vector3(-5.37+float(side)*3.8,1.78,91.95),brown)
    _picture("WestExitDestinations","exit.svg",Vector2(7.05,0.793),Vector3(-5.37,4.1,84.65),PI)
    _b("WestVestibuleFloor",Vector3(7.2,0.2,4),Vector3(-5.37,5.53,96.3),stairs)
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

    # Photo 6731: full-height reflecting mirror on a short metal pedestal.
    for side in [-1.0,1.0]:
        var direction := 1.0 if side>0.0 else -1.0
        var root := Node3D.new();root.name="DriverPlatformMirror"
        root.position=Vector3(CX+side*4.43,FY+1.36,82.4 if direction>0.0 else -9.0)
        root.rotation.y=(PI if direction>0.0 else 0.0)-side*0.13
        add_child(root)
        var backing := MeshInstance3D.new();var body := BoxMesh.new()
        body.size=Vector3(0.71,1.88,0.06);backing.mesh=body;backing.material_override=white;root.add_child(backing)
        var mirror := MeshInstance3D.new();mirror.name="ReflectingSurface"
        mirror.set_script(preload("res://modules/stations/borisovsky_trakt/driver_mirrors.gd"))
        var quad := QuadMesh.new();quad.size=Vector2(0.63,1.78);mirror.mesh=quad
        mirror.position.z=0.035;mirror.set_meta("mirror_size",quad.size);root.add_child(mirror)
        _cylinder("MirrorPedestal",0.075,0.44,root.position-Vector3(0,1.14,0),steel)
        _cylinder("MirrorRoundFoot",0.22,0.035,Vector3(root.position.x,FY+0.018,root.position.z),steel)

func _finish_details() -> void:
    var joint := _material(Color("#a5a294"),0.0,0.8)
    for i in range(16):
        if i%2==0:continue
        var z := -5.0+float(i)*6.0
        if z>82.0:continue
        for y in [2.66,3.32,3.98]:
            _b("PierMarbleHorizontalJoint",Vector3(1.56,0.003,2.56),Vector3(CX,float(y),z),joint)
        for side in [-1.0,1.0]:
            for dz in [-0.65,0.0,0.65]:
                _b("PierMarbleVerticalJoint",Vector3(0.008,2.78,0.004),Vector3(CX+side*0.78,3.10,z+float(dz)),joint)
            # Broad head plate drops at the ends as in 6720; no floating single cap.
            _b("DroppedPierSteelPanel",Vector3(0.025,0.90,0.80),Vector3(CX+side*0.785,3.91,z+0.84),steel)
    for side in [-1.0,1.0]:
        var x: float = CX+side*4.8
        for i in range(70):
            _b("GlobeFixturePlate",Vector3(0.16,0.16,0.025),Vector3(x,4.93,-12.0+float(i)*1.5),steel)
    for x in [-9.12,-6.60,-1.62]:
        _b("StairRailFootPlate",Vector3(0.16,0.018,0.18),Vector3(float(x),1.197,85.0),steel)
