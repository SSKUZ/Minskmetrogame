extends "res://modules/stations/yakuba_kolasa/station_builder.gd"
## Yakuba Kolasa V64: 40 owner photographs; thirteen opposing relief pairs.
const ART := "res://modules/stations/yakuba_kolasa/art/"
const NORTH := -2.80
const SOUTH := 82.024
const PITCH := 6.80
const COL_X := 2.60
const ESCALATOR_PITCH := 2.05
const ESCALATOR_STEP_WIDTH := 1.30
const GIRDER_START := -1.10+PITCH-0.505
const GIRDER_END := -1.10+11.0*PITCH+0.505
const UPPER_HALL_LENGTH := 19.40
const UPPER_GATE_DISTANCE := 15.20
var wall_stone: StandardMaterial3D
var column_stones: Array[StandardMaterial3D]=[]
var stair_stone: StandardMaterial3D
var trim: StandardMaterial3D
var yellow: StandardMaterial3D
var floor_stone: StandardMaterial3D
var floor_dark: StandardMaterial3D
var lettering: StandardMaterial3D
var station_letters_mat: StandardMaterial3D
var bench_oak: StandardMaterial3D
var _depths: Dictionary={}
var _relief_meshes: Dictionary={}
var _relief_materials: Dictionary={}

func _ready() -> void:
    super._ready()
    begin_station()
    white=_photo("ceiling_paint.jpg",Vector2(0.9,0.9),0.88)
    wall_stone=_photo("wall_marble.jpg",Vector2(1.2,0.65),0.35)
    granite=_photo("wall_plinth.jpg",Vector2(1.2,0.50),0.40)
    stair_stone=_photo("stair_grey.jpg",Vector2(0.60,0.60),0.72)
    stair_stone.albedo_color=Color(1.10,1.10,1.07)
    floor_stone=_photo("floor_red.jpg",Vector2(0.60,1.20),0.40)
    floor_dark=_photo("floor_tan.jpg",Vector2(0.55,1.20),0.43)
    floor_dark.albedo_color=Color(1.22,1.32,1.40)
    trim=_material(Color("#c4b28d"),0.16,0.38)
    lettering=_material(Color("#aa8b47"),0.65,0.30)
    station_letters_mat=_photo("ceiling_paint.jpg",Vector2(0.09,0.09),0.43)
    station_letters_mat.albedo_color=Color("#695638");station_letters_mat.metallic=0.56
    bench_oak=_photo("bench_oak.jpg",Vector2(0.48,0.60),0.40)
    bench_oak.albedo_color=Color(0.99,0.92,0.77)
    yellow=_material(Color("#d5ae3c"),0.0,0.68)
    var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ART+"relief_heights.json"))
    _depths=data["depths"]
    _floor()
    _walls()
    _columns_and_girders()
    _ceilings()
    _stairs(-1.0,NORTH)
    _escalators(SOUTH)
    _signs()
    _track_details()
    var trackwork := preload("res://modules/stations/yakuba_kolasa/trackwork.gd").new()
    trackwork.name="DetailedTrackwork";add_child(trackwork)
    _close_portal_joints()
    _portal_equipment()
    _floor_fittings()
    for z in [18.0,47.0,73.0]:_television(float(z),false)
    for side in [-1.0,1.0]:
        for bay in [3,6,9]:_bench(Vector3(CX+side*COL_X,FY,-1.1+(float(bay)+0.5)*PITCH))
    flush()

func _photo(file: String,slab: Vector2,roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_texture=load(ART+file)
    mat.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED
    mat.roughness=roughness
    mat.uv1_triplanar=true;mat.uv1_world_triplanar=true;mat.uv1_triplanar_sharpness=8.0
    mat.uv1_scale=Vector3(1.0/slab.x,1.0/slab.y,1.0/slab.x)
    mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return mat

func _floor() -> void:
    (get_node("IslandPlatform") as MeshInstance3D).material_override=floor_stone
    # Parallel reddish granite fields and narrow beige/brown strips, not a square grid.
    var red: Array[StandardMaterial3D]=[]
    for i in range(4):
        var m := floor_stone.duplicate() as StandardMaterial3D
        m.albedo_color=Color(0.91+float(i)*0.035,0.91+float(i)*0.035,0.89+float(i)*0.035)
        m.uv1_offset=Vector3(float(i)*0.37,0,float(i)*0.23);red.append(m)
    for row in range(88):
        for col in range(14):
            box(Vector3(0.598,0.008,1.194),Vector3(CX-3.90+float(col)*0.60,FY+0.005,ZA+0.6+float(row)*1.20),red[(row*3+col)%4])
    for x in [-4.05,-3.32,-2.05,-1.46,0.0,1.46,2.05,3.32,4.05]:
        box(Vector3(0.15 if absf(float(x))<3.0 else 0.22,0.012,105),Vector3(CX+float(x),FY+0.014,MID),floor_dark)
    var edge := _photo("floor_tan.jpg",Vector2(0.6,1.2),0.6)
    edge.albedo_color=Color(1.08,1.07,1.03)
    for side in [-1.0,1.0]:
        box(Vector3(0.45,0.014,105),Vector3(CX+side*4.77,FY+0.011,MID),edge)
        box(Vector3(0.19,0.013,105),Vector3(CX+side*4.43,FY+0.017,MID),yellow)
        for i in range(1312):
            var z: float=ZA+0.04+float(i)*0.08
            for dx in [-0.058,0.0,0.058]:cylinder(0.011,0.004,Vector3(CX+side*4.43+float(dx),FY+0.026,z),yellow)

func _walls() -> void:
    var joint := _material(Color("#9b9b90"),0.0,0.8)
    var alt := _photo("wall_marble_alt.jpg",Vector2(1.2,0.65),0.36)
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.90
        var base: float=FY+0.57
        box(Vector3(0.28,base,105),Vector3(x,base*0.5,MID),granite)
        box(Vector3(0.28,6.4-base,105),Vector3(x,(6.4+base)*0.5,MID),wall_stone)
        box(Vector3(0.30,0.016,105),Vector3(x-side*0.02,base,MID),trim)
        for row in range(7):
            var y: float=base+float(row)*0.65
            box(Vector3(0.006,0.0035,105),Vector3(x-side*0.144,y,MID),joint)
            for i in range(88):
                var z: float=ZA+float(i)*1.20+(0.6 if row%2==1 else 0.0)
                box(Vector3(0.006,0.65,0.0035),Vector3(x-side*0.145,y+0.325,z),joint)
                if (i*3+row)%9==0 and z+1.2<ZB:box(Vector3(0.004,0.644,1.194),Vector3(x-side*0.145,y+0.325,z+0.6),alt)
        for y in [6.01,6.08]:rod(Vector3(x-side*0.20,float(y),ZA),Vector3(x-side*0.20,float(y),ZB),0.016,lettering)
        rod(Vector3(x-side*0.18,5.98,ZA),Vector3(x-side*0.18,5.98,ZB),0.013,black)
        for i in range(62):box(Vector3(0.055,0.045,0.035),Vector3(x-side*0.20,5.98,ZA+float(i)*1.70),metal)
        for z in [4.0,23.0,42.0,61.0,80.0]:
            _name("ПЛОШЧА  ЯКУБА  КОЛАСА" if side>0 else "ПЛОЩАДЬ  ЯКУБА  КОЛАСА",Vector3(x-side*0.19,3.66,float(z)),-side*PI/2.0)
            picture("route_track1.svg" if side>0 else "route_track2.svg",Vector2(4.80,0.86),Vector3(x-side*0.20,2.87,float(z)),-side*PI/2.0,true)

func _name(value: String,p: Vector3,yaw: float) -> void:
    var font := FontVariation.new()
    font.base_font=load(ART+"station_letters.ttf");font.variation_embolden=1.10
    var frame := Node3D.new();frame.name="OutlinedMetalStationLetters";frame.position=p;frame.rotation.y=yaw;add_child(frame)
    var size := 0.0043
    var total: float=float(maxi(value.length()-1,0))*0.035
    for letter in value:total+=font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,72).x*size
    var cursor: float=-total*0.5
    for letter in value:
        var advance: float=font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,72).x*size
        for face in range(2):
            var mesh := TextMesh.new();mesh.font=font;mesh.text=letter;mesh.font_size=72;mesh.pixel_size=size;mesh.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
            mesh.depth=0.045 if face==0 else 0.007;mesh.material=station_letters_mat
            var node := MeshInstance3D.new();node.mesh=mesh;node.position=Vector3(cursor+advance*0.5,0,0.0 if face==0 else 0.026)
            if face==1:node.scale=Vector3(0.98,0.98,1.0)
            frame.add_child(node)
        cursor+=advance+0.035

func _columns_and_girders() -> void:
    var ceramic := _material(Color("#bca679"),0.12,0.43)
    var base_mat := _photo("base_marble.jpg",Vector2(1.0,0.24),0.44)
    for side in [-1.0,1.0]:
        var x: float=CX+side*COL_X
        box(Vector3(1.0,0.42,GIRDER_END-GIRDER_START),Vector3(x,6.14,(GIRDER_START+GIRDER_END)*0.5),white)
        # Remove only the first and last column of each row: four in total.
        for i in range(1,12):
            var z: float=-1.1+float(i)*PITCH
            var p := Vector3(x,FY,z)
            box(Vector3(1.01,0.20,1.01),p+Vector3(0,0.10,0),base_mat)
            box(Vector3(0.96,3.44,0.96),p+Vector3(0,1.92,0),ceramic)
            box(Vector3(0.97,1.15,0.97),p+Vector3(0,4.215,0),white)
            box(Vector3(0.99,0.028,0.99),p+Vector3(0,3.655,0),metal)
            # Pair i shares every relief face with the opposite column. The order
            # is deterministic and follows the photographic walk through the hall.
            var motif := "relief_%02d" % (i+1)
            for face in range(4):
                var yaw: float=float(face)*PI/2.0
                var basis := Basis(Vector3.UP,yaw)
                _relief_panel("lower_ornament",Vector2(0.945,1.96),0.023,p+basis*Vector3(0,1.18,0.505),yaw)
                _relief_panel(motif,Vector2(0.975,1.03),0.042,p+basis*Vector3(0,2.675,0.525),yaw)
                _relief_panel("upper_ornament",Vector2(0.945,0.45),0.023,p+basis*Vector3(0,3.415,0.505),yaw)
                # Physical octagonal rim surrounds the figurative relief.
                var outline := [Vector2(-0.34,-0.51),Vector2(0.34,-0.51),Vector2(0.48,-0.35),Vector2(0.48,0.35),Vector2(0.34,0.51),Vector2(-0.34,0.51),Vector2(-0.48,0.35),Vector2(-0.48,-0.35)]
                for j in range(8):
                    var a: Vector2=outline[j];var b: Vector2=outline[(j+1)%8]
                    rod(p+basis*Vector3(a.x,a.y+2.675,0.552),p+basis*Vector3(b.x,b.y+2.675,0.552),0.009,trim)
                for dx in [-0.475,0.0,0.475]:box(Vector3(0.012,1.94,0.014),p+basis*Vector3(float(dx),1.18,0.529),trim,basis)
    # Long diffusers run continuously along the four girder edges.
    for side in [-1.0,1.0]:
        for face in [-1.0,1.0]:
            for j in range(49):
                var z: float=-2.3+float(j)*1.76
                var a: float=maxf(GIRDER_START,z-0.845)
                var b: float=minf(GIRDER_END,z+0.845)
                if b>a:box(Vector3(0.055,0.065,b-a),Vector3(CX+side*COL_X+face*0.43,6.14,(a+b)*0.5),glow)

func _relief_panel(asset: String,size: Vector2,depth: float,p: Vector3,yaw: float) -> void:
    var key := asset
    if not _relief_meshes.has(key):
        var mat := StandardMaterial3D.new()
        mat.albedo_texture=load(ART+asset+".jpg")
        mat.normal_enabled=true;mat.normal_texture=load(ART+asset+"_normal.png");mat.normal_scale=0.65
        mat.roughness=0.37;mat.metallic=0.16
        mat.cull_mode=BaseMaterial3D.CULL_DISABLED
        mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        _relief_materials[key]=mat
        var values: Array=_depths[asset]
        var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for row in range(48):
            for col in range(40):
                for corner in [Vector2i(col,row),Vector2i(col+1,row),Vector2i(col,row+1),Vector2i(col+1,row),Vector2i(col+1,row+1),Vector2i(col,row+1)]:
                    var u: float=float(corner.x)/40.0;var v: float=float(corner.y)/48.0
                    var index: int=corner.y*41+corner.x
                    var h: float=float(values[index])
                    var left: float=float(values[corner.y*41+maxi(0,corner.x-1)])
                    var right: float=float(values[corner.y*41+mini(40,corner.x+1)])
                    var up: float=float(values[maxi(0,corner.y-1)*41+corner.x])
                    var down: float=float(values[mini(48,corner.y+1)*41+corner.x])
                    st.set_normal(Vector3(-(right-left)*depth*20.0/size.x,-(up-down)*depth*24.0/size.y,1.0).normalized())
                    st.set_uv(Vector2(u,v))
                    st.add_vertex(Vector3((u-0.5)*size.x,(0.5-v)*size.y,(h-0.5)*depth))
        st.generate_tangents()
        var mesh := st.commit();mesh.surface_set_material(0,mat);_relief_meshes[key]=mesh
    var label := "Relief"+asset
    if not batches.has(label):batches[label]={"kind":"custom","mesh":_relief_meshes[key],"mat":_relief_materials[key],"poses":[]}
    batches[label].poses.append(Transform3D(Basis(Vector3.UP,yaw),p))

func _ceilings() -> void:
    box(Vector3(5.22,0.14,SOUTH-NORTH-0.20),Vector3(CX,6.76,(NORTH+SOUTH)*0.5),white)
    for side in [-1.0,1.0]:
        # Keep the roof above the tracks while removing its overlap into the ascents.
        box(Vector3(5.36,0.13,105),Vector3(CX+side*6.23,6.48,MID),white)
        box(Vector3(0.95,0.13,SOUTH-NORTH-0.20),Vector3(CX+side*3.08,6.48,(NORTH+SOUTH)*0.5),white)
    # The central rib is a chevron in plan, with two broad diagonal arms.
    for i in range(36):
        var z: float=-2.6+float(i)*2.43
        if z-0.78<NORTH+0.10 or z+0.30>SOUTH-0.10:continue
        var apex := Vector3(CX,6.54,z-0.78)
        _beam(Vector3(CX-2.16,6.54,z+0.30),apex,0.15,0.26,white)
        _beam(apex,Vector3(CX+2.16,6.54,z+0.30),0.15,0.26,white)
    for side in [-1.0,1.0]:
        for i in range(44):
            var z: float=ZA+float(i)*2.43
            var inner: float=3.10 if z>NORTH+0.10 and z+1.21<SOUTH-0.10 else 3.65
            _beam(Vector3(CX+side*inner,6.27,z),Vector3(CX+side*8.85,6.27,z),0.15,0.29,white)
            _beam(Vector3(CX+side*inner,6.27,z),Vector3(CX+side*5.62,6.27,z+1.21),0.13,0.29,white)
            _beam(Vector3(CX+side*5.62,6.27,z+1.21),Vector3(CX+side*8.85,6.27,z),0.13,0.29,white)
    for child in get_children():
        if child is OmniLight3D:
            child.position.y=6.18;child.light_energy=1.40;child.light_color=Color(1.0,0.98,0.94)
    for z in [8.0,35.0,61.0,83.0]:
        var light := OmniLight3D.new();light.position=Vector3(CX,6.55,float(z));light.light_energy=0.50;light.omni_range=16.0;light.shadow_enabled=false;add_child(light)

    # Gentle upward spot lights reveal the existing chevron relief.
    for z in [20.485,42.355,64.225]:
        var light := SpotLight3D.new()
        light.name="CeilingReliefLight";light.position=Vector3(CX+0.55,6.12,float(z));light.rotation.x=PI/2.0
        light.light_color=Color(1.0,0.98,0.94);light.light_energy=0.28
        light.spot_range=8.0;light.spot_angle=80.0
        light.shadow_enabled=true;light.shadow_bias=0.06;light.shadow_normal_bias=1.0;add_child(light)

func _beam(a: Vector3,b: Vector3,width: float,height: float,mat: Material) -> void:
    var d := b-a
    var basis := Basis(Vector3.UP,atan2(d.x,d.z))
    box(Vector3(width,height,d.length()),(a+b)*0.5,mat,basis)

func _stairs(direction: float,start: float) -> void:
    var width := 7.1
    var rise := 0.13
    var run := 0.30
    var landing := 0.90
    var top: float=FY+36*rise
    for i in range(36):
        var h: float=float(i+1)*rise
        var z: float=start+direction*(float(i)*run+(landing if i>=20 else 0.0))
        box(Vector3(width,h,run+0.003),Vector3(CX,FY+h*0.5,z),stair_stone)
        if i in [0,19,20,35]:box(Vector3(width,0.016,0.06),Vector3(CX,FY+h+0.009,z-direction*0.12),yellow)
    box(Vector3(width,0.18,landing),Vector3(CX,FY+20*rise-0.09,start+direction*6.30),stair_stone)
    var finish: float=start+direction*(35*run+landing+run*0.5)
    box(Vector3(width,0.20,3.8),Vector3(CX,top-0.10,finish+direction*1.8),floor_stone)
    _exit_hall(direction,start,width,top,UPPER_HALL_LENGTH)
    for side in [-1.0,1.0]:
        var x: float=CX+side*(width*0.5-0.045)
        var points := [Vector2(-0.30,0),Vector2(5.85,20*rise),Vector2(6.75,20*rise),Vector2(11.55,36*rise)]
        for i in range(points.size()-1):
            var a: Vector2=points[i];var b: Vector2=points[i+1]
            rod(Vector3(x,FY+0.88+a.y,start+direction*a.x),Vector3(x,FY+0.88+b.y,start+direction*b.x),0.027,metal)
        rod(Vector3(x,FY+0.88,start),Vector3(x,FY+0.67,start-direction*0.20),0.027,metal)
    board("exit_stairs.jpg",Vector3(CX,4.72,start-direction*0.45),Vector2(5.75,0.84))
    foot_grille(start-direction*0.7,7.35)

func _escalators(start: float) -> void:
    var width := 7.10
    var rise := 4.65
    var run := 9.20
    var lower := 1.20
    var tan := _photo("escalator_wood.jpg",Vector2(0.7,1.8),0.40)
    var rubber := _material(Color("#20241f"),0.05,0.60)
    var stepmat := _material(Color("#5d625b"),0.45,0.50)
    var half_step: float=ESCALATOR_STEP_WIDTH*0.5
    var half_case: float=ESCALATOR_PITCH*0.5
    var side_width: float=half_case-half_step
    _exit_hall(1.0,start,width,FY+rise,UPPER_HALL_LENGTH)
    # Full lower slab and full-height upper landing close the machine pit and rear view.
    box(Vector3(width+0.04,0.16,14.9),Vector3(CX,FY-0.08,start+7.25),floor_stone)
    box(Vector3(width+0.04,rise+0.05,4.40),Vector3(CX,FY+(rise-0.05)*0.5,start+12.5),floor_stone)
    var body := PackedVector2Array([Vector2(-0.18,0.025),Vector2(lower,0.025),Vector2(lower+run,rise-0.16),Vector2(12.30,rise-0.16)])
    var casing := PackedVector2Array([Vector2(-0.16,0.76),Vector2(lower,0.76),Vector2(lower+run,rise+0.76),Vector2(12.25,rise+0.76)])
    # Three complete housings touch at their sides. There is no open trench between lanes.
    for lane in range(3):
        var x: float=CX+(float(lane)-1.0)*ESCALATOR_PITCH
        _closed_ramp_strip(x-half_case-0.006,x+half_case+0.006,start,body,tan)
        for i in range(49):
            var t: float=float(i)/48.0
            var z: float=start+lower+t*run
            var h: float=maxf(0.045,rise*t)
            box(Vector3(ESCALATOR_STEP_WIDTH,h,0.205),Vector3(x,FY+h*0.5,z),stepmat)
            for groove in range(14):
                box(Vector3(0.006,0.007,0.185),Vector3(x-half_step+0.05+float(groove)*(ESCALATOR_STEP_WIDTH-0.10)/13.0,FY+h+0.004,z),black)
        box(Vector3(ESCALATOR_STEP_WIDTH,0.04,1.25),Vector3(x,FY+0.02,start+0.48),stepmat)
        for side in [-1.0,1.0]:
            var x0: float=x+side*half_step
            var x1: float=x+side*half_case
            _closed_ramp_strip(minf(x0,x1)-0.006,maxf(x0,x1)+0.006,start,casing,tan)
            var bx: float=x+side*(half_step+side_width*0.5)
            var offsets := [Vector2(0.0,0.0),Vector2(lower,0.0),Vector2(lower+run,rise),Vector2(12.20,rise)]
            for i in range(offsets.size()-1):
                var p0: Vector2=offsets[i];var p1: Vector2=offsets[i+1]
                rod(Vector3(bx,FY+p0.y+0.82,start+p0.x),Vector3(bx,FY+p1.y+0.82,start+p1.x),0.045,rubber)
                rod(Vector3(x0,FY+p0.y+0.70,start+p0.x),Vector3(x0,FY+p1.y+0.70,start+p1.x),0.022,metal)
            cylinder(0.085,0.57,Vector3(bx,FY+0.285,start+0.06),metal)
            picture("escalator_warning.svg",Vector2(0.22,0.25),Vector3(bx,FY+0.31,start-0.05),PI)
            box(Vector3(0.15,0.68,0.26),Vector3(bx,FY+0.34,start-0.10),metal)
        box(Vector3(ESCALATOR_STEP_WIDTH,0.012,0.06),Vector3(x,FY+0.047,start+0.03),yellow)
        var indicator := _material(Color("#0f9d57") if lane==0 else Color("#bc274a"),0,0.4)
        indicator.emission_enabled=true;indicator.emission=indicator.albedo_color
        box(Vector3(0.08,0.10,0.02),Vector3(x-half_step-side_width*0.5,FY+0.58,start-0.245),indicator)
    # Marble cheeks meet the outer housings and overlap the existing hall walls.
    for side in [-1.0,1.0]:
        var x0: float=CX+side*ESCALATOR_PITCH*1.5
        var x1: float=CX+side*(width*0.5+0.025)
        _closed_ramp_strip(minf(x0,x1)-0.006,maxf(x0,x1)+0.006,start,casing,wall_stone)
    board("exit_escalators.jpg",Vector3(CX,4.71,start-0.48),Vector2(5.75,0.84))
    foot_grille(start-0.46,7.25)

func _exit_hall(direction: float,start: float,width: float,top: float,length: float) -> void:
    var roof_y: float=top+2.90
    for side in [-1.0,1.0]:
        var x: float=CX+side*(width*0.5+0.14)
        box(Vector3(0.28,roof_y+0.10-FY,length),Vector3(x,(roof_y+0.10+FY)*0.5,start+direction*(length*0.5-0.30)),wall_stone)
        box(Vector3(0.29,0.09,length),Vector3(x,FY+0.045,start+direction*(length*0.5-0.30)),black)
        picture("no_smoking.svg",Vector2(0.22,0.22),Vector3(x,FY+1.9,start-direction*0.46),0.0 if direction<0 else PI)
        picture("sos_info.svg",Vector2(0.25,0.39),Vector3(x,FY+0.94,start-direction*0.462),0.0 if direction<0 else PI)
        _camera_box(Vector3(x-side*0.16,4.92,start-direction*0.5),0.0 if direction<0 else PI)
    box(Vector3(width+0.55,0.20,length),Vector3(CX,roof_y,start+direction*(length*0.5-0.30)),white)
    box(Vector3(width+0.55,roof_y+0.10-5.34,0.40),Vector3(CX,(roof_y+0.10+5.34)*0.5,start-direction*0.36),white)
    for i in range(14):
        var z: float=start+direction*float(i)*1.4
        box(Vector3(width+0.1,0.20,0.16),Vector3(CX,roof_y-0.20,z),white)
        if i%2==0:box(Vector3(5.60,0.035,0.07),Vector3(CX,roof_y-0.33,z),glow)
    box(Vector3(width+0.55,roof_y+0.10-FY,0.24),Vector3(CX,(roof_y+0.10+FY)*0.5,start+direction*(length-0.45)),wall_stone)
    _upper_landing(direction,start,width,top,length)

func _signs() -> void:
    for bay in [1,5,9]:
        var z: float=-1.1+(float(bay)+0.5)*PITCH
        for side in [-1.0,1.0]:
            var p := Vector3(CX+side*COL_X,5.55,z)
            var size := Vector2(3.95,0.60)
            box(Vector3(0.075,0.68,4.03),p,metal)
            for face in [-1.0,1.0]:picture("platform_track1.jpg" if side>0.0 else "platform_track2.jpg",size,p+Vector3(face*0.043,0,0),face*PI/2.0)
            for dz in [-1.75,1.75]:rod(p+Vector3(0,0.34,float(dz)),Vector3(p.x,5.98,z+float(dz)),0.020,metal)

func _bench(p: Vector3) -> void:
    var brown := _material(Color("#514339"),0.25,0.61)
    box(Vector3(0.60,0.38,2.45),p+Vector3(0,0.19,0),brown)
    for i in range(5):
        var z: float=p.z-0.98+float(i)*0.49
        _rounded_bench_box(Vector3(0.63,0.10,0.46),Vector3(p.x,p.y+0.43,z),bench_oak,0.025)
        for dx in [-0.14,0.14]:box(Vector3(0.009,0.008,0.455),Vector3(p.x+float(dx),p.y+0.485,z),brown)
        if i<4:box(Vector3(0.68,0.065,0.037),Vector3(p.x,p.y+0.46,z+0.244),brown)

func _television(z: float,_event: bool) -> void:
    var p := Vector3(CX,5.15,z)
    box(Vector3(1.56,0.95,0.13),p,black)
    for dx in [-0.48,0.48]:
        rod(p+Vector3(float(dx),0.50,0),Vector3(CX+float(dx),6.65,z),0.015,metal)
        box(Vector3(0.14,0.02,0.16),Vector3(CX+float(dx),6.65,z),metal)
    for face in [-1.0,1.0]:
        box(Vector3(1.48,0.86,0.006),p+Vector3(0,0,face*0.07),_material(Color("#111719"),0.35,0.15))

func _floor_fittings() -> void:
    for z in [11.0,37.0,65.0]:
        cylinder(0.20,0.014,Vector3(CX+0.3,FY+0.023,float(z)),metal)
        for i in range(6):box(Vector3(0.012,0.016,0.25),Vector3(CX+0.22+float(i)*0.032,FY+0.030,float(z)),black)
        box(Vector3(0.35,0.018,0.38),Vector3(CX-0.25,FY+0.025,float(z)+3.4),trim)
        for i in range(8):box(Vector3(0.20,0.022,0.018),Vector3(CX-0.25,FY+0.030,float(z)+3.26+float(i)*0.036),black)

func _track_details() -> void:
    for x in [0.992,-11.732]:
        for direction in [-1.0,1.0]:
            var end: float=ZA if direction<0.0 else ZB
            box(Vector3(3.94,0.20,8.12),Vector3(x,4.90,end+direction*3.9),wall_stone)
            for side in [-1.0,1.0]:
                box(Vector3(0.14,5.02,8.12),Vector3(x+side*1.94,2.31,end+direction*3.9),wall_stone)
                for h in [0.70,1.1,1.5,1.9,2.35,2.65]:rod(Vector3(x+side*1.84,float(h),end),Vector3(x+side*1.84,float(h),end+direction*7.8),0.015,black)
            box(Vector3(4.04,5.45,0.14),Vector3(x,2.275,end+direction*8.0),black)

func _portal_equipment() -> void:
    var infra := get_node("StationInfrastructure")
    infra.set("_amber",Color(1.0,0.13,0.055))
    var displays: Array=infra.get("_displays")
    for display in displays:
        for i in range(70,76):display.set_instance_color(i,Color(1.0,0.13,0.055))
    for node in infra.get_children():
        if node is Node3D and "Portal" in str(node.name):
            node.position.y=4.68
            # Track 1 leads toward -Z, Track 2 toward +Z; rear clocks are hidden.
            node.visible=str(node.name)=="Track1Portal1Clock" or str(node.name)=="Track2Portal2Clock"
    for direction in [-1.0,1.0]:
        var end: float=ZA if direction<0.0 else ZB
        for side in [-1.0,1.0]:
            var tx: float=CX+side*6.362
            var yaw: float=0.0 if direction<0.0 else PI
            if side==-direction:
                var root := Node3D.new();root.name="WhiteDriverMirror";root.position=Vector3(CX+side*4.58,FY+1.42,end-direction*2.6);root.rotation.y=yaw-side*0.12;add_child(root)
                var mirror := MeshInstance3D.new();mirror.set_script(preload("res://modules/stations/yakuba_kolasa/driver_mirrors.gd"));mirror.name="ReflectingSurface";mirror.position.z=0.016
                var q := QuadMesh.new();q.size=Vector2(0.60,1.56);mirror.mesh=q;mirror.set_meta("mirror_size",q.size);root.add_child(mirror)
                var pts: Array[Vector3]=[]
                for corner in range(4):
                    var c := Vector2(0.235*(1.0 if corner in [0,3] else -1.0),0.70*(1.0 if corner in [0,1] else -1.0))
                    for j in range(9):
                        var a: float=float(corner)*PI/2.0+float(j)*PI/16.0;pts.append(Vector3(c.x+0.11*cos(a),c.y+0.11*sin(a),0))
                for i in range(pts.size()):_local_rod(root,pts[i],pts[(i+1)%pts.size()],0.032,white)
                _local_rod(root,Vector3(0,-1.42,0),Vector3(0,-0.80,0),0.075,_material(Color("#285476"),0.3,0.42))
                for dx in [-0.42,0.42]:_local_rod(root,Vector3(float(dx),-1.42,0),Vector3(float(dx),-0.52,0.10),0.023,metal)
                _local_rod(root,Vector3(-0.42,-0.52,0.10),Vector3(0.42,-0.52,0.10),0.023,metal)
                var p := Vector3(tx-side*1.42,4.68,end-direction*0.30)
                box(Vector3(0.72,0.46,0.08),p,black)
                picture("platform_cctv.jpg",Vector2(0.66,0.371),p+Vector3(0,0,-direction*0.048),yaw)
            _camera_box(Vector3(CX+side*3.95,4.56,end-direction*0.35),yaw)

func _local_rod(parent: Node3D,a: Vector3,b: Vector3,r: float,mat: Material) -> void:
    var mesh := CylinderMesh.new();mesh.top_radius=r;mesh.bottom_radius=r;mesh.height=a.distance_to(b);mesh.radial_segments=10;mesh.material=mat
    var n := MeshInstance3D.new();n.mesh=mesh;n.position=(a+b)*0.5
    var d := (b-a).normalized();var axis := Vector3.UP.cross(d)
    if axis.length_squared()>0.00001:n.basis=Basis(axis.normalized(),Vector3.UP.angle_to(d))
    parent.add_child(n)

func _camera_box(p: Vector3,yaw: float) -> void:
    var b := Basis(Vector3.UP,yaw)
    box(Vector3(0.17,0.13,0.30),p,white,b)
    box(Vector3(0.19,0.02,0.34),p+Vector3(0,0.09,0),white,b)
    sphere(Vector3(0.075,0.075,0.015),p+b*Vector3(0,0,0.16),black)
    rod(p+Vector3(0,0.1,0),p+Vector3(0,0.3,0),0.014,metal)


func _closed_ramp_strip(x0: float,x1: float,start: float,points: PackedVector2Array,mat: Material) -> void:
    # Closed six-face segments, including the floor and both end caps; standard mesh surfaces.
    var bottom: float=FY-0.06
    for i in range(points.size()-1):
        var a: Vector2=points[i];var b: Vector2=points[i+1]
        var z0: float=start+a.x;var z1: float=start+b.x
        var y0: float=FY+a.y;var y1: float=FY+b.y
        quad(Vector3(x0,bottom,z0),Vector3(x1,bottom,z0),Vector3(x1,bottom,z1),Vector3(x0,bottom,z1),mat,Vector3.DOWN)
        quad(Vector3(x0,y0,z0),Vector3(x0,y1,z1),Vector3(x1,y1,z1),Vector3(x1,y0,z0),mat,Vector3.UP)
        quad(Vector3(x0,bottom,z0),Vector3(x0,bottom,z1),Vector3(x0,y1,z1),Vector3(x0,y0,z0),mat,Vector3.LEFT)
        quad(Vector3(x1,bottom,z0),Vector3(x1,y0,z0),Vector3(x1,y1,z1),Vector3(x1,bottom,z1),mat,Vector3.RIGHT)
        if i==0:
            quad(Vector3(x0,bottom,z0),Vector3(x0,y0,z0),Vector3(x1,y0,z0),Vector3(x1,bottom,z0),mat,Vector3.FORWARD)
        if i==points.size()-2:
            quad(Vector3(x0,bottom,z1),Vector3(x1,bottom,z1),Vector3(x1,y1,z1),Vector3(x0,y1,z1),mat,Vector3.BACK)

func _close_portal_joints() -> void:
    # Four closed end assemblies, fitted to Yakuba Kolasa's 6.48 m side roof.
    # Preserve Station Base connections, running clearances and all column reliefs.
    var roof_top := 6.56
    for direction in [-1.0,1.0]:
        var end: float=ZA if direction<0.0 else ZB
        for side in [-1.0,1.0]:
            box(Vector3(3.96,roof_top-4.44,0.36),Vector3(CX+side*6.362,(roof_top+4.44)*0.5,end),wall_stone)
            box(Vector3(0.94,roof_top-FY,0.36),Vector3(CX+side*4.01,(roof_top+FY)*0.5,end),wall_stone)
            box(Vector3(0.66,roof_top+0.45,0.36),Vector3(CX+side*8.57,(roof_top-0.45)*0.5,end),wall_stone)
    # Native upstands close the raised centre roof/girder seams.
    for side in [-1.0,1.0]:
        box(Vector3(0.18,0.44,SOUTH-NORTH-0.20),Vector3(CX+side*2.60,6.52,(NORTH+SOUTH)*0.5),white)

func _rounded_bench_box(size: Vector3,p: Vector3,mat: Material,radius: float=0.03) -> void:
    var r: float=minf(radius,minf(size.x,size.y)*0.49)
    var pts := PackedVector2Array()
    for corner in range(4):
        var center := Vector2(p.x+(size.x*0.5-r)*(1.0 if corner in [0,3] else -1.0),p.y+(size.y*0.5-r)*(1.0 if corner in [0,1] else -1.0))
        for j in range(7):
            var a: float=float(corner)*PI/2.0+float(j)*PI/12.0;pts.append(center+Vector2(cos(a),sin(a))*r)
    extrusion(pts,p.z-size.z*0.5,p.z+size.z*0.5,mat)


func _upper_landing(direction: float,start: float,width: float,top: float,length: float) -> void:
    # Native, station-local architecture. Distances and named nodes remain extractable in metres.
    var root := Node3D.new();root.name="NorthUpperLanding" if direction<0.0 else "SouthUpperLanding"
    root.position=Vector3(CX,top,start);root.rotation.y=PI if direction<0.0 else 0.0
    root.set_meta("metres_per_unit",1.0);add_child(root)
    var front := 11.35 if direction<0.0 else 10.35
    box(Vector3(width+0.02,top-FY+0.04,length-front-0.20),Vector3(CX,(top+FY)*0.5-0.02,start+direction*(front+length-0.20)*0.5),floor_stone)
    var arrival := Marker3D.new();arrival.name="Arrival";arrival.position=Vector3(0,0,12.20)
    arrival.set_meta("role","waypoint");root.add_child(arrival)
    var steel := _material(Color("#a8aeac"),0.80,0.33)
    var dark := _material(Color("#263438"),0.15,0.24)
    var green := _material(Color("#249d65"),0.0,0.5)
    green.emission_enabled=true;green.emission=Color("#249d65");green.emission_energy_multiplier=0.40
    for i in range(4):
        var gate := Node3D.new();gate.name="Turnstile%02d" % (i+1)
        gate.position=Vector3(-2.65+float(i)*1.10,0,UPPER_GATE_DISTANCE)
        gate.set_meta("role","equipment");gate.set_meta("static_architecture",true);root.add_child(gate)
        _landing_box(gate,"Pedestal",Vector3(0.23,0.93,1.05),Vector3(0,0.465,0),steel)
        _landing_box(gate,"Top",Vector3(0.27,0.065,1.10),Vector3(0,0.9625,0),metal)
        _landing_box(gate,"Reader",Vector3(0.17,0.025,0.24),Vector3(0,1.01,-0.31),dark)
        _landing_box(gate,"FrontPanel",Vector3(0.15,0.33,0.018),Vector3(0,0.67,-0.535),dark)
        _landing_box(gate,"Indicator",Vector3(0.055,0.055,0.014),Vector3(0,0.78,-0.55),green)
        _local_rod(gate,Vector3(0.10,0.64,0),Vector3(0.22,0.64,0),0.09,steel)
        for angle in [0.0,TAU/3.0,2.0*TAU/3.0]:
            _local_rod(gate,Vector3(0.18,0.64,0),Vector3(0.77,0.64+0.27*sin(float(angle)),0.27*cos(float(angle))),0.018,steel)
        for z in [-0.35,0.35]:
            _landing_box(gate,"BasePlate",Vector3(0.33,0.022,0.23),Vector3(0,0.011,float(z)),steel)
    var booth := Node3D.new();booth.name="ControllerBooth";booth.position=Vector3(2.55,0,UPPER_GATE_DISTANCE+0.90)
    booth.set_meta("role","equipment");booth.set_meta("static_architecture",true);root.add_child(booth)
    var glass := _material(Color(0.64,0.77,0.79,0.26),0.05,0.17)
    glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
    _landing_box(booth,"Floor",Vector3(1.43,0.045,1.80),Vector3(0,0.0225,0),steel)
    _landing_box(booth,"FrontApron",Vector3(1.42,0.80,0.055),Vector3(0,0.40,-0.875),wall_stone)
    for x in [-0.69,0.69]:
        _landing_box(booth,"SideApron",Vector3(0.055,0.80,1.75),Vector3(float(x),0.40,0),wall_stone)
        _landing_box(booth,"SideWindow",Vector3(0.018,1.26,1.68),Vector3(float(x),1.47,0),glass)
        for z in [-0.875,0.875]:
            _landing_box(booth,"CornerPost",Vector3(0.045,2.16,0.045),Vector3(float(x),1.10,float(z)),steel)
        _landing_box(booth,"WindowRail",Vector3(0.04,0.045,1.79),Vector3(float(x),0.83,0),steel)
    _landing_box(booth,"FrontWindow",Vector3(1.34,1.26,0.018),Vector3(0,1.47,-0.875),glass)
    _landing_box(booth,"Door",Vector3(1.32,2.02,0.022),Vector3(0,1.07,0.875),glass)
    for x in [-0.64,0.64]:
        _landing_box(booth,"DoorFrame",Vector3(0.035,2.10,0.04),Vector3(float(x),1.09,0.89),steel)
    _local_rod(booth,Vector3(-0.42,0.95,0.915),Vector3(-0.42,1.16,0.915),0.012,steel)
    _landing_box(booth,"Roof",Vector3(1.49,0.10,1.87),Vector3(0,2.20,0),steel)
    _landing_box(booth,"Desk",Vector3(1.23,0.055,0.55),Vector3(0,0.82,-0.31),trim)
    _landing_box(booth,"Monitor",Vector3(0.37,0.27,0.045),Vector3(0,1.02,-0.36),dark)
    _landing_box(booth,"MonitorStand",Vector3(0.05,0.13,0.10),Vector3(0,0.91,-0.36),steel)
    var light := OmniLight3D.new();light.name="LandingLight"
    light.position=Vector3(0,2.42,UPPER_GATE_DISTANCE-1.30);light.light_color=Color(1.0,0.98,0.94)
    light.light_energy=0.60;light.omni_range=7.0;light.shadow_enabled=false;root.add_child(light)


func _landing_box(parent: Node3D,label: String,size: Vector3,p: Vector3,mat: Material) -> void:
    var mesh := BoxMesh.new();mesh.size=size;mesh.material=mat
    var node := MeshInstance3D.new();node.name=label;node.mesh=mesh;node.position=p;parent.add_child(node)

