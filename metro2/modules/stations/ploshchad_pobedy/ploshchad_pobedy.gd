extends "res://modules/stations/ploshchad_pobedy/station_builder.gd"
## Ploshchad Pobedy V65.1, owner-reference reconstruction: 40 owner photos and both complete video clips.
const ART := "res://modules/stations/ploshchad_pobedy/art/"
const NORTH := -5.10
const SOUTH := 84.20
const PITCH := 4.80
const COL_X := 2.55
var wall_stone: StandardMaterial3D
var column_stones: Array[StandardMaterial3D]=[]
var stair_stone: StandardMaterial3D
var trim: StandardMaterial3D
var yellow: StandardMaterial3D
var floor_stone: StandardMaterial3D
var floor_dark: StandardMaterial3D
var lettering: StandardMaterial3D
var floor_red: StandardMaterial3D
var bronze: StandardMaterial3D
var lamp_bead: StandardMaterial3D
var lamp_tube: StandardMaterial3D
var oak: StandardMaterial3D

func _ready() -> void:
    super._ready()
    begin_station()
    white=_photo("ceiling_paint.jpg",Vector2(1.0,1.0),0.90)
    white.normal_enabled=true;white.normal_texture=load(ART+"ceiling_normal.png");white.normal_scale=0.045
    wall_stone=_photo("wall_marble.jpg",Vector2(0.90,0.90),0.46)
    granite=_photo("plinth_granite.jpg",Vector2(0.65,0.65),0.48)
    stair_stone=_photo("stair_granite.jpg",Vector2(0.55,0.55),0.62)
    floor_stone=_photo("floor_grey.jpg",Vector2(0.60,0.60),0.42)
    floor_dark=_photo("floor_dark.jpg",Vector2(0.75,0.75),0.45)
    floor_red=_photo("floor_red.jpg",Vector2(0.6,0.6),0.38)
    trim=_material(Color("#a6a493"),0.12,0.52)
    brass=_material(Color("#8d6b38"),0.50,0.37)
    bronze=_material(Color("#6f4c2d"),0.38,0.43)
    lamp_bead=_material(Color("#ad9060"),0.25,0.29)
    lamp_tube=_material(Color("#cdb585"),0.05,0.46)
    lamp_tube.emission_enabled=true;lamp_tube.emission=Color(0.70,0.47,0.20);lamp_tube.emission_energy_multiplier=0.13
    lettering=_material(Color("#b69b60"),0.45,0.32)
    yellow=_material(Color("#d7ad39"),0.0,0.67)
    oak=_photo("bench_oak.jpg",Vector2(0.65,0.30),0.48)
    for i in range(4):
        var m := _photo("column_marble.jpg" if i%2==0 else "column_marble_alt.jpg",Vector2(0.80,0.80),0.41)
        m.uv1_offset=Vector3(float(i)*0.21,float(i)*0.13,0.0)
        column_stones.append(m)
    for file in ["floor_red","floor_grey","floor_dark"]:
        var mat: StandardMaterial3D=floor_red if file=="floor_red" else floor_stone if file=="floor_grey" else floor_dark
        mat.normal_enabled=true;mat.normal_texture=load(ART+file+"_normal.png");mat.normal_scale=0.12
    _floor()
    _walls()
    _columns_and_girders()
    _ceilings()
    _stairs(-1.0,NORTH)
    _escalators(SOUTH)
    _signs()
    _track_details()
    _portal_equipment()
    _floor_fittings()
    for z in [12.0,39.6,67.0]:_television(float(z),true)
    for side in [-1.0,1.0]:
        for bay in [3,7,11,15]:_bench(Vector3(CX+side*COL_X,FY,-1.2+(float(bay)+0.5)*PITCH))
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
    # One material per paving cell, all at exactly the same top plane: no overlapping cross-stripes.
    var xs: Array[float]=[-5.0,-4.50,-4.31,-3.10,-2.90,-2.15,-1.95,1.95,2.15,2.90,3.10,4.31,4.50,5.0]
    var zs: Array[float]=[ZA,ZB]
    for i in range(8):xs.append(-4.2+float(i)*1.2)
    for i in range(175):zs.append(ZA+float(i)*0.60)
    for i in range(18):
        var z: float=-1.2+float(i)*PITCH
        for off in [-0.60,-0.38,0.38,0.60]:zs.append(z+float(off))
    xs.sort();zs.sort()
    var edge := _material(Color("#9f9786"),0,0.65)
    for ix in range(xs.size()-1):
        for iz in range(zs.size()-1):
            var w: float=xs[ix+1]-xs[ix];var l: float=zs[iz+1]-zs[iz]
            if w<0.004 or l<0.004:continue
            var x: float=(xs[ix]+xs[ix+1])*0.5;var z: float=(zs[iz]+zs[iz+1])*0.5
            var near: float=abs(fposmod(z+1.2+PITCH*0.5,PITCH)-PITCH*0.5)
            var cross_band: bool=near<0.38 and z>-1.8 and z<81.1
            var border: bool=near<0.60 and z>-1.8 and z<81.1
            var mat: Material=floor_red
            if abs(x)>4.50:mat=edge
            elif abs(x)>4.31:mat=yellow
            elif cross_band:mat=floor_dark
            elif border:mat=floor_stone
            elif abs(x)>2.15 and abs(x)<2.90:mat=floor_dark
            elif (abs(x)>1.95 and abs(x)<2.15) or (abs(x)>2.90 and abs(x)<3.10):mat=floor_stone
            box(Vector3(w-0.002,0.012,l-0.002),Vector3(CX+x,FY+0.015,z),mat)
    for side in [-1.0,1.0]:
        for i in range(1312):
            for dx in [-0.058,0.0,0.058]:cylinder(0.010,0.004,Vector3(CX+side*4.405+float(dx),FY+0.025,ZA+0.04+float(i)*0.08),yellow)

func _wall_names() -> Array[float]:
    return [1.8,20.6,39.4,58.2,77.0]

func _walls() -> void:
    var bed := _material(Color("#8c8779"),0.0,0.76)
    var alternate := _photo("wall_marble_alt.jpg",Vector2(0.90,0.90),0.46)
    var names: Array[float]=_wall_names()
    var y0: float=FY+0.70
    var cuts_y: Array[float]=[y0,3.08,3.56,6.20]
    var cuts_z: Array[float]=[ZA,ZB]
    for i in range(8):
        var y: float=y0+float(i)*0.60
        if y<6.20:cuts_y.append(y)
    for i in range(88):cuts_z.append(ZA+float(i)*1.20)
    for z in names:cuts_z.append(z-2.48);cuts_z.append(z+2.48)
    cuts_y.sort();cuts_z.sort()
    for side in [-1.0,1.0]:
        # Base at the BACK of each recess; a separate marble skin forms the visible wall.
        var x: float=CX+side*8.90
        box(Vector3(0.36,6.2-y0,105),Vector3(CX+side*9.10,(y0+6.2)*0.5,MID),bed)
        box(Vector3(0.30,y0,105),Vector3(x,y0*0.5,MID),granite)
        for iy in range(cuts_y.size()-1):
            for iz in range(cuts_z.size()-1):
                var h: float=cuts_y[iy+1]-cuts_y[iy];var w: float=cuts_z[iz+1]-cuts_z[iz]
                if h<0.004 or w<0.004:continue
                var y: float=(cuts_y[iy]+cuts_y[iy+1])*0.5;var z: float=(cuts_z[iz]+cuts_z[iz+1])*0.5
                var opening: bool=false
                if y>3.08 and y<3.56:
                    for center in names:
                        if abs(z-center)<2.48:opening=true
                if not opening:box(Vector3(0.16,h-0.002,w-0.002),Vector3(CX+side*8.84,y,z),alternate if (iy+iz)%7==0 else wall_stone)
        rod(Vector3(CX+side*8.73,4.88,ZA),Vector3(CX+side*8.73,4.88,ZB),0.014,metal)
        for j in range(74):box(Vector3(0.025,0.035,0.022),Vector3(CX+side*8.72,4.88,ZA+float(j)*1.44),bronze)
        for z in names:
            _name_recess(side,z)
            picture("route_track1.svg" if side>0 else "route_track2.svg",Vector2(4.92,0.80),Vector3(CX+side*8.70,2.60,z),-side*PI/2.0,true)
        box(Vector3(0.035,0.020,105),Vector3(CX+side*8.73,y0+0.01,MID),metal)

func _name_recess(side: float,z: float) -> void:
    var yaw: float=-side*PI/2.0
    # Actual opening, 14cm deep, with back, four stone reveals and a narrow shaded upper lip.
    box(Vector3(0.012,0.48,4.96),Vector3(CX+side*8.917,3.32,z),wall_stone)
    for dz in [-2.48,2.48]:box(Vector3(0.16,0.48,0.025),Vector3(CX+side*8.84,3.32,z+float(dz)),wall_stone)
    for y in [3.08,3.56]:box(Vector3(0.16,0.025,4.96),Vector3(CX+side*8.84,float(y),z),wall_stone)
    box(Vector3(0.13,0.015,4.93),Vector3(CX+side*8.843,3.545,z),bronze)
    _lit_picture("name_be.jpg" if side>0 else "name_ru.jpg",Vector2(4.84,0.405),Vector3(CX+side*8.895,3.32,z),yaw)

func _lit_picture(file: String,size: Vector2,p: Vector3,yaw: float) -> void:
    var mat := StandardMaterial3D.new();mat.albedo_texture=load(ART+file);mat.roughness=0.52
    mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    var q := QuadMesh.new();q.size=size;q.material=mat
    var n := MeshInstance3D.new();n.mesh=q;n.position=p;n.rotation.y=yaw;add_child(n)

func _capital_radius(t: float) -> float:
    return 0.42+0.98*pow(t,2.30)

func _capital_point(o: Vector3,face: int,t: float,u: float,offset: float=0.0) -> Vector3:
    var angle: float=float(face)*PI/2.0
    var radial := Vector3(sin(angle),0,cos(angle))
    var tangent := Vector3(cos(angle),0,-sin(angle))
    var r: float=_capital_radius(t)
    return o+radial*(r+offset)+tangent*u+Vector3.UP*(4.12+1.98*t)

func _columns_and_girders() -> void:
    var joint := _material(Color("#969184"),0.10,0.60)
    for side in [-1.0,1.0]:
        var x: float=CX+side*COL_X
        for i in range(18):
            var z: float=-1.2+float(i)*PITCH
            var o := Vector3(x,0,z)
            box(Vector3(0.85,0.075,0.85),Vector3(x,FY+0.0375,z),black)
            box(Vector3(0.84,4.12-FY-0.075,0.84),Vector3(x,(4.12+FY+0.075)*0.5,z),column_stones[i%4])
            for y in [FY+0.91,FY+1.82,FY+2.71]:
                box(Vector3(0.842,0.002,0.842),Vector3(x,float(y),z),joint)
            for face in range(4):
                var angle: float=float(face)*PI/2.0
                var radial := Vector3(sin(angle),0,cos(angle))
                var tangent := Vector3(cos(angle),0,-sin(angle))
                for off in [-0.045,0.045]:
                    box(Vector3(0.006,2.86,0.004),o+radial*0.422+tangent*float(off)+Vector3.UP*(FY+1.50),joint,Basis(Vector3.UP,angle))
                # Smooth, CLOSED square trumpet capital. Fixtures wrap its corners, not four floating triangles.
                for row in range(28):
                    var t0: float=float(row)/28.0;var t1: float=float(row+1)/28.0
                    var r0: float=_capital_radius(t0);var r1: float=_capital_radius(t1)
                    quad(_capital_point(o,face,t0,-r0),_capital_point(o,face,t0,r0),_capital_point(o,face,t1,r1),_capital_point(o,face,t1,-r1),white,radial-Vector3.UP)
                for wing in [-1.0,1.0]:_lamp_wing(o,face,wing)
                var corner: Vector3=(radial+tangent).normalized()*0.597
                rod(o+corner+Vector3.UP*3.61,o+corner+Vector3.UP*4.58,0.012,brass)
            box(Vector3(2.80,0.14,2.80),Vector3(x,6.17,z),white)

func _lamp_point(o: Vector3,face: int,wing: float,t: float,u: float,offset: float=0.022) -> Vector3:
    var level: float=0.21+t*0.715
    var inner: float=0.24+0.045*t
    var outer: float=_capital_radius(level)-0.035
    return _capital_point(o,face,level,wing*lerpf(inner,outer,u),offset)

func _lamp_wing(o: Vector3,face: int,wing: float) -> void:
    var angle: float=float(face)*PI/2.0
    var radial := Vector3(sin(angle),0,cos(angle))
    # Brown stamped-metal trays, slender amber tubes, rows of bronze cups and muted glass beads.
    for row in range(18):
        var t0: float=float(row)/18.0;var t1: float=float(row+1)/18.0
        quad(_lamp_point(o,face,wing,t0,0),_lamp_point(o,face,wing,t0,1),_lamp_point(o,face,wing,t1,1),_lamp_point(o,face,wing,t1,0),bronze,radial-Vector3.UP)
        for u in [0.0,1.0]:rod(_lamp_point(o,face,wing,t0,float(u),0.030),_lamp_point(o,face,wing,t1,float(u),0.030),0.010,brass)
        for lane in range(5):
            var u: float=(float(lane)+0.5)/5.0
            rod(_lamp_point(o,face,wing,t0,u,0.041),_lamp_point(o,face,wing,t1,u,0.041),0.006,brass)
            if lane in [1,3]:rod(_lamp_point(o,face,wing,t0,u,0.048),_lamp_point(o,face,wing,t1,u,0.048),0.009,lamp_tube)
    for row in range(10):
        var t: float=0.05+float(row)*0.10
        rod(_lamp_point(o,face,wing,t,0,0.035),_lamp_point(o,face,wing,t,1,0.035),0.006,brass)
        var count: int=2+int(t*3.0)
        for j in range(count):
            var u: float=(float(j)+0.5)/float(count)
            var p: Vector3=_lamp_point(o,face,wing,t,u,0.052)
            sphere(Vector3(0.048,0.045,0.048),p,brass)
            sphere(Vector3(0.027,0.028,0.027),p+radial*0.016,lamp_bead)

func _ceilings() -> void:
    # Solid white soffit, recessed panel fields and narrow panel joints instead of repeated Academy ribs.
    box(Vector3(7.7,0.18,SOUTH-NORTH),Vector3(CX,6.30,(SOUTH+NORTH)*0.5),white)
    for side in [-1.0,1.0]:box(Vector3(5.15,0.18,105),Vector3(CX+side*6.425,6.30,MID),white)
    var seam := _material(Color("#c1c2b9"),0.0,0.80)
    for i in range(44):
        var z: float=ZA+1.2+float(i)*2.4
        if z>NORTH and z<SOUTH:box(Vector3(7.70,0.004,0.008),Vector3(CX,6.203,z),seam)
        for side in [-1.0,1.0]:box(Vector3(5.15,0.004,0.008),Vector3(CX+side*6.425,6.203,z),seam)
    for j in range(8):
        var x: float=CX-8.4+float(j)*2.4
        var central: bool=abs(x-CX)<3.85
        box(Vector3(0.008,0.004,SOUTH-NORTH if central else 105.0),Vector3(x,6.203,(SOUTH+NORTH)*0.5 if central else MID),seam)
    for side in [-1.0,1.0]:box(Vector3(0.44,0.30,SOUTH-NORTH),Vector3(CX+side*COL_X,6.12,(SOUTH+NORTH)*0.5),white)
    for i in range(18):
        var z: float=-1.2+float(i)*PITCH
        box(Vector3(17.9,0.30,0.44),Vector3(CX,6.12,z),white)
    for child in get_children():
        if child is OmniLight3D:
            child.position.y=5.52;child.light_energy=0.78;child.light_color=Color(1.0,0.96,0.88)
    # Local non-shadowing pools at selected lamp heads, with restrained falloff.
    for i in range(6):
        for side in [-1.0,1.0]:
            var light := OmniLight3D.new()
            light.position=Vector3(CX+side*COL_X,5.3,1.2+float(i)*15.4)
            light.light_energy=0.12;light.light_color=Color(1.0,0.87,0.62);light.omni_range=6.5;light.shadow_enabled=false;add_child(light)

func _stairs(direction: float,start: float) -> void:
    var width := 7.12
    var rise := 0.145
    var run := 0.31
    var landing := 1.15
    var count := 32
    var top: float=FY+float(count)*rise
    var riser := stair_stone.duplicate() as StandardMaterial3D;riser.albedo_color=Color(0.76,0.76,0.73)
    for i in range(count):
        var y: float=FY+float(i+1)*rise
        var z: float=start+direction*(float(i)*run+(landing if i>=16 else 0.0))
        for slab in range(5):
            var x: float=CX-width*0.5+(float(slab)+0.5)*width/5.0
            box(Vector3(width/5.0-0.003,0.055,run-0.002),Vector3(x,y-0.0275,z),stair_stone)
            box(Vector3(width/5.0-0.003,rise-0.052,0.022),Vector3(x,y-rise*0.5-0.026,z-direction*(run*0.5-0.012)),riser)
        box(Vector3(width,0.005,0.026),Vector3(CX,y+0.003,z-direction*0.125),yellow if i in [0,15,16,31] else metal)
    var middle: float=start+direction*(15.5*run+landing*0.5)
    box(Vector3(width,0.08,landing),Vector3(CX,FY+16.0*rise-0.04,middle),stair_stone)
    var finish: float=start+direction*(31.5*run+landing)
    box(Vector3(width,0.15,3.40),Vector3(CX,top-0.075,finish+direction*1.7),floor_stone)
    _exit_hall(direction,start,width,top,14.7)
    for side in [-1.0,1.0]:
        var x: float=CX+side*(width*0.5-0.11)
        var points: Array[Vector2]=[Vector2(-0.32,0),Vector2(15.5*run,16.0*rise),Vector2(15.5*run+landing,16.0*rise),Vector2(31.5*run+landing,32.0*rise),Vector2(13.5,32.0*rise)]
        for i in range(points.size()-1):
            var a: Vector2=points[i];var b: Vector2=points[i+1]
            rod(Vector3(x,FY+0.90+a.y,start+direction*a.x),Vector3(x,FY+0.90+b.y,start+direction*b.x),0.025,metal)
            for j in range(3):
                var t: float=(float(j)+0.5)/3.0;var q: Vector2=a.lerp(b,t)
                rod(Vector3(x,FY+0.90+q.y,start+direction*q.x),Vector3(x+side*0.11,FY+0.80+q.y,start+direction*q.x),0.011,metal)
    board("exit_stairs.svg",Vector3(CX,4.66,start-direction*0.50),Vector2(5.90,0.959))
    _landing(start-direction*0.75,7.35,0.55)

func _escalator_height(s: float) -> float:
    if s<1.0:return 0.0
    if s<2.60:return 0.58*pow(s-1.0,2.0)/3.20
    if s<10.40:return 0.464+(s-2.60)*0.58
    if s<12.0:
        var t: float=s-10.40
        return 4.988+0.58*t-0.58*t*t/3.20
    return 5.452

func _escalators(start: float) -> void:
    var width := 7.12
    var rubber := _material(Color("#1d201d"),0.0,0.52)
    var stepmat := _material(Color("#555a54"),0.55,0.46)
    var casing := _photo("escalator_oak.jpg",Vector2(0.65,0.80),0.47)
    _exit_hall(1.0,start,width,FY+5.452,16.5)
    _landing(start+0.18,7.12,1.60)
    for lane in range(3):
        var x: float=CX+(float(lane)-1.0)*2.0
        for i in range(54):
            var s: float=-0.20+float(i)*0.25
            var y: float=_escalator_height(s)
            box(Vector3(1.39,0.055,0.246),Vector3(x,FY+y+0.028,start+s),stepmat)
            var h: float=maxf(0.005,y-_escalator_height(s-0.25))
            box(Vector3(1.39,h,0.018),Vector3(x,FY+y-h*0.5,start+s-0.123),stepmat)
            for groove in range(18):box(Vector3(0.005,0.005,0.242),Vector3(x-0.65+float(groove)*0.076,FY+y+0.058,start+s),black)
        for j in range(70):box(Vector3(0.007,0.017,0.075),Vector3(x-0.67+float(j)*0.0193,FY+0.065,start-0.35),metal)
    # Four SHARED balustrades, each with continuous curved transitions and a rounded return nose.
    for boundary in range(4):
        var x: float=CX-3.0+float(boundary)*2.0
        var outline := PackedVector2Array()
        var rail: Array[Vector3]=[]
        for i in range(76):
            var s: float=float(i)*0.18
            var h: float=_escalator_height(s)
            outline.append(Vector2(s,h+0.84));rail.append(Vector3(x,FY+h+0.86,start+s))
        for i in range(75,-1,-1):
            var s: float=float(i)*0.18
            outline.append(Vector2(s,_escalator_height(s)+0.10))
        for j in range(17):
            var a: float=-PI/2.0-float(j)*PI/16.0
            outline.append(Vector2(0.37*cos(a),0.47+0.37*sin(a)))
        _side_panel(outline,x-0.26,x+0.26,start,casing)
        for i in range(rail.size()-1):
            rod(rail[i],rail[i+1],0.045,rubber)
            for off in [-0.263,0.263]:rod(rail[i]+Vector3(float(off),-0.055,0),rail[i+1]+Vector3(float(off),-0.055,0),0.018,metal)
        for j in range(24):
            var a0: float=PI/2.0+float(j)*PI/24.0;var a1: float=PI/2.0+float(j+1)*PI/24.0
            var a := Vector3(x,FY+0.47+0.39*sin(a0),start+0.39*cos(a0))
            var b := Vector3(x,FY+0.47+0.39*sin(a1),start+0.39*cos(a1))
            rod(a,b,0.045,rubber)
            for off in [-0.263,0.263]:rod(a+Vector3(float(off),-0.035,0),b+Vector3(float(off),-0.035,0),0.019,metal)
        box(Vector3(0.28,0.69,0.27),Vector3(x,FY+0.345,start-0.63),metal)
        box(Vector3(0.29,0.055,0.28),Vector3(x,FY+0.03,start-0.63),black)
        picture("escalator_warning.svg",Vector2(0.20,0.23),Vector3(x,FY+0.30,start-0.771),PI)
        if boundary in [1,2]:
            box(Vector3(0.075,1.63,0.075),Vector3(x,FY+0.815,start-0.63),black)
            var status := _material(Color("#c02151") if boundary==1 else Color("#30a56c"),0,0.50)
            status.emission_enabled=true;status.emission=status.albedo_color;status.emission_energy_multiplier=0.45
            box(Vector3(0.071,0.12,0.008),Vector3(x,FY+1.52,start-0.673),status)
    box(Vector3(width,0.16,3.1),Vector3(CX,FY+5.452-0.08,start+14.5),floor_stone)
    board("exit_escalators.svg",Vector3(CX,4.66,start-0.88),Vector2(5.90,0.959))

func _side_panel(points: PackedVector2Array,x0: float,x1: float,z0: float,mat: Material) -> void:
    var caps := Geometry2D.triangulate_polygon(points)
    for side in [0,1]:
        var x: float=x0 if side==0 else x1
        for j in range(0,caps.size(),3):
            var a: Vector2=points[caps[j]];var b: Vector2=points[caps[j+1]];var c: Vector2=points[caps[j+2]]
            triangle(Vector3(x,FY+a.y,z0+a.x),Vector3(x,FY+b.y,z0+b.x),Vector3(x,FY+c.y,z0+c.x),mat,Vector3(-1 if side==0 else 1,0,0))
    for j in range(points.size()):
        var a: Vector2=points[j];var b: Vector2=points[(j+1)%points.size()]
        quad(Vector3(x0,FY+a.y,z0+a.x),Vector3(x1,FY+a.y,z0+a.x),Vector3(x1,FY+b.y,z0+b.x),Vector3(x0,FY+b.y,z0+b.x),mat)

func _landing(z: float,width: float,length: float) -> void:
    var plate := _photo("checker_plate.svg",Vector2(0.32,0.32),0.47)
    box(Vector3(width,0.018,length),Vector3(CX,FY+0.025,z),plate)
    for i in range(12):box(Vector3(width*0.82,0.004,0.012),Vector3(CX,FY+0.036,z-length*0.42+float(i)*length*0.075),black)

func _exit_hall(direction: float,start: float,width: float,top: float,length: float) -> void:
    for side in [-1.0,1.0]:
        var x: float=CX+side*(width*0.5+0.16)
        box(Vector3(0.30,8.0-FY,length),Vector3(x,(8.0+FY)*0.5,start+direction*(length*0.5-0.30)),wall_stone)
        box(Vector3(0.31,0.09,length),Vector3(x,FY+0.045,start+direction*(length*0.5-0.30)),black)
        for y in [FY+0.6,FY+1.2,FY+1.8,FY+2.4,FY+3.0,FY+3.6,FY+4.2]:
            box(Vector3(0.003,0.003,length),Vector3(x-side*0.152,float(y),start+direction*(length*0.5-0.30)),trim)
        picture("no_smoking.svg",Vector2(0.22,0.22),Vector3(x,FY+1.9,start-direction*0.47),0.0 if direction<0 else PI)
        picture("sos_info.svg",Vector2(0.25,0.39),Vector3(x,FY+0.94,start-direction*0.472),0.0 if direction<0 else PI)
        _camera_box(Vector3(x-side*0.16,4.92,start-direction*0.5),0.0 if direction<0 else PI)
    box(Vector3(width+0.62,0.20,length),Vector3(CX,8.10,start+direction*(length*0.5-0.3)),white)
    # The rectangular plaster recess above the exit board is also physical geometry.
    var front: float=start-direction*0.36
    box(Vector3(width+0.62,1.05,0.42),Vector3(CX,5.87,front),white)
    box(Vector3(width+0.62,1.00,0.42),Vector3(CX,7.60,front),white)
    for side in [-1.0,1.0]:box(Vector3((width+0.62-2.6)*0.5,0.73,0.42),Vector3(CX+side*(2.6+(width+0.62-2.6)*0.5)*0.5,6.755,front),white)
    box(Vector3(2.6,0.73,0.06),Vector3(CX,6.755,front+direction*0.16),white)
    for i in range(7):
        var z: float=start+direction*float(i)*2.3
        box(Vector3(width+0.2,0.14,0.28),Vector3(CX,7.95,z),white)
        box(Vector3(5.6,0.045,0.045),Vector3(CX,7.84,z),glow)
    for side in [-1.0,1.0]:
        rod(Vector3(CX+side*3.35,5.22,start),Vector3(CX+side*3.35,5.22,start+direction*5.0),0.025,glow)
    box(Vector3(width+0.60,2.2,0.20),Vector3(CX,top+1.10,start+direction*(length-0.45)),wall_stone)

func _signs() -> void:
    # Clear opening = 4.80 - .84 = 3.96 m; framed signs = 3.48 m.
    for bay in [2,6,10,14]:
        var z: float=-1.2+(float(bay)+0.5)*PITCH
        for side in [-1.0,1.0]:
            var p := Vector3(CX+side*COL_X,4.63,z)
            var size := Vector2(3.40,0.5383)
            box(Vector3(0.075,0.60,3.48),p,metal)
            for face in [-1.0,1.0]:picture("platform_track1.svg" if side>0 else "platform_track2.svg",size,p+Vector3(face*0.043,0,0),face*PI/2.0)
            for dz in [-0.95,0.95]:rod(p+Vector3(0,0.27,float(dz)),Vector3(p.x,6.02,z+float(dz)),0.022,metal)

func _bench(p: Vector3) -> void:
    var base := _material(Color("#4b3d29"),0.05,0.67)
    box(Vector3(0.60,0.34,2.99),p+Vector3(0,0.21,0),base)
    for seat in range(5):
        var z: float=-1.20+float(seat)*0.60
        # Contoured saddle with rounded front and rear noses; five distinct photographed modules.
        for strip in range(15):
            var x: float=-0.35+(float(strip)+0.5)*0.70/15.0
            var y: float=0.475+0.028*pow(abs(x)/0.35,3.0)
            box(Vector3(0.047,0.066,0.575),p+Vector3(x,y-0.033,z),oak)
        for side in [-1.0,1.0]:
            for j in range(8):
                var a0: float=-PI/2.0+float(j)*PI/8.0;var a1: float=-PI/2.0+float(j+1)*PI/8.0
                var x0: float=side*(0.327+0.028*cos(a0));var x1: float=side*(0.327+0.028*cos(a1))
                quad(p+Vector3(x0,0.473+0.028*sin(a0),z-0.2875),p+Vector3(x0,0.473+0.028*sin(a0),z+0.2875),p+Vector3(x1,0.473+0.028*sin(a1),z+0.2875),p+Vector3(x1,0.473+0.028*sin(a1),z-0.2875),oak)
        for edge in [-1.0,1.0]:
            var joint_z: float=z+edge*0.293
            box(Vector3(0.715,0.014,0.018),p+Vector3(0,0.504,joint_z),black)
            for side in [-1.0,1.0]:box(Vector3(0.018,0.11,0.018),p+Vector3(side*0.35,0.455,joint_z),black)

func _television(z: float,event: bool) -> void:
    var p := Vector3(CX,4.65,z)
    box(Vector3(1.56,0.95,0.13),p,black)
    for dx in [-0.48,0.48]:
        rod(p+Vector3(float(dx),0.50,0),Vector3(CX+float(dx),5.98,z),0.015,metal)
        box(Vector3(0.14,0.02,0.16),Vector3(CX+float(dx),5.97,z),metal)
    for face in [-1.0,1.0]:
        if event:picture("burger_ad.jpg",Vector2(1.48,0.86),p+Vector3(0,0,face*0.07),0.0 if face>0 else PI)
        else:box(Vector3(1.48,0.86,0.006),p+Vector3(0,0,face*0.07),_material(Color("#111719"),0.35,0.15))

func _floor_fittings() -> void:
    for z in [11.0,37.0,65.0]:
        cylinder(0.20,0.014,Vector3(CX+0.3,FY+0.023,float(z)),metal)
        for i in range(6):box(Vector3(0.012,0.016,0.25),Vector3(CX+0.22+float(i)*0.032,FY+0.030,float(z)),black)
        box(Vector3(0.35,0.018,0.38),Vector3(CX-0.25,FY+0.025,float(z)+3.4),trim)
        for i in range(8):box(Vector3(0.20,0.022,0.018),Vector3(CX-0.25,FY+0.030,float(z)+3.26+float(i)*0.036),black)

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
            var end: float=ZA if direction<0.0 else ZB
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
        if node is Node3D and "Portal" in str(node.name):node.position.y=4.68
    for direction in [-1.0,1.0]:
        var end: float=ZA if direction<0.0 else ZB
        for side in [-1.0,1.0]:
            var tx: float=CX+side*6.362
            var yaw: float=0.0 if direction<0.0 else PI
            box(Vector3(3.90,0.48,0.25),Vector3(tx,4.68,end),wall_stone)
            var root := Node3D.new();root.name="WhiteDriverMirror";root.position=Vector3(CX+side*4.58,FY+1.42,end-direction*2.6);root.rotation.y=yaw-side*0.12;add_child(root)
            var mirror := MeshInstance3D.new();mirror.set_script(preload("res://modules/stations/ploshchad_pobedy/driver_mirrors.gd"));mirror.name="ReflectingSurface";mirror.position.z=0.016
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

