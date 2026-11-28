extends "res://modules/stations/malinovka/station_builder.gd"
## Малінаўка: all 47 owner photos, independent Station Base-compatible package.
const ART := "res://modules/stations/malinovka/art/"
const CarvedColumn = preload("res://modules/stations/malinovka/carved_column.gd")
const Bird = preload("res://modules/stations/malinovka/bird_sculpture.gd")
var layout: Dictionary
var floor_light: StandardMaterial3D
var floor_dark: StandardMaterial3D
var wall_dark: StandardMaterial3D
var wall_stone: StandardMaterial3D
var stair_stone: StandardMaterial3D
var seat_wood: StandardMaterial3D
var cream: StandardMaterial3D
var column_enamel: StandardMaterial3D
var green: StandardMaterial3D
var pale_green: StandardMaterial3D
var burgundy: StandardMaterial3D
var yellow: StandardMaterial3D
var seam: StandardMaterial3D
var truss_paint: StandardMaterial3D
var amber: StandardMaterial3D
var name_mesh: ArrayMesh
var rounds: Dictionary={}

func _ready() -> void:
    super._ready()
    begin_station()
    layout=JSON.parse_string(FileAccess.get_file_as_string(ART+"station_layout.json"))
    for child in get_children():
        if child is OmniLight3D:child.queue_free()
    floor_light=_photo("floor_granite.jpg",Vector2(0.60,0.60),0.32)
    floor_dark=_photo("floor_dark.jpg",Vector2(0.6,0.6),0.24)
    wall_dark=_photo("wall_granite.jpg",Vector2(0.6,0.5),0.32)
    wall_stone=_photo("wall_stone.jpg",Vector2(0.9,0.6),0.31)
    stair_stone=_photo("stair_granite.jpg",Vector2(1.4,0.30),0.60)
    seat_wood=_photo("seat_wood.jpg",Vector2(0.54,0.88),0.32)
    cream=_material(Color("#deded1"),0.10,0.30)
    column_enamel=_material(Color("#dfdfd0"),0.14,0.17)
    green=_material(Color("#50673c"),0.12,0.24)
    pale_green=_material(Color("#a1b5a3"),0.08,0.48)
    burgundy=_material(Color("#57313a"),0.15,0.40)
    yellow=_material(Color("#dfb62d"),0.0,0.58)
    seam=_material(Color("#b0b3aa"),0.6,0.38)
    truss_paint=cream
    amber=_material(Color("#ffae2b"),0.15,0.26);amber.emission_enabled=true
    amber.emission=Color(1,0.40,0.025);amber.emission_energy_multiplier=2.4
    _platform();_walls();_roof()
    for value in layout.column_z_m:
        var z=float(value);var carved=false
        for decorated in layout.carved_column_z_m:
            if absf(float(decorated)-z)<0.01:carved=true
        for offset in layout.column_rows_relative_x_m:_column(CX+float(offset),z,carved)
    for value in layout.bench_z_m:_bench(float(value))
    for data in layout.stairs:_stairs(data)
    _railway();_equipment();_anchors();_screens()
    flush()

func _photo(file: String,metres: Vector2,roughness: float) -> StandardMaterial3D:
    var m=StandardMaterial3D.new();m.albedo_texture=load(ART+file);m.roughness=roughness
    m.uv1_triplanar=true;m.uv1_world_triplanar=true;m.uv1_triplanar_sharpness=8.0
    m.uv1_scale=Vector3(1.0/metres.x,1.0/metres.y,1.0/metres.x)
    m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return m

func _solid(size: Vector3,p: Vector3,mat: Material) -> void:
    box(size,p,mat)
    var body=StaticBody3D.new();body.name="ArchitectureCollision";body.position=p
    var shape=BoxShape3D.new();shape.size=size
    var collision=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);add_child(body)

func _platform() -> void:
    _solid(Vector3(10,0.20,105),Vector3(CX,FY-0.10,MID),floor_light)
    for row in range(175):
        for col in range(16):
            box(Vector3(0.598,0.008,0.598),Vector3(CX-4.8+(float(col)+0.5)*0.6,FY+0.008,ZA+(float(row)+0.5)*0.6),floor_light)
    # Broad polished granite bands under the column rows; the centre remains grey.
    for offset in layout.column_rows_relative_x_m:
        box(Vector3(1.18,0.012,105),Vector3(CX+float(offset),FY+0.025,MID),floor_dark)
    for side in [-1.0,1.0]:
        box(Vector3(0.27,0.014,105),Vector3(CX+side*4.865,FY+0.018,MID),floor_light)
        box(Vector3(0.13,0.012,105),Vector3(CX+side*4.66,FY+0.025,MID),yellow)
        box(Vector3(0.25,0.012,105),Vector3(CX+side*4.43,FY+0.025,MID),floor_dark)
        for dx in [-0.095,-0.057,-0.019,0.019,0.057,0.095]:
            box(Vector3(0.005,0.004,105),Vector3(CX+side*4.43+float(dx),FY+0.034,MID),black)
        for z in layout.bench_z_m:
            cylinder(0.16,0.014,Vector3(CX+side*1.45,FY+0.020,float(z)-1.05),metal)

func _walls() -> void:
    for side in [-1.0,1.0]:
        var x=CX+side*8.56
        _solid(Vector3(0.25,5.70,105),Vector3(x,2.85,MID),pale_green)
        for i in range(126):
            var z=ZA+(float(i)+0.5)*105.0/126.0
            box(Vector3(0.10,1.80,0.829),Vector3(x-side*0.16,0.95,z),wall_dark)
            box(Vector3(0.12,1.90,0.825),Vector3(x-side*0.17,2.80,z),cream)
            box(Vector3(0.13,0.27,0.825),Vector3(x-side*0.18,1.985,z),green)
            box(Vector3(0.025,1.90,0.015),Vector3(x-side*0.24,2.80,z-0.4167),seam)
            if z>float(layout.ornamental_wall_band_min_z_m) and z<float(layout.ornamental_wall_band_max_z_m):
                picture("raspberry_panels.jpg",Vector2(0.82,1.79),Vector3(x-side*0.247,2.88,z),-side*PI/2.0)
        for h in [0.60,1.20]:box(Vector3(0.012,0.004,105),Vector3(x-side*0.22,float(h),MID),black)
        box(Vector3(0.02,0.025,105),Vector3(x-side*0.25,3.76,MID),seam)
        for h in [3.86,3.93]:rod(Vector3(x-side*0.22,float(h),ZA),Vector3(x-side*0.22,float(h),ZB),0.014,black)
        for z in [-1.0,13.0,66.0,80.0]:picture("wall_route.jpg",Vector2(4.3,1.05),Vector3(x-side*0.27,2.89,float(z)),-side*PI/2.0)
        _wall_name(Vector3(x-side*0.29,2.89,float(layout.ornamental_wall_centre_z_m)),-side*PI/2.0)

func _roof() -> void:
    var soffit=float(layout.soffit_y_m);var central=float(layout.central_ceiling_y_m)
    var half=float(layout.central_ceiling_half_width_m)
    box(Vector3(half*2,0.16,105),Vector3(CX,central+0.08,MID),cream)
    for side in [-1.0,1.0]:
        box(Vector3(6.45,0.15,105),Vector3(CX+side*(half+3.225),soffit+0.075,MID),cream)
        for i in range(1501):box(Vector3(6.45,0.008,0.007),Vector3(CX+side*(half+3.225),soffit-0.007,ZA+float(i)*0.07),seam)
        box(Vector3(0.15,0.24,105),Vector3(CX+side*(half-0.03),soffit+0.12,MID),cream)
        box(Vector3(0.14,0.06,105),Vector3(CX+side*(half-0.15),soffit+0.27,MID),pale_green)
        var cove=_material(Color("#b4e0c2"),0,0.7);cove.emission_enabled=true;cove.emission=Color(0.55,0.8,0.63);cove.emission_energy_multiplier=0.48
        box(Vector3(0.055,0.04,105),Vector3(CX+side*(half-0.13),soffit+0.25,MID),cove)
        # Curved, vertically ribbed fascia above the putative track soffit.
        for j in range(16):
            var a=float(j)*PI/32.0;var b=float(j+1)*PI/32.0
            var x0=CX+side*(6.45+0.7*(1-cos(a)));var x1=CX+side*(6.45+0.7*(1-cos(b)))
            var y0=4.95+0.7*sin(a);var y1=4.95+0.7*sin(b)
            quad(Vector3(x0,y0,ZA),Vector3(x1,y1,ZA),Vector3(x1,y1,ZB),Vector3(x0,y0,ZB),cream,Vector3(-side,-1,0))
        for i in range(701):
            var z=ZA+float(i)*0.15
            for j in range(8):
                var a=float(j)*PI/16.0;var b=float(j+1)*PI/16.0
                rod(Vector3(CX+side*(6.45+0.696*(1-cos(a))),4.95+0.696*sin(a),z),Vector3(CX+side*(6.45+0.696*(1-cos(b))),4.95+0.696*sin(b),z),0.004,black)
        box(Vector3(0.20,0.10,105),Vector3(CX+side*6.46,4.92,MID),burgundy)
        for dx in [-0.15,0.15]:_strip(Vector3(CX+side*6.46+float(dx),4.83,ZA),Vector3(CX+side*6.46+float(dx),4.83,ZB),0.12)
        for z in [2.0,23.0,44.0,65.0,85.0]:
            var face=Vector3(CX+side*6.36,5.18,float(z))
            picture("side_exit.jpg",Vector2(4.1,0.45),face,-side*PI/2.0)
        for z in [12.0,40.0,73.0]:
            picture("no_boarding.jpg" if side<0.0 else "departure_route.jpg",Vector2(3.6,0.75 if side<0.0 else 0.54),Vector3(CX+side*6.34,5.15,float(z)),-side*PI/2.0)
        for i in range(12):_lamp(Vector3(CX+side*3.0,5.13,ZA+4.5+float(i)*8.75),1.25,9.2)
        for z in layout.column_z_m:
            cylinder(0.065,0.008,Vector3(CX+side*4.55,soffit-0.012,float(z)+1.8),black)
            annulus(Vector3(CX+side*4.55,0,float(z)+1.8),0.065,0.079,soffit-0.02,soffit-0.02,metal,32)

func _round(radius: float,height: float,p: Vector3,mat: Material,label: String) -> void:
    var key=str(mat.get_instance_id())
    if not rounds.has(key):
        var mesh=CylinderMesh.new();mesh.top_radius=0.5;mesh.bottom_radius=0.5;mesh.height=1;mesh.radial_segments=80;mesh.material=mat;rounds[key]=mesh
    var node=MeshInstance3D.new();node.name=label;node.mesh=rounds[key]
    node.position=p;node.scale=Vector3(radius*2,height,radius*2);add_child(node)

func _torus(p: Vector3,inner: float,outer: float,mat: Material) -> void:
    var mesh=TorusMesh.new();mesh.inner_radius=inner;mesh.outer_radius=outer;mesh.rings=80;mesh.ring_segments=12;mesh.material=mat
    var node=MeshInstance3D.new();node.name="StainlessColumnRing";node.mesh=mesh;node.position=p;add_child(node)

func _column(x: float,z: float,carved: bool) -> void:
    var h=float(layout.column_base_height_m);var soffit=float(layout.soffit_y_m)
    _round(0.515,h,Vector3(x,FY+h*0.5,z),green,"GreenColumnPlinth")
    _torus(Vector3(x,FY+0.15,z),0.59,0.625,metal)
    for i in range(4):
        var a=float(i)*PI/2.0
        rod(Vector3(x+0.505*sin(a),FY+0.06,z+0.505*cos(a)),Vector3(x+0.59*sin(a),FY+0.15,z+0.59*cos(a)),0.014,metal)
        rod(Vector3(x+0.518*sin(a),FY+0.02,z+0.518*cos(a)),Vector3(x+0.518*sin(a),FY+h,z+0.518*cos(a)),0.005,black)
    if carved:
        var column=CarvedColumn.new();column.name="CarvedTreeColumnWithBirds";column.position=Vector3(x,FY+h,z);add_child(column)
        annulus(Vector3(x,0,z),0.49,0.74,soffit-0.04,soffit-0.04,metal,96)
        _torus(Vector3(x,soffit-0.032,z),0.727,0.751,metal)
        for i in range(18):
            var angle=float(i)*TAU/18.0
            sphere(Vector3(0.030,0.014,0.030),Vector3(x+sin(angle)*0.65,soffit-0.05,z+cos(angle)*0.65),amber)
        var light=SpotLight3D.new();light.name="AmberCarvingLight";light.position=Vector3(x+0.69,soffit-0.12,z)
        light.rotation.x=-PI/2.0;light.light_color=Color(1.0,0.57,0.19);light.light_energy=1.1
        light.spot_range=4.8;light.spot_angle=27;light.spot_attenuation=0.9;light.shadow_enabled=true;light.shadow_bias=0.025;add_child(light)
    else:
        _round(0.50,soffit-FY-h,Vector3(x,(soffit+FY+h)*0.5,z),column_enamel,"SmoothCreamColumn")
        _torus(Vector3(x,FY+1.80,z),0.499,0.503,seam)
        for a in [0.0,PI]:rod(Vector3(x+sin(float(a))*0.501,FY+h,z+cos(float(a))*0.501),Vector3(x+sin(float(a))*0.501,soffit,z+cos(float(a))*0.501),0.0025,seam)
        annulus(Vector3(x,0,z),0.501,0.57,soffit-0.015,soffit-0.015,metal,80)
    var body=StaticBody3D.new();body.name="ColumnCollision";body.position=Vector3(x,(soffit+FY)*0.5,z)
    var shape=CylinderShape3D.new();shape.radius=0.59 if carved else 0.51;shape.height=soffit-FY
    var collision=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);add_child(body)

func _strip(a: Vector3,b: Vector3,width: float) -> void:
    var length=a.distance_to(b);var direction=(b-a).normalized();var basis=Basis(Vector3.UP,atan2(direction.x,direction.z))
    var count=maxi(1,int(ceilf(length/1.50)));var pitch=length/float(count)
    for i in range(count):
        var p=a+direction*(float(i)+0.5)*pitch
        box(Vector3(width+0.05,0.085,pitch-0.018),p+Vector3(0,0.025,0),cream,basis)
        box(Vector3(width,0.033,maxf(0.02,pitch-0.15)),p,glow,basis)
        for d in [-0.5,0.5]:box(Vector3(width+0.06,0.08,0.035),p+direction*(float(d)*(pitch-0.15)),cream,basis)

func _lamp(p: Vector3,energy: float,radius: float) -> void:
    var light=OmniLight3D.new();light.name="PlatformFluorescentFill";light.position=p
    light.light_color=Color(0.98,1.0,0.94);light.light_energy=energy;light.omni_range=radius;light.omni_attenuation=1.18;light.shadow_enabled=false;add_child(light)

func _wall_name(p: Vector3,yaw: float) -> void:
    if name_mesh==null:
        var image=(load(ART+"name_height.png") as Texture2D).get_image()
        if image.is_compressed():image.decompress()
        var nx=image.get_width();var ny=image.get_height();var size=Vector2(float(layout.ornamental_wall_length_m),2.06)
        var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for y in range(ny-1):
            for x in range(nx-1):
                for d in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
                    var ix=x+d.x;var iy=y+d.y;var u=float(ix)/float(nx-1);var v=float(iy)/float(ny-1)
                    var dx=(image.get_pixel(mini(ix+1,nx-1),iy).r-image.get_pixel(maxi(ix-1,0),iy).r)*0.055*float(nx)/size.x
                    var dy=(image.get_pixel(ix,mini(iy+1,ny-1)).r-image.get_pixel(ix,maxi(iy-1,0)).r)*0.055*float(ny)/size.y
                    st.set_normal(Vector3(-dx,dy,1).normalized());st.set_uv(Vector2(u,v));st.add_vertex(Vector3((u-0.5)*size.x,(0.5-v)*size.y,image.get_pixel(ix,iy).r*0.055))
        st.index();name_mesh=st.commit()
        var mat=StandardMaterial3D.new();mat.albedo_texture=load(ART+"name_wall.jpg");mat.metallic=0.12;mat.roughness=0.41;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
        name_mesh.surface_set_material(0,mat)
    var root=Node3D.new();root.name="RaspberryAndRaisedМАЛІНАЎКА";root.position=p;root.rotation.y=yaw;add_child(root)
    var face=MeshInstance3D.new();face.mesh=name_mesh;root.add_child(face)
    for x in [-0.65,1.45]:
        var bird=Bird.new();bird.name="BronzeBirdOnStationName";bird.variant=0 if float(x)<0 else 1
        bird.scale=Vector3.ONE*0.65;bird.position=Vector3(float(x),0.25,0.075);bird.rotation=Vector3(-0.15,0.8 if float(x)<0 else -0.7,0);root.add_child(bird)

func _screens() -> void:
    for z in [14.0,67.0]:
        var p=Vector3(CX,4.92,float(z))
        box(Vector3(1.34,0.80,0.09),p,black)
        board("station_screen.svg",p,Vector2(1.24,0.70))
        rod(p+Vector3(0,0.45,0),Vector3(CX,6.50,float(z)),0.025,metal)
    for z in [22.0,57.0]:
        var p=Vector3(CX,6.19,float(z));box(Vector3(0.42,0.15,0.32),p,cream)
        sphere(Vector3(0.075,0.075,0.035),p+Vector3(0,-0.02,0.18),black)
func _bench(z: float) -> void:
    var width=float(layout.bench_seats)*0.54
    var profile_points=PackedVector2Array([Vector2(CX-width/2.0,FY+0.05),Vector2(CX+width/2.0,FY+0.05),Vector2(CX+width/2.0,FY+0.13),Vector2(CX+width/2.0-0.07,FY+0.21),Vector2(CX+width/2.0-0.07,FY+0.43),Vector2(CX-width/2.0+0.07,FY+0.43),Vector2(CX-width/2.0+0.07,FY+0.21),Vector2(CX-width/2.0,FY+0.13)])
    extrusion(profile_points,z-0.35,z+0.35,metal)
    _solid(Vector3(width-0.14,0.40,0.70),Vector3(CX,FY+0.23,z),metal)
    for i in range(int(layout.bench_seats)):
        var x=CX-width*0.5+(float(i)+0.5)*0.54
        for j in range(18):
            var a=-PI/2.0+float(j)*PI/18.0;var b=-PI/2.0+float(j+1)*PI/18.0
            var z0=z+0.46*sin(a);var z1=z+0.46*sin(b)
            var y0=FY+0.45+0.065*cos(a);var y1=FY+0.45+0.065*cos(b)
            quad(Vector3(x-0.263,y0,z0),Vector3(x+0.263,y0,z0),Vector3(x+0.263,y1,z1),Vector3(x-0.263,y1,z1),seat_wood,Vector3.UP)
            for side in [-1.0,1.0]:
                var xx=x+side*0.263
                quad(Vector3(xx,y0,z0),Vector3(xx,y1,z1),Vector3(xx,y1-0.055,z1),Vector3(xx,y0-0.055,z0),seat_wood,Vector3(side,0,0))
        box(Vector3(0.526,0.04,0.90),Vector3(x,FY+0.425,z),seat_wood)
        box(Vector3(0.018,0.035,0.90),Vector3(x+0.27,FY+0.47,z),metal)
        for side in [-1.0,1.0]:_point("Seat_%s_%s_%s" % [str(z),str(i),str(side)],Vector3(x,FY+0.51,z+side*0.19),"seat",0.0 if side>0 else PI)
    for side in [-1.0,1.0]:
        cylinder(0.16,0.018,Vector3(CX,FY+0.025,z+side*0.69),metal)
        rod(Vector3(CX-0.05,FY+0.04,z+side*0.69),Vector3(CX+0.05,FY+0.04,z+side*0.69),0.008,black)


func _stairs(data: Dictionary) -> void:
    var direction=float(data.direction);var start=float(data.start_z_m);var width=float(layout.stair_width_m)
    var run=float(layout.stair_run_m);var rise=float(layout.stair_rise_m);var landing=float(layout.stair_landing_m)
    var upper=FY+float(layout.stairs_per_end)*rise
    for i in range(int(layout.stairs_per_end)):
        var h=float(i+1)*rise;var z=start+direction*(float(i)*run+(landing if i>=15 else 0.0))
        _solid(Vector3(width,h,run+0.006),Vector3(CX,FY+h*0.5,z),stair_stone)
        box(Vector3(width,0.014,0.045),Vector3(CX,FY+h+0.012,z-direction*0.13),yellow if i in [0,14,15,29] else metal)
        for dz in [-0.10,-0.065,-0.03]:box(Vector3(width-0.25,0.003,0.006),Vector3(CX,FY+h+0.004,z+direction*float(dz)),floor_dark)
    var mid=start+direction*(14.5*run+landing*0.5)
    _solid(Vector3(width,0.20,landing),Vector3(CX,FY+15.0*rise-0.1,mid),stair_stone)
    var finish=start+direction*(29.5*run+landing)
    _solid(Vector3(width,0.20,4.0),Vector3(CX,upper-0.1,finish+direction*2.0),floor_light)
    for side in [-1.0,1.0]:
        var x=CX+side*(width*0.5+0.16)
        _solid(Vector3(0.32,7.3,14.5),Vector3(x,FY+3.65,start+direction*6.3),wall_stone)
        for j in range(24):box(Vector3(0.014,7.1,0.007),Vector3(x-side*0.17,FY+3.55,start-direction*0.8+direction*float(j)*0.6),seam)
        for j in range(11):box(Vector3(0.014,0.005,14.4),Vector3(x-side*0.17,FY+float(j)*0.6,start+direction*6.3),seam)
        # Dark triangular stair skirting follows the actual flights and level landing.
        var points=[Vector2(start-direction*0.25,FY),Vector2(start-direction*0.25,FY+0.22),Vector2(start+direction*14.5*run,FY+15.0*rise+0.22),Vector2(start+direction*(14.5*run+landing),FY+15.0*rise+0.22),Vector2(finish,upper+0.22),Vector2(finish+direction*4.0,upper+0.22),Vector2(finish+direction*4.0,FY)]
        for i in range(1,points.size()-1):triangle(Vector3(x-side*0.18,points[0].y,points[0].x),Vector3(x-side*0.18,points[i].y,points[i].x),Vector3(x-side*0.18,points[i+1].y,points[i+1].x),green,Vector3(-side,0,0))
        for h in [0.70,1.0]:
            var xx=x-side*0.27
            var a=Vector3(xx,FY+float(h),start-direction*0.25)
            var b=Vector3(xx,FY+15.0*rise+float(h),start+direction*14.5*run)
            var c=Vector3(xx,b.y,start+direction*(14.5*run+landing))
            var d=Vector3(xx,upper+float(h),finish)
            rod(a,b,0.025,metal);rod(b,c,0.025,metal);rod(c,d,0.025,metal)
            rod(d,d+Vector3(0,0,direction*3.4),0.025,metal)
            for p in [a,b,c,d]:rod(p,p+Vector3(side*0.10,-0.08,0),0.012,metal)
        # Stainless end-of-platform safety gate beside each portal.
        var gate_x=CX+side*4.15;var gate_z=start+direction*2.25
        for dx in [-0.62,0.62]:rod(Vector3(gate_x+float(dx),FY,gate_z),Vector3(gate_x+float(dx),FY+1.0,gate_z),0.028,metal)
        for h in [0.08,0.94]:rod(Vector3(gate_x-0.62,FY+float(h),gate_z),Vector3(gate_x+0.62,FY+float(h),gate_z),0.025,metal)
        for j in range(7):rod(Vector3(gate_x-0.5+float(j)/6.0,FY+0.1,gate_z),Vector3(gate_x-0.5+float(j)/6.0,FY+0.92,gate_z),0.011,metal)
        var sign_z=start-direction*0.2
        picture("no_smoking.svg",Vector2(0.22,0.22),Vector3(x-side*0.18,FY+2.45,sign_z),-side*PI/2.0)
        picture("free_wifi.svg",Vector2(0.29,0.16),Vector3(x-side*0.18,FY+1.7,sign_z),-side*PI/2.0)
    # Vestibule ceiling rises above the stairs; no slab crosses the upper flight.
    box(Vector3(width,0.18,12),Vector3(CX,upper+2.65,start+direction*7.0),cream)
    for i in range(4):
        var z=start+direction*(3.0+float(i)*2.5)
        _strip(Vector3(CX-3.05,upper+2.51,z),Vector3(CX+3.05,upper+2.51,z),0.08)
        _lamp(Vector3(CX,upper+2.25,z),1.1,7.0)
    box(Vector3(width+0.6,0.86,0.26),Vector3(CX,4.70,start-direction*0.63),cream)
    box(Vector3(width*0.9,0.022,1.05),Vector3(CX,5.30,start-direction*1.0),black)
    for j in range(35):box(Vector3(0.015,0.025,1.05),Vector3(CX-width*0.44+float(j)*width*0.88/34.0,5.278,start-direction*1.0),metal)
    for dz in [-0.5,-0.2,0.1,0.4]:box(Vector3(width*0.9,0.025,0.012),Vector3(CX,5.274,start-direction*1.0+float(dz)),metal)
    var sign_z=start-direction*0.8
    board(str(data.exit_art),Vector3(CX,4.63,sign_z),Vector2(5.2,0.64))
    board("exit.svg",Vector3(CX,5.10,sign_z),Vector2(0.90,0.23))
    # Visible side lift doorway in the approach recess, not a central platform shaft.
    var lift_x=CX+3.91;var lift_z=start+direction*1.6
    box(Vector3(1.08,2.55,0.18),Vector3(lift_x,FY+1.275,lift_z),seam)
    for side in [-1.0,1.0]:box(Vector3(0.49,2.16,0.035),Vector3(lift_x+side*0.25,FY+1.11,lift_z-direction*0.12),metal)
    board("lift.svg",Vector3(lift_x,FY+2.72,lift_z-direction*0.16),Vector2(0.98,0.36))
    _point("StairApproach"+str(int(direction)),Vector3(CX,FY,start-direction*0.8),"waypoint")
    _point("UpperLanding"+str(int(direction)),Vector3(CX,upper,finish+direction),"waypoint")
    _point("LiftApproach"+str(int(direction)),Vector3(lift_x,FY,lift_z-direction*0.8),"waypoint")


func _railway() -> void:
    var detail=preload("res://modules/stations/malinovka/track_detail.gd").new()
    detail.name="StationBaseDetailedTracks";detail.start_z=track_min_z;detail.finish_z=track_max_z;add_child(detail)
    for direction in [-1.0,1.0]:
        var end=ZA if direction<0.0 else ZB
        for tx in [0.992,-11.732]:
            var centre=float(tx)
            for j in range(24):
                var a=float(j)*PI/24.0;var b=float(j+1)*PI/24.0
                var x0=centre+1.94*cos(a);var x1=centre+1.94*cos(b)
                var y0=2.65+2.10*sin(a);var y1=2.65+2.10*sin(b)
                quad(Vector3(x0,y0,end),Vector3(x1,y1,end),Vector3(x1,y1,end+direction*10),Vector3(x0,y0,end+direction*10),wall_stone)
            for side in [-1.0,1.0]:
                box(Vector3(0.21,3.0,10.0),Vector3(centre+side*1.95,1.22,end+direction*5.0),wall_stone)
                for h in [0.8,1.1,1.45,1.85]:rod(Vector3(centre+side*1.80,float(h),end),Vector3(centre+side*1.80,float(h),end+direction*10.0),0.022,black)
                for j in range(13):box(Vector3(0.02,1.2,0.05),Vector3(centre+side*1.82,1.4,end+direction*(float(j)+0.5)*0.75),metal)
            for j in range(14):
                var z=end+direction*(float(j)+0.5)*0.7
                rod(Vector3(centre-1.91,2.64,z),Vector3(centre-1.91,0.25,z),0.025,black)
                rod(Vector3(centre+1.91,2.64,z),Vector3(centre+1.91,0.25,z),0.025,black)
            box(Vector3(3.7,4.5,0.15),Vector3(centre,2.20,end+direction*9.9),black)


func _equipment() -> void:
    for direction in [-1.0,1.0]:
        var z=(ZA+1.0) if direction<0.0 else (ZB-1.0)
        for side in [-1.0,1.0]:
            var p=Vector3(CX+side*3.05,5.15,z)
            box(Vector3(0.20,0.15,0.33),p,cream)
            sphere(Vector3(0.09,0.07,0.03),p+Vector3(0,-0.015,-direction*0.18),black)
            box(Vector3(0.27,0.33,0.20),p+Vector3(side*0.18,-0.32,0),metal)
        var cabinet=Vector3(CX-3.79,FY+0.65,z)
        box(Vector3(0.68,1.3,0.22),cabinet,_material(Color("#a61f24"),0.25,0.36))
        rod(cabinet+Vector3(0.22,-0.08,-direction*0.13),cabinet+Vector3(0.22,0.10,-direction*0.13),0.012,metal)
    var infrastructure=get_node("StationInfrastructure")
    for child in infrastructure.get_children():
        if child is Node3D and "Portal" in str(child.name):child.position.y=4.74


func _point(label: String,p: Vector3,role: String,yaw: float=0.0) -> void:
    var node=Marker3D.new();node.name=label;node.position=p;node.rotation.y=yaw
    node.set_meta("portable_role",role);get_node("PassengerAnchors").add_child(node)


func _anchors() -> void:
    for side in [-1.0,1.0]:
        var tx=0.992 if side>0 else -11.732
        _point("V106StopTrack"+str(1 if side>0 else 2),Vector3(tx,0,STOP_Z),"stop")
        for z in [0.0,12.0,24.0,36.0,48.0,60.0,72.0,84.0]:
            _point("Waiting_%s_%s" % [str(side),str(z)],Vector3(CX+side*3.9,FY,float(z)),"waiting")
