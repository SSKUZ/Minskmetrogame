extends "res://modules/stations/akademiya_nauk/station_builder.gd"
## Academy of Sciences V62: owner photos 7744–7770 and full video 7761.
const ART := "res://modules/stations/akademiya_nauk/art/"
const NORTH := -2.80
const SOUTH := 82.024
const PITCH := 4.35
const COL_X := 2.55
var wall_stone: StandardMaterial3D
var column_stones: Array[StandardMaterial3D]=[]
var stair_stone: StandardMaterial3D
var trim: StandardMaterial3D
var yellow: StandardMaterial3D
var floor_stone: StandardMaterial3D
var floor_dark: StandardMaterial3D
var lettering: StandardMaterial3D

func _ready() -> void:
    super._ready()
    begin_station()
    white=_photo("ceiling_paint.jpg",Vector2(1.0,1.0),0.90)
    white.normal_enabled=true;white.normal_texture=load(ART+"ceiling_normal.png");white.normal_scale=0.16
    wall_stone=_photo("wall_marble.jpg",Vector2(1.20,0.48),0.36)
    granite=_photo("plinth_granite.jpg",Vector2(1.20,0.40),0.50)
    stair_stone=_photo("stair_granite.jpg",Vector2(1.4,0.16),0.64)
    floor_stone=_photo("floor_grey.jpg",Vector2(0.60,0.60),0.42)
    floor_dark=_photo("floor_dark.jpg",Vector2(1.20,0.15),0.36)
    floor_dark.albedo_color=Color(0.42,0.45,0.43)
    trim=_material(Color("#bdb9a8"),0.15,0.42)
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
    for z in [14.0,43.0,70.5]:_television(float(z),z==43.0)
    for side in [-1.0,1.0]:
        for bay in [5,12]:_bench(Vector3(CX+side*COL_X,FY,-1.5+(float(bay)+0.5)*PITCH))
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
    # Native stone slabs: grey field, black transverse bands, narrow cream inlay.
    var pale := _material(Color("#d6d3c2"),0.0,0.51)
    var variants: Array[StandardMaterial3D]=[]
    for i in range(5):
        var mat := floor_stone.duplicate() as StandardMaterial3D
        mat.albedo_color=Color(0.88+float(i)*0.035,0.89+float(i)*0.033,0.88+float(i)*0.033)
        mat.uv1_offset=Vector3(float(i)*0.19,0,float(i)*0.37);variants.append(mat)
    for row in range(175):
        for col in range(15):
            var z: float=ZA+0.30+float(row)*0.60
            var x: float=CX-4.20+float(col)*0.60
            box(Vector3(0.598,0.008,0.598),Vector3(x,FY+0.005,z),variants[(row*7+col*3)%5])
    for i in range(24):
        var z: float=-10.2+float(i)*PITCH
        box(Vector3(8.92,0.011,0.14),Vector3(CX,FY+0.013,z),floor_dark)
        box(Vector3(8.92,0.012,0.025),Vector3(CX,FY+0.014,z+0.71),pale)
    for side in [-1.0,1.0]:
        box(Vector3(0.16,0.012,105),Vector3(CX+side*3.03,FY+0.014,MID),floor_dark)
        box(Vector3(0.026,0.014,105),Vector3(CX+side*3.16,FY+0.015,MID),pale)
        box(Vector3(0.46,0.014,105),Vector3(CX+side*4.77,FY+0.010,MID),_material(Color("#948d7c"),0.0,0.68))
        box(Vector3(0.19,0.014,105),Vector3(CX+side*4.42,FY+0.018,MID),yellow)
        for i in range(1312):
            var z: float=ZA+0.04+float(i)*0.08
            for dx in [-0.058,0.0,0.058]:cylinder(0.011,0.004,Vector3(CX+side*4.42+float(dx),FY+0.027,z),yellow)

func _walls() -> void:
    var joint := _material(Color("#8c8d81"),0.0,0.85)
    var alternate := _photo("wall_marble_alt.jpg",Vector2(1.2,0.48),0.38)
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.90
        var plinth_top: float=FY+0.60
        box(Vector3(0.28,plinth_top,105),Vector3(x,plinth_top*0.5,MID),granite)
        box(Vector3(0.28,5.73-plinth_top,105),Vector3(x,(5.73+plinth_top)*0.5,MID),wall_stone)
        for y in [plinth_top,plinth_top+0.025]:box(Vector3(0.31,0.018,105),Vector3(x-side*0.025,float(y),MID),metal)
        # Individual horizontal courses have real seams; upper plates turn vertical.
        for row in range(6):
            var y: float=plinth_top+0.03+float(row)*0.48
            box(Vector3(0.006,0.0035,105),Vector3(x-side*0.144,y,MID),joint)
            for j in range(88):
                var z: float=ZA+float(j)*1.20+(0.60 if row%2==1 else 0.0)
                box(Vector3(0.006,0.48,0.003),Vector3(x-side*0.145,y+0.24,z),joint)
                if (j+row*3)%7==0 and z+0.60<ZB:
                    box(Vector3(0.003,0.473,1.193),Vector3(x-side*0.143,y+0.24,z+0.60),alternate)
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
            _name("АКАДЭМІЯ  НАВУК" if side>0.0 else "АКАДЕМИЯ  НАУК",Vector3(x-side*0.19,3.35,z),-side*PI/2.0)
            if j%2==0:picture("route_track1.svg" if side>0.0 else "route_track2.svg",Vector2(4.6,0.92),Vector3(x-side*0.20,2.55,z),-side*PI/2.0,true)

func _name(value: String,p: Vector3,yaw: float) -> void:
    var font: Font=load(ART+"station_letters.ttf")
    var frame := Node3D.new();frame.name="OutlinedMetalStationLetters";frame.position=p;frame.rotation.y=yaw;add_child(frame)
    var size := 0.0048
    var total: float=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,72).x*size+float(value.length())*0.035
    var cursor: float=-total*0.5
    for letter in value:
        var advance: float=font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,72).x*size
        for face in range(2):
            var mesh := TextMesh.new();mesh.font=font;mesh.text=letter;mesh.font_size=72;mesh.pixel_size=size;mesh.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
            mesh.depth=0.033 if face==0 else 0.004;mesh.material=black if face==0 else lettering
            var node := MeshInstance3D.new();node.mesh=mesh;node.position=Vector3(cursor+advance*0.5,0,0.0 if face==0 else 0.019)
            if face==1:node.scale=Vector3(0.84,0.84,1.0)
            frame.add_child(node)
        cursor+=advance+0.035

func _columns_and_girders() -> void:
    var bottom: float=FY+0.09
    var capital := FY+2.70
    for side in [-1.0,1.0]:
        var x: float=CX+side*COL_X
        box(Vector3(0.86,0.53,86.6),Vector3(x,5.385,39.7),white)
        for i in range(20):
            var z: float=-1.50+float(i)*PITCH
            # Solid opaque core; four closed stone faces, no transparent column shader.
            box(Vector3(0.84,capital-bottom,0.84),Vector3(x,(capital+bottom)*0.5,z),column_stones[i%4])
            box(Vector3(0.87,0.09,0.87),Vector3(x,FY+0.045,z),black)
            box(Vector3(0.84,5.14-capital,0.84),Vector3(x,(capital+5.14)*0.5,z),white)
            # Stepped ogee-like light stone moulding wraps all four faces.
            for step in range(9):
                var t: float=float(step)/8.0
                var w: float=0.86+0.10*sin(t*PI)
                box(Vector3(w,0.028,w),Vector3(x,capital-0.04+t*0.224,z),trim)
            box(Vector3(0.86,0.17,0.86),Vector3(x,capital+0.235,z),column_stones[(i+1)%4])
            box(Vector3(0.89,0.025,0.89),Vector3(x,capital+0.335,z),trim)
            # Narrow polished vertical paired strips on the broad marble faces.
            for dx in [-0.045,0.045]:
                for face in [-1.0,1.0]:
                    box(Vector3(0.027,3.84,0.018),Vector3(x+float(dx),FY+1.98,z+face*0.43),metal)
                    box(Vector3(0.018,3.84,0.027),Vector3(x+face*0.43,FY+1.98,z+float(dx)),metal)
            for h in [FY+0.91,FY+1.78]:box(Vector3(0.842,0.002,0.842),Vector3(x,float(h),z),_material(Color("#656962"),0.0,0.6))
            if i<19:
                _haunch(x,z+0.42,1.0)
                _haunch(x,z+PITCH-0.42,-1.0)
                var center: float=z+PITCH*0.5
                box(Vector3(0.055,0.048,3.23),Vector3(x,5.107,center),glow)
                box(Vector3(0.065,0.045,3.47),Vector3(x-side*0.36,5.70,center),glow)

func _haunch(x: float,z: float,direction: float) -> void:
    # Rounded upper inside corner of each rectangular opening, in the Y/Z plane.
    var points := PackedVector2Array([Vector2(z,5.14),Vector2(z,4.93)])
    for i in range(13):
        var a: float=float(i)*PI/24.0
        points.append(Vector2(z+direction*(0.20-0.20*cos(a)),4.94+0.20*sin(a)))
    var caps := Geometry2D.triangulate_polygon(points)
    for face in [-1.0,1.0]:
        for k in range(0,caps.size(),3):
            var a: Vector2=points[caps[k]];var b: Vector2=points[caps[k+1]];var c: Vector2=points[caps[k+2]]
            triangle(Vector3(x+face*0.43,a.y,a.x),Vector3(x+face*0.43,b.y,b.x),Vector3(x+face*0.43,c.y,c.x),white,Vector3(face,0,0))
    for i in range(points.size()):
        var a: Vector2=points[i];var b: Vector2=points[(i+1)%points.size()]
        quad(Vector3(x-0.43,a.y,a.x),Vector3(x+0.43,a.y,a.x),Vector3(x+0.43,b.y,b.x),Vector3(x-0.43,b.y,b.x),white)

func _ceilings() -> void:
    box(Vector3(5.12,0.12,86.8),Vector3(CX,6.04,39.7),white)
    for side in [-1.0,1.0]:box(Vector3(6.43,0.12,105),Vector3(CX+side*5.73,5.73,MID),white)
    for i in range(59):
        var z: float=ZA+0.35+float(i)*1.80
        if z>NORTH and z<SOUTH:box(Vector3(4.35,0.34,0.16),Vector3(CX,5.80,z),white)
        for side in [-1.0,1.0]:box(Vector3(6.40,0.34,0.14),Vector3(CX+side*5.73,5.50,z),white)
    for child in get_children():
        if child is OmniLight3D:
            child.position.y=5.45;child.light_energy=1.45;child.light_color=Color(1.0,0.98,0.94)
    for z in [7.0,33.0,61.0,84.0]:
        var light := OmniLight3D.new();light.position=Vector3(CX,5.74,float(z));light.light_energy=0.45;light.omni_range=14.0;light.shadow_enabled=false;add_child(light)

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
    var tan := _material(Color("#9a8060"),0.25,0.38)
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
    # Clear opening = 4.35 - .84 = 3.51 m; framed signs = 3.23 m.
    for bay in [2,7,12,17]:
        var z: float=-1.5+(float(bay)+0.5)*PITCH
        for side in [-1.0,1.0]:
            var p := Vector3(CX+side*COL_X,4.63,z)
            var size := Vector2(3.15,0.47)
            box(Vector3(0.075,0.55,3.23),p,metal)
            for face in [-1.0,1.0]:picture("platform_track1.jpg" if side>0 else "platform_track2.jpg",size,p+Vector3(face*0.043,0,0),face*PI/2.0)
            for dz in [-1.40,1.40]:rod(p+Vector3(0,0.27,float(dz)),Vector3(p.x,5.12,z+float(dz)),0.022,metal)

func _bench(p: Vector3) -> void:
    var timbermat := _material(Color("#aa8956"),0.0,0.47)
    for i in range(5):box(Vector3(0.51,0.055,2.15),p+Vector3(-0.22+float(i)*0.11,0.48,0),timbermat)
    for dz in [-0.78,0.78]:box(Vector3(0.45,0.43,0.10),p+Vector3(0,0.23,float(dz)),black)

func _television(z: float,event: bool) -> void:
    var p := Vector3(CX,4.65,z)
    box(Vector3(1.56,0.95,0.13),p,black)
    for dx in [-0.48,0.48]:
        rod(p+Vector3(float(dx),0.50,0),Vector3(CX+float(dx),5.98,z),0.015,metal)
        box(Vector3(0.14,0.02,0.16),Vector3(CX+float(dx),5.97,z),metal)
    for face in [-1.0,1.0]:
        if event:picture("student_event.jpg",Vector2(1.48,0.86),p+Vector3(0,0,face*0.07),0.0 if face>0 else PI)
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
            var mirror := MeshInstance3D.new();mirror.set_script(preload("res://modules/stations/akademiya_nauk/driver_mirrors.gd"));mirror.name="ReflectingSurface";mirror.position.z=0.016
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

