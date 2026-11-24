extends "res://modules/stations/akademiya_nauk/station_builder.gd"
## Academy of Sciences V62: owner photos 7744–7770 and full video 7761.
const ART := "res://modules/stations/akademiya_nauk/art/"
const NORTH := -2.80
const SOUTH := 82.024
const PITCH := 4.35
const COL_X := 2.55
# Metres from the stair/escalator threshold toward its tunnel end. Base connections stay fixed.
const PORTAL_GAP := 1.75
const ESCALATOR_PITCH := 2.05
const ESCALATOR_STEP_WIDTH := 1.30
const GIRDER_START := -1.50+PITCH-0.43
const GIRDER_END := -1.50+18.0*PITCH+0.43
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
var bench_oak: StandardMaterial3D

func _ready() -> void:
    var line_work: RefCounted=_line_work()
    if line_work!=null: line_work.begin(self)
    if not await _line_checkpoint(): return
    super._ready()
    if not await _line_checkpoint(): return
    begin_station()
    if not await _line_checkpoint(): return
    white=_photo("ceiling_paint.jpg",Vector2(1.0,1.0),0.90)
    if not await _line_checkpoint(): return
    white.normal_enabled=true;white.normal_texture=load(ART+"ceiling_normal.png");white.normal_scale=0.16
    if not await _line_checkpoint(): return
    wall_stone=_photo("wall_marble.jpg",Vector2(1.20,0.48),0.36)
    if not await _line_checkpoint(): return
    granite=_photo("plinth_granite.jpg",Vector2(1.20,0.40),0.50)
    if not await _line_checkpoint(): return
    stair_stone=_photo("stair_granite.jpg",Vector2(1.4,0.16),0.64)
    if not await _line_checkpoint(): return
    floor_stone=_photo("floor_grey.jpg",Vector2(0.60,0.60),0.42)
    if not await _line_checkpoint(): return
    floor_dark=_photo("floor_dark.jpg",Vector2(1.20,0.15),0.36)
    if not await _line_checkpoint(): return
    floor_dark.albedo_color=Color(0.42,0.45,0.43)
    if not await _line_checkpoint(): return
    trim=_material(Color("#bdb9a8"),0.15,0.42)
    if not await _line_checkpoint(): return
    lettering=_photo("ceiling_paint.jpg",Vector2(0.09,0.09),0.38)
    if not await _line_checkpoint(): return
    lettering.albedo_color=Color("#bdb8a9");lettering.metallic=0.78
    if not await _line_checkpoint(): return
    lettering.normal_enabled=true;lettering.normal_texture=load(ART+"ceiling_normal.png");lettering.normal_scale=0.14
    if not await _line_checkpoint(): return
    yellow=_material(Color("#d9ac37"),0.0,0.68)
    for i in range(4):
        if not await _line_checkpoint(): return
        var m := _photo("column_marble.jpg" if i%2==0 else "column_marble_alt.jpg",Vector2(0.82,2.65),0.26)
        m.uv1_offset=Vector3(0.0,float(i)*0.26,0.0)
        column_stones.append(m)
    if not await _line_checkpoint(): return
    bench_oak=_photo("bench_oak.jpg",Vector2(0.48,0.60),0.40)
    if not await _line_checkpoint(): return
    bench_oak.albedo_color=Color(0.99,0.92,0.77)
    if not await _line_checkpoint(): return
    await _floor()
    if not await _line_checkpoint(): return
    await _walls()
    if not await _line_checkpoint(): return
    await _columns_and_girders()
    if not await _line_checkpoint(): return
    await _ceilings()
    if not await _line_checkpoint(): return
    await _stairs(-1.0,NORTH)
    if not await _line_checkpoint(): return
    await _escalators(SOUTH)
    if not await _line_checkpoint(): return
    await _signs()
    if not await _line_checkpoint(): return
    await _track_details()
    if not await _line_checkpoint(): return
    var trackwork := preload("res://modules/stations/akademiya_nauk/trackwork.gd").new()
    if not await _line_checkpoint(): return
    trackwork.name="DetailedTrackwork";add_child(trackwork)
    if not await _line_checkpoint(): return
    await _close_end_joints()
    if not await _line_checkpoint(): return
    await _portal_equipment()
    if not await _line_checkpoint(): return
    await _floor_fittings()
    for z in [14.0,43.0,70.5]:
        if not await _line_checkpoint(): return
        await _television(float(z),z==43.0)
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        for bay in [5,12]:
            if not await _line_checkpoint(): return
            await _bench(Vector3(CX+side*COL_X,FY,-1.5+(float(bay)+0.5)*PITCH))
    if not await _line_checkpoint(): return
    await flush()
    if line_work!=null: line_work.finish(self)
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
    if not await _line_checkpoint(): return
    (get_node("IslandPlatform") as MeshInstance3D).material_override=floor_stone
    # Native stone slabs: grey field, black transverse bands, narrow cream inlay.
    var pale := _material(Color("#d6d3c2"),0.0,0.51)
    var variants: Array[StandardMaterial3D]=[]
    for i in range(5):
        if not await _line_checkpoint(): return
        var mat := floor_stone.duplicate() as StandardMaterial3D
        mat.albedo_color=Color(0.88+float(i)*0.035,0.89+float(i)*0.033,0.88+float(i)*0.033)
        mat.uv1_offset=Vector3(float(i)*0.19,0,float(i)*0.37);variants.append(mat)
    for row in range(175):
        if not await _line_checkpoint(): return
        for col in range(15):
            if not await _line_checkpoint(): return
            var z: float=ZA+0.30+float(row)*0.60
            var x: float=CX-4.20+float(col)*0.60
            box(Vector3(0.598,0.008,0.598),Vector3(x,FY+0.005,z),variants[(row*7+col*3)%5])
    for i in range(24):
        if not await _line_checkpoint(): return
        var z: float=-10.2+float(i)*PITCH
        box(Vector3(8.92,0.011,0.14),Vector3(CX,FY+0.013,z),floor_dark)
        box(Vector3(8.92,0.012,0.025),Vector3(CX,FY+0.014,z+0.71),pale)
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        box(Vector3(0.16,0.012,105),Vector3(CX+side*3.03,FY+0.014,MID),floor_dark)
        box(Vector3(0.026,0.014,105),Vector3(CX+side*3.16,FY+0.015,MID),pale)
        box(Vector3(0.46,0.014,105),Vector3(CX+side*4.77,FY+0.010,MID),_material(Color("#948d7c"),0.0,0.68))
        box(Vector3(0.19,0.014,105),Vector3(CX+side*4.42,FY+0.018,MID),yellow)
        for i in range(1312):
            if not await _line_checkpoint(): return
            var z: float=ZA+0.04+float(i)*0.08
            for dx in [-0.058,0.0,0.058]:
                if not await _line_checkpoint(): return
                cylinder(0.011,0.004,Vector3(CX+side*4.42+float(dx),FY+0.027,z),yellow)

func _walls() -> void:
    if not await _line_checkpoint(): return
    var joint := _material(Color("#8c8d81"),0.0,0.85)
    var alternate := _photo("wall_marble_alt.jpg",Vector2(1.2,0.48),0.38)
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        var x: float=CX+side*8.90
        var plinth_top: float=FY+0.60
        box(Vector3(0.28,plinth_top,105),Vector3(x,plinth_top*0.5,MID),granite)
        box(Vector3(0.28,5.73-plinth_top,105),Vector3(x,(5.73+plinth_top)*0.5,MID),wall_stone)
        for y in [plinth_top,plinth_top+0.025]:
            if not await _line_checkpoint(): return
            box(Vector3(0.31,0.018,105),Vector3(x-side*0.025,float(y),MID),metal)
        # Individual horizontal courses have real seams; upper plates turn vertical.
        for row in range(6):
            if not await _line_checkpoint(): return
            var y: float=plinth_top+0.03+float(row)*0.48
            box(Vector3(0.006,0.0035,105),Vector3(x-side*0.144,y,MID),joint)
            for j in range(88):
                if not await _line_checkpoint(): return
                var z: float=ZA+float(j)*1.20+(0.60 if row%2==1 else 0.0)
                box(Vector3(0.006,0.48,0.003),Vector3(x-side*0.145,y+0.24,z),joint)
                if (j+row*3)%7==0 and z+0.60<ZB:
                    box(Vector3(0.003,0.473,1.193),Vector3(x-side*0.143,y+0.24,z+0.60),alternate)
        for i in range(59):
            if not await _line_checkpoint(): return
            var z: float=ZA+float(i)*1.80
            box(Vector3(0.009,0.78,0.005),Vector3(x-side*0.15,5.34,z),joint)
        rod(Vector3(x-side*0.19,4.89,ZA),Vector3(x-side*0.19,4.89,ZB),0.016,metal)
        rod(Vector3(x-side*0.18,4.94,ZA),Vector3(x-side*0.18,4.94,ZB),0.009,black)
        for i in range(74):
            if not await _line_checkpoint(): return
            var z: float=ZA+float(i)*1.44
            box(Vector3(0.045,0.035,0.026),Vector3(x-side*0.195,4.91,z),black)
        for j in range(5):
            if not await _line_checkpoint(): return
            var z: float=1.8+float(j)*18.8
            await _name("АКАДЭМІЯ  НАВУК" if side>0.0 else "АКАДЕМИЯ  НАУК",Vector3(x-side*0.19,3.35,z),-side*PI/2.0)
            if j%2==0:picture("route_track1.svg" if side>0.0 else "route_track2.svg",Vector2(4.6,0.92),Vector3(x-side*0.20,2.55,z),-side*PI/2.0,true)

func _name(value: String,p: Vector3,yaw: float) -> void:
    if not await _line_checkpoint(): return
    var font := FontVariation.new()
    font.base_font=load(ART+"station_letters.ttf");font.variation_embolden=1.10
    var frame := Node3D.new();frame.name="OutlinedMetalStationLetters";frame.position=p;frame.rotation.y=yaw;add_child(frame)
    var size := 0.0048
    var total: float=float(maxi(value.length()-1,0))*0.035
    for letter in value:
        if not await _line_checkpoint(): return
        total+=font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,72).x*size
    var cursor: float=-total*0.5
    for letter in value:
        if not await _line_checkpoint(): return
        var advance: float=font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,72).x*size
        for face in range(2):
            if not await _line_checkpoint(): return
            var mesh := TextMesh.new();mesh.font=font;mesh.text=letter;mesh.font_size=72;mesh.pixel_size=size;mesh.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
            mesh.depth=0.045 if face==0 else 0.007;mesh.material=black if face==0 else lettering
            var node := MeshInstance3D.new();node.mesh=mesh;node.position=Vector3(cursor+advance*0.5,0,0.0 if face==0 else 0.026)
            if face==1:node.scale=Vector3(0.98,0.98,1.0)
            frame.add_child(node)
        cursor+=advance+0.035

func _columns_and_girders() -> void:
    if not await _line_checkpoint(): return
    var bottom: float=FY+0.09
    var capital := FY+2.70
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        var x: float=CX+side*COL_X
        box(Vector3(0.86,0.53,GIRDER_END-GIRDER_START),Vector3(x,5.385,(GIRDER_START+GIRDER_END)*0.5),white)
        # Omit exactly the first/last column in each row: four columns in total.
        for i in range(1,19):
            if not await _line_checkpoint(): return
            var z: float=-1.50+float(i)*PITCH
            # Solid opaque core; four closed stone faces, no transparent column shader.
            box(Vector3(0.84,capital-bottom,0.84),Vector3(x,(capital+bottom)*0.5,z),column_stones[i%4])
            box(Vector3(0.87,0.09,0.87),Vector3(x,FY+0.045,z),black)
            box(Vector3(0.84,5.14-capital,0.84),Vector3(x,(capital+5.14)*0.5,z),white)
            # Stepped ogee-like light stone moulding wraps all four faces.
            for step in range(9):
                if not await _line_checkpoint(): return
                var t: float=float(step)/8.0
                var w: float=0.86+0.10*sin(t*PI)
                box(Vector3(w,0.028,w),Vector3(x,capital-0.04+t*0.224,z),trim)
            box(Vector3(0.86,0.17,0.86),Vector3(x,capital+0.235,z),column_stones[(i+1)%4])
            box(Vector3(0.89,0.025,0.89),Vector3(x,capital+0.335,z),trim)
            # Narrow polished vertical paired strips on the broad marble faces.
            for dx in [-0.045,0.045]:
                if not await _line_checkpoint(): return
                for face in [-1.0,1.0]:
                    if not await _line_checkpoint(): return
                    box(Vector3(0.027,3.84,0.018),Vector3(x+float(dx),FY+1.98,z+face*0.43),metal)
                    box(Vector3(0.018,3.84,0.027),Vector3(x+face*0.43,FY+1.98,z+float(dx)),metal)
            for h in [FY+0.91,FY+1.78]:
                if not await _line_checkpoint(): return
                box(Vector3(0.842,0.002,0.842),Vector3(x,float(h),z),_material(Color("#656962"),0.0,0.6))
            if i<18:
                await _haunch(x,z+0.42,1.0)
                await _haunch(x,z+PITCH-0.42,-1.0)
                var center: float=z+PITCH*0.5
                box(Vector3(0.055,0.048,3.23),Vector3(x,5.107,center),glow)
                box(Vector3(0.065,0.045,3.47),Vector3(x-side*0.36,5.70,center),glow)

func _haunch(x: float,z: float,direction: float) -> void:
    if not await _line_checkpoint(): return
    # Rounded upper inside corner of each rectangular opening, in the Y/Z plane.
    var points := PackedVector2Array([Vector2(z,5.14),Vector2(z,4.93)])
    for i in range(13):
        if not await _line_checkpoint(): return
        var a: float=float(i)*PI/24.0
        points.append(Vector2(z+direction*(0.20-0.20*cos(a)),4.94+0.20*sin(a)))
    var caps := Geometry2D.triangulate_polygon(points)
    for face in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        for k in range(0,caps.size(),3):
            if not await _line_checkpoint(): return
            var a: Vector2=points[caps[k]];var b: Vector2=points[caps[k+1]];var c: Vector2=points[caps[k+2]]
            triangle(Vector3(x+face*0.43,a.y,a.x),Vector3(x+face*0.43,b.y,b.x),Vector3(x+face*0.43,c.y,c.x),white,Vector3(face,0,0))
    for i in range(points.size()):
        if not await _line_checkpoint(): return
        var a: Vector2=points[i];var b: Vector2=points[(i+1)%points.size()]
        quad(Vector3(x-0.43,a.y,a.x),Vector3(x+0.43,a.y,a.x),Vector3(x+0.43,b.y,b.x),Vector3(x-0.43,b.y,b.x),white)

func _ceilings() -> void:
    if not await _line_checkpoint(): return
    # Existing photographic paint and relief stay separate from column/wall finishes.
    var plaster := _photo("ceiling_paint.jpg",Vector2(0.72,0.72),0.96)
    plaster.albedo_color=Color(0.98,0.976,0.96)
    plaster.normal_enabled=true;plaster.normal_texture=load(ART+"ceiling_normal.png");plaster.normal_scale=0.42
    var rib_paint := plaster.duplicate() as StandardMaterial3D
    rib_paint.albedo_color=Color(0.955,0.95,0.93)
    box(Vector3(5.12,0.12,SOUTH-NORTH-0.20),Vector3(CX,6.04,(NORTH+SOUTH)*0.5),plaster)
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        # Outer strip reaches the tunnel header; inner strip ends before either ascent.
        var outer_length: float=_portal_z(1.0)-_portal_z(-1.0)+0.20
        box(Vector3(5.40,0.12,outer_length),Vector3(CX+side*6.25,5.73,(NORTH+SOUTH)*0.5),plaster)
        box(Vector3(1.045,0.12,SOUTH-NORTH-0.20),Vector3(CX+side*3.0325,5.73,(NORTH+SOUTH)*0.5),plaster)
        # Narrow projecting cornices give the longitudinal edges a readable profile.
        box(Vector3(0.105,0.075,GIRDER_END-GIRDER_START),Vector3(CX+side*2.18,5.645,(GIRDER_START+GIRDER_END)*0.5),rib_paint)
    for i in range(59):
        if not await _line_checkpoint(): return
        var z: float=ZA+0.35+float(i)*1.80
        if z>NORTH and z<SOUTH:
            await _rounded_ceiling_rib(Vector3(4.35,0.34,0.16),Vector3(CX,5.80,z),rib_paint)
        for side in [-1.0,1.0]:
            if not await _line_checkpoint(): return
            if z>NORTH and z<SOUTH:
                await _rounded_ceiling_rib(Vector3(6.40,0.34,0.14),Vector3(CX+side*5.73,5.50,z),rib_paint)
            elif z>_portal_z(-1.0) and z<_portal_z(1.0):
                await _rounded_ceiling_rib(Vector3(5.38,0.34,0.14),Vector3(CX+side*6.24,5.50,z),rib_paint)
    for child in get_children():
        if not await _line_checkpoint(): return
        if child is OmniLight3D:
            child.position.y=5.45;child.light_energy=1.30;child.light_color=Color(1.0,0.98,0.94)
    for z in [7.0,33.0,61.0,84.0]:
        if not await _line_checkpoint(): return
        var light := OmniLight3D.new();light.position=Vector3(CX,5.74,float(z));light.light_energy=0.45;light.omni_range=14.0;light.shadow_enabled=false;add_child(light)
    # Gentle upward light makes the physical ribs cast onto the ceiling.
    # Existing diffuse lamps keep their unshadowed fill; avoid cube-map omni shadows.
    for z in [20.762,40.562,60.362]:
        if not await _line_checkpoint(): return
        var light := SpotLight3D.new()
        light.name="CeilingRibUplight";light.position=Vector3(CX+0.55,5.32,float(z));light.rotation.x=PI/2.0
        light.light_color=Color(1.0,0.98,0.94);light.light_energy=0.28
        light.spot_range=8.0;light.spot_angle=80.0
        light.shadow_enabled=true;light.shadow_bias=0.06;light.shadow_normal_bias=1.0
        add_child(light)

func _stairs(direction: float,start: float) -> void:
    if not await _line_checkpoint(): return
    var width := 7.1
    var rise := 0.13
    var run := 0.30
    var landing := 0.90
    var top: float=FY+36*rise
    for i in range(36):
        if not await _line_checkpoint(): return
        var h: float=float(i+1)*rise
        var z: float=start+direction*(float(i)*run+(landing if i>=20 else 0.0))
        box(Vector3(width,h,run+0.003),Vector3(CX,FY+h*0.5,z),stair_stone)
        if i in [0,19,20,35]:box(Vector3(width,0.016,0.06),Vector3(CX,FY+h+0.009,z-direction*0.12),yellow)
    box(Vector3(width,0.18,landing),Vector3(CX,FY+20*rise-0.09,start+direction*6.30),stair_stone)
    var finish: float=start+direction*(35*run+landing+run*0.5)
    box(Vector3(width,0.20,3.8),Vector3(CX,top-0.10,finish+direction*1.8),floor_stone)
    await _exit_hall(direction,start,width,top,UPPER_HALL_LENGTH)
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        var x: float=CX+side*(width*0.5-0.045)
        var points := [Vector2(-0.30,0),Vector2(5.85,20*rise),Vector2(6.75,20*rise),Vector2(11.55,36*rise)]
        for i in range(points.size()-1):
            if not await _line_checkpoint(): return
            var a: Vector2=points[i];var b: Vector2=points[i+1]
            rod(Vector3(x,FY+0.88+a.y,start+direction*a.x),Vector3(x,FY+0.88+b.y,start+direction*b.x),0.027,metal)
        rod(Vector3(x,FY+0.88,start),Vector3(x,FY+0.67,start-direction*0.20),0.027,metal)
    board("exit_stairs.jpg",Vector3(CX,4.72,start-direction*0.45),Vector2(5.75,0.84))
    foot_grille(start-direction*0.7,7.35)

func _escalators(start: float) -> void:
    if not await _line_checkpoint(): return
    var width := 7.10
    var rise := 4.65
    var run := 9.20
    var lower := 1.20
    var tan := _material(Color("#9a8060"),0.25,0.38)
    var rubber := _material(Color("#20241f"),0.05,0.60)
    var stepmat := _material(Color("#5d625b"),0.45,0.50)
    var half_step: float=ESCALATOR_STEP_WIDTH*0.5
    var half_case: float=ESCALATOR_PITCH*0.5
    var side_width: float=half_case-half_step
    await _exit_hall(1.0,start,width,FY+rise,UPPER_HALL_LENGTH)
    # Full lower slab and full-height upper landing close the machine pit and rear view.
    box(Vector3(width+0.04,0.16,14.9),Vector3(CX,FY-0.08,start+7.25),floor_stone)
    box(Vector3(width+0.04,rise+0.05,4.40),Vector3(CX,FY+(rise-0.05)*0.5,start+12.5),floor_stone)
    var body := PackedVector2Array([Vector2(-0.18,0.025),Vector2(lower,0.025),Vector2(lower+run,rise-0.16),Vector2(12.30,rise-0.16)])
    var casing := PackedVector2Array([Vector2(-0.16,0.76),Vector2(lower,0.76),Vector2(lower+run,rise+0.76),Vector2(12.25,rise+0.76)])
    # Three complete housings touch at their sides. There is no open trench between lanes.
    for lane in range(3):
        if not await _line_checkpoint(): return
        var x: float=CX+(float(lane)-1.0)*ESCALATOR_PITCH
        await _closed_ramp_strip(x-half_case-0.006,x+half_case+0.006,start,body,tan)
        for i in range(49):
            if not await _line_checkpoint(): return
            var t: float=float(i)/48.0
            var z: float=start+lower+t*run
            var h: float=maxf(0.045,rise*t)
            box(Vector3(ESCALATOR_STEP_WIDTH,h,0.205),Vector3(x,FY+h*0.5,z),stepmat)
            for groove in range(14):
                if not await _line_checkpoint(): return
                box(Vector3(0.006,0.007,0.185),Vector3(x-half_step+0.05+float(groove)*(ESCALATOR_STEP_WIDTH-0.10)/13.0,FY+h+0.004,z),black)
        box(Vector3(ESCALATOR_STEP_WIDTH,0.04,1.25),Vector3(x,FY+0.02,start+0.48),stepmat)
        for side in [-1.0,1.0]:
            if not await _line_checkpoint(): return
            var x0: float=x+side*half_step
            var x1: float=x+side*half_case
            await _closed_ramp_strip(minf(x0,x1)-0.006,maxf(x0,x1)+0.006,start,casing,tan)
            var bx: float=x+side*(half_step+side_width*0.5)
            var offsets := [Vector2(0.0,0.0),Vector2(lower,0.0),Vector2(lower+run,rise),Vector2(12.20,rise)]
            for i in range(offsets.size()-1):
                if not await _line_checkpoint(): return
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
        if not await _line_checkpoint(): return
        var x0: float=CX+side*ESCALATOR_PITCH*1.5
        var x1: float=CX+side*(width*0.5+0.025)
        await _closed_ramp_strip(minf(x0,x1)-0.006,maxf(x0,x1)+0.006,start,casing,wall_stone)
    board("exit_escalators.jpg",Vector3(CX,4.71,start-0.48),Vector2(5.75,0.84))
    foot_grille(start-0.46,7.25)

func _exit_hall(direction: float,start: float,width: float,top: float,length: float) -> void:
    if not await _line_checkpoint(): return
    var roof_y: float=top+2.90
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        var x: float=CX+side*(width*0.5+0.14)
        box(Vector3(0.28,roof_y+0.10-FY,length),Vector3(x,(roof_y+0.10+FY)*0.5,start+direction*(length*0.5-0.30)),wall_stone)
        box(Vector3(0.29,0.09,length),Vector3(x,FY+0.045,start+direction*(length*0.5-0.30)),black)
        picture("no_smoking.svg",Vector2(0.22,0.22),Vector3(x,FY+1.9,start-direction*0.46),0.0 if direction<0 else PI)
        picture("sos_info.svg",Vector2(0.25,0.39),Vector3(x,FY+0.94,start-direction*0.462),0.0 if direction<0 else PI)
        _camera_box(Vector3(x-side*0.16,4.92,start-direction*0.5),0.0 if direction<0 else PI)
    box(Vector3(width+0.55,0.20,length),Vector3(CX,roof_y,start+direction*(length*0.5-0.30)),white)
    box(Vector3(width+0.55,roof_y+0.10-5.34,0.40),Vector3(CX,(roof_y+0.10+5.34)*0.5,start-direction*0.36),white)
    for i in range(14):
        if not await _line_checkpoint(): return
        var z: float=start+direction*float(i)*1.4
        box(Vector3(width+0.1,0.20,0.16),Vector3(CX,roof_y-0.20,z),white)
        if i%2==0:box(Vector3(5.60,0.035,0.07),Vector3(CX,roof_y-0.33,z),glow)
    box(Vector3(width+0.55,roof_y+0.10-FY,0.24),Vector3(CX,(roof_y+0.10+FY)*0.5,start+direction*(length-0.45)),wall_stone)
    await _upper_landing(direction,start,width,top,length)

func _signs() -> void:
    if not await _line_checkpoint(): return
    # Clear opening = 4.35 - .84 = 3.51 m; framed signs = 3.23 m.
    for bay in [2,7,12,17]:
        if not await _line_checkpoint(): return
        var z: float=-1.5+(float(bay)+0.5)*PITCH
        for side in [-1.0,1.0]:
            if not await _line_checkpoint(): return
            var p := Vector3(CX+side*COL_X,4.63,z)
            var size := Vector2(3.15,0.47)
            box(Vector3(0.075,0.55,3.23),p,metal)
            for face in [-1.0,1.0]:
                if not await _line_checkpoint(): return
                picture("platform_track1.jpg" if side>0 else "platform_track2.jpg",size,p+Vector3(face*0.043,0,0),face*PI/2.0)
            for dz in [-1.40,1.40]:
                if not await _line_checkpoint(): return
                rod(p+Vector3(0,0.27,float(dz)),Vector3(p.x,5.12,z+float(dz)),0.022,metal)

func _bench(p: Vector3) -> void:
    if not await _line_checkpoint(): return
    var brown := _material(Color("#514339"),0.25,0.61)
    box(Vector3(0.60,0.38,2.45),p+Vector3(0,0.19,0),brown)
    for i in range(5):
        if not await _line_checkpoint(): return
        var z: float=p.z-0.98+float(i)*0.49
        await _rounded_bench_box(Vector3(0.63,0.10,0.46),Vector3(p.x,p.y+0.43,z),bench_oak,0.025)
        for dx in [-0.14,0.14]:
            if not await _line_checkpoint(): return
            box(Vector3(0.009,0.008,0.455),Vector3(p.x+float(dx),p.y+0.485,z),brown)
        if i<4:box(Vector3(0.68,0.065,0.037),Vector3(p.x,p.y+0.46,z+0.244),brown)

func _television(z: float,event: bool) -> void:
    if not await _line_checkpoint(): return
    var p := Vector3(CX,4.65,z)
    box(Vector3(1.56,0.95,0.13),p,black)
    for dx in [-0.48,0.48]:
        if not await _line_checkpoint(): return
        rod(p+Vector3(float(dx),0.50,0),Vector3(CX+float(dx),5.98,z),0.015,metal)
        box(Vector3(0.14,0.02,0.16),Vector3(CX+float(dx),5.97,z),metal)
    for face in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        if event:picture("student_event.jpg",Vector2(1.48,0.86),p+Vector3(0,0,face*0.07),0.0 if face>0 else PI)
        else:box(Vector3(1.48,0.86,0.006),p+Vector3(0,0,face*0.07),_material(Color("#111719"),0.35,0.15))

func _floor_fittings() -> void:
    if not await _line_checkpoint(): return
    for z in [11.0,37.0,65.0]:
        if not await _line_checkpoint(): return
        cylinder(0.20,0.014,Vector3(CX+0.3,FY+0.023,float(z)),metal)
        for i in range(6):
            if not await _line_checkpoint(): return
            box(Vector3(0.012,0.016,0.25),Vector3(CX+0.22+float(i)*0.032,FY+0.030,float(z)),black)
        box(Vector3(0.35,0.018,0.38),Vector3(CX-0.25,FY+0.025,float(z)+3.4),trim)
        for i in range(8):
            if not await _line_checkpoint(): return
            box(Vector3(0.20,0.022,0.018),Vector3(CX-0.25,FY+0.030,float(z)+3.26+float(i)*0.036),black)

func _track_details() -> void:
    if not await _line_checkpoint(): return
    for x in [0.992,-11.732]:
        if not await _line_checkpoint(): return
        for direction in [-1.0,1.0]:
            if not await _line_checkpoint(): return
            var end: float=_portal_z(direction)
            var far: float=ZA-8.0 if direction<0.0 else ZB+8.0
            var length: float=absf(far-end)
            var center: float=(far+end)*0.5
            box(Vector3(3.92,0.20,length+0.12),Vector3(x,4.90,center),wall_stone)
            for side in [-1.0,1.0]:
                if not await _line_checkpoint(): return
                box(Vector3(0.14,5.02,length+0.12),Vector3(x+side*1.94,2.31,center),wall_stone)
                for h in [0.70,1.1,1.5,1.9,2.35,2.65]:
                    if not await _line_checkpoint(): return
                    rod(Vector3(x+side*1.84,float(h),end),Vector3(x+side*1.84,float(h),far-direction*0.20),0.015,black)
            box(Vector3(4.04,5.45,0.14),Vector3(x,2.275,far),black)

func _portal_equipment() -> void:
    if not await _line_checkpoint(): return
    var infra := get_node("StationInfrastructure")
    infra.set("_amber",Color(1.0,0.13,0.055))
    var displays: Array=infra.get("_displays")
    for display in displays:
        if not await _line_checkpoint(): return
        for i in range(70,76):
            if not await _line_checkpoint(): return
            display.set_instance_color(i,Color(1.0,0.13,0.055))
    for node in infra.get_children():
        if not await _line_checkpoint(): return
        if node is Node3D and "Portal" in str(node.name):
            node.position.y=4.68
            node.position.z=_portal_z(-1.0)+0.20 if "Portal1Clock" in str(node.name) else _portal_z(1.0)-0.20
            # Track 1 runs toward decreasing Z; Track 2 has the opposite leading end.
            node.visible=str(node.name)=="Track1Portal1Clock" or str(node.name)=="Track2Portal2Clock"
    for direction in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        var end: float=_portal_z(direction)
        for side in [-1.0,1.0]:
            if not await _line_checkpoint(): return
            var tx: float=CX+side*6.362
            var yaw: float=0.0 if direction<0.0 else PI
            if side==-direction:
                var root := Node3D.new();root.name="WhiteDriverMirror";root.position=Vector3(CX+side*4.58,FY+1.42,end-direction*2.6);root.rotation.y=yaw-side*0.12;add_child(root)
                var mirror := MeshInstance3D.new();mirror.set_script(preload("res://modules/stations/akademiya_nauk/driver_mirrors.gd"));mirror.name="ReflectingSurface";mirror.position.z=0.016
                var q := QuadMesh.new();q.size=Vector2(0.60,1.56);mirror.mesh=q;mirror.set_meta("mirror_size",q.size);root.add_child(mirror)
                var pts: Array[Vector3]=[]
                for corner in range(4):
                    if not await _line_checkpoint(): return
                    var c := Vector2(0.235*(1.0 if corner in [0,3] else -1.0),0.70*(1.0 if corner in [0,1] else -1.0))
                    for j in range(9):
                        if not await _line_checkpoint(): return
                        var a: float=float(corner)*PI/2.0+float(j)*PI/16.0;pts.append(Vector3(c.x+0.11*cos(a),c.y+0.11*sin(a),0))
                for i in range(pts.size()):
                    if not await _line_checkpoint(): return
                    _local_rod(root,pts[i],pts[(i+1)%pts.size()],0.032,white)
                _local_rod(root,Vector3(0,-1.42,0),Vector3(0,-0.80,0),0.075,_material(Color("#285476"),0.3,0.42))
                for dx in [-0.42,0.42]:
                    if not await _line_checkpoint(): return
                    _local_rod(root,Vector3(float(dx),-1.42,0),Vector3(float(dx),-0.52,0.10),0.023,metal)
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


func _portal_z(direction: float) -> float:
    return NORTH-PORTAL_GAP if direction<0.0 else SOUTH+PORTAL_GAP

func _close_end_joints() -> void:
    if not await _line_checkpoint(): return
    # Overlap opaque native wall/roof meshes so the tunnel mouths form one closed shell.
    for direction in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        var start: float=NORTH if direction<0.0 else SOUTH
        var end: float=_portal_z(direction)
        for side in [-1.0,1.0]:
            if not await _line_checkpoint(): return
            box(Vector3(3.94,1.40,0.32),Vector3(CX+side*6.362,5.14,end),wall_stone)
            box(Vector3(0.94,5.84-FY,PORTAL_GAP+0.60),Vector3(CX+side*4.01,(5.84+FY)*0.5,(start+end)*0.5),wall_stone)
            box(Vector3(0.66,6.29,0.32),Vector3(CX+side*8.57,2.695,end),wall_stone)
    # Close the raised roof's exposed edges without changing its lighting/materials.
    for side in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        box(Vector3(0.18,0.58,SOUTH-NORTH-0.20),Vector3(CX+side*2.55,5.83,(NORTH+SOUTH)*0.5),white)

func _closed_ramp_strip(x0: float,x1: float,start: float,points: PackedVector2Array,mat: Material) -> void:
    if not await _line_checkpoint(): return
    # Closed six-face segments, including the floor and both end caps; standard mesh surfaces.
    var bottom: float=FY-0.06
    for i in range(points.size()-1):
        if not await _line_checkpoint(): return
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

# Local copy of the Moscow bench profile; no dependency on the other station package.
func _rounded_bench_box(size: Vector3,p: Vector3,mat: Material,radius: float=0.03) -> void:
    if not await _line_checkpoint(): return
    var r: float=minf(radius,minf(size.x,size.y)*0.49)
    var pts := PackedVector2Array()
    for corner in range(4):
        if not await _line_checkpoint(): return
        var center := Vector2(p.x+(size.x*0.5-r)*(1.0 if corner in [0,3] else -1.0),p.y+(size.y*0.5-r)*(1.0 if corner in [0,1] else -1.0))
        for j in range(7):
            if not await _line_checkpoint(): return
            var a: float=float(corner)*PI/2.0+float(j)*PI/12.0;pts.append(center+Vector2(cos(a),sin(a))*r)
    await extrusion(pts,p.z-size.z*0.5,p.z+size.z*0.5,mat)

func _rounded_ceiling_rib(size: Vector3,p: Vector3,mat: Material) -> void:
    if not await _line_checkpoint(): return
    # Closed native cross-section along X: eased lower edges, solid end caps.
    var radius := 0.022
    var points := PackedVector2Array()
    for corner in range(4):
        if not await _line_checkpoint(): return
        var center := Vector2((size.y*0.5-radius)*(1.0 if corner in [0,3] else -1.0),(size.z*0.5-radius)*(1.0 if corner in [0,1] else -1.0))
        for j in range(5):
            if not await _line_checkpoint(): return
            var angle: float=float(corner)*PI/2.0+float(j)*PI/8.0
            points.append(center+Vector2(cos(angle),sin(angle))*radius)
    var x0: float=p.x-size.x*0.5
    var x1: float=p.x+size.x*0.5
    for i in range(points.size()):
        if not await _line_checkpoint(): return
        var a: Vector2=points[i];var b: Vector2=points[(i+1)%points.size()]
        var hint := Vector3(0,(a.x+b.x)*0.5,(a.y+b.y)*0.5)
        quad(Vector3(x0,p.y+a.x,p.z+a.y),Vector3(x1,p.y+a.x,p.z+a.y),Vector3(x1,p.y+b.x,p.z+b.y),Vector3(x0,p.y+b.x,p.z+b.y),mat,hint)
    var caps := Geometry2D.triangulate_polygon(points)
    for face in [-1.0,1.0]:
        if not await _line_checkpoint(): return
        var x: float=x0 if face<0.0 else x1
        for i in range(0,caps.size(),3):
            if not await _line_checkpoint(): return
            var a: Vector2=points[caps[i]];var b: Vector2=points[caps[i+1]];var c: Vector2=points[caps[i+2]]
            triangle(Vector3(x,p.y+a.x,p.z+a.y),Vector3(x,p.y+b.x,p.z+b.y),Vector3(x,p.y+c.x,p.z+c.y),mat,Vector3(face,0,0))

func _upper_landing(direction: float,start: float,width: float,top: float,length: float) -> void:
    if not await _line_checkpoint(): return
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
        if not await _line_checkpoint(): return
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
            if not await _line_checkpoint(): return
            _local_rod(gate,Vector3(0.18,0.64,0),Vector3(0.77,0.64+0.27*sin(float(angle)),0.27*cos(float(angle))),0.018,steel)
        for z in [-0.35,0.35]:
            if not await _line_checkpoint(): return
            _landing_box(gate,"BasePlate",Vector3(0.33,0.022,0.23),Vector3(0,0.011,float(z)),steel)
    var booth := Node3D.new();booth.name="ControllerBooth";booth.position=Vector3(2.55,0,UPPER_GATE_DISTANCE+0.90)
    booth.set_meta("role","equipment");booth.set_meta("static_architecture",true);root.add_child(booth)
    var glass := _material(Color(0.64,0.77,0.79,0.26),0.05,0.17)
    glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
    _landing_box(booth,"Floor",Vector3(1.43,0.045,1.80),Vector3(0,0.0225,0),steel)
    _landing_box(booth,"FrontApron",Vector3(1.42,0.80,0.055),Vector3(0,0.40,-0.875),wall_stone)
    for x in [-0.69,0.69]:
        if not await _line_checkpoint(): return
        _landing_box(booth,"SideApron",Vector3(0.055,0.80,1.75),Vector3(float(x),0.40,0),wall_stone)
        _landing_box(booth,"SideWindow",Vector3(0.018,1.26,1.68),Vector3(float(x),1.47,0),glass)
        for z in [-0.875,0.875]:
            if not await _line_checkpoint(): return
            _landing_box(booth,"CornerPost",Vector3(0.045,2.16,0.045),Vector3(float(x),1.10,float(z)),steel)
        _landing_box(booth,"WindowRail",Vector3(0.04,0.045,1.79),Vector3(float(x),0.83,0),steel)
    _landing_box(booth,"FrontWindow",Vector3(1.34,1.26,0.018),Vector3(0,1.47,-0.875),glass)
    _landing_box(booth,"Door",Vector3(1.32,2.02,0.022),Vector3(0,1.07,0.875),glass)
    for x in [-0.64,0.64]:
        if not await _line_checkpoint(): return
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
