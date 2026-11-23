extends "res://modules/stations/grushevka/station_builder.gd"
## Owner-photo reproduction: one central column row, open golden lattice crowns and a pear vestibule.
const ART := "res://modules/stations/grushevka/art/"
const NORTH := -8.0
const SOUTH := 92.112
const COLUMN_FIRST := -0.8
const COLUMN_PITCH := 10.2
const COLUMN_COUNT := 9
const CEILING_Y := 5.45
var light_stone: StandardMaterial3D
var dark_stone: StandardMaterial3D
var green_stone: StandardMaterial3D
var marble_stone: StandardMaterial3D
var stairs_stone: StandardMaterial3D
var service_stone: StandardMaterial3D
var column_yellow: StandardMaterial3D
var ceiling_green: StandardMaterial3D
var lattice_gold: StandardMaterial3D
var tactile: StandardMaterial3D
var name_mesh: ArrayMesh

func _ready() -> void:
    super._ready();begin_station()
    for child in get_children():
        if child is OmniLight3D:child.queue_free()
    light_stone=_photo("floor_light.jpg",Vector2(0.60,0.60),0.37)
    dark_stone=_photo("floor_dark.jpg",Vector2(0.60,0.60),0.36)
    green_stone=_photo("plinth_green.jpg",Vector2(0.95,0.50),0.33)
    marble_stone=_photo("marble.jpg",Vector2(0.95,0.60),0.37)
    stairs_stone=_photo("stair_granite.jpg",Vector2(1.10,0.30),0.62)
    service_stone=_photo("service_stone.jpg",Vector2(0.70,0.50),0.40)
    column_yellow=_material(Color("#d1b15f"),0.22,0.24)
    column_yellow.metallic_specular=0.62
    ceiling_green=_material(Color("#3e4b40"),0.58,0.28)
    lattice_gold=_material(Color("#bca551"),0.40,0.46)
    tactile=_material(Color("#d6b13c"),0.0,0.69)
    white=_material(Color("#e0ddc9"),0.13,0.47)
    granite=dark_stone
    _floor();_walls();_ceiling()
    for i in range(COLUMN_COUNT):
        var z: float=COLUMN_FIRST+float(i)*COLUMN_PITCH
        _column(z);_crown(z);_canopy_lights(z)
        if i<COLUMN_COUNT-1 and i%2==0:_bench(z+COLUMN_PITCH*0.5)
        if i%3==1:_televisions(z)
    _stair_exit();_service_end();_railway();_driver_equipment();_small_details()
    flush()

func _photo(file: String,slab: Vector2,roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new();mat.albedo_texture=load(ART+file);mat.roughness=roughness
    mat.uv1_triplanar=true;mat.uv1_world_triplanar=true;mat.uv1_triplanar_sharpness=8.0
    mat.uv1_scale=Vector3(1.0/slab.x,1.0/slab.y,1.0/slab.x)
    mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return mat

func _solid(size: Vector3,p: Vector3,mat: Material) -> void:
    box(size,p,mat)
    var root := StaticBody3D.new();root.position=p;root.name="StationStructure"
    var shape := BoxShape3D.new();shape.size=size
    var collision := CollisionShape3D.new();collision.shape=shape;root.add_child(collision);add_child(root)

func _floor() -> void:
    _solid(Vector3(10,0.20,105),Vector3(CX,FY-0.10,MID),light_stone)
    for row in range(175):
        for col in range(16):
            box(Vector3(0.597,0.010,0.597),Vector3(CX-4.8+(float(col)+0.5)*0.6,FY+0.008,ZA+(float(row)+0.5)*0.6),light_stone)
    for i in range(COLUMN_COUNT):
        var z: float=COLUMN_FIRST+float(i)*COLUMN_PITCH
        box(Vector3(2.18,0.012,2.18),Vector3(CX,FY+0.017,z),dark_stone)
        # Asymmetric black triangular inlays clustered between the pillars, as in 171110/171306.
        for side in [-1.0,1.0]:
            for j in range(5):
                var x: float=CX+side*(0.75+float(j%3)*0.65)
                var zz: float=z+1.55+float(j)*0.75
                var p := Vector3(x,FY+0.021,zz)
                var turn: float=float((i+j)%4)*PI/2.0
                var basis := Basis(Vector3.UP,turn)
                triangle(p+basis*Vector3(-0.48,0,-0.34),p+basis*Vector3(0.48,0,-0.34),p+basis*Vector3(0.15,0,0.35),dark_stone,Vector3.UP)
    for side in [-1.0,1.0]:
        box(Vector3(0.35,0.022,105),Vector3(CX+side*4.825,FY+0.017,MID),light_stone)
        box(Vector3(0.16,0.012,105),Vector3(CX+side*4.54,FY+0.032,MID),tactile)
        box(Vector3(0.18,0.012,105),Vector3(CX+side*4.36,FY+0.033,MID),dark_stone)
        for i in range(875):
            for dx in [-0.048,0.0,0.048]:cylinder(0.009,0.003,Vector3(CX+side*4.54+float(dx),FY+0.040,ZA+float(i)*0.12),tactile)

func _walls() -> void:
    var length: float=SOUTH-NORTH
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.90
        _solid(Vector3(0.25,1.10,length),Vector3(x,0.55,(NORTH+SOUTH)*0.5),green_stone)
        for row in range(2):
            for i in range(106):
                var z: float=NORTH+(float(i)+0.5)*length/106.0
                box(Vector3(0.007,0.004,length/106.0),Vector3(x-side*0.129,0.10+float(row)*0.50,z),black)
                box(Vector3(0.007,0.49,0.004),Vector3(x-side*0.129,0.35+float(row)*0.5,z),black)
        box(Vector3(0.24,2.42,length),Vector3(x,2.31,(NORTH+SOUTH)*0.5),white)
        for i in range(121):
            var z: float=NORTH+float(i)*length/120.0
            box(Vector3(0.018,2.42,0.014),Vector3(x-side*0.13,2.31,z),metal)
        box(Vector3(0.27,0.42,length),Vector3(x,3.73,(NORTH+SOUTH)*0.5),black)
        for i in range(6):
            var z: float=0.8+float(i)*16.5
            _nameplate(Vector3(x-side*0.16,2.56,z),-side*PI/2.0)
            if z+8.0<SOUTH-3.0:picture("wall_route.svg",Vector2(3.75,0.60),Vector3(x-side*0.16,2.72,z+8.0),-side*PI/2.0,true)
        for i in range(5):
            var z: float=2.0+float(i)*19.0
            box(Vector3(0.09,0.64,4.05),Vector3(CX+side*8.15,4.75,z),metal)
            picture("wall_route.svg",Vector2(3.95,0.57),Vector3(CX+side*8.09,4.75,z),-side*PI/2.0,true)
        # White ribbed rolled return above the continuous linear light shelf.
        for j in range(20):
            var a: float=float(j)*PI/40.0;var b: float=float(j+1)*PI/40.0
            var p0 := Vector2(7.4+1.5*sin(a),3.94+1.5*cos(a))
            var p1 := Vector2(7.4+1.5*sin(b),3.94+1.5*cos(b))
            quad(Vector3(CX+side*p0.x,p0.y,NORTH),Vector3(CX+side*p1.x,p1.y,NORTH),Vector3(CX+side*p1.x,p1.y,SOUTH),Vector3(CX+side*p0.x,p0.y,SOUTH),white,Vector3(-side,-1,0))
        for k in range(625):
            var z: float=NORTH+float(k)*length/624.0
            for j in range(12):
                var a: float=float(j)*PI/24.0;var b: float=float(j+1)*PI/24.0
                rod(Vector3(CX+side*(7.4+1.48*sin(a)),3.94+1.48*cos(a),z),Vector3(CX+side*(7.4+1.48*sin(b)),3.94+1.48*cos(b),z),0.006,metal)
        box(Vector3(0.28,0.10,length),Vector3(CX+side*8.64,4.00,(NORTH+SOUTH)*0.5),metal)
        for i in range(84):
            var z: float=NORTH+(float(i)+0.5)*length/84.0
            box(Vector3(0.18,0.032,length/84.0-0.025),Vector3(CX+side*8.59,3.933,z),glow)

func _nameplate(p: Vector3,yaw: float) -> void:
    if name_mesh==null:
        var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ART+"name_relief.json"))
        var nx: int=data.width;var ny: int=data.height;var values: Array=data["values"]
        var size := Vector2(3.20,0.75);var depth: float=data.depth_m
        var mat := StandardMaterial3D.new();mat.albedo_texture=load(ART+"nameplate.jpg");mat.roughness=0.43;mat.metallic=0.48;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
        var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for y in range(ny-1):
            for x in range(nx-1):
                for offset in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
                    var ix: int=x+offset.x;var iy: int=y+offset.y
                    var u: float=float(ix)/float(nx-1);var v: float=float(iy)/float(ny-1)
                    var dx: float=(float(values[iy*nx+mini(ix+1,nx-1)])-float(values[iy*nx+maxi(ix-1,0)]))*depth*float(nx)/size.x
                    var dy: float=(float(values[mini(iy+1,ny-1)*nx+ix])-float(values[maxi(iy-1,0)*nx+ix]))*depth*float(ny)/size.y
                    st.set_normal(Vector3(-dx,dy,1).normalized());st.set_uv(Vector2(u,v))
                    st.add_vertex(Vector3((u-0.5)*size.x,(0.5-v)*size.y,float(values[iy*nx+ix])*depth))
        st.generate_tangents();name_mesh=st.commit();name_mesh.surface_set_material(0,mat)
    var node := MeshInstance3D.new();node.name="PhotoMatchedRaisedGrushaLetters";node.mesh=name_mesh;node.position=p;node.rotation.y=yaw;add_child(node)
    box(Vector3(3.24,0.79,0.045),p-Basis(Vector3.UP,yaw)*Vector3(0,0,0.024),black,Basis(Vector3.UP,yaw))

func _ceiling() -> void:
    box(Vector3(14.8,0.18,SOUTH-NORTH),Vector3(CX,CEILING_Y+0.10,(NORTH+SOUTH)*0.5),ceiling_green)
    for i in range(1002):
        var z: float=NORTH+float(i)*(SOUTH-NORTH)/1001.0
        box(Vector3(14.8,0.005,0.007),Vector3(CX,CEILING_Y+0.006,z),black)

func _round(radius: float,height: float,p: Vector3,mat: Material) -> void:
    var mesh := CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=64;mesh.material=mat
    var node := MeshInstance3D.new();node.mesh=mesh;node.position=p;add_child(node)

func _column(z: float) -> void:
    _round(0.70,0.29,Vector3(CX,FY+0.145,z),green_stone)
    _round(0.62,CEILING_Y-FY-0.36,Vector3(CX,(FY+0.28+CEILING_Y-0.08)*0.5,z),column_yellow)
    for a in [0.0,PI/2.0,PI,PI*1.5]:
        var x: float=CX+0.623*cos(float(a));var zz: float=z+0.623*sin(float(a))
        rod(Vector3(x,FY+0.29,zz),Vector3(x,CEILING_Y-0.09,zz),0.004,black)
    annulus(Vector3(CX,0,z),0.620,0.625,FY+2.15,FY+2.156,black,96)
    _round(0.96,0.06,Vector3(CX,CEILING_Y-0.12,z),black)
    annulus(Vector3(CX,0,z),0.93,0.98,CEILING_Y-0.16,CEILING_Y-0.15,lattice_gold,96)
    for h in [0.13,0.32]:
        var torus := TorusMesh.new();torus.inner_radius=0.78;torus.outer_radius=0.84;torus.rings=64;torus.ring_segments=12;torus.material=metal
        var node := MeshInstance3D.new();node.mesh=torus;node.position=Vector3(CX,FY+float(h),z);add_child(node)
    for i in range(6):
        var a: float=float(i)*TAU/6.0
        rod(Vector3(CX+0.81*cos(a),FY+0.03,z+0.81*sin(a)),Vector3(CX+0.81*cos(a),FY+0.34,z+0.81*sin(a)),0.023,metal)
    var collision := StaticBody3D.new();collision.position=Vector3(CX,(FY+CEILING_Y)*0.5,z)
    var shape := CylinderShape3D.new();shape.radius=0.64;shape.height=CEILING_Y-FY
    var c := CollisionShape3D.new();c.shape=shape;collision.add_child(c);add_child(collision)

func _crown(z: float) -> void:
    var radius := 3.57
    _round(radius,0.022,Vector3(CX,CEILING_Y-0.022,z),black)
    annulus(Vector3(CX,0,z),radius-0.015,radius+0.025,CEILING_Y-0.145,CEILING_Y-0.125,ceiling_green,128)
    # Open clipped lattice, including the circular opening around the pillar's black capital.
    for i in range(-29,30):
        var offset: float=float(i)*0.12
        var reach: float=sqrt(maxf(0.0,radius*radius-offset*offset))
        var gap: float=sqrt(maxf(0.0,0.99*0.99-offset*offset)) if absf(offset)<0.99 else 0.0
        for axis in range(2):
            for side in [-1.0,1.0]:
                var length: float=reach-gap
                var middle: float=side*(reach+gap)*0.5
                var size := Vector3(0.012,0.090,length) if axis==0 else Vector3(length,0.090,0.012)
                var p := Vector3(CX+offset,CEILING_Y-0.10,z+middle) if axis==0 else Vector3(CX+middle,CEILING_Y-0.10,z+offset)
                box(size,p,lattice_gold)

func _canopy_lights(z: float) -> void:
    for side in [-1.0,1.0]:
        for end in [-1.0,1.0]:
            var p := Vector3(CX+side*3.80,CEILING_Y-0.20,z+end*2.6)
            var basis := Basis(Vector3.UP,side*end*0.32)
            box(Vector3(0.18,0.075,2.20),p,metal,basis)
            box(Vector3(0.115,0.026,2.10),p-Vector3(0,0.046,0),glow,basis)
        var light := OmniLight3D.new();light.position=Vector3(CX+side*2.80,4.85,z);light.light_energy=1.10;light.omni_range=7.2;light.light_color=Color(0.98,1.0,0.94);add_child(light)

func _bench(z: float) -> void:
    # Four broad curved wooden modules on one sculpted stainless-steel base; no backrest.
    var seat := _photo("seat_wood.jpg",Vector2(0.64,0.50),0.30)
    var profile := PackedVector2Array([Vector2(-0.42,0.44),Vector2(-0.46,0.37),Vector2(-0.39,0.31),Vector2(-0.29,0.24),Vector2(-0.29,0.06),Vector2(0.29,0.06),Vector2(0.29,0.24),Vector2(0.39,0.31),Vector2(0.46,0.37),Vector2(0.42,0.44)])
    var shifted := PackedVector2Array()
    for p in profile:shifted.append(Vector2(CX+p.x,FY+p.y))
    extrusion(shifted,z-1.05,z+1.05,metal)
    for i in range(4):
        var zz: float=z-0.78+float(i)*0.52
        for j in range(16):
            var a: float=-PI/2.0+float(j)*PI/16.0;var b: float=-PI/2.0+float(j+1)*PI/16.0
            var x0: float=CX+0.45*sin(a);var x1: float=CX+0.45*sin(b)
            var y0: float=FY+0.43+0.070*cos(a);var y1: float=FY+0.43+0.070*cos(b)
            quad(Vector3(x0,y0,zz-0.248),Vector3(x1,y1,zz-0.248),Vector3(x1,y1,zz+0.248),Vector3(x0,y0,zz+0.248),seat,Vector3.UP)
        rod(Vector3(CX-0.43,FY+0.435,zz-0.258),Vector3(CX+0.43,FY+0.435,zz-0.258),0.014,metal)

func _televisions(z: float) -> void:
    for side in [-1.0,1.0]:
        var p := Vector3(CX+side*1.45,4.40,z)
        box(Vector3(1.35,0.82,0.16),p,black)
        for face in [-1.0,1.0]:picture("advert.jpg",Vector2(1.24,0.70),p+Vector3(0,0,face*0.086),0 if face>0 else PI)
        rod(p+Vector3(0,0.43,0),p+Vector3(0,0.98,0),0.018,metal)

func _stair_exit() -> void:
    # Only the photographed public exit is built; the opposite platform end is the service core.
    for flight in range(2):
        for i in range(16):
            var y: float=FY+float(flight)*2.40+float(i+1)*0.15
            var distance: float=float(flight)*6.0+(float(i)+0.5)*0.30
            _solid(Vector3(7.2,0.18,0.30),Vector3(CX,y-0.09,NORTH-distance),stairs_stone)
            box(Vector3(7.18,0.012,0.055),Vector3(CX,y+0.008,NORTH-distance+0.12),tactile if i in [0,15] else light_stone)
        if flight==0:_solid(Vector3(7.2,0.20,1.20),Vector3(CX,FY+2.30,NORTH-5.40),light_stone)
        for side in [-1.0,1.0]:
            var x: float=CX+side*3.72
            var a := Vector3(x,FY+float(flight)*2.4,NORTH-float(flight)*6.0)
            var b := Vector3(x,FY+float(flight+1)*2.4,NORTH-float(flight)*6.0-4.8)
            for face in [-1.0,1.0]:quad(a+Vector3(float(face)*0.12,0,0),b+Vector3(float(face)*0.12,0,0),b+Vector3(float(face)*0.12,1.03,0),a+Vector3(float(face)*0.12,1.03,0),marble_stone,Vector3(face,0,0))
            quad(a+Vector3(-0.12,1.03,0),b+Vector3(-0.12,1.03,0),b+Vector3(0.12,1.03,0),a+Vector3(0.12,1.03,0),marble_stone,Vector3.UP)
            for h in [0.76,1.00]:
                rod(a+Vector3(-side*0.17,float(h),0),b+Vector3(-side*0.17,float(h),0),0.028,metal)
                if flight==0:rod(b+Vector3(-side*0.17,float(h),0),b+Vector3(-side*0.17,float(h),-1.2),0.028,metal)
            if flight==0:
                box(Vector3(0.24,1.03,1.2),b+Vector3(0,0.515,-0.60),marble_stone)
    for side in [-1.0,1.0]:_solid(Vector3(0.28,7.92,6.85),Vector3(CX+side*3.86,FY+3.96,NORTH-3.425),marble_stone)
    for j in range(7):
        var a: float=float(j);var b: float=float(j+1)
        quad(Vector3(CX-3.99,5.45+a*0.52,NORTH-a),Vector3(CX+3.99,5.45+a*0.52,NORTH-a),Vector3(CX+3.99,5.45+b*0.52,NORTH-b),Vector3(CX-3.99,5.45+b*0.52,NORTH-b),white,Vector3.DOWN)
    var top: float=FY+4.8
    _solid(Vector3(7.2,0.20,2.6),Vector3(CX,top-0.10,NORTH-12.1),light_stone)
    # A shallow entry soffit meets the platform ceiling above the lower stair.
    box(Vector3(7.6,0.75,0.30),Vector3(CX,4.98,NORTH),white)
    for side in [-1.0,1.0]:
        _solid(Vector3(0.30,3.28,10.7),Vector3(CX+side*6.75,top+1.64,NORTH-12.2),marble_stone)
        # Upper gallery overlooks the stair, with actual railings and two supporting piers.
        _solid(Vector3(3.15,0.20,3.4),Vector3(CX+side*5.175,top-0.10,NORTH-11.7),light_stone)
        for d in [10.4,13.4,16.4]:
            rod(Vector3(CX+side*3.69,top+0.20,NORTH-float(d)),Vector3(CX+side*3.69,top+1.07,NORTH-float(d)),0.026,metal)
        for h in [0.61,1.05]:rod(Vector3(CX+side*3.69,top+float(h),NORTH-10.4),Vector3(CX+side*3.69,top+float(h),NORTH-17.5),0.028,metal)
        # The low stair-side wall is opened at the gallery: no extra column blocks the stair width.
        _solid(Vector3(0.42,3.12,0.46),Vector3(CX+side*3.91,top+1.56,NORTH-13.0),marble_stone)
    _upper_pear_hall(top)
    board("exit.svg",Vector3(CX,4.23,NORTH+0.12),Vector2(5.8,0.72))
    foot_grille(NORTH+0.30,7.1)

func _upper_pear_hall(floor_y: float) -> void:
    var z: float=NORTH-17.8
    _solid(Vector3(13.5,0.20,5.2),Vector3(CX,floor_y-0.10,NORTH-16.0),light_stone)
    box(Vector3(13.8,0.16,12.0),Vector3(CX,9.14,NORTH-13.0),ceiling_green)
    for i in range(138):box(Vector3(13.7,0.009,0.012),Vector3(CX,9.048,NORTH-7.1-float(i)*0.086),black)
    for x in [-4.7,-2.4,0.0,2.4,4.7]:
        box(Vector3(0.11,0.025,10.8),Vector3(CX+float(x),9.02,NORTH-13.0),glow)
    # Substrate and sculpted branch ribbons contain no baked visitors from the source photographs.
    _solid(Vector3(11.8,3.12,0.28),Vector3(CX,floor_y+1.56,z),white)
    _pear_relief(Vector3(CX,floor_y,z+0.17))
    for side in [-1.0,1.0]:
        _solid(Vector3(5.75,0.20,4.1),Vector3(CX+side*9.625,floor_y-0.10,z+1.8),light_stone)
        box(Vector3(5.6,0.16,4.1),Vector3(CX+side*9.7,9.14,z+1.8),ceiling_green)
        for zz in [-0.28,3.9]:box(Vector3(7.5,3.1,0.20),Vector3(CX+side*8.75,floor_y+1.55,z+float(zz)),marble_stone)
        box(Vector3(0.10,3.1,4.1),Vector3(CX+side*12.55,floor_y+1.55,z+1.8),black)
        var anchor := Marker3D.new();anchor.name="Vestibule"+("Left" if side<0 else "Right")+"Continuation";anchor.position=Vector3(CX+side*10.6,floor_y,z+1.8);get_node("PassengerAnchors").add_child(anchor)
        for gate in range(3):
            var x: float=CX+side*7.65;var gz: float=z+0.60+float(gate)*1.10
            box(Vector3(0.85,0.90,0.25),Vector3(x,floor_y+0.45,gz),metal)
            rod(Vector3(x,floor_y+0.78,gz),Vector3(x-0.05,floor_y+0.78,gz+0.44),0.024,metal)
    _controller_booth(Vector3(CX-9.9,floor_y,z+2.0))
    var light := OmniLight3D.new();light.position=Vector3(CX,8.5,z+2.5);light.light_energy=1.35;light.omni_range=8;light.light_color=Color(1.0,0.93,0.87);add_child(light)
    for side in [-1.0,1.0]:
        var wash := OmniLight3D.new();wash.position=Vector3(CX+side*3.2,8.7,z+0.5);wash.light_color=Color(1.0,0.75,0.73);wash.light_energy=0.28;wash.omni_range=3.8;add_child(wash)

func _pear_relief(origin: Vector3) -> void:
    var branch := _material(Color("#b8a98f"),0.18,0.64)
    var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ART+"pear_relief_paths.json"))
    for side in [-1.0,1.0]:
        for path in data.branches:
            var line := PackedVector2Array()
            for segment in path.curves:
                var a := Vector2(segment[0][0],segment[0][1]);var b := Vector2(segment[1][0],segment[1][1]);var c := Vector2(segment[2][0],segment[2][1]);var d := Vector2(segment[3][0],segment[3][1])
                for i in range(25):
                    var t: float=float(i)/24.0
                    var p: Vector2=a.bezier_interpolate(b,c,d,t)
                    var vertex := Vector2(side*p.x,p.y)
                    if line.is_empty() or line[line.size()-1].distance_squared_to(vertex)>0.000001:line.append(vertex)
            for shape in Geometry2D.offset_polyline(line,float(path.width)*0.5,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
                var indices := Geometry2D.triangulate_polygon(shape)
                for i in range(0,indices.size(),3):
                    var a: Vector2=shape[indices[i]];var b: Vector2=shape[indices[i+1]];var c: Vector2=shape[indices[i+2]]
                    triangle(origin+Vector3(a.x,a.y,0.07),origin+Vector3(b.x,b.y,0.07),origin+Vector3(c.x,c.y,0.07),branch,Vector3.BACK)
                for i in range(shape.size()):
                    var a: Vector2=shape[i];var b: Vector2=shape[(i+1)%shape.size()]
                    quad(origin+Vector3(a.x,a.y,0),origin+Vector3(b.x,b.y,0),origin+Vector3(b.x,b.y,0.07),origin+Vector3(a.x,a.y,0.07),branch)
        for point in data.fruits:_pear(origin+Vector3(side*float(point[0]),float(point[1]),0.14),0.075,0.25)
    _pear(origin+Vector3(0,0,0.30),0.67,2.20)

func _pear(p: Vector3,width: float,height: float) -> void:
    var material := _material(Color("#786b50"),0.43,0.49)
    var profile: Array[Vector2]=[Vector2(0,0.32),Vector2(0.05,0.72),Vector2(0.13,0.96),Vector2(0.24,1),Vector2(0.37,0.86),Vector2(0.52,0.62),Vector2(0.70,0.36),Vector2(0.84,0.23),Vector2(0.96,0.20),Vector2(1.0,0.12)]
    for j in range(profile.size()-1):
        var a: Vector2=profile[j];var b: Vector2=profile[j+1]
        for i in range(48):
            var t0: float=float(i)*TAU/48.0;var t1: float=float(i+1)*TAU/48.0
            quad(p+Vector3(cos(t0)*a.y*width,a.x*height,sin(t0)*a.y*width),p+Vector3(cos(t1)*a.y*width,a.x*height,sin(t1)*a.y*width),p+Vector3(cos(t1)*b.y*width,b.x*height,sin(t1)*b.y*width),p+Vector3(cos(t0)*b.y*width,b.x*height,sin(t0)*b.y*width),material,Vector3(cos((t0+t1)*0.5),0,sin((t0+t1)*0.5)))
    rod(p+Vector3(0,height,0),p+Vector3(width*0.12,height*1.08,0),width*0.035,material)
    sphere(Vector3(width*0.38,height*0.06,width*0.08),p+Vector3(width*0.16,height*1.08,0),material)
    if height>1.0:
        for side in [-1.0,1.0]:sphere(Vector3(0.055,0.095,0.030),p+Vector3(side*0.18,0.38,width*0.87),black)

func _service_end() -> void:
    # Rounded yellow core with a real service door and dark ventilation louvres, observed at 171315-171334.
    var z: float=SOUTH-2.35
    var core := Vector3(CX,FY,z)
    _solid(Vector3(3.6,4.25,2.40),core+Vector3(0,2.125,1.00),column_yellow)
    for j in range(48):
        var a: float=PI+float(j)*PI/48.0;var b: float=PI+float(j+1)*PI/48.0
        var p0 := core+Vector3(1.80*cos(a),0,1.80*sin(a))
        var p1 := core+Vector3(1.80*cos(b),0,1.80*sin(b))
        quad(p0,p1,p1+Vector3(0,2.8,0),p0+Vector3(0,2.8,0),column_yellow,Vector3(cos((a+b)*0.5),0,sin((a+b)*0.5)))
        quad(p0+Vector3(0,2.8,0),p1+Vector3(0,2.8,0),p1+Vector3(0,4.25,0),p0+Vector3(0,4.25,0),black)
        if j%6==0:rod(p0+Vector3(0,0.02,0),p0+Vector3(0,2.78,0),0.005,black)
    for h in range(21):
        var y: float=FY+2.88+float(h)*0.061
        for j in range(36):
            var a: float=PI+float(j)*PI/36.0;var b: float=PI+float(j+1)*PI/36.0
            rod(core+Vector3(1.82*cos(a),y-FY,1.82*sin(a)),core+Vector3(1.82*cos(b),y-FY,1.82*sin(b)),0.012,ceiling_green)
    # White access leaf is inset into a framed, legible doorway in front of the core surface.
    box(Vector3(1.13,2.29,0.12),Vector3(CX,FY+1.145,z-1.80),metal)
    box(Vector3(1.02,2.18,0.025),Vector3(CX,FY+1.10,z-1.875),white)
    rod(Vector3(CX+0.36,FY+1.05,z-1.91),Vector3(CX+0.36,FY+0.89,z-1.91),0.013,metal)
    picture("service_door.svg",Vector2(0.32,0.30),Vector3(CX,FY+1.76,z-1.896),PI)
    for side in [-1.0,1.0]:
        box(Vector3(3.95,4.6,0.22),Vector3(CX+side*6.362,2.3,SOUTH+1.2),black)
        _solid(Vector3(0.30,4.4,1.0),Vector3(CX+side*4.16,2.2,SOUTH+0.6),service_stone)
        var gate := Vector3(CX+side*4.70,FY+0.5,SOUTH-0.2)
        for dx in [-0.40,0.40]:rod(gate+Vector3(float(dx),-0.5,0),gate+Vector3(float(dx),0.5,0),0.028,metal)
        rod(gate+Vector3(-0.4,0.5,0),gate+Vector3(0.4,0.5,0),0.028,metal)

func _controller_booth(p: Vector3) -> void:
    box(Vector3(1.80,0.70,1.50),p+Vector3(0,0.35,0),marble_stone)
    box(Vector3(1.88,0.12,1.58),p+Vector3(0,2.23,0),metal)
    var glass := _material(Color(0.52,0.65,0.63,0.26),0.10,0.14);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    box(Vector3(1.74,1.44,0.018),p+Vector3(0,1.45,0.73),glass)
    for side in [-1.0,1.0]:
        box(Vector3(0.018,1.44,1.42),p+Vector3(side*0.88,1.45,0),glass)
        for z in [-0.73,0.73]:box(Vector3(0.035,1.58,0.035),p+Vector3(side*0.88,1.45,float(z)),metal)
    box(Vector3(1.55,0.06,0.55),p+Vector3(0,1.0,0.22),timber)
    box(Vector3(0.38,0.28,0.035),p+Vector3(0.3,1.19,0.15),black)


func _railway() -> void:
    var detail := preload("res://modules/stations/grushevka/track_detail.gd").new();detail.name="DetailedStationTracks"
    detail.start_z=track_min_z;detail.finish_z=track_max_z;add_child(detail)
    for x in [0.992,-11.732]:
        for direction in [-1.0,1.0]:
            var end: float=NORTH if direction<0 else SOUTH
            var length: float=absf((track_min_z if direction<0 else track_max_z)-end)
            var mid: float=end+direction*length*0.5
            box(Vector3(3.8,0.20,length),Vector3(float(x),4.70,mid),black)
            for side in [-1.0,1.0]:
                box(Vector3(0.20,4.60,length),Vector3(float(x)+side*1.95,2.30,mid),marble_stone)
                for h in [0.6,1.0,1.5,2.0,2.5]:rod(Vector3(float(x)+side*1.82,float(h),end),Vector3(float(x)+side*1.82,float(h),end+direction*length),0.018,black)
                for j in range(int(length/0.8)):
                    box(Vector3(0.025,0.55,0.055),Vector3(float(x)+side*1.83,1.65,end+direction*(float(j)+0.5)*0.8),metal)
            box(Vector3(3.8,4.6,0.10),Vector3(float(x),2.3,end+direction*(length-0.1)),black)


func _driver_equipment() -> void:
    var infrastructure := get_node("StationInfrastructure")
    infrastructure.set("_amber",Color(1.0,0.16,0.055))
    var displays: Array=infrastructure.get("_displays")
    for display in displays:
        for i in range(70,76):display.set_instance_color(i,Color(1.0,0.16,0.055))
    for node in infrastructure.get_children():
        if node is Node3D and "Portal" in str(node.name):
            var north: bool=node.position.z<MID
            node.position.y=4.14;node.position.z=(NORTH+0.56) if north else (SOUTH-0.56)
            node.visible=str(node.name) in ["Track1Portal1Clock","Track2Portal2Clock"]
    for side in [-1.0,1.0]:
        var direction: float=-side
        var end: float=NORTH if direction<0 else SOUTH
        var yaw: float=0 if direction<0 else PI
        var root := Node3D.new();root.name="HeadDriverMirror";root.position=Vector3(CX+side*4.66,FY+1.36,end-direction*(3.1 if direction<0 else 9.0));root.rotation.y=yaw-side*0.13;add_child(root)
        var mirror := MeshInstance3D.new();mirror.set_script(preload("res://modules/stations/grushevka/driver_mirrors.gd"));mirror.name="ReflectingSurface"
        var q := QuadMesh.new();q.size=Vector2(0.57,1.52);mirror.mesh=q;mirror.set_meta("mirror_size",q.size);mirror.position.z=0.022;root.add_child(mirror)
        var frame := _material(Color("#d8d8c7"),0.18,0.42)
        var points: Array[Vector3]=[]
        for corner in range(4):
            var c := Vector2(0.205*(1 if corner in [0,3] else -1),0.65*(1 if corner in [0,1] else -1))
            for j in range(9):
                var a: float=float(corner)*PI/2.0+float(j)*PI/16.0;points.append(Vector3(c.x+0.10*cos(a),c.y+0.10*sin(a),0))
        for i in range(points.size()):_local_rod(root,points[i],points[(i+1)%points.size()],0.030,frame)
        _local_rod(root,Vector3(0,-1.36,0),Vector3(0,-0.73,0),0.060,_material(Color("#285278"),0.35,0.45))
        var camera := Vector3(CX+side*4.1,4.74,end-direction*0.35)
        box(Vector3(0.14,0.12,0.28),camera,white,Basis(Vector3.UP,yaw))
        sphere(Vector3(0.065,0.065,0.025),camera+Vector3(0,0,-direction*0.15),black)


func _local_rod(root: Node3D,a: Vector3,b: Vector3,r: float,mat: Material) -> void:
    var mesh := CylinderMesh.new();mesh.top_radius=r;mesh.bottom_radius=r;mesh.height=a.distance_to(b);mesh.material=mat;mesh.radial_segments=10
    var node := MeshInstance3D.new();node.mesh=mesh;node.position=(a+b)*0.5
    var axis := Vector3.UP.cross((b-a).normalized())
    if axis.length_squared()>0.00001:node.basis=Basis(axis.normalized(),Vector3.UP.angle_to((b-a).normalized()))
    root.add_child(node)


func _small_details() -> void:
    for z in [12.0,35.0,63.0]:
        var p := Vector3(CX+1.35,FY+0.025,float(z))
        cylinder(0.22,0.022,p,black);cylinder(0.19,0.024,p,metal)
        for i in range(12):
            var a: float=float(i)*TAU/12.0
            box(Vector3(0.018,0.009,0.045),p+Vector3(sin(a)*0.14,0.017,cos(a)*0.14),black,Basis(Vector3.UP,a))
    for direction in [-1.0,1.0]:
        var end: float=NORTH if direction<0 else SOUTH
        for side in [-1.0,1.0]:
            var x: float=CX+side*3.58
            picture("sos.svg",Vector2(0.30,0.50),Vector3(x,2.25,end+direction*0.65),-side*PI/2.0)
            picture("no_smoking.svg",Vector2(0.18,0.18),Vector3(x,2.72,end+direction*0.65),-side*PI/2.0)

