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
    var line_work: RefCounted=_line_work()
    if line_work!=null: line_work.begin(self)
    if not await _line_checkpoint(): return
    super._ready()
    if not await _line_checkpoint(): return
    stone = _photo_stone("column_marble.jpg", Color.WHITE,0.28,Vector3(0.85,0.72,0.85))
    for i in range(4):
        if not await _line_checkpoint(): return
        var shade := 0.96+float(i)*0.015
        marble_tiles.append(_photo_stone("wall_marble.jpg" if i%2==0 else "wall_marble_alt.jpg",Color(shade,shade,shade),0.31,Vector3(0.75,1.2,0.75)))
    if not await _line_checkpoint(): return
    brown = _photo_stone("red_granite.jpg",Color.WHITE,0.38,Vector3(1.0,1.0,1.0))
    if not await _line_checkpoint(): return
    floor_dark = _photo_stone("floor_dark.jpg",Color.WHITE,0.24,Vector3(1.1,1.1,1.1))
    if not await _line_checkpoint(): return
    stairs = _photo_stone("stair_granite.jpg",Color.WHITE,0.55,Vector3(0.6,1.3,0.6))
    if not await _line_checkpoint(): return
    bronze = _material(Color("#514031"),0.74,0.32)
    if not await _line_checkpoint(): return
    letter_face = _material(Color("#baac91"),0.50,0.42)
    if not await _line_checkpoint(): return
    steel = _material(Color(0.58,0.61,0.62),0.85,0.24)
    if not await _line_checkpoint(): return
    white = _material(Color(0.81,0.81,0.76),0.15,0.65)
    if not await _line_checkpoint(): return
    dark = _material(Color(0.075,0.065,0.06),0.18,0.32)
    if not await _line_checkpoint(): return
    wood = _photo_stone("seat_oak.jpg",Color.WHITE,0.44,Vector3(1.5,1.5,1.5))
    if not await _line_checkpoint(): return
    chocolate = _material(Color("#493239"),0.42,0.36)
    if not await _line_checkpoint(): return
    glow = _material(Color(0.93,0.96,0.91))
    glow.emission_enabled = true
    if not await _line_checkpoint(): return
    glow.emission = Color(0.92,0.96,0.89)
    glow.emission_energy_multiplier = 1.6
    if not await _line_checkpoint(): return
    var floor_node := get_node("IslandPlatform") as MeshInstance3D
    if not await _line_checkpoint(): return
    floor_node.material_override = _photo_stone("floor_pale.jpg",Color.WHITE,0.38,Vector3(0.75,0.75,0.75))
    for label in ["SafetyEdgeTrack1","SafetyEdgeTrack2","TrainStopMarker"]:
        if not await _line_checkpoint(): return
        (get_node(label) as MeshInstance3D).hide()
    for child in get_children():
        if not await _line_checkpoint(): return
        if child is OmniLight3D:
            child.light_color = Color(1.0,0.98,0.92)
            child.light_energy = 1.35
            child.omni_range = 18.0
    if not await _line_checkpoint(): return
    await _floor_details()
    if not await _line_checkpoint(): return
    await _walls()
    if not await _line_checkpoint(): return
    await _ceiling()
    if not await _line_checkpoint(): return
    await _supports()
    if not await _line_checkpoint(): return
    await _ends()
    if not await _line_checkpoint(): return
    await _equipment()
    if not await _line_checkpoint(): return
    await _finish_details()
    if not await _line_checkpoint(): return
    await _flush_batches()
    if line_work!=null: line_work.finish(self)
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
    if not await _line_checkpoint(): return
    for key in _batches:
        if not await _line_checkpoint(): return
        var data: Dictionary = _batches[key]
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = data.mesh
        mm.instance_count = data.poses.size()
        for i in range(mm.instance_count):
            if not await _line_checkpoint(): return
            mm.set_instance_transform(i,data.poses[i])
        var node := MultiMeshInstance3D.new()
        node.name = str(data.label)+"Instances"
        node.multimesh = mm
        add_child(node)
    _batches.clear()
    for key in _profiles:
        if not await _line_checkpoint(): return
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
    if not await _line_checkpoint(): return
    # Video 181/331: one broad polished central ribbon, pale circulation lanes.
    _b("CentralDarkGraniteField",Vector3(3.35,0.008,105),Vector3(CX,FY+0.004,MID),floor_dark)
    var joint := _material(Color("#797b73"),0.0,0.8)
    for i in range(89):
        if not await _line_checkpoint(): return
        var z := Z0+float(i)*1.20
        _b("FloorTileJoint",Vector3(9.96,0.002,0.003),Vector3(CX,FY+0.011,z),joint)
    for x in [-9.12,-7.71,-3.03,-1.62]:
        if not await _line_checkpoint(): return
        _b("PaleFloorLongJoint",Vector3(0.003,0.002,105),Vector3(float(x),FY+0.011,MID),joint)
    var tactile := _material(Color("#c49634"),0.0,0.78)
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        var x: float = CX+side*4.70
        _b("YellowTactilePaving",Vector3(0.18,0.012,105),Vector3(x,FY+0.006,MID),tactile)
        for row in [-0.055,0.0,0.055]:
            if not await _line_checkpoint(): return
            # Narrow raised rows retain the dotted character without thousands of meshes.
            for i in range(1050):
                if not await _line_checkpoint(): return
                _cylinder("TactileStud",0.012,0.006,Vector3(x+float(row),FY+0.015,Z0+float(i)*0.10),tactile)
        _b("PlatformEdgeCoping",Vector3(0.15,0.006,105),Vector3(CX+side*4.92,FY+0.003,MID),stairs)
    for z in [1.0,25.0,49.0,73.0]:
        if not await _line_checkpoint(): return
        _cylinder("AccessCoverRim",0.30,0.007,Vector3(CX+0.62,FY+0.013,float(z)),steel)
        _cylinder("AccessCoverLid",0.268,0.009,Vector3(CX+0.62,FY+0.018,float(z)),_material(Color("#8d9691"),0.58,0.5))
        _b("AccessCoverHandle",Vector3(0.16,0.007,0.022),Vector3(CX+0.62,FY+0.025,float(z)),dark)
    for z in [7.0,31.0,55.0,79.0]:
        if not await _line_checkpoint(): return
        _cylinder("RoundFloorDrain",0.088,0.008,Vector3(CX+0.72,FY+0.014,float(z)),dark)
        for j in range(5):
            if not await _line_checkpoint(): return
            _b("DrainGrille",Vector3(0.13,0.009,0.006),Vector3(CX+0.72,FY+0.019,float(z)-0.05+float(j)*0.025),steel)

func _walls() -> void:
    if not await _line_checkpoint(): return
    var seam := _material(Color("#97978b"),0.0,0.9)
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        var x: float = CX+side*9.0
        _b("BlackWallFoot",Vector3(0.24,0.18,105),Vector3(x,0.08,MID),dark)
        _b("RedGraniteTrackPlinth",Vector3(0.20,1.20,105),Vector3(x,0.76,MID),brown)
        _b("MarbleBacking",Vector3(0.18,2.64,105),Vector3(x,2.68,MID),marble_tiles[0])
        # Individual slab faces retain genuine joints and small stone-to-stone differences.
        for row in range(4):
            if not await _line_checkpoint(): return
            for i in range(88):
                if not await _line_checkpoint(): return
                var za := Z0+float(i)*1.20
                var zb := minf(za+1.20,Z1)
                if zb<=za:continue
                _b("IndividualMarbleSlab",Vector3(0.012,0.656,zb-za-0.004),Vector3(x-side*0.098,1.69+float(row)*0.66,(za+zb)*0.5),marble_tiles[(i*7+row*3)%4])
        _b("UpperTrackPlaster",Vector3(0.22,1.62,105),Vector3(x,4.81,MID),white)
        _b("PlasterShadowJoint",Vector3(0.235,0.015,105),Vector3(x,4.02,MID),seam)
        _rod(Vector3(x-side*0.13,4.035,Z0),Vector3(x-side*0.13,4.035,Z1),0.013,dark)
        for i in range(55):
            if not await _line_checkpoint(): return
            _b("BlackCableSaddle",Vector3(0.045,0.065,0.028),Vector3(x-side*0.14,4.04,Z0+float(i)*1.95),dark)
        for z in [12.0,66.0]:
            if not await _line_checkpoint(): return
            await _wall_name(side,x,float(z))
        for z in [35.0,82.0]:
            if not await _line_checkpoint(): return
            var asset: String = PLATFORM_ROUTES[int(side)]["wall"]
            _picture("MoscowLineWallDiagram",asset,Vector2(5.35,0.973),Vector3(x-side*0.145,2.73,float(z)),-side*PI/2.0,true)
        # Leave clear breaks around the two wall diagrams.
        for z in [-7.5,44.0]:
            if not await _line_checkpoint(): return
            await _wall_ornament(side,x,float(z),8.3)
        await _wall_ornament(side,x,88.7,6.5)

func _wall_name(side: float,x: float,z: float) -> void:
    if not await _line_checkpoint(): return
    var root := Node3D.new();root.name="RaisedBelarusianStationName"
    root.position=Vector3(x-side*0.15,2.96,z);root.rotation.y=-side*PI/2.0;add_child(root)
    var font: Font=preload("res://modules/stations/borisovsky_trakt/art_v69/station_name.ttf")
    var value := "БАРЫСАЎСКІ ТРАКТ"
    var nominal := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,100).x*0.006
    for layer in range(2):
        if not await _line_checkpoint(): return
        var mesh := TextMesh.new();mesh.font=font;mesh.text=value;mesh.font_size=100;mesh.pixel_size=0.006
        mesh.depth=0.055 if layer==0 else 0.023;mesh.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
        mesh.material=bronze if layer==0 else letter_face
        var node := MeshInstance3D.new();node.mesh=mesh;node.position.z=0.0 if layer==0 else 0.038
        node.scale=Vector3(7.9/maxf(nominal,0.01)*(1.023 if layer==0 else 1.0),1.025 if layer==0 else 1.0,1.0)
        root.add_child(node)
    await _wall_ornament(side,x,z,9.7)

func _wall_ornament(side: float,x: float,z: float,length: float) -> void:
    if not await _line_checkpoint(): return
    # Photo 6726: straight, parallel polished strips; no stagger or bent-up tips.
    var face := x-side*0.15
    for j in range(3):
        if not await _line_checkpoint(): return
        var y := 2.43+float(j)*0.047
        var a := Vector3(face,y,z-length*0.5)
        var b := Vector3(face,y,z+length*0.5)
        _beam("InterruptedMetalWallBlade",a,b,0.028,0.023,steel)

func _profile(label: String, profile: Array[Vector2], z0: float,z1: float,mat: Material) -> void:
    if not await _line_checkpoint(): return
    var key := label+str(mat.get_instance_id())
    if not _profiles.has(key):
        var surface := SurfaceTool.new()
        surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        var double_mat := mat.duplicate() as StandardMaterial3D
        double_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        _profiles[key] = {"label":label,"surface":surface,"material":double_mat}
    var st: SurfaceTool = _profiles[key].surface
    for i in range(profile.size()-1):
        if not await _line_checkpoint(): return
        var a := profile[i]
        var b := profile[i+1]
        for v in [Vector3(a.x,a.y,z0),Vector3(b.x,b.y,z0),Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z0),Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z1)]:
            if not await _line_checkpoint(): return
            st.add_vertex(v)
    if profile.size()>3 and profile[0].is_equal_approx(profile[-1]):
        var polygon := PackedVector2Array(profile)
        polygon.resize(polygon.size()-1)
        var triangles := Geometry2D.triangulate_polygon(polygon)
        for k in range(0,triangles.size(),3):
            if not await _line_checkpoint(): return
            for j in [0,1,2]:
                if not await _line_checkpoint(): return
                var a := polygon[triangles[k+j]]
                st.add_vertex(Vector3(a.x,a.y,z0))
            for j in [2,1,0]:
                if not await _line_checkpoint(): return
                var a := polygon[triangles[k+j]]
                st.add_vertex(Vector3(a.x,a.y,z1))

func _ceiling() -> void:
    if not await _line_checkpoint(): return
    # Keep the rising west stair opening clear of the low platform roof.
    var finish := 84.8
    var length := finish-Z0
    var middle := (finish+Z0)*0.5
    _b("PlatformCeilingSlab",Vector3(10.1,0.16,length),Vector3(CX,5.73,middle),white)
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        _b("OverTrackCeiling",Vector3(4.0,0.16,105),Vector3(CX+side*7.0,5.73,MID),white)
    # Flat central underside with rounded side returns, not a suspended half-pipe.
    var cornice: Array[Vector2]=[Vector2(CX-2.03,5.64)]
    for j in range(9):
        if not await _line_checkpoint(): return
        var a := PI-float(j)*PI/16.0
        cornice.append(Vector2(CX-1.70+0.33*cos(a),5.63-0.33*sin(a)))
    cornice.append(Vector2(CX+1.70,5.30))
    for j in range(9):
        if not await _line_checkpoint(): return
        var a := -PI/2.0+float(j)*PI/16.0
        cornice.append(Vector2(CX+1.70+0.33*cos(a),5.63+0.33*sin(a)))
    await _profile("MaroonFlatSoffitRoundedFascias",cornice,Z0,finish,chocolate)
    var groove := _material(Color("#231a1d"),0.2,0.52)
    for i in range(820):
        if not await _line_checkpoint(): return
        var z := Z0+float(i)*0.12
        if z>finish:break
        await _profile("CentralCeilingSlatGrooves",cornice,z,z+0.009,groove)
    for x in [CX-1.1,CX+1.1]:
        if not await _line_checkpoint(): return
        for i in range(32):
            if not await _line_checkpoint(): return
            var z := Z0+1.1+float(i)*3.0
            if z+1.10>finish:continue
            _b("CentralTubeHousing",Vector3(0.10,0.04,2.12),Vector3(float(x),5.267,z),steel)
            _b("LongitudinalFluorescentTube",Vector3(0.040,0.028,1.98),Vector3(float(x),5.237,z),glow)
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        var edge: float = CX+side*4.8
        _b("WhiteGlobeCorniceBeam",Vector3(0.14,0.19,105),Vector3(edge,4.92,MID),white)
        for i in range(70):
            if not await _line_checkpoint(): return
            var z := -12.0+float(i)*1.5
            _instance("sphere","OpalGlobe",Transform3D(Basis.from_scale(Vector3(0.29,0.29,0.29)),Vector3(edge,5.08,z)),glow)
            _cylinder("GlobeMetalSocket",0.065,0.10,Vector3(edge,4.89,z),steel)
        for i in range(44):
            if not await _line_checkpoint(): return
            var z := Z0+float(i)*2.4
            var rib: Array[Vector2]=[Vector2(CX+side*2.02,5.65),Vector2(CX+side*4.15,5.65)]
            for j in range(10):
                if not await _line_checkpoint(): return
                var a := float(j)*PI/18.0
                rib.append(Vector2(CX+side*(4.15+0.65*sin(a)),5.0+0.65*cos(a)))
            if z<finish:await _profile("WhiteCurvedPlatformCeilingRib",rib,z,minf(z+0.13,finish),white)
            _b("WhiteTrackTransverseBeam",Vector3(4.15,0.24,0.13),Vector3(CX+side*6.96,5.17,z),white)
        for i in range(11):
            if not await _line_checkpoint(): return
            var x: float = CX+side*(2.2+float(i)*0.20)
            _b("WhiteLongitudinalCeilingSlat",Vector3(0.009,0.012,length),Vector3(x,5.632,middle),steel)
    # Enclosed, higher stair hall: the stair flight now reaches visible space.
    _b("RaisedExitHallRoof",Vector3(7.8,0.16,14.3),Vector3(CX,8.12,91.95),white)
    _b("StairOpeningTransom",Vector3(7.8,0.25,0.16),Vector3(CX,7.96,85.0),white)
    for z in [88.0,91.0,94.0,97.0]:
        if not await _line_checkpoint(): return
        _b("StairHallTube",Vector3(5.6,0.045,0.06),Vector3(CX,8.0,float(z)),glow)

func _supports() -> void:
    if not await _line_checkpoint(): return
    for i in range(16):
        if not await _line_checkpoint(): return
        var z := -5.0+float(i)*6.0
        if z>82.0:continue
        if i%2==0:
            _cylinder("RoundMarbleColumn",0.43,3.57,Vector3(CX,3.075,z),stone)
            _cylinder("RoundColumnBlackFoot",0.445,0.23,Vector3(CX,FY+0.115,z),dark)
            _cylinder("ColumnSteelCapital",0.45,0.46,Vector3(CX,5.08,z),steel)
            _cylinder("WideCapitalTopPlate",0.64,0.035,Vector3(CX,5.294,z),dark)
            _cylinder("ColumnPolishedMetalBelt",0.447,0.26,Vector3(CX,2.12,z),steel)
            for y in [1.96,2.29]:
                if not await _line_checkpoint(): return
                _torus(Vector3(CX,float(y),z),0.575)
                for a in [0.0,PI/2.0,PI,PI*1.5]:
                    if not await _line_checkpoint(): return
                    _rod(Vector3(CX+0.44*cos(float(a)),float(y),z+0.44*sin(float(a))),Vector3(CX+0.575*cos(float(a)),float(y),z+0.575*sin(float(a))),0.018,steel)
            var joint := _material(Color("#a09d8c"),0.0,0.8)
            for y in [2.66,3.32,3.98]:
                if not await _line_checkpoint(): return
                _cylinder("ColumnMarbleCourseJoint",0.431,0.003,Vector3(CX,float(y),z),joint)
        else:
            _b("WideMarblePierCore",Vector3(1.55,4.05,2.55),Vector3(CX,3.205,z),stone)
            _b("PierSteelHead",Vector3(1.60,0.87,2.62),Vector3(CX,4.77,z),steel)
            _b("PierBlackFoot",Vector3(1.61,0.18,2.62),Vector3(CX,FY+0.09,z),floor_dark)
            for y in [1.98,2.33]:
                if not await _line_checkpoint(): return
                _b("PierTwoDarkStoneBands",Vector3(1.575,0.16,2.58),Vector3(CX,float(y),z),floor_dark)
            for side in [-1,1]:
                if not await _line_checkpoint(): return
                await _bench(CX+float(side)*1.105,z,side)
                _b("BenchLightCanopy",Vector3(0.75,0.09,2.88),Vector3(CX+float(side)*1.07,5.17,z),dark)
                for dz in [-0.88,0.0,0.88]:
                    if not await _line_checkpoint(): return
                    var lamp := Vector3(CX+float(side)*1.03,5.115,z+float(dz))
                    _cylinder("CanopyRoundLampRim",0.14,0.03,lamp,steel)
                    _cylinder("CanopyRoundDiffuser",0.118,0.033,lamp-Vector3(0,0.012,0),glow)
    # Boards sit between column bays; none pass through marble supports.
    for z in [4.0,34.0,64.0]:
        if not await _line_checkpoint(): return
        for side in [-1.0,1.0]:
            if not await _line_checkpoint(): return
            var x: float = CX+side*2.55
            var file: String = PLATFORM_ROUTES[int(side)]["board"]
            var size := Vector2(3.45,0.712)
            _b("DirectionBoardSteelCase",Vector3(size.x+0.08,size.y+0.08,0.075),Vector3(x,4.30,float(z)),steel)
            for face in [-1.0,1.0]:
                if not await _line_checkpoint(): return
                _picture("BilingualDirectionBoard",file,size,Vector3(x,4.30,float(z)+face*0.043),0.0 if face>0.0 else PI)
            for dx in [-1.54,1.54]:
                if not await _line_checkpoint(): return
                _b("DirectionBoardHanger",Vector3(0.034,0.65,0.034),Vector3(x+float(dx),5.02,float(z)),steel)

func _bench(x: float,z: float,side: int) -> void:
    if not await _line_checkpoint(): return
    _b("BenchStonePlinth",Vector3(0.62,0.37,2.05),Vector3(x,FY+0.185,z),floor_dark)
    for i in range(32):
        if not await _line_checkpoint(): return
        var zz := z-1.01+float(i)*0.065
        # Bent wood slats: upright back, rounded shoulder, seat and rolled front.
        var section: Array[Vector2]=[]
        for uv in [Vector2(-0.28,0.45),Vector2(-0.28,0.97),Vector2(-0.25,1.01),Vector2(-0.20,0.99),Vector2(-0.19,0.94),Vector2(-0.19,0.55),Vector2(-0.14,0.49),Vector2(0.22,0.49),Vector2(0.30,0.46),Vector2(0.33,0.40),Vector2(0.31,0.33),Vector2(0.25,0.34),Vector2(0.24,0.40),Vector2(-0.20,0.40),Vector2(-0.28,0.45)]:
            if not await _line_checkpoint(): return
            section.append(Vector2(x+float(side)*uv.x,FY+uv.y))
        await _profile("CurvedOakBenchSlats",section,zz,zz+0.052,wood)
    for zz in [z-1.06,z+1.06]:
        if not await _line_checkpoint(): return
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
    if not await _line_checkpoint(): return
    # Working west exit, broad granite flight with a distinct intermediate landing.
    var start := 85.0
    var landing := 1.24
    for i in range(30):
        if not await _line_checkpoint(): return
        var z := start+float(i)*0.31+(landing if i>=15 else 0.0)
        var height := float(i+1)*0.145
        _b("WestGraniteStep",Vector3(7.2,height,0.32),Vector3(-5.37,1.1805+height*0.5,z),stairs)
        if i in [0,14,29]:
            _b("YellowStairNosing",Vector3(7.2,0.025,0.05),Vector3(-5.37,1.20+height,z-0.14),_material(Color(0.95,0.68,0.08)))
    _b("IntermediateStairLanding",Vector3(7.2,0.16,landing),Vector3(-5.37,1.1805+15.0*0.145-0.08,start+14.5*0.31+landing*0.5),stairs)
    await _west_stair_railings(start,landing)
    _picture("WestExitDestinations","exit.svg",Vector2(7.05,0.793),Vector3(CX,4.1,84.65),PI)
    await _west_exit_control_area(start+29.0*0.31+landing)
    await _closed_east_screen()
    for x in [0.992,-11.732]:
        if not await _line_checkpoint(): return
        for z in [-16.9,96.1]:
            if not await _line_checkpoint(): return
            _b("ShortTunnelRoof",Vector3(4.6,0.3,8),Vector3(x,4.05,z),dark)
            for side in [-1,1]:
                if not await _line_checkpoint(): return
                _b("ShortTunnelSide",Vector3(0.25,4.3,8),Vector3(x+float(side)*2.3,1.9,z),dark)
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
    if not await _line_checkpoint(): return
    for z in [2.0,32.0,62.0,81.0]:
        if not await _line_checkpoint(): return
        for x in [-8.0,-2.74]:
            if not await _line_checkpoint(): return
            _b("PublicAddressSpeaker",Vector3(0.15,0.29,0.18),Vector3(x,5.15,z),steel)
            _b("SpeakerFace",Vector3(0.12,0.24,0.02),Vector3(x,5.15,z-0.1),dark)
    for x in [-9.5,-1.25]:
        if not await _line_checkpoint(): return
        _b("CCTVBody",Vector3(0.16,0.15,0.35),Vector3(x,4.26,83.2),white)
        _b("CCTVBracket",Vector3(0.04,0.3,0.04),Vector3(x,4.45,83.3),steel)
    await _information_monitors()
    for x in [-9.1,-1.65]:
        if not await _line_checkpoint(): return
        _b("EmergencyCallPanel",Vector3(0.24,0.45,0.05),Vector3(x,2.27,84.0),_material(Color(0.95,0.77,0.12)))
        _b("SOSButton",Vector3(0.08,0.10,0.065),Vector3(x,2.27,83.97),_material(Color(0.75,0.08,0.04)))

    # Photo 6731: full-height reflecting mirror on a short metal pedestal.
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
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
    if not await _line_checkpoint(): return
    var joint := _material(Color("#a5a294"),0.0,0.8)
    for i in range(16):
        if not await _line_checkpoint(): return
        if i%2==0:continue
        var z := -5.0+float(i)*6.0
        if z>82.0:continue
        for y in [2.66,3.32,3.98]:
            if not await _line_checkpoint(): return
            _b("PierMarbleHorizontalJoint",Vector3(1.56,0.003,2.56),Vector3(CX,float(y),z),joint)
        for side in [-1.0,1.0]:
            if not await _line_checkpoint(): return
            for dz in [-0.65,0.0,0.65]:
                if not await _line_checkpoint(): return
                _b("PierMarbleVerticalJoint",Vector3(0.008,2.78,0.004),Vector3(CX+side*0.78,3.10,z+float(dz)),joint)
            # Broad head plate drops at the ends as in 6720; no floating single cap.
            _b("DroppedPierSteelPanel",Vector3(0.025,0.90,0.80),Vector3(CX+side*0.785,3.91,z+0.84),steel)
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        var x: float = CX+side*4.8
        for i in range(70):
            if not await _line_checkpoint(): return
            _b("GlobeFixturePlate",Vector3(0.16,0.16,0.025),Vector3(x,4.93,-12.0+float(i)*1.5),steel)

func _information_monitors() -> void:
    if not await _line_checkpoint(): return
    # Reuse the existing local artwork: static illuminated ads on both faces.
    # Two rods, a mounting plate, fixings and a rear crossmember form a continuous
    # connection from each monitor case to the actual side ceiling at y=5.65.
    for i in range(2):
        if not await _line_checkpoint(): return
        var z := 22.0+float(i)*36.0
        var p := Vector3(-2.5,4.1,z)
        _b("InformationMonitor",Vector3(1.2,0.7,0.12),p,dark)
        _b("MonitorMountCrossmember",Vector3(0.94,0.05,0.09),p+Vector3(0,0.32,0),steel)
        for dx in [-0.42,0.42]:
            if not await _line_checkpoint(): return
            var x: float=p.x+float(dx)
            _rod(Vector3(x,4.40,z),Vector3(x,5.63,z),0.019,steel)
            _b("MonitorCeilingPlate",Vector3(0.16,0.035,0.18),Vector3(x,5.64,z),steel)
            for dz in [-0.055,0.055]:
                if not await _line_checkpoint(): return
                _cylinder("MonitorMountBolt",0.013,0.012,Vector3(x,5.618,z+float(dz)),dark)
            _b("MonitorCaseClamp",Vector3(0.09,0.10,0.14),Vector3(x,4.43,z),steel)
        # The cable is visibly secured alongside the suspension, not floating.
        _rod(Vector3(p.x+0.445,4.42,z+0.025),Vector3(p.x+0.445,5.62,z+0.025),0.006,dark)
        for face in [-1.0,1.0]:
            if not await _line_checkpoint(): return
            _picture("StaticAdvertisingScreen","ad_%d.svg" % i,Vector2(1.10,1.10*680.0/1200.0),p+Vector3(0,0,face*0.062),0.0 if face>0.0 else PI)

func _stair_tread_height(z: float,start: float,landing: float) -> float:
    var first_end := start+14.5*0.31
    if z<first_end:
        return FY+clampf(floorf((z-start+0.155)/0.31)+1.0,1.0,15.0)*0.145
    if z<first_end+landing:return FY+15.0*0.145
    return FY+clampf(floorf((z-start-landing+0.155)/0.31)+1.0,16.0,30.0)*0.145

func _west_stair_railings(start: float,landing: float) -> void:
    if not await _line_checkpoint(): return
    # Open stainless balustrades replace both tall solid side walls. Posts sit
    # on the actual treads; the upper side guards continue along the landing.
    var first_end := start+14.5*0.31
    var second_start := first_end+landing
    var top := start+29.5*0.31+landing
    for index in range(3):
        if not await _line_checkpoint(): return
        var x: float=[CX-3.42,-6.60,CX+3.42][index]
        var path: Array[Vector2]=[
            Vector2(start-0.155,FY+0.145),
            Vector2(first_end,FY+2.175),
            Vector2(second_start,FY+2.175),
            Vector2(top,FY+4.35)
        ]
        if index!=1:path.append(Vector2(98.90,FY+4.35))
        for segment in range(path.size()-1):
            if not await _line_checkpoint(): return
            var a: Vector2=path[segment]
            var b: Vector2=path[segment+1]
            for height in [0.18,0.64,1.10]:
                if not await _line_checkpoint(): return
                _rod(Vector3(x,a.y+float(height),a.x),Vector3(x,b.y+float(height),b.x),0.025 if height==1.10 else 0.018,steel)
            var count := maxi(1,ceili((b.x-a.x)/0.72))
            for j in range(count):
                if not await _line_checkpoint(): return
                var t := float(j)/float(count)
                var z := lerpf(a.x,b.x,t)
                var y := _stair_tread_height(z,start,landing)
                var rail_y := lerpf(a.y,b.y,t)+1.10
                _rod(Vector3(x,y,z),Vector3(x,rail_y,z),0.022,steel)
                _b("StairRailFootPlate",Vector3(0.13,0.014,0.14),Vector3(x,y+0.007,z),steel)
        var end: Vector2=path[-1]
        _rod(Vector3(x,end.y,end.x),Vector3(x,end.y+1.10,end.x),0.022,steel)
        _b("StairTopPostFoot",Vector3(0.13,0.014,0.14),Vector3(x,end.y+0.007,end.x),steel)

func _west_exit_control_area(top_step_z: float) -> void:
    if not await _line_checkpoint(): return
    var floor_y := FY+4.35
    # The landing starts flush with the final tread and ends under the existing
    # high exit roof. Furniture remains behind the stair approach.
    var length := 3.80
    _b("WestVestibuleFloor",Vector3(7.2,0.20,length),Vector3(CX,floor_y-0.10,top_step_z+length*0.5),stairs)
    _b("WestVestibuleBack",Vector3(7.5,2.42,0.16),Vector3(CX,floor_y+1.21,99.0),stone)
    var reader := _material(Color("#18252c"),0.28,0.28)
    var indicator := _material(Color("#46c892"),0.0,0.65)
    indicator.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    # Six cabinets form five visible lanes to the left of the attendant cabin.
    for i in range(6):
        if not await _line_checkpoint(): return
        var x := CX-3.05+float(i)*0.90
        var z := 97.05
        _b("TurnstileFoot",Vector3(0.29,0.055,1.12),Vector3(x,floor_y+0.0275,z),dark)
        _b("TurnstileCabinet",Vector3(0.22,0.94,1.08),Vector3(x,floor_y+0.525,z),steel)
        _b("TurnstileTop",Vector3(0.26,0.06,1.12),Vector3(x,floor_y+1.025,z),steel)
        _b("FareCardReader",Vector3(0.17,0.035,0.25),Vector3(x,floor_y+1.072,z-0.29),reader)
        _b("TurnstileLaneIndicator",Vector3(0.08,0.035,0.016),Vector3(x,floor_y+0.89,z-0.549),indicator)
        if i<5:
            var pivot := Vector3(x+0.15,floor_y+0.73,z)
            _b("TurnstileRotor",Vector3(0.12,0.16,0.16),pivot,steel)
            for arm in range(3):
                if not await _line_checkpoint(): return
                var angle := float(arm)*TAU/3.0
                _rod(pivot,pivot+Vector3(0.60,0.23*sin(angle),0.23*cos(angle)),0.022,steel)
    # A glazed booth with a solid lower panel, metal mullions and an interior
    # desk is visible above the stairs rather than hidden behind a high wall.
    var bx := CX+2.55
    var front := 96.48
    var back := 98.23
    var shell := _material(Color("#788b89"),0.38,0.48)
    var frame := _material(Color("#4a6061"),0.62,0.31)
    var glass := _material(Color(0.40,0.57,0.58,0.24),0.05,0.17)
    glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    _b("ControlBoothLowerFront",Vector3(1.60,0.90,0.07),Vector3(bx,floor_y+0.45,front),shell)
    _b("ControlBoothCounter",Vector3(1.64,0.07,0.25),Vector3(bx,floor_y+0.94,front+0.06),steel)
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        var x: float=bx+side*0.80
        _b("ControlBoothLowerSide",Vector3(0.07,0.90,back-front),Vector3(x,floor_y+0.45,(front+back)*0.5),shell)
        _b("ControlBoothSideGlass",Vector3(0.025,1.19,back-front-0.08),Vector3(x,floor_y+1.545,(front+back)*0.5),glass)
        for z in [front,back]:
            if not await _line_checkpoint(): return
            _b("ControlBoothCornerPost",Vector3(0.06,2.20,0.06),Vector3(x,floor_y+1.10,float(z)),frame)
    for dx in [-0.41,0.41]:
        if not await _line_checkpoint(): return
        _b("ControlBoothFrontGlass",Vector3(0.75,1.19,0.025),Vector3(bx+float(dx),floor_y+1.545,front),glass)
    _b("ControlBoothFrontMullion",Vector3(0.045,1.24,0.06),Vector3(bx,floor_y+1.55,front),frame)
    _b("ControlBoothHeader",Vector3(1.65,0.095,0.08),Vector3(bx,floor_y+2.18,front),frame)
    _b("ControlBoothRoof",Vector3(1.76,0.09,1.91),Vector3(bx,floor_y+2.245,(front+back)*0.5),shell)
    _b("ControlBoothRearPanel",Vector3(1.60,2.12,0.07),Vector3(bx,floor_y+1.06,back),shell)
    _b("ControlBoothDesk",Vector3(1.24,0.055,0.48),Vector3(bx,floor_y+0.82,front+0.43),wood)
    _b("ControlBoothConsole",Vector3(0.34,0.25,0.055),Vector3(bx+0.27,floor_y+1.01,front+0.43),dark)
    _b("ControlBoothConsoleScreen",Vector3(0.29,0.20,0.01),Vector3(bx+0.27,floor_y+1.01,front+0.398),reader)


func _gypsum_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
render_mode cull_disabled;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash_p(vec3 q){return fract(sin(dot(q,vec3(127.1,311.7,74.7)))*43758.5453);}
float cloud(vec3 q){
    vec3 i=floor(q),f=fract(q);f=f*f*(3.0-2.0*f);
    float a=mix(mix(hash_p(i),hash_p(i+vec3(1,0,0)),f.x),mix(hash_p(i+vec3(0,1,0)),hash_p(i+vec3(1,1,0)),f.x),f.y);
    float b=mix(mix(hash_p(i+vec3(0,0,1)),hash_p(i+vec3(1,0,1)),f.x),mix(hash_p(i+vec3(0,1,1)),hash_p(i+vec3(1,1,1)),f.x),f.y);
    return mix(a,b,f.z);
}
void fragment(){
    float coating=cloud(p*3.8);
    float grain=hash_p(floor(p*175.0));
    ALBEDO=mix(vec3(0.86,0.87,0.84),vec3(0.92,0.925,0.90),coating)+vec3((grain-0.5)*0.008);
    ROUGHNESS=0.88+grain*0.06;SPECULAR=0.22;
}
"""
    var mat := ShaderMaterial.new()
    mat.shader=shader
    return mat

func _screen_collision(node: MeshInstance3D,size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.name="SolidPartition"
    var shape := BoxShape3D.new()
    shape.size=size
    var collider := CollisionShape3D.new()
    collider.shape=shape
    body.add_child(collider)
    node.add_child(body)

func _screen_wall(label: String,size: Vector3,p: Vector3,mat: Material) -> void:
    var mesh := BoxMesh.new()
    mesh.size=size
    var node := _mesh(label,mesh,p,mat)
    _screen_collision(node,size)

func _closed_east_screen() -> void:
    if not await _line_checkpoint(): return
    var gypsum := _gypsum_material()
    var joint := _material(Color("#ced0c8"),0.0,0.95)
    var cap := _material(Color("#daddd5"),0.10,0.67)
    # A solid end wall fills the whole platform width and meets both the floor
    # and the existing ceiling. Returns close the sides behind the curved face.
    # There is no opening into the unmodelled space, even beside the screen.
    var height := 4.65
    var y := FY-0.02+height*0.5
    _screen_wall("ClosedVestibuleRearWall",Vector3(10.0,height,0.35),Vector3(CX,y,Z0-0.155),gypsum)
    var room_front := -10.50
    var room_back := Z0-0.30
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        _screen_wall("ClosedVestibuleSideReturn",Vector3(0.12,height,room_front-room_back),Vector3(CX+side*4.94,y,(room_front+room_back)*0.5),gypsum)
    var screen: Array[Vector2]=[]
    for i in range(21):
        if not await _line_checkpoint(): return
        var angle := PI*float(i)/20.0
        screen.append(Vector2(CX+3.4*cos(angle),-10.7-1.6*sin(angle)))
    for i in range(screen.size()-1):
        if not await _line_checkpoint(): return
        var a: Vector2=screen[i]
        var b: Vector2=screen[i+1]
        var mesh := BoxMesh.new()
        mesh.size=Vector3(a.distance_to(b)+0.010,3.10,0.14)
        var node := _mesh("PaintedGypsumScreenPanel",mesh,Vector3((a.x+b.x)*0.5,FY+1.55,(a.y+b.y)*0.5),gypsum)
        node.rotation.y=-atan2(b.y-a.y,b.x-a.x)
        _screen_collision(node,mesh.size)
        _beam("GypsumScreenTopCap",Vector3(a.x,FY+3.11,a.y),Vector3(b.x,FY+3.11,b.y),0.16,0.025,cap)
        _beam("GypsumScreenSkirting",Vector3(a.x,FY+0.04,a.y),Vector3(b.x,FY+0.04,b.y),0.16,0.08,cap)
        if i>0:
            var tangent := (b-a).normalized()
            var face := Vector3(tangent.y,0,-tangent.x)*0.076
            _rod(Vector3(a.x,FY+0.09,a.y)+face,Vector3(a.x,FY+3.07,a.y)+face,0.003,joint)

# Integration supplies this opt-in budget; standalone station builds stay direct.
func _line_work() -> RefCounted:
    var node: Node=self
    while node!=null:
        if node.has_meta("metro_line_work"):
            var work: RefCounted=node.get_meta("metro_line_work")
            if node!=self: set_meta("metro_line_work",work)
            return work
        node=node.get_parent()
    return null

func _line_checkpoint() -> bool:
    var work: RefCounted=_line_work()
    if work==null: return true
    return await work.checkpoint()
