extends "res://modules/stations/ploshchad_lenina/station_builder.gd"
## Owner archive V67. Independent Station Base block, with a true hole for the lower interchange.
const ART := "res://modules/stations/ploshchad_lenina/art/"
const NORTH := -4.976
const SOUTH := 84.20
const WELL_BACK := 41.0
const WELL_TOP := 53.0
const WELL_HALF := 2.0
const LOWER := FY-5.40
var wall_stone: StandardMaterial3D
var pale: StandardMaterial3D
var stair_stone: StandardMaterial3D
var grey: StandardMaterial3D
var dark: StandardMaterial3D
var gold: StandardMaterial3D
var yellow: StandardMaterial3D
var glass: StandardMaterial3D

func _ready() -> void:
    super._ready();begin_station()
    for child in get_children():
        if child is OmniLight3D:child.queue_free()
    white=_photo("ceiling_paint.jpg",Vector2(1.4,1.4),0.87)
    white.normal_enabled=true;white.normal_texture=load(ART+"ceiling_paint_normal.png");white.normal_scale=0.10
    wall_stone=_photo("wall_breccia.jpg",Vector2(1.15,0.58),0.41)
    pale=_photo("white_marble.jpg",Vector2(1.10,0.58),0.44)
    stair_stone=_photo("stair_granite.jpg",Vector2(1.2,0.18),0.63)
    grey=_photo("floor_grey.jpg",Vector2(0.60,0.60),0.43)
    grey.normal_enabled=true;grey.normal_texture=load(ART+"floor_grey_normal.png");grey.normal_scale=0.13
    dark=_photo("floor_dark.jpg",Vector2(0.65,0.65),0.45)
    granite=dark;yellow=_material(Color("#d6b341"),0,0.68)
    gold=_material(Color("#ac8c4e"),0.72,0.33)
    glass=_material(Color(0.78,0.87,0.84,0.25),0.12,0.12);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
    _platform();_walls();_vault();_lower_interchange();_order_pylon()
    _exit(-1.0,NORTH,false);_exit(1.0,SOUTH,true)
    _track_details();_portal_equipment();_fittings()
    flush()

func _photo(file: String,slab: Vector2,roughness: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new();m.albedo_texture=load(ART+file);m.roughness=roughness
    m.uv1_triplanar=true;m.uv1_world_triplanar=true;m.uv1_triplanar_sharpness=8.0;m.uv1_scale=Vector3(1.0/slab.x,1.0/slab.y,1.0/slab.x)
    m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return m

func _solid_box(size: Vector3,p: Vector3,mat: Material,basis: Basis=Basis.IDENTITY) -> void:
    box(size,p,mat,basis)
    var body := StaticBody3D.new();body.name="StationStructure";body.position=p;body.basis=basis
    var shape := BoxShape3D.new();shape.size=size;var c := CollisionShape3D.new();c.shape=shape;body.add_child(c);add_child(body)

func _floor_rectangle(x0: float,x1: float,z0: float,z1: float,mat: Material,y: float=FY+0.014) -> void:
    if x1-x0<0.001 or z1-z0<0.001:return
    # Clip every paving/inlay rectangle around the actual stairwell, including narrow crossing strips.
    var xs: Array[float]=[x0,x1];var zs: Array[float]=[z0,z1]
    for x in [CX-WELL_HALF,CX+WELL_HALF]:
        if x>x0 and x<x1:xs.append(x)
    for z in [WELL_BACK,WELL_TOP]:
        if z>z0 and z<z1:zs.append(z)
    xs.sort();zs.sort()
    for i in range(xs.size()-1):
        for j in range(zs.size()-1):
            var x: float=(xs[i]+xs[i+1])*0.5;var z: float=(zs[j]+zs[j+1])*0.5
            if absf(x-CX)<WELL_HALF and z>WELL_BACK and z<WELL_TOP:continue
            box(Vector3(xs[i+1]-xs[i],0.012,zs[j+1]-zs[j]),Vector3(x,y,z),mat)

func _platform() -> void:
    # Station Base is deliberately split; no original full platform or hidden collider covers the opening.
    for side in [-1.0,1.0]:
        _solid_box(Vector3(3.0,0.20,105),Vector3(CX+side*3.5,FY-0.10,MID),grey)
    for interval in [Vector2(ZA,WELL_BACK),Vector2(WELL_TOP,ZB)]:
        _solid_box(Vector3(4.0,0.20,interval.y-interval.x),Vector3(CX,FY-0.10,(interval.x+interval.y)*0.5),grey)
    _floor_rectangle(CX-5,CX+5,ZA,ZB,grey)
    var veined := _photo("floor_veined.jpg",Vector2(0.60,0.60),0.42)
    for row in range(175):
        for col in range(15):
            if (row*7+col*11)%17!=0:continue
            var x: float=CX-4.30+(float(col)+0.5)*0.5733;var z: float=ZA+float(row)*0.60
            _floor_rectangle(x-0.285,x+0.285,z,z+0.595,veined,FY+0.022)
    # Long interlocking double rectangular frames, matching the photographed grey/black pattern.
    for i in range(15):
        var z0: float=ZA+float(i)*7.0;var z1: float=minf(z0+7.0,ZB)
        for inset in [0.0,0.58]:
            var left: float=CX-3.90+float(inset);var right: float=CX+3.90-float(inset)
            var front: float=z0+0.26+float(inset);var back: float=z1-0.26-float(inset)
            var w: float=0.25 if inset==0.0 else 0.17
            _floor_rectangle(left,left+w,front,back,dark,FY+0.030);_floor_rectangle(right-w,right,front,back,dark,FY+0.030)
            _floor_rectangle(left+w,right-w,front,front+w,dark,FY+0.030);_floor_rectangle(left+w,right-w,back-w,back,dark,FY+0.030)
    for side in [-1.0,1.0]:
        _floor_rectangle(CX+side*4.75-0.25,CX+side*4.75+0.25,ZA,ZB,grey,FY+0.032)
        box(Vector3(0.17,0.014,105),Vector3(CX+side*4.40,FY+0.037,MID),yellow)
        for i in range(875):
            for dx in [-0.05,0.0,0.05]:cylinder(0.010,0.004,Vector3(CX+side*4.40+float(dx),FY+0.047,ZA+float(i)*0.12),yellow)

func _walls() -> void:
    var alt := _photo("wall_breccia_alt.jpg",Vector2(1.2,0.6),0.42)
    var joint := _material(Color("#5f5548"),0,0.80)
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.90
        box(Vector3(0.28,0.56,105),Vector3(x,0.28,MID),dark)
        box(Vector3(0.27,3.00,105),Vector3(x,2.06,MID),joint)
        for row in range(6):
            for col in range(105):
                var z: float=ZA+(float(col)+0.5);var y: float=0.56+(float(row)+0.5)*0.50
                box(Vector3(0.020,0.496,0.996),Vector3(x-side*0.145,y,z),alt if (row*3+col*7)%5<2 else wall_stone)
        box(Vector3(0.28,0.34,105),Vector3(x,3.73,MID),pale)
        for y in [3.61,3.68]:rod(Vector3(x-side*0.18,float(y),ZA),Vector3(x-side*0.18,float(y),ZB),0.009,black)
        for j in range(5):
            var z: float=2.8+float(j)*18.3
            box(Vector3(0.023,2.10,4.2),Vector3(x-side*0.165,2.38,z),pale)
            if side<0.0:picture("name_ru.jpg",Vector2(4.2,2.10),Vector3(x-side*0.18,2.38,z),-side*PI/2.0)
            else:_name_be(Vector3(x-side*0.19,2.87,z),-side*PI/2.0)
            picture("route_track1.svg" if side>0 else "route_track2.svg",Vector2(4.70,0.745),Vector3(x-side*0.18,2.72,z+7.5),-side*PI/2.0,true)
        for i in range(7):
            var z: float=ZA+8.3+float(i)*14.0
            picture("platform_track1.svg" if side>0 else "platform_track2.svg",Vector2(4.4,0.712),Vector3(CX+side*8.42,4.28,z),-side*PI/2.0)

func _name_be(p: Vector3,yaw: float) -> void:
    var root := Node3D.new();root.name="BronzeBelarusianStationLetters";root.position=p;root.rotation.y=yaw;add_child(root)
    for row in range(2):
        for face in range(3):
            var m := TextMesh.new();m.font=load(ART+"station_letters.ttf");m.text="ПЛОШЧА" if row==0 else "ЛЕНІНА";m.font_size=80
            m.pixel_size=0.0036 if row==0 else 0.0056;m.depth=0.023 if face==0 else 0.004;m.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
            m.material=black if face==0 else gold if face==1 else pale
            var n := MeshInstance3D.new();n.mesh=m;n.position=Vector3(0,-float(row)*0.42,float(face)*0.015)
            var k: float=1.02 if face==0 else 1.0 if face==1 else 0.86;n.scale=Vector3(k,k,1);root.add_child(n)

func _vault() -> void:
    # Continuous low ellipse, with shallow construction joints; cove light bays form the visible scalloped wash.
    var spring := 3.94;var height := 3.88
    var length: float=SOUTH-NORTH
    for bay in range(26):
        var z0: float=NORTH+float(bay)*length/26.0;var z1: float=NORTH+float(bay+1)*length/26.0
        var mat: Material=white.duplicate()
        for j in range(72):
            var a0: float=float(j)*PI/72.0;var a1: float=float(j+1)*PI/72.0
            var a := Vector3(CX+8.96*cos(a0),spring+height*sin(a0),z0)
            var b := Vector3(CX+8.96*cos(a1),spring+height*sin(a1),z0)
            quad(a,b,Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z1),mat,Vector3(CX-(a.x+b.x)*0.5,-1,0))
        if bay%2==0:
            for side in [-1.0,1.0]:
                var light := OmniLight3D.new();light.position=Vector3(CX+side*7.92,4.60,(z0+z1)*0.5);light.light_color=Color(0.94,0.98,1.0);light.light_energy=1.10;light.omni_range=7.3;light.omni_attenuation=1.10;light.shadow_enabled=false;add_child(light)
    var fascia := _material(Color("#c8c8ba"),0.0,0.82)
    for side in [-1.0,1.0]:
        box(Vector3(0.85,0.23,length),Vector3(CX+side*8.48,3.90,MID),fascia)
        box(Vector3(0.65,0.12,length),Vector3(CX+side*8.38,4.06,MID),white)
        box(Vector3(0.16,0.36,length),Vector3(CX+side*8.13,4.24,MID),white)
        box(Vector3(0.15,0.04,length),Vector3(CX+side*8.48,4.29,MID),glow)
        for i in range(26):
            var z: float=NORTH+(float(i)+0.5)*length/26.0
            # Opaque triangular back of the cornice; light source is behind its upper lip.
            var x: float=CX+side*8.07
            quad(Vector3(x,4.12,z-1.35),Vector3(x,3.97,z+1.35),Vector3(x,3.88,z+1.35),Vector3(x,3.88,z-1.35),fascia,Vector3(-side,0,0))
    for z in [8.0,27.0,63.0,77.0]:
        var light := OmniLight3D.new();light.position=Vector3(CX,5.5,float(z));light.omni_range=17;light.light_energy=0.40;light.light_color=Color(0.96,0.96,0.87);add_child(light)

func _lower_interchange() -> void:
    var length: float=WELL_TOP-WELL_BACK
    for side in [-1.0,1.0]:
        var x: float=CX+side*(WELL_HALF+0.08)
        _solid_box(Vector3(0.16,5.65,length),Vector3(x,FY-2.70,(WELL_TOP+WELL_BACK)*0.5),pale)
        box(Vector3(0.21,0.24,length),Vector3(x,FY+0.12,(WELL_TOP+WELL_BACK)*0.5),grey)
        for i in range(10):
            var z: float=WELL_BACK+(float(i)+0.5)*length/10.0
            box(Vector3(0.018,0.93,length/10.0-0.025),Vector3(x,FY+0.77,z),glass)
            rod(Vector3(x,FY+0.23,z-length/20.0),Vector3(x,FY+1.25,z-length/20.0),0.023,metal)
            for y in [0.54,1.24]:rod(Vector3(x,FY+float(y),z-length/20.0),Vector3(x,FY+float(y),z+length/20.0),0.025,metal)
        for i in range(9):
            var z: float=WELL_TOP-0.60-float(i)*1.20
            for j in range(7):box(Vector3(0.013,0.005,1.195),Vector3(x-side*0.090,FY-0.25-float(j)*0.50,z),_material(Color("#c1c1b6"),0,0.8))
    _solid_box(Vector3(4.32,0.24,0.20),Vector3(CX,FY+0.12,WELL_BACK),grey)
    box(Vector3(4.12,0.93,0.018),Vector3(CX,FY+0.77,WELL_BACK),glass)
    for y in [0.54,1.24]:rod(Vector3(CX-2.1,FY+float(y),WELL_BACK),Vector3(CX+2.1,FY+float(y),WELL_BACK),0.026,metal)
    for x in [-1.95,0.0,1.95]:rod(Vector3(CX+float(x),FY+0.24,WELL_BACK),Vector3(CX+float(x),FY+1.25,WELL_BACK),0.023,metal)
    # Two descending flights with a real intermediate landing, individual stone steps and three handrail lines.
    for flight in range(2):
        var zstart: float=WELL_TOP-float(flight)*6.60
        for i in range(18):
            var y: float=FY-float(flight)*2.70-float(i+1)*0.15
            var z: float=zstart-(float(i)+0.5)*0.30
            _solid_box(Vector3(3.98,0.16,0.30),Vector3(CX,y-0.08,z),stair_stone)
            box(Vector3(3.96,0.005,0.045),Vector3(CX,y+0.004,z+0.122),yellow if i in [0,17] else metal)
        for x in [-1.84,0.0,1.84]:
            for h in [0.67,0.96]:
                var a := Vector3(CX+float(x),FY-float(flight)*2.70+float(h),zstart+0.12)
                var b := Vector3(CX+float(x),FY-float(flight+1)*2.70+float(h),zstart-5.4)
                rod(a,b,0.025,metal)
                for i in range(6):
                    var p: Vector3=a.lerp(b,float(i)/5.0)
                    if h==0.96:rod(p,p-Vector3.UP*0.91,0.020,metal)
                if flight==0:rod(b,b-Vector3(0,0,1.20),0.025,metal)
        if flight==0:_solid_box(Vector3(4.0,0.20,1.20),Vector3(CX,FY-2.80,zstart-6.0),grey)
    _solid_box(Vector3(4.0,0.20,6.5),Vector3(CX,LOWER-0.10,WELL_BACK-3.25),grey)
    # The far upper return wall hangs above the lower corridor rather than sealing its mouth.
    box(Vector3(4.0,1.85,0.18),Vector3(CX,FY-0.925,WELL_BACK),white)
    for i in range(39):box(Vector3(0.018,1.70,0.025),Vector3(CX-1.95+float(i)*0.10,FY-0.92,WELL_BACK+0.10),pale)
    for side in [-1.0,1.0]:
        box(Vector3(0.18,3.10,6.5),Vector3(CX+side*2.04,LOWER+1.55,WELL_BACK-3.25),pale)
        for z in [WELL_TOP-2.0,WELL_BACK-1.0]:
            var light := OmniLight3D.new();light.position=Vector3(CX+side*1.6,FY-1.0 if z>WELL_BACK else LOWER+2.2,float(z));light.light_energy=0.60;light.omni_range=5.6;light.light_color=Color(0.94,0.98,1.0);add_child(light)
        box(Vector3(0.045,0.025,length-0.9),Vector3(CX+side*1.93,FY-0.21,(WELL_TOP+WELL_BACK)*0.5),glow)
    box(Vector3(4.2,0.15,6.5),Vector3(CX,LOWER+3.20,WELL_BACK-3.25),white)
    picture("transfer.svg",Vector2(2.80,0.616),Vector3(CX,LOWER+1.95,WELL_BACK-6.42),0)
    box(Vector3(4.0,3.1,0.08),Vector3(CX,LOWER+1.55,WELL_BACK-6.5),dark)
    for name in ["LowerTransferEntrance","LowerTransferLanding","TransferToVakzalnaya","BypassLeft","BypassRight"]:
        var p := Vector3(CX,FY,WELL_TOP+0.8)
        if name=="LowerTransferLanding":p=Vector3(CX,FY-2.70,WELL_TOP-6.0)
        elif name=="TransferToVakzalnaya":p=Vector3(CX,LOWER,WELL_BACK-6.2)
        elif name=="BypassLeft":p=Vector3(CX-3.1,FY,(WELL_TOP+WELL_BACK)*0.5)
        elif name=="BypassRight":p=Vector3(CX+3.1,FY,(WELL_TOP+WELL_BACK)*0.5)
        var marker := Marker3D.new();marker.name=name;marker.position=p;get_node("PassengerAnchors").add_child(marker)
    _stair_pole(WELL_TOP+0.38)
    for x in [-1.03,1.03]:_floor_sign("no_entrance_floor.svg",Vector3(CX+float(x),FY+0.05,WELL_TOP+0.61),Vector2(0.65,0.215))

func _floor_sign(file: String,p: Vector3,size: Vector2) -> void:
    var m := StandardMaterial3D.new();m.albedo_texture=load(ART+file);m.roughness=0.65
    var q := QuadMesh.new();q.size=size;q.material=m;var n := MeshInstance3D.new();n.mesh=q;n.rotation.x=-PI/2.0;n.position=p;add_child(n)

func _stair_pole(z: float) -> void:
    cylinder(0.105,0.045,Vector3(CX,FY+0.022,z),metal)
    cylinder(0.065,4.65,Vector3(CX,FY+2.325,z),metal)
    for y in [0.15,2.8,3.2,4.5]:cylinder(0.080,0.05,Vector3(CX,FY+float(y),z),metal)
    sphere(Vector3(0.35,0.40,0.35),Vector3(CX,FY+4.88,z),glow)
    for h in [0.67,0.96]:
        var pts: Array[Vector3]=[]
        for i in range(25):
            var a: float=float(i)*PI/24.0;pts.append(Vector3(CX+0.17*cos(a),FY+float(h),z+0.29*sin(a)))
        for i in range(pts.size()-1):rod(pts[i],pts[i+1],0.026,metal)
    board("no_entrance.svg",Vector3(CX,FY+3.48,z-0.11),Vector2(0.98,0.327))
    for side in [-1.0,1.0]:
        rod(Vector3(CX,FY+3.64,z),Vector3(CX+side*1.6,FY+3.64,z),0.011,metal)
    picture("transfer.svg",Vector2(1.6,0.352),Vector3(CX,FY+2.60,z+0.09),0)

func _order_pylon() -> void:
    var z := 24.2
    _solid_box(Vector3(0.50,0.12,0.55),Vector3(CX,FY+0.06,z),dark)
    box(Vector3(0.34,3.65,0.25),Vector3(CX,FY+1.94,z),pale)
    for x in [-0.18,0.18]:box(Vector3(0.035,3.75,0.29),Vector3(CX+float(x),FY+1.95,z),gold)
    var centre := Vector3(CX,FY+4.35,z)
    var copper := _material(Color("#80513a"),0.64,0.42)
    # Faceted solid order body, native metal rims and separately curved laurel leaves.
    for face in [-1.0,1.0]:
        var outline: Array[Vector3]=[]
        for j in range(12):
            var a: float=float(j)*TAU/12.0
            outline.append(centre+Vector3(sin(a)*0.87,cos(a)*0.87,face*0.12))
        for j in range(12):
            var a: Vector3=outline[j];var b: Vector3=outline[(j+1)%12]
            triangle(centre+Vector3(0,0,face*0.14),a,b,copper,Vector3(0,0,face))
            rod(a,b,0.025,gold)
            quad(a,b,Vector3(b.x,b.y,-face*0.12),Vector3(a.x,a.y,-face*0.12),copper)
        _photo_relief("order_face",centre+Vector3(0,0,face*0.16),Vector2(1.66,1.66),0.0 if face>0 else PI,0.07)
    for side in [-1.0,1.0]:
        var branch: Array[Vector3]=[]
        for i in range(9):
            var t: float=float(i)/8.0
            var p := centre+Vector3(side*(0.25+1.10*t-0.27*t*t),-0.87+0.90*t,0)
            branch.append(p)
            for k in [-1.0,1.0]:
                var tip: Vector3=p+Vector3(side*(0.23 if k>0 else -0.10),0.26,0)
                _leaf(p,tip,0.105,gold)
        for i in range(branch.size()-1):rod(branch[i],branch[i+1],0.018,gold)
    for side in [-1.0,1.0]:
        var p := Vector3(CX+side*1.65,FY+4.27,z)
        box(Vector3(1.38,0.86,0.10),p,black)
        for face in [-1.0,1.0]:box(Vector3(1.29,0.77,0.008),p+Vector3(0,0,face*0.058),_material(Color("#101418"),0.25,0.20))
        rod(p+Vector3(0,0.44,0),Vector3(p.x,7.42,z),0.014,metal)
    for side in [-1.0,1.0]:
        var p := Vector3(CX+side*0.62,FY,z)
        box(Vector3(0.52,0.36,3.7),p+Vector3(0,0.18,0),dark)
        for i in range(9):box(Vector3(0.049,0.065,3.65),p+Vector3(-0.22+float(i)*0.055,0.47,0),timber)
    for zz in [z-0.20,z+0.20]:rod(Vector3(CX-1.95,7.47,zz),Vector3(CX+1.95,7.47,zz),0.020,metal)

func _leaf(base: Vector3,tip: Vector3,w: float,mat: Material) -> void:
    var tangent := Vector3(-(tip-base).y,(tip-base).x,0).normalized()*w
    var mid: Vector3=base.lerp(tip,0.48)
    var peak: Vector3=mid+Vector3(0,0,0.07)
    for edge in [mid+tangent,mid-tangent]:
        triangle(base,edge,peak,mat);triangle(edge,tip,peak,mat)
        triangle(base,edge,mid-Vector3(0,0,0.03),mat);triangle(edge,tip,mid-Vector3(0,0,0.03),mat)

func _photo_relief(file: String,p: Vector3,size: Vector2,yaw: float,depth: float) -> void:
    var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ART+file+".json"));var nx: int=int(data["width"]);var ny: int=int(data["height"]);var heights: Array=data["values"]
    var m := StandardMaterial3D.new();m.albedo_texture=load(ART+file+".png");m.roughness=0.46;m.metallic=0.50;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;m.alpha_scissor_threshold=0.4;m.cull_mode=BaseMaterial3D.CULL_DISABLED
    var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for y in range(ny-1):
        for x in range(nx-1):
            for off in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
                var ix: int=x+off.x;var iy: int=y+off.y;var u: float=float(ix)/float(nx-1);var v: float=float(iy)/float(ny-1)
                var dx: float=(float(heights[iy*nx+mini(ix+1,nx-1)])-float(heights[iy*nx+maxi(ix-1,0)]))/255.0*depth*float(nx)/size.x
                var dy: float=(float(heights[mini(iy+1,ny-1)*nx+ix])-float(heights[maxi(iy-1,0)*nx+ix]))/255.0*depth*float(ny)/size.y
                st.set_normal(Vector3(-dx,dy,1).normalized());st.set_uv(Vector2(u,v));st.add_vertex(Vector3((u-0.5)*size.x,(0.5-v)*size.y,float(heights[iy*nx+ix])/255.0*depth))
    st.generate_tangents();var mesh := st.commit();mesh.surface_set_material(0,m)
    var n := MeshInstance3D.new();n.name="OwnerReferencedMetalRelief";n.mesh=mesh;n.position=p;n.rotation.y=yaw;add_child(n)

func _exit(direction: float,start: float,portrait: bool) -> void:
    var width := 7.20
    for flight in range(2):
        for i in range(14):
            var y: float=FY+float(flight)*2.10+float(i+1)*0.15
            var s: float=float(flight)*5.40+(float(i)+0.5)*0.30
            _solid_box(Vector3(width,0.16,0.30),Vector3(CX,y-0.08,start+direction*s),stair_stone)
            box(Vector3(width-0.03,0.012,0.06),Vector3(CX,y+0.008,start+direction*(s-0.12)),yellow if i in [0,13] else dark)
        if flight==0:_solid_box(Vector3(width,0.20,1.20),Vector3(CX,FY+2.0,start+direction*4.8),grey)
        for side in [-1.0,1.0]:
            for h in [0.72,1.02]:
                var a := Vector3(CX+side*3.36,FY+float(flight)*2.10+float(h),start+direction*(float(flight)*5.4-0.12))
                var b := Vector3(a.x,FY+float(flight+1)*2.10+float(h),start+direction*(float(flight)*5.4+4.2))
                rod(a,b,0.026,metal)
                if flight==0:rod(b,b+Vector3(0,0,direction*1.2),0.026,metal)
    _solid_box(Vector3(width,0.20,4.5),Vector3(CX,FY+4.10,start+direction*11.85),grey)
    for side in [-1.0,1.0]:
        box(Vector3(0.28,7.25,14.2),Vector3(CX+side*3.74,FY+3.625,start+direction*7.0),pale)
        for i in range(8):box(Vector3(0.02,0.003,14.1),Vector3(CX+side*3.585,FY+float(i)*0.6,start+direction*7.0),dark)
    box(Vector3(width+0.6,0.18,14.3),Vector3(CX,8.65,start+direction*7.0),white)
    for i in range(9):
        var z: float=start+direction*float(i)*1.55
        box(Vector3(width+0.4,0.18,0.22),Vector3(CX,8.45,z),white)
        box(Vector3(5.6,0.035,0.055),Vector3(CX,8.34,z),glow)
    for side in [-1.0,1.0]:box(Vector3(1.08,2.8,0.35),Vector3(CX+side*3.2,6.40,start),pale)
    box(Vector3(width+0.5,1.5,0.35),Vector3(CX,7.72,start),white)
    board("exit_south.svg" if portrait else "exit_north.svg",Vector3(CX,4.66,start-direction*0.4),Vector2(5.8,0.918))
    box(Vector3(width+0.3,3.0,0.18),Vector3(CX,FY+5.70,start+direction*14.1),pale)
    if portrait:
        var z: float=start+direction*13.9
        box(Vector3(3.1,1.8,0.12),Vector3(CX,FY+5.15,z),wall_stone)
        _photo_relief("lenin_relief",Vector3(CX,FY+5.25,z-direction*0.10),Vector2(2.60,1.43),PI,0.25)
    for side in [-1.0,1.0]:
        var p := Vector3(CX+side*2.24,5.48,start-direction*0.30)
        box(Vector3(1.45,0.82,0.09),p,black)
        # The side screens in the owner's end views display changing colour advertisements.
        var screen := _material(Color("#8c9b9d"),0.05,0.38);screen.emission_enabled=true;screen.emission=Color(0.20,0.24,0.22);screen.emission_energy_multiplier=0.28
        box(Vector3(1.35,0.73,0.008),p+Vector3(0,0,-direction*0.051),screen)

func _fittings() -> void:
    for z in [11.0,31.0,59.0,74.0]:
        cylinder(0.21,0.014,Vector3(CX+0.20,FY+0.045,float(z)),dark)
        for row in range(7):
            for col in range(7):
                var x: float=-0.13+float(col)*0.043;var dz: float=-0.13+float(row)*0.043
                if x*x+dz*dz<0.034:cylinder(0.009,0.016,Vector3(CX+0.20+x,FY+0.051,float(z)+dz),metal)
        box(Vector3(0.31,0.018,0.43),Vector3(CX+0.12,FY+0.050,float(z)+1.2),dark)
        for i in range(9):box(Vector3(0.25,0.021,0.017),Vector3(CX+0.12,FY+0.057,float(z)+1.03+float(i)*0.04),metal)

func _track_details() -> void:
    for name in ["Track1","Track2"]:
        var root := get_node(name)
        (root.get_node("Beds") as MultiMeshInstance3D).multimesh.mesh.material=_material(Color("#34322c"),0.0,0.92)
        (root.get_node("Sleepers") as MultiMeshInstance3D).multimesh.mesh.material=_material(Color("#3b3730"),0.0,0.91)
        var x: float=0.992 if name=="Track1" else -11.732
        for i in range(161):
            var z: float=ZA+float(i)*0.65
            for dx in [-0.8075,0.8075]:box(Vector3(0.21,0.025,0.15),Vector3(x+float(dx),-0.11,z),black)
        for direction in [-1.0,1.0]:
            var end: float=NORTH if direction<0.0 else SOUTH
            box(Vector3(3.78,0.20,8.0),Vector3(x,4.90,end+direction*3.9),wall_stone)
            for side in [-1.0,1.0]:
                box(Vector3(0.14,4.60,8.0),Vector3(x+side*1.94,2.12,end+direction*3.9),wall_stone)
                for h in [0.70,1.1,1.5,1.9,2.35,2.65]:rod(Vector3(x+side*1.84,float(h),end),Vector3(x+side*1.84,float(h),end+direction*7.8),0.015,black)
            box(Vector3(3.85,4.65,0.10),Vector3(x,2.13,end+direction*8.0),black)

func _portal_equipment() -> void:
    var infra := get_node("StationInfrastructure")
    infra.set("_amber",Color(1.0,0.13,0.055))
    var displays: Array=infra.get("_displays")
    for display in displays:
        for i in range(70,76):display.set_instance_color(i,Color(1.0,0.13,0.055))
    for node in infra.get_children():
        if node is Node3D and "Portal" in str(node.name):
            node.position.y=4.22;node.position.z=NORTH if node.position.z<MID else SOUTH
    for direction in [-1.0,1.0]:
        var end: float=NORTH if direction<0.0 else SOUTH
        for side in [-1.0,1.0]:
            var tx: float=CX+side*6.362
            var yaw: float=0.0 if direction<0.0 else PI
            box(Vector3(3.90,0.48,0.25),Vector3(tx,4.33,end),wall_stone)
            var root := Node3D.new();root.name="WhiteDriverMirror";root.position=Vector3(CX+side*4.58,FY+1.42,end-direction*2.6);root.rotation.y=yaw-side*0.12;add_child(root)
            var mirror := MeshInstance3D.new();mirror.set_script(preload("res://modules/stations/ploshchad_lenina/driver_mirrors.gd"));mirror.name="ReflectingSurface";mirror.position.z=0.016
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
            var p := Vector3(tx-side*1.42,4.68,end-direction*0.16)
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

