extends "res://modules/stations/mihalovo/station_builder.gd"
## Міхалова: owner archive 22 November. Native meshes; Station Base rail datum retained.
const ART := "res://modules/stations/mihalovo/art/"
const SOFFIT := 5.65
const CENTRAL_ROOF := 6.55
const UPPER := FY+4.32
var layout: Dictionary
var floor_light: StandardMaterial3D
var floor_dark: StandardMaterial3D
var wall_dark: StandardMaterial3D
var wall_marble: StandardMaterial3D
var stair_stone: StandardMaterial3D
var seat_wood: StandardMaterial3D
var cream: StandardMaterial3D
var navy: StandardMaterial3D
var burgundy: StandardMaterial3D
var glass: StandardMaterial3D
var yellow: StandardMaterial3D
var relief_meshes: Dictionary={}

func _ready() -> void:
    super._ready()
    begin_station()
    layout=JSON.parse_string(FileAccess.get_file_as_string(ART+"station_layout.json"))
    for child in get_children():
        if child is OmniLight3D:child.queue_free()
    floor_light=_photo("floor_light.jpg",Vector2(0.6,0.6),0.31)
    floor_dark=_photo("floor_dark.jpg",Vector2(0.6,0.6),0.28)
    wall_dark=_photo("wall_granite.jpg",Vector2(1.2,0.6),0.38)
    wall_marble=_photo("wall_marble.jpg",Vector2(0.6,0.6),0.34)
    stair_stone=_photo("stair_granite.jpg",Vector2(1.0,0.3),0.57)
    seat_wood=_photo("seat_wood.jpg",Vector2(0.52,0.85),0.30)
    cream=_material(Color("#e2ddc5"),0.12,0.24)
    navy=_material(Color("#1e2537"),0.12,0.64)
    burgundy=_material(Color("#302231"),0.28,0.25)
    yellow=_material(Color("#dfba39"),0.0,0.65)
    glass=_material(Color(0.17,0.23,0.25,0.48),0.14,0.09)
    glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    glass.cull_mode=BaseMaterial3D.CULL_DISABLED
    glass.metallic_specular=0.85
    _platform();_track_walls();_roof()
    for z in layout.column_z_m:
        for offset in layout.column_rows_x_m:_column(float(offset),float(z))
    for z in layout.benches_z_m:_bench(float(z))
    for stair in layout.stairs:_stair_node(float(stair.direction),float(stair.start_z_m))
    _lift();_service_core();_railway();_equipment();_anchors()
    flush()

func _photo(file: String,metres: Vector2,roughness: float) -> StandardMaterial3D:
    var m = StandardMaterial3D.new()
    m.albedo_texture=load(ART+file);m.roughness=roughness
    m.uv1_triplanar=true;m.uv1_world_triplanar=true;m.uv1_triplanar_sharpness=8.0
    m.uv1_scale=Vector3(1.0/metres.x,1.0/metres.y,1.0/metres.x)
    m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return m

func _solid(size: Vector3,p: Vector3,mat: Material) -> void:
    box(size,p,mat)
    var body = StaticBody3D.new();body.name="ArchitectureCollision";body.position=p
    var shape = BoxShape3D.new();shape.size=size
    var collision = CollisionShape3D.new();collision.shape=shape;body.add_child(collision);add_child(body)

func _platform() -> void:
    _solid(Vector3(10,0.2,105),Vector3(CX,FY-0.1,MID),floor_light)
    for row in range(175):
        for col in range(16):
            box(Vector3(0.598,0.009,0.598),Vector3(CX-4.8+(float(col)+0.5)*0.6,FY+0.008,ZA+(float(row)+0.5)*0.6),floor_light)
    # Repeated broad dark granite rectangles, pale triangular sails and perimeter ribbons.
    for z in [6.0,19.0,31.8,44.6,57.4,70.2,83.0]:
        box(Vector3(5.7,0.012,5.2),Vector3(CX,FY+0.017,float(z)),floor_dark)
        var y = FY+0.026
        triangle(Vector3(CX-2.85,y,float(z)-2.58),Vector3(CX+1.9,y,float(z)-2.58),Vector3(CX-0.45,y,float(z)+0.2),floor_light,Vector3.UP)
        triangle(Vector3(CX+2.85,y,float(z)+2.58),Vector3(CX-1.9,y,float(z)+2.58),Vector3(CX+0.45,y,float(z)-0.2),floor_light,Vector3.UP)
    for side in [-1.0,1.0]:
        box(Vector3(0.26,0.015,105),Vector3(CX+side*4.84,FY+0.016,MID),floor_light)
        box(Vector3(0.12,0.012,105),Vector3(CX+side*4.59,FY+0.024,MID),yellow)
        box(Vector3(0.18,0.012,105),Vector3(CX+side*4.40,FY+0.023,MID),floor_dark)
        for i in range(875):
            for dx in [-0.035,0.0,0.035]:
                cylinder(0.007,0.003,Vector3(CX+side*4.59+float(dx),FY+0.032,ZA+float(i)*0.12),yellow)
    for z in [9.0,11.3,19.0]:
        for side in [-1.0,1.0]:box(Vector3(0.18,0.012,3.5),Vector3(CX+side*1.8,FY+0.032,float(z)),floor_dark)

func _track_walls() -> void:
    for side in [-1.0,1.0]:
        var x = CX+side*8.56
        _solid(Vector3(0.24,1.85,105),Vector3(x,0.925,MID),wall_dark)
        # Warm cream panels curve gently towards the inward rolled ceiling return.
        for i in range(126):
            var z = ZA+(float(i)+0.5)*105.0/126.0
            for j in range(8):
                var y0 = 1.85+float(j)*0.245;var y1 = y0+0.245
                var x0 = x-side*0.075*pow(float(j)/8.0,2.0)
                var x1 = x-side*0.075*pow(float(j+1)/8.0,2.0)
                quad(Vector3(x0,y0,z-0.416),Vector3(x1,y1,z-0.416),Vector3(x1,y1,z+0.416),Vector3(x0,y0,z+0.416),cream,Vector3(-side,0,0))
            box(Vector3(0.025,1.96,0.015),Vector3(x-side*0.09,2.83,z-0.417),metal)
        box(Vector3(0.26,0.58,105),Vector3(x-side*0.08,4.10,MID),navy)
        for z in [-3.0,16.0,35.0,54.0,73.0,88.0]:
            _relief("name",Vector2(3.35,0.53),Vector3(x-side*0.15,2.78,float(z)),-side*PI/2.0)
        for z in [6.5,25.5,44.5,63.5,82.5]:
            picture("wall_route.svg",Vector2(3.85,0.79),Vector3(x-side*0.17,2.86,float(z)),-side*PI/2.0,true)
        # Bright uninterrupted wall light; short opaque end caps separate tubes.
        _light_strip(Vector3(x-side*0.22,4.46,ZA),Vector3(x-side*0.22,4.46,ZB),0.14)
        for z in range(66):box(Vector3(0.23,0.10,0.08),Vector3(x-side*0.22,4.46,ZA+float(z)*1.60),metal)
        for j in range(24):
            var a = float(j)*PI/48.0;var b = float(j+1)*PI/48.0
            var xa = CX+side*(7.35+1.20*sin(a));var xb = CX+side*(7.35+1.20*sin(b))
            var ya = 4.45+1.20*cos(a);var yb = 4.45+1.20*cos(b)
            quad(Vector3(xa,ya,ZA),Vector3(xb,yb,ZA),Vector3(xb,yb,ZB),Vector3(xa,ya,ZB),cream,Vector3(-side,-1,0))
        for i in range(1051):
            var z = ZA+float(i)*0.10
            for j in range(12):
                var a = float(j)*PI/24.0;var b = float(j+1)*PI/24.0
                rod(Vector3(CX+side*(7.35+1.196*sin(a)),4.45+1.196*cos(a),z),Vector3(CX+side*(7.35+1.196*sin(b)),4.45+1.196*cos(b),z),0.0035,black)

func _roof() -> void:
    for side in [-1.0,1.0]:
        box(Vector3(4.35,0.18,105),Vector3(CX+side*5.175,SOFFIT+0.09,MID),cream)
        for i in range(1051):box(Vector3(4.34,0.008,0.006),Vector3(CX+side*5.175,SOFFIT-0.006,ZA+float(i)*0.1),black)
        _light_strip(Vector3(CX+side*2.98,SOFFIT-0.11,ZA),Vector3(CX+side*2.98,SOFFIT-0.11,ZB),0.12)
    # End stairwells interrupt the central roof: no ceiling slab cuts across their upper flights.
    box(Vector3(5.96,0.18,76.8),Vector3(CX,CENTRAL_ROOF+0.09,39.6),navy)
    for z in range(13):
        var zz = 3.0+float(z)*6.1
        for side in [-1.0,1.0]:
            _light_strip(Vector3(CX+side*2.15,CENTRAL_ROOF-0.08,zz),Vector3(CX+side*2.15,CENTRAL_ROOF-0.08,zz+4.8),0.10)
        _light_strip(Vector3(CX-2.15,CENTRAL_ROOF-0.08,zz),Vector3(CX+2.15,CENTRAL_ROOF-0.08,zz),0.10)
    for i in range(15):
        for side in [-1.0,1.0]:
            _lamp(Vector3(CX+side*2.7,5.18,ZA+4.0+float(i)*6.85),0.95,8.3)

func _light_strip(a: Vector3,b: Vector3,width: float) -> void:
    var length = a.distance_to(b)
    var basis = Basis(Vector3.UP,atan2((b-a).x,(b-a).z))
    box(Vector3(width+0.035,0.07,length),((a+b)*0.5)+Vector3(0,0.025,0),metal,basis)
    box(Vector3(width,0.025,length-0.025),(a+b)*0.5,glow,basis)

func _lamp(p: Vector3,energy: float,radius: float,shadows: bool=false) -> void:
    var light = OmniLight3D.new();light.name="FluorescentFill";light.position=p
    light.light_color=Color(1.0,0.975,0.91);light.light_energy=energy;light.omni_range=radius
    light.omni_attenuation=1.15;light.shadow_enabled=shadows;light.shadow_bias=0.035;add_child(light)

func _round(radius: float,height: float,p: Vector3,mat: Material) -> void:
    var mesh = CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius
    mesh.height=height;mesh.radial_segments=64;mesh.material=mat
    var node = MeshInstance3D.new();node.mesh=mesh;node.position=p;add_child(node)

func _column(offset: float,z: float) -> void:
    var x = CX+offset
    _round(0.53,0.27,Vector3(x,FY+0.135,z),metal)
    _round(0.50,SOFFIT-FY-0.30,Vector3(x,(SOFFIT+FY+0.30)*0.5,z),cream)
    _round(0.57,0.07,Vector3(x,SOFFIT-0.025,z),black)
    for a in [0.0,PI/2.0,PI,PI*1.5]:
        rod(Vector3(x+0.502*cos(float(a)),FY+0.30,z+0.502*sin(float(a))),Vector3(x+0.502*cos(float(a)),SOFFIT-0.07,z+0.502*sin(float(a))),0.004,metal)
    for h in [0.09,0.25]:
        var mesh = TorusMesh.new();mesh.inner_radius=0.61;mesh.outer_radius=0.65;mesh.rings=64;mesh.ring_segments=12;mesh.material=metal
        var node = MeshInstance3D.new();node.mesh=mesh;node.position=Vector3(x,FY+float(h),z);add_child(node)
    for i in range(6):
        var a = float(i)*TAU/6.0
        rod(Vector3(x+0.62*cos(a),FY+0.04,z+0.62*sin(a)),Vector3(x+0.53*cos(a),FY+0.29,z+0.53*sin(a)),0.018,metal)
    var body = StaticBody3D.new();body.position=Vector3(x,(FY+SOFFIT)*0.5,z)
    var shape = CylinderShape3D.new();shape.radius=0.54;shape.height=SOFFIT-FY
    var collision = CollisionShape3D.new();collision.shape=shape;body.add_child(collision);add_child(body)

func _bench(z: float) -> void:
    # Five broad convex timber seats across the axis; pressed stainless pedestal.
    var profile = PackedVector2Array([Vector2(CX-1.40,FY+0.06),Vector2(CX+1.40,FY+0.06),Vector2(CX+1.40,FY+0.14),Vector2(CX+1.31,FY+0.21),Vector2(CX+1.31,FY+0.44),Vector2(CX-1.31,FY+0.44),Vector2(CX-1.31,FY+0.21),Vector2(CX-1.40,FY+0.14)])
    extrusion(profile,z-0.31,z+0.31,metal)
    for i in range(5):
        var x = CX-1.08+float(i)*0.54
        for j in range(16):
            var a = -PI/2.0+float(j)*PI/16.0;var b = -PI/2.0+float(j+1)*PI/16.0
            var z0 = z+0.43*sin(a);var z1 = z+0.43*sin(b)
            var y0 = FY+0.44+0.065*cos(a);var y1 = FY+0.44+0.065*cos(b)
            quad(Vector3(x-0.262,y0,z0),Vector3(x+0.262,y0,z0),Vector3(x+0.262,y1,z1),Vector3(x-0.262,y1,z1),seat_wood,Vector3.UP)
        box(Vector3(0.018,0.05,0.82),Vector3(x+0.27,FY+0.46,z),metal)

func _stair_node(direction: float,start: float) -> void:
    var width = 5.45
    var steps = 30
    var run = 0.30
    var rise = 0.144
    var landing = 1.25
    for i in range(steps):
        var h = float(i+1)*rise
        var z = start+direction*(float(i)*run+(landing if i>=15 else 0.0))
        _solid(Vector3(width,h,run+0.006),Vector3(CX,FY+h*0.5,z),stair_stone)
        box(Vector3(width,0.014,0.042),Vector3(CX,FY+h+0.01,z-direction*0.128),yellow if i in [0,14,15,29] else metal)
        for side in [-1.0,1.0]:box(Vector3(0.42,0.017,run+0.008),Vector3(CX+side*(width*0.5-0.21),FY+h+0.012,z),floor_dark)
    _solid(Vector3(width,0.20,landing),Vector3(CX,FY+15.0*rise-0.10,start+direction*(14.5*run+landing*0.5)),stair_stone)
    var end = start+direction*(29.5*run+landing)
    _solid(Vector3(width,0.22,5.0),Vector3(CX,UPPER-0.11,end+direction*2.5),floor_light)
    for side in [-1.0,1.0]:
        _stair_cheek(side,direction,start,width)
        for h in [0.72,1.02]:
            var x = CX+side*(width*0.5-0.14)
            var a = Vector3(x,FY+float(h),start-direction*0.25)
            var b = Vector3(x,FY+15.0*rise+float(h),start+direction*14.5*run)
            var c = b+Vector3(0,0,direction*landing)
            var d = Vector3(x,UPPER+float(h),end)
            rod(a,b,0.024,metal);rod(b,c,0.024,metal);rod(c,d,0.024,metal)
            for i in range(9):
                var t = float(i)/8.0
                rod(a.lerp(d,t)-Vector3(0,0.13,0),a.lerp(d,t)+Vector3(side*0.11,0,0),0.012,metal)
        # Upper landing balustrade is smoke glass, with individual clamps and steel cap rails.
        _glass_panel(Vector3(CX+side*2.76,UPPER+0.66,end+direction*2.2),Vector2(4.2,1.25),PI/2.0)
        rod(Vector3(CX+side*2.77,UPPER+1.30,end),Vector3(CX+side*2.77,UPPER+1.30,end+direction*4.5),0.026,metal)
    # Raised dark ceiling over the stair opening rather than a slab crossing the stairs.
    box(Vector3(5.96,0.18,16.5),Vector3(CX,8.50,start+direction*7.6),navy)
    for side in [-1.0,1.0]:_light_strip(Vector3(CX+side*2.3,8.36,start),Vector3(CX+side*2.3,8.36,end+direction*4.5),0.11)
    _lamp(Vector3(CX,6.8,start+direction*6.0),1.35,9.0,true)
    # Owner photo 170745: suspended steel birds over a rainbow and village silhouette.
    var art_z = end+direction*1.0
    box(Vector3(5.48,2.35,0.13),Vector3(CX,UPPER+1.65,art_z),navy)
    _relief("birds",Vector2(5.25,1.97),Vector3(CX,UPPER+1.68,art_z-direction*0.079),0.0 if direction<0.0 else PI)
    for sign_z in [start-direction*1.6]:
        board("exit.svg",Vector3(CX,4.33,float(sign_z)),Vector2(3.8,0.57))
    # Drainage grilles directly before first riser.
    box(Vector3(width,0.02,0.34),Vector3(CX,FY+0.025,start-direction*0.40),black)
    for i in range(100):box(Vector3(0.018,0.025,0.32),Vector3(CX-width*0.5+float(i)*width/100.0,FY+0.04,start-direction*0.40),metal)
    # Lateral alcoves at the platform end remain separate from the adjacent track tunnels.
    var terminal = ZA if direction<0.0 else ZB
    for side in [-1.0,1.0]:
        _solid(Vector3(1.85,4.30,0.22),Vector3(CX+side*3.9,FY+2.15,terminal),wall_marble)
        box(Vector3(0.9,2.02,0.025),Vector3(CX+side*3.9,FY+1.01,terminal-direction*0.13),cream)
        rod(Vector3(CX+side*3.55,FY+1.01,terminal-direction*0.16),Vector3(CX+side*3.55,FY+1.13,terminal-direction*0.16),0.015,metal)

func _stair_cheek(side: float,direction: float,start: float,width: float) -> void:
    var x = CX+side*(width*0.5+0.105)
    var total = 11.0
    var centre = 4.25
    var radius = 3.20
    var cy = FY+2.73
    var ry = 1.29
    # Solid marble above and below an elliptical opening; the opening is actual missing mesh.
    for i in range(88):
        var t0 = float(i)*total/88.0;var t1 = float(i+1)*total/88.0
        var inside = absf((t0+t1)*0.5-centre)<radius
        var dz0 = clampf((t0-centre)/radius,-1.0,1.0);var dz1 = clampf((t1-centre)/radius,-1.0,1.0)
        var root0 = sqrt(maxf(0.0,1.0-dz0*dz0));var root1 = sqrt(maxf(0.0,1.0-dz1*dz1))
        var lo0 = cy-ry*root0;var lo1 = cy-ry*root1
        var hi0 = cy+ry*root0;var hi1 = cy+ry*root1
        var z0 = start+direction*t0;var z1 = start+direction*t1
        for skin in [-1.0,1.0]:
            var xx = x+skin*0.085
            if inside:
                quad(Vector3(xx,FY,z0),Vector3(xx,lo0,z0),Vector3(xx,lo1,z1),Vector3(xx,FY,z1),wall_marble,Vector3(side,0,0))
                quad(Vector3(xx,hi0,z0),Vector3(xx,UPPER,z0),Vector3(xx,UPPER,z1),Vector3(xx,hi1,z1),wall_marble,Vector3(side,0,0))
            else:quad(Vector3(xx,FY,z0),Vector3(xx,UPPER,z0),Vector3(xx,UPPER,z1),Vector3(xx,FY,z1),wall_marble,Vector3(side,0,0))
        if inside:
            for upper in [false,true]:
                var ya = hi0 if upper else lo0;var yb = hi1 if upper else lo1
                quad(Vector3(x-0.085,ya,z0),Vector3(x+0.085,ya,z0),Vector3(x+0.085,yb,z1),Vector3(x-0.085,yb,z1),metal)
                rod(Vector3(x+side*0.095,ya,z0),Vector3(x+side*0.095,yb,z1),0.018,metal)
        # Fine marble tile joints around, but never across, the curved opening.
        if i%5==0:
            var segments: Array = [[FY,lo0],[hi0,UPPER]] if inside else [[FY,UPPER]]
            for limits in segments:
                box(Vector3(0.005,maxf(0.005,float(limits[1])-float(limits[0])),0.004),Vector3(x+side*0.088,(float(limits[0])+float(limits[1]))*0.5,z0),metal)
    box(Vector3(0.22,0.10,total),Vector3(x,UPPER+0.025,start+direction*total*0.5),metal)
    for i in range(7):
        var z = start+direction*(0.78+float(i)*1.52)
        _glass_panel(Vector3(x,UPPER+0.96,z),Vector2(1.50,1.79),PI/2.0)
        for dz in [-0.66,0.66]:
            for h in [0.23,1.60]:
                sphere(Vector3(0.04,0.075,0.075),Vector3(x+side*0.028,UPPER+float(h),z+float(dz)),metal)
    # Sideways access corridor: enough clearance outside the cheeks for walking.
    for t in [0.9,10.1]:
        var body = StaticBody3D.new();body.position=Vector3(x,FY+2.16,start+direction*float(t))
        var shape = BoxShape3D.new();shape.size=Vector3(0.18,4.32,1.65)
        var collision = CollisionShape3D.new();collision.shape=shape;body.add_child(collision);add_child(body)

func _glass_panel(p: Vector3,size: Vector2,yaw: float) -> void:
    var mesh = QuadMesh.new();mesh.size=size;mesh.material=glass
    var node = MeshInstance3D.new();node.name="SmokeTintedPointFixedGlass";node.mesh=mesh;node.position=p;node.rotation.y=yaw
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)

func _lift() -> void:
    var data: Dictionary=layout.lift
    var z = float(data.centre_z_m);var w = float(data.width_m);var length = float(data.length_m)
    _solid(Vector3(w,CENTRAL_ROOF-FY,length),Vector3(CX,(CENTRAL_ROOF+FY)*0.5,z),burgundy)
    box(Vector3(w+0.04,0.12,length+0.04),Vector3(CX,FY+0.06,z),metal)
    # Lift faces back towards the adjacent stair; other three sides remain closed.
    var front = z-length*0.5-0.016
    for side in [-1.0,1.0]:
        box(Vector3(0.14,2.40,0.12),Vector3(CX+side*0.76,FY+1.20,front-0.03),metal)
        box(Vector3(0.69,2.24,0.025),Vector3(CX+side*0.35,FY+1.13,front-0.102),metal)
        box(Vector3(0.014,2.22,0.014),Vector3(CX,FY+1.13,front-0.12),black)
    box(Vector3(1.67,0.24,0.12),Vector3(CX,FY+2.42,front-0.035),metal)
    picture("lift.svg",Vector2(0.95,0.15),Vector3(CX,FY+2.43,front-0.102),PI)
    box(Vector3(0.10,0.28,0.035),Vector3(CX-0.99,FY+1.18,front-0.03),metal)
    for h in [1.1,1.25]:sphere(Vector3(0.025,0.025,0.01),Vector3(CX-0.99,FY+float(h),front-0.053),black)
    box(Vector3(0.17,0.095,0.02),Vector3(CX,FY+2.49,front-0.13),black)
    for i in range(3):box(Vector3(0.008,0.06,0.005),Vector3(CX-0.02+float(i)*0.018,FY+2.49,front-0.144),_material(Color("#d8404b")))
    for side in [-1.0,1.0]:
        for t in [-0.5,0.0,0.5]:
            box(Vector3(0.014,CENTRAL_ROOF-FY,0.018),Vector3(CX+side*(w*0.5+0.01),(CENTRAL_ROOF+FY)*0.5,z+float(t)*length),metal)
            box(Vector3(0.018,CENTRAL_ROOF-FY,0.014),Vector3(CX+float(t)*w,(CENTRAL_ROOF+FY)*0.5,z+side*(length*0.5+0.01)),metal)
        for h in [0.67,0.89]:
            rod(Vector3(CX+side*(w*0.5+0.13),FY+float(h),z-length*0.5),Vector3(CX+side*(w*0.5+0.13),FY+float(h),z+length*0.5),0.027,metal)
            for dz in [-length*0.5,length*0.5]:rod(Vector3(CX+side*0.86,FY+float(h),z+float(dz)),Vector3(CX+side*(w*0.5+0.13),FY+float(h),z+float(dz)),0.027,metal)
    _lamp(Vector3(CX-2.1,5.9,z-1.1),0.55,5.0,true)
    for side in [-1.0,1.0]:
        box(Vector3(0.012,0.012,length),Vector3(CX+side*(w*0.5+0.014),FY+2.62,z),metal)

func _service_core() -> void:
    var data: Dictionary=layout.service_core
    var z = float(data.centre_z_m);var w = float(data.width_m);var length = float(data.length_m)
    _solid(Vector3(w,4.28,length),Vector3(CX,FY+2.14,z),wall_marble)
    for side in [-1.0,1.0]:
        var x = CX+side*(w*0.5+0.008)
        for i in range(7):box(Vector3(0.006,4.20,0.005),Vector3(x,FY+2.10,z-length*0.5+float(i)*0.6),metal)
        for i in range(7):box(Vector3(0.008,0.005,length),Vector3(x,FY+float(i)*0.6,z),metal)
        box(Vector3(0.03,2.0,0.88),Vector3(x+side*0.015,FY+1.0,z+0.85),cream)
        rod(Vector3(x+side*0.035,FY+0.96,z+1.18),Vector3(x+side*0.035,FY+1.1,z+1.18),0.012,metal)
        picture("no_smoking.svg",Vector2(0.15,0.15),Vector3(x+side*0.035,FY+2.48,z-1.0),side*PI/2.0,true)
        box(Vector3(0.025,0.45,length-0.30),Vector3(x+side*0.02,FY+3.86,z),black)
        for i in range(8):box(Vector3(0.04,0.014,length-0.35),Vector3(x+side*0.04,FY+3.67+float(i)*0.049,z),metal)
    board("exit.svg",Vector3(CX,4.22,z+length*0.5+0.12),Vector2(2.65,0.42))

func _relief(kind: String,size: Vector2,p: Vector3,yaw: float) -> void:
    if not relief_meshes.has(kind):
        var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ART+("name_relief.json" if kind=="name" else "birds_relief.json")))
        var nx = int(data.width);var ny = int(data.height);var values: Array=data["values"]
        var depth = float(data.depth_m)
        var st = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for y in range(ny-1):
            for x in range(nx-1):
                for d in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
                    var ix = x+d.x;var iy = y+d.y
                    var u = float(ix)/float(nx-1);var v = float(iy)/float(ny-1)
                    var dx = (float(values[iy*nx+mini(ix+1,nx-1)])-float(values[iy*nx+maxi(ix-1,0)]))*depth*float(nx)/size.x
                    var dy = (float(values[mini(iy+1,ny-1)*nx+ix])-float(values[maxi(iy-1,0)*nx+ix]))*depth*float(ny)/size.y
                    st.set_normal(Vector3(-dx,dy,1).normalized());st.set_uv(Vector2(u,v))
                    st.add_vertex(Vector3((u-0.5)*size.x,(0.5-v)*size.y,float(values[iy*nx+ix])*depth))
        st.generate_tangents()
        var mesh = st.commit()
        var mat = StandardMaterial3D.new();mat.albedo_texture=load(ART+("nameplate.jpg" if kind=="name" else "birds_panorama.jpg"))
        mat.metallic=0.58;mat.roughness=0.35;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
        mesh.surface_set_material(0,mat);relief_meshes[kind]=mesh
    var node = MeshInstance3D.new();node.name="OwnerPhotoRaised"+kind.capitalize();node.mesh=relief_meshes[kind];node.position=p;node.rotation.y=yaw;add_child(node)

func _railway() -> void:
    var detail = preload("res://modules/stations/mihalovo/track_detail.gd").new()
    detail.name="StationBaseDetailedTracks";detail.start_z=track_min_z;detail.finish_z=track_max_z;add_child(detail)
    for direction in [-1.0,1.0]:
        var end = ZA if direction<0.0 else ZB
        for tx in [0.992,-11.732]:
            var length = 10.0
            box(Vector3(3.85,0.20,length),Vector3(float(tx),4.65,end+direction*length*0.5),navy)
            for side in [-1.0,1.0]:
                box(Vector3(0.22,4.6,length),Vector3(float(tx)+side*1.96,2.25,end+direction*length*0.5),wall_dark)
                for h in [0.7,1.1,1.65,2.1]:rod(Vector3(float(tx)+side*1.82,float(h),end),Vector3(float(tx)+side*1.82,float(h),end+direction*length),0.017,black)
                for i in range(12):box(Vector3(0.025,0.55,0.06),Vector3(float(tx)+side*1.84,1.65,end+direction*(float(i)+0.5)*0.8),metal)
            box(Vector3(3.7,4.5,0.15),Vector3(float(tx),2.2,end+direction*9.9),black)

func _equipment() -> void:
    for side in [-1.0,1.0]:
        for z in [0.0,72.0]:
            var p = Vector3(CX+side*3.38,4.20,float(z))
            box(Vector3(1.05,0.58,0.10),p,black)
            for face in [-1.0,1.0]:picture("exit.svg",Vector2(0.98,0.48),p+Vector3(0,0,face*0.056),0.0 if face>0.0 else PI)
            rod(p+Vector3(0,0.30,0),p+Vector3(0,1.38,0),0.018,metal)
        for direction in [-1.0,1.0]:
            var z = (ZA+1.3) if direction<0.0 else (ZB-1.3)
            var p = Vector3(CX+side*4.12,4.65,z)
            box(Vector3(0.17,0.12,0.28),p,cream)
            sphere(Vector3(0.06,0.06,0.025),p+Vector3(0,0,-direction*0.15),black)
    for z in [6.0,24.0,43.0,62.0,81.0]:
        var p = Vector3(CX+3.95,FY+0.012,float(z))
        _round(0.18,0.018,p,metal)
        rod(p+Vector3(-0.05,0.015,0),p+Vector3(0.05,0.015,0),0.008,black)
    var infrastructure = get_node("StationInfrastructure")
    for child in infrastructure.get_children():
        if child is Node3D and "Portal" in str(child.name):child.position.y=4.13

func _anchors() -> void:
    var anchors = get_node("PassengerAnchors")
    for stair in layout.stairs:
        var marker = Marker3D.new();marker.name="StairNorth" if float(stair.direction)<0.0 else "StairSouth"
        marker.position=Vector3(CX,FY,float(stair.start_z_m)-float(stair.direction));anchors.add_child(marker)
        for side in [-1.0,1.0]:
            var bypass = Marker3D.new();bypass.name=marker.name+("LeftBypass" if side<0.0 else "RightBypass")
            bypass.position=Vector3(CX+side*4.05,FY,float(stair.start_z_m)+float(stair.direction)*4.0);anchors.add_child(bypass)
    var lift_point = Marker3D.new();lift_point.name="LiftApproach";lift_point.position=Vector3(CX,FY,float(layout.lift.centre_z_m)-2.4);anchors.add_child(lift_point)
