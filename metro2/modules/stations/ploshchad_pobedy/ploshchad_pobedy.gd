extends "res://modules/stations/ploshchad_pobedy/station_builder.gd"
## Ploshchad Pobedy V65: 40 owner photos and both complete video clips.
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
var crystal_mesh: ArrayMesh
var crystals: Array[StandardMaterial3D]=[]

func _ready() -> void:
    super._ready()
    begin_station()
    white=_photo("ceiling_paint.jpg",Vector2(1.0,1.0),0.90)
    white.normal_enabled=true;white.normal_texture=load(ART+"ceiling_normal.png");white.normal_scale=0.16
    wall_stone=_photo("wall_marble.jpg",Vector2(1.20,0.60),0.36)
    granite=_photo("plinth_granite.jpg",Vector2(1.20,0.60),0.42)
    stair_stone=_photo("stair_granite.jpg",Vector2(1.4,0.16),0.64)
    floor_stone=_photo("floor_grey.jpg",Vector2(0.60,0.60),0.42)
    floor_dark=_photo("floor_dark.jpg",Vector2(1.20,0.15),0.36)
    floor_red=_photo("floor_red.jpg",Vector2(0.6,0.6),0.38)
    trim=_material(Color("#bdb9a8"),0.15,0.42)
    brass=_material(Color("#be9d53"),0.65,0.24)
    _make_crystal_mesh()
    for i in range(4):
        var m := _material(Color(0.88+float(i)*0.025,0.84+float(i)*0.031,0.69+float(i)*0.069),0.22,0.12)
        m.emission_enabled=true;m.emission=Color(1.0,0.87,0.61);m.emission_energy_multiplier=0.22+float(i)*0.14
        crystals.append(m)
    lettering=_material(Color("#d0cbc0"),0.55,0.29)
    yellow=_material(Color("#d9ac37"),0.0,0.68)
    for i in range(4):
        var m := _photo("column_marble.jpg" if i%2==0 else "column_marble_alt.jpg",Vector2(0.82,2.65),0.26)
        m.uv1_offset=Vector3(0.0,float(i)*0.26,0.0)
        column_stones.append(m)
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
    (get_node("IslandPlatform") as MeshInstance3D).material_override=floor_red
    # Red granite fields bounded by grey strips; dark veined bands cross under each column pair.
    for row in range(175):
        var z: float=ZA+0.30+float(row)*0.60
        for col in range(15):
            box(Vector3(0.598,0.008,0.598),Vector3(CX-4.20+float(col)*0.60,FY+0.005,z),floor_red)
    for side in [-1.0,1.0]:
        box(Vector3(0.22,0.014,105),Vector3(CX+side*2.02,FY+0.013,MID),floor_stone)
        box(Vector3(0.75,0.015,105),Vector3(CX+side*2.55,FY+0.014,MID),floor_dark)
        box(Vector3(0.20,0.016,105),Vector3(CX+side*3.025,FY+0.015,MID),floor_stone)
    for i in range(19):
        var z: float=-1.2+float(i)*PITCH
        box(Vector3(8.92,0.016,0.75),Vector3(CX,FY+0.015,z),floor_dark)
        for offset in [-0.49,0.49]:box(Vector3(8.92,0.018,0.23),Vector3(CX,FY+0.016,z+float(offset)),floor_stone)
    for side in [-1.0,1.0]:
        box(Vector3(0.46,0.020,105),Vector3(CX+side*4.77,FY+0.014,MID),_material(Color("#9a917b"),0.0,0.58))
        box(Vector3(0.19,0.022,105),Vector3(CX+side*4.42,FY+0.018,MID),yellow)
        for i in range(1312):
            var z: float=ZA+0.04+float(i)*0.08
            for dx in [-0.058,0.0,0.058]:cylinder(0.011,0.004,Vector3(CX+side*4.42+float(dx),FY+0.032,z),yellow)

func _walls() -> void:
    var joint := _material(Color("#8c8d81"),0.0,0.85)
    var alternate := _photo("wall_marble_alt.jpg",Vector2(1.2,0.60),0.38)
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.90
        var plinth_top: float=FY+0.60
        box(Vector3(0.28,plinth_top,105),Vector3(x,plinth_top*0.5,MID),granite)
        box(Vector3(0.28,6.15-plinth_top,105),Vector3(x,(6.15+plinth_top)*0.5,MID),wall_stone)
        for y in [plinth_top,plinth_top+0.025]:box(Vector3(0.31,0.018,105),Vector3(x-side*0.025,float(y),MID),metal)
        # Individual horizontal courses have real seams; upper plates turn vertical.
        for row in range(7):
            var y: float=plinth_top+0.03+float(row)*0.60
            box(Vector3(0.006,0.0035,105),Vector3(x-side*0.144,y,MID),joint)
            for j in range(88):
                var z: float=ZA+float(j)*1.20+(0.60 if row%2==1 else 0.0)
                box(Vector3(0.006,0.60,0.003),Vector3(x-side*0.145,y+0.30,z),joint)
                if (j+row*3)%7==0 and z+0.60<ZB:
                    box(Vector3(0.003,0.593,1.193),Vector3(x-side*0.143,y+0.30,z+0.60),alternate)
        for i in range(59):
            var z: float=ZA+float(i)*1.80
            box(Vector3(0.009,0.78,0.005),Vector3(x-side*0.15,5.34,z),joint)
        rod(Vector3(x-side*0.19,4.89,ZA),Vector3(x-side*0.19,4.89,ZB),0.016,metal)
        rod(Vector3(x-side*0.18,4.94,ZA),Vector3(x-side*0.18,4.94,ZB),0.009,black)
        for i in range(74):
            var z: float=ZA+float(i)*1.44
            box(Vector3(0.045,0.035,0.026),Vector3(x-side*0.195,4.91,z),black)
        for j in range(5):
            var z: float=1.8+float(j)*18.8
            var yaw: float=-side*PI/2.0
            var p := Vector3(x-side*0.19,3.17,z)
            box(Vector3(0.055,0.38,4.65),p,brass)
            picture("name_be.jpg" if side>0.0 else "name_ru.jpg",Vector2(4.60,0.36),p+Vector3(-side*0.032,0,0),yaw)
            picture("route_track1.svg" if side>0.0 else "route_track2.svg",Vector2(4.75,0.80),Vector3(x-side*0.23,2.55,z),yaw,true)

func _columns_and_girders() -> void:
    var joint := _material(Color("#aaa99c"),0.0,0.72)
    # Matching rows; four diagonal concrete branches leave four open faces for the fan chandeliers.
    for side in [-1.0,1.0]:
        var x: float=CX+side*COL_X
        box(Vector3(0.52,0.30,90.3),Vector3(x,6.08,39.6),white)
        for i in range(18):
            var z: float=-1.20+float(i)*PITCH
            box(Vector3(0.86,0.075,0.86),Vector3(x,FY+0.0375,z),black)
            box(Vector3(0.84,4.12-FY,0.84),Vector3(x,(4.12+FY)*0.5,z),column_stones[i%4])
            box(Vector3(0.84,0.32,0.84),Vector3(x,4.28,z),white)
            for y in [FY+1.03,FY+2.02]:box(Vector3(0.842,0.0025,0.842),Vector3(x,float(y),z),joint)
            for offset in [-0.19,0.19]:
                for face in [-1.0,1.0]:
                    box(Vector3(0.0035,2.94,0.004),Vector3(x+float(offset),FY+1.55,z+face*0.422),joint)
                    box(Vector3(0.004,2.94,0.0035),Vector3(x+face*0.422,FY+1.55,z+float(offset)),joint)
            for k in range(4):
                var angle: float=float(k)*PI/2.0
                _branch(Vector3(x,0,z),angle+PI/4.0)
                _fan_light(Vector3(x,0,z),angle,i+k)
                var d := Vector3(sin(angle),0,cos(angle))
                rod(Vector3(x,3.59,z)+d*0.426,Vector3(x,4.52,z)+d*0.426,0.014,brass)
                rod(Vector3(x,4.09,z)+d*0.429,Vector3(x,4.09,z)+d*0.429+Vector3(cos(angle),0,-sin(angle))*0.40,0.007,brass)

func _branch(origin: Vector3,angle: float) -> void:
    # Curved haunch extruded across each of the four white shoulder arms.
    var d := Vector3(sin(angle),0,cos(angle))
    var t := Vector3(cos(angle),0,-sin(angle))
    var outline := PackedVector2Array([Vector2(0.42,4.07),Vector2(0.45,4.43),Vector2(0.51,4.76),Vector2(0.65,5.09),Vector2(0.90,5.38),Vector2(1.23,5.61),Vector2(1.62,5.80),Vector2(2.15,5.94),Vector2(2.15,6.20),Vector2(0.42,6.20)])
    var caps := Geometry2D.triangulate_polygon(outline)
    for side in [-1.0,1.0]:
        for j in range(0,caps.size(),3):
            var a: Vector2=outline[caps[j]];var b: Vector2=outline[caps[j+1]];var c: Vector2=outline[caps[j+2]]
            triangle(origin+d*a.x+Vector3.UP*a.y+t*side*0.18,origin+d*b.x+Vector3.UP*b.y+t*side*0.18,origin+d*c.x+Vector3.UP*c.y+t*side*0.18,white,t*side)
    for j in range(outline.size()):
        var a: Vector2=outline[j];var b: Vector2=outline[(j+1)%outline.size()]
        quad(origin+d*a.x+Vector3.UP*a.y-t*0.18,origin+d*a.x+Vector3.UP*a.y+t*0.18,origin+d*b.x+Vector3.UP*b.y+t*0.18,origin+d*b.x+Vector3.UP*b.y-t*0.18,white)

func _fan_point(origin: Vector3,angle: float,t: float,across: float=0.0) -> Vector3:
    var radial := Vector3(sin(angle),0,cos(angle))
    var tangent := Vector3(cos(angle),0,-sin(angle))
    return origin+radial*(0.53+t*1.34)+Vector3.UP*(4.52+t*1.45)+tangent*across*(0.07+t*0.59)

func _fan_light(origin: Vector3,angle: float,variant: int) -> void:
    var a := _fan_point(origin,angle,0.0,-1.0)
    var b := _fan_point(origin,angle,0.0,1.0)
    var c := _fan_point(origin,angle,1.0,1.0)
    var d := _fan_point(origin,angle,1.0,-1.0)
    var radial := Vector3(sin(angle),0,cos(angle))
    # Four separate sloping tapered fixtures; warm core behind brass rails and individual prisms.
    var lift: Vector3=(radial-Vector3.UP)*0.025
    quad(a-lift,b-lift,c-lift,d-lift,glow,radial-Vector3.UP)
    for ends in [[a,b],[b,c],[c,d],[d,a]]:rod(ends[0],ends[1],0.014,brass)
    for lane in range(7):
        var u: float=-0.88+float(lane)*1.76/6.0
        rod(_fan_point(origin,angle,0.03,u)+lift,_fan_point(origin,angle,0.98,u)+lift,0.007,brass)
    var slope := (c-b).normalized()
    var tangent := Vector3(cos(angle),0,-sin(angle))
    var basis := Basis(tangent,slope,tangent.cross(slope).normalized())
    for row in range(10):
        var t: float=0.065+float(row)*0.097
        rod(_fan_point(origin,angle,t,-0.95)+lift,_fan_point(origin,angle,t,0.95)+lift,0.005,brass)
        var count: int=3+int(t*7.0)
        for j in range(count):
            var u: float=-0.86+float(j)*1.72/float(count-1)
            var mat: StandardMaterial3D=crystals[(j+row+variant)%4]
            var key: String="crystal"+str(mat.get_instance_id())
            var p: Vector3=_fan_point(origin,angle,t,u)+lift*2.4
            batch("crystal",mat,Transform3D(basis*Basis.from_scale(Vector3(0.052+t*0.020,0.100,0.065)),p))
            batches[key]["mesh"]=crystal_mesh
    # Central concealed warm tube remains legible from the far end of the platform.
    rod(_fan_point(origin,angle,0.08)+lift,_fan_point(origin,angle,0.93)+lift,0.018,glow)

func _make_crystal_mesh() -> void:
    var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(4):
        var a := Vector3(cos(float(i)*PI/2.0)*0.5,0,sin(float(i)*PI/2.0)*0.5)
        var b := Vector3(cos(float(i+1)*PI/2.0)*0.5,0,sin(float(i+1)*PI/2.0)*0.5)
        for tip in [Vector3(0,0.5,0),Vector3(0,-0.5,0)]:
            var n: Vector3=(a-tip).cross(b-tip).normalized()
            var reverse: bool=n.dot((a+b+tip)/3.0)<0.0
            if reverse:n=-n
            st.set_normal(n)
            st.add_vertex(tip);st.add_vertex(a if reverse else b);st.add_vertex(b if reverse else a)
    crystal_mesh=st.commit()

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
    for i in range(18):
        var z: float=-1.2+float(i)*PITCH
        box(Vector3(17.9,0.27,0.42),Vector3(CX,6.10,z),white)
    for child in get_children():
        if child is OmniLight3D:
            child.position.y=5.52;child.light_energy=1.28;child.light_color=Color(1.0,0.94,0.82)
    # Local non-shadowing pools at selected lamp heads, with restrained falloff.
    for i in range(9):
        for side in [-1.0,1.0]:
            var light := OmniLight3D.new()
            light.position=Vector3(CX+side*COL_X,5.3,1.2+float(i)*9.6)
            light.light_energy=0.30;light.light_color=Color(1.0,0.87,0.62);light.omni_range=6.5;light.shadow_enabled=false;add_child(light)

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
    _exit_hall(direction,start,width,top,14.8)
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
    var lower := 1.2
    var tan := _material(Color("#aa844d"),0.25,0.38)
    var rubber := _material(Color("#20241f"),0.05,0.60)
    var stepmat := _material(Color("#5d625b"),0.45,0.50)
    _exit_hall(1.0,start,width,FY+rise,14.7)
    for lane in range(3):
        var x: float=CX+(float(lane)-1.0)*2.05
        for i in range(49):
            var t: float=float(i)/48.0
            var z: float=start+lower+t*run
            box(Vector3(1.05,0.18+rise*t,0.205),Vector3(x,FY+(0.18+rise*t)*0.5,z),stepmat)
            for groove in range(11):box(Vector3(0.006,0.007,0.185),Vector3(x-0.47+float(groove)*0.094,FY+0.185+rise*t,z),black)
        box(Vector3(1.05,0.04,1.25),Vector3(x,FY+0.02,start+0.48),stepmat)
        for side in [-1.0,1.0]:
            var bx: float=x+side*0.69
            var offsets := [Vector2(0.0,0.0),Vector2(1.2,0.0),Vector2(10.4,rise),Vector2(12.2,rise)]
            for i in range(offsets.size()-1):
                var a: Vector2=offsets[i];var b: Vector2=offsets[i+1]
                var slope: float=atan2(b.y-a.y,b.x-a.x)
                var length: float=a.distance_to(b)
                box(Vector3(0.30,0.76,length),Vector3(bx,FY+(a.y+b.y)*0.5+0.38,start+(a.x+b.x)*0.5),tan,Basis(Vector3.RIGHT,-slope))
                rod(Vector3(bx,FY+a.y+0.82,start+a.x),Vector3(bx,FY+b.y+0.82,start+b.x),0.045,rubber)
                rod(Vector3(bx-side*0.16,FY+a.y+0.70,start+a.x),Vector3(bx-side*0.16,FY+b.y+0.70,start+b.x),0.022,metal)
            cylinder(0.085,0.57,Vector3(bx,FY+0.285,start+0.06),metal)
            picture("escalator_warning.svg",Vector2(0.22,0.25),Vector3(bx,FY+0.31,start-0.05),PI)
            box(Vector3(0.15,0.68,0.26),Vector3(bx,FY+0.34,start-0.10),metal)
        box(Vector3(1.05,0.012,0.06),Vector3(x,FY+0.047,start+0.03),yellow)
        var indicator := _material(Color("#0f9d57") if lane==0 else Color("#bc274a"),0,0.4)
        indicator.emission_enabled=true;indicator.emission=indicator.albedo_color
        box(Vector3(0.08,0.10,0.02),Vector3(x-0.69,FY+0.58,start-0.245),indicator)
    box(Vector3(width,0.22,4.2),Vector3(CX,FY+rise-0.11,start+12.5),floor_stone)
    board("exit_escalators.jpg",Vector3(CX,4.71,start-0.48),Vector2(5.75,0.84))
    foot_grille(start-0.46,7.25)

func _exit_hall(direction: float,start: float,width: float,top: float,length: float) -> void:
    for side in [-1.0,1.0]:
        var x: float=CX+side*(width*0.5+0.14)
        box(Vector3(0.28,7.9-FY,length),Vector3(x,(7.9+FY)*0.5,start+direction*(length*0.5-0.30)),wall_stone)
        box(Vector3(0.29,0.09,length),Vector3(x,FY+0.045,start+direction*(length*0.5-0.30)),black)
        picture("no_smoking.svg",Vector2(0.22,0.22),Vector3(x,FY+1.9,start-direction*0.46),0.0 if direction<0 else PI)
        picture("sos_info.svg",Vector2(0.25,0.39),Vector3(x,FY+0.94,start-direction*0.462),0.0 if direction<0 else PI)
        _camera_box(Vector3(x-side*0.16,4.92,start-direction*0.5),0.0 if direction<0 else PI)
    box(Vector3(width+0.55,0.20,length),Vector3(CX,7.95,start+direction*(length*0.5-0.3)),white)
    box(Vector3(width+0.55,2.56,0.40),Vector3(CX,6.62,start-direction*0.36),white)
    for i in range(10):
        var z: float=start+direction*float(i)*1.4
        box(Vector3(width+0.1,0.20,0.16),Vector3(CX,7.75,z),white)
        if i%2==0:box(Vector3(5.60,0.035,0.07),Vector3(CX,7.62,z),glow)
    # Upper landing is deliberately limited to the photographed approach.
    box(Vector3(width+0.55,2.2,0.20),Vector3(CX,top+1.10,start+direction*(length-0.45)),wall_stone)

func _signs() -> void:
    # Clear opening = 4.80 - .84 = 3.96 m; framed signs = 3.48 m.
    for bay in [2,6,10,14]:
        var z: float=-1.2+(float(bay)+0.5)*PITCH
        for side in [-1.0,1.0]:
            var p := Vector3(CX+side*COL_X,4.63,z)
            var size := Vector2(3.40,0.52)
            box(Vector3(0.075,0.60,3.48),p,metal)
            for face in [-1.0,1.0]:picture("platform_track1.jpg" if side>0 else "platform_track2.jpg",size,p+Vector3(face*0.043,0,0),face*PI/2.0)
            for dz in [-1.40,1.40]:rod(p+Vector3(0,0.27,float(dz)),Vector3(p.x,6.02,z+float(dz)),0.022,metal)

func _bench(p: Vector3) -> void:
    var oak := _photo("bench_oak.jpg",Vector2(0.5,0.2),0.45)
    # Five wide timber saddle modules, backless as photographed, on two solid dark supports.
    for seat in range(5):
        var z: float=-1.05+float(seat)*0.525
        for strip in range(7):
            var x: float=-0.30+float(strip)*0.10
            var h: float=0.48+0.045*pow(abs(x)/0.30,2.0)
            box(Vector3(0.095,0.055,0.50),p+Vector3(x,h,z),oak)
        for edge in [-1.0,1.0]:box(Vector3(0.69,0.045,0.022),p+Vector3(0,0.49,z+edge*0.254),black)
    for dz in [-0.90,0.90]:box(Vector3(0.62,0.42,0.15),p+Vector3(0,0.23,float(dz)),black)

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

