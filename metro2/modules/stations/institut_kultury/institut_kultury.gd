extends "res://modules/stations/institut_kultury/station_builder.gd"
## Independent photo-built single-vault station. Native meshes, metres, original Station Base connections.
const ART := "res://modules/stations/institut_kultury/art/"
const NORTH := -8.0
const SOUTH := 87.224
const RX := 8.90
const SPRING := 3.15
const RY := 4.25
const ARCH_FIRST := -3.60
const ARCH_PITCH := 7.20
const ARCH_COUNT := 13
const VITRAL_RECESS := -0.04
const SHELL_FRONT_INSET := 0.30
const SHELL_BACK_INSET := 0.16
const COFFER_DEPTH := 0.14
const APRON_BOTTOM := 2.10
const APRON_LOWER_INSET := 0.40
const APRON_TILT := 0.095
const SIGN_BAY_CYCLE := 4
const INFORMATION_POSTS := [10.8,39.6,68.4]
var wall_stone: StandardMaterial3D
var floor_russet: StandardMaterial3D
var floor_taupe: StandardMaterial3D
var floor_light: StandardMaterial3D
var stair_stone: StandardMaterial3D
var vestibule_stone: StandardMaterial3D
var yellow: StandardMaterial3D
var plaster: ShaderMaterial
var glass_palette: Array[StandardMaterial3D]=[]
var picture_surfaces: Dictionary={}

func _ready() -> void:
    super._ready();begin_station()
    for child in get_children():
        if child is OmniLight3D:child.queue_free()
    white=_material(Color("#e4e3dd"),0.0,0.88)
    wall_stone=_photo("wall_granite.jpg",Vector2(0.95,0.55),0.39)
    floor_russet=_photo("floor_russet.jpg",Vector2(0.60,0.60),0.47)
    floor_taupe=_photo("floor_taupe.jpg",Vector2(0.60,0.60),0.48)
    floor_light=_photo("floor_light.jpg",Vector2(0.60,0.60),0.49)
    stair_stone=_photo("stair_granite.jpg",Vector2(1.0,0.30),0.64)
    vestibule_stone=_photo("vestibule_marble.jpg",Vector2(1.1,0.60),0.48)
    granite=wall_stone;yellow=_material(Color("#d6b240"),0.0,0.65)
    metal.albedo_color=Color("#a4a6a0");metal.roughness=0.37
    plaster=ShaderMaterial.new();plaster.shader=preload("res://modules/stations/institut_kultury/plaster.gdshader")
    plaster.set_shader_parameter("paint_color",Color("#e4e3dd"))
    for tint in ["#9d7c30","#bda34a","#d0b85b","#8d7135","#b99339","#a19058","#735738","#c2af72"]:
        var mat := _material(Color(tint),0.18,0.28)
        mat.emission_enabled=true;mat.emission=Color(tint);mat.emission_energy_multiplier=0.09
        glass_palette.append(mat)
    _platform_floor();_track_walls();_vault()
    for i in range(ARCH_COUNT):_vitral_arch(ARCH_FIRST+float(i)*ARCH_PITCH,i)
    _end(-1.0,NORTH);_end(1.0,SOUTH)
    for z in INFORMATION_POSTS:_information_furniture(float(z))
    _railway();_driver_equipment();_small_details()
    _finish_pictures();flush()

func _photo(file: String,slab: Vector2,roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new();mat.albedo_texture=load(ART+file);mat.roughness=roughness
    mat.uv1_triplanar=true;mat.uv1_world_triplanar=true;mat.uv1_triplanar_sharpness=8.0
    mat.uv1_scale=Vector3(1.0/slab.x,1.0/slab.y,1.0/slab.x)
    mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return mat

func _solid(size: Vector3,p: Vector3,mat: Material) -> void:
    box(size,p,mat)
    var body := StaticBody3D.new();body.position=p;body.name="StationStructure"
    var shape := BoxShape3D.new();shape.size=size
    var collision := CollisionShape3D.new();collision.shape=shape;body.add_child(collision);add_child(body)

func _platform_floor() -> void:
    _solid(Vector3(10,0.20,105),Vector3(CX,FY-0.10,MID),floor_taupe)
    for row in range(175):
        for col in range(16):
            var x: float=CX-4.8+(float(col)+0.5)*0.60
            var z: float=ZA+(float(row)+0.5)*0.60
            var mat: Material=floor_taupe if (row+col)%4<2 else floor_russet
            box(Vector3(0.597,0.010,0.597),Vector3(x,FY+0.008,z),mat)
    # Broad interlocking diamond/chevron fields, photographed at 172048-172052.
    for i in range(17):
        var z: float=ZA+3.1+float(i)*6.0
        for side in [-1.0,1.0]:
            var x: float=CX+side*2.0
            var a := Vector3(x,FY+0.018,z-2.70)
            var b := Vector3(x+1.75,FY+0.018,z)
            var c := Vector3(x,FY+0.018,z+2.70)
            var d := Vector3(x-1.75,FY+0.018,z)
            quad(a,b,c,d,floor_russet,Vector3.UP)
            var e := Vector3(x,FY+0.021,z-1.76)
            var f := Vector3(x+1.06,FY+0.021,z)
            var g := Vector3(x,FY+0.021,z+1.76)
            var h := Vector3(x-1.06,FY+0.021,z)
            triangle(e,f,g,floor_light,Vector3.UP);triangle(e,g,h,floor_taupe,Vector3.UP)
    for side in [-1.0,1.0]:
        box(Vector3(0.38,0.022,105),Vector3(CX+side*4.81,FY+0.018,MID),floor_taupe)
        box(Vector3(0.13,0.010,105),Vector3(CX+side*4.53,FY+0.034,MID),yellow)
        for i in range(875):
            for dx in [-0.038,0.0,0.038]:cylinder(0.008,0.003,Vector3(CX+side*4.53+float(dx),FY+0.041,ZA+float(i)*0.12),yellow)

func _track_walls() -> void:
    for side in [-1.0,1.0]:
        var x: float=CX+side*RX
        box(Vector3(0.28,0.46,SOUTH-NORTH),Vector3(x,0.23,MID),black)
        box(Vector3(0.30,2.72,SOUTH-NORTH),Vector3(x,1.82,MID),wall_stone)
        for row in range(5):
            for col in range(96):
                var z: float=NORTH+(float(col)+0.5)*(SOUTH-NORTH)/96.0
                box(Vector3(0.006,0.004,(SOUTH-NORTH)/96.0-0.005),Vector3(x-side*0.155,0.5+float(row)*0.55,z),black)
                box(Vector3(0.006,0.545,0.004),Vector3(x-side*0.155,0.775+float(row)*0.55,z),black)
        for bay in range(ARCH_COUNT-1):
            var z: float=ARCH_FIRST+(float(bay)+0.5)*ARCH_PITCH
            # Full repeating rhythm: station name / empty apron / route board / empty apron.
            var phase: int=bay%SIGN_BAY_CYCLE
            if phase==0:
                _station_name(Vector3(_apron_face_x(side,2.62),2.62,z),-side*PI/2.0,"ИНСТИТУТ КУЛЬТУРЫ" if side<0 else "ІНСТЫТУТ КУЛЬТУРЫ")
            elif phase==2:
                _wall_route_board(Vector3(_apron_face_x(side,2.66),2.66,z),-side*PI/2.0)
        rod(Vector3(x-side*0.36,3.20,NORTH),Vector3(x-side*0.36,3.20,SOUTH),0.014,metal)
        for i in range(53):
            var z: float=NORTH+float(i)*1.8
            box(Vector3(0.035,0.07,0.035),Vector3(x-side*0.34,3.20,z),metal)

func _station_name(p: Vector3,yaw: float,text: String) -> void:
    var mesh := TextMesh.new();mesh.font=load(ART+"station_serif.ttf");mesh.text=text
    mesh.font_size=127;mesh.pixel_size=0.01;mesh.depth=0.032;mesh.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    var bronze := _material(Color("#98988e"),0.48,0.42);mesh.material=bronze
    var bounds: AABB=mesh.get_aabb()
    var node := MeshInstance3D.new();node.name="RaisedStationName";node.mesh=mesh;node.position=p;node.basis=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-APRON_TILT)
    node.scale=Vector3(4.95/maxf(bounds.size.x,0.001),0.285/maxf(bounds.size.y,0.001),1.0);add_child(node)

func _roof(a: float,z: float,inset: float=0.0) -> Vector3:
    return Vector3(CX+(RX-inset)*cos(a),SPRING+(RY-inset)*sin(a),z)

func _vault_normal(a: float) -> Vector3:
    return Vector3(-RY*cos(a),-RX*sin(a),0).normalized()

func _shell_inset(a: float,back: bool=false) -> float:
    var coffer_a: float=acos(2.6/RX)
    var inset: float=SHELL_BACK_INSET if back else SHELL_FRONT_INSET
    if a>coffer_a and a<PI-coffer_a:inset-=COFFER_DEPTH
    return inset

func _apron_face_x(side: float,y: float) -> float:
    var t: float=clampf((SPRING-y)/(SPRING-APRON_BOTTOM),0.0,1.0)
    return CX+side*(RX-lerpf(SHELL_FRONT_INSET,APRON_LOWER_INSET,t)-0.026)

func _wall_route_board(p: Vector3,yaw: float) -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_texture=load(ART+"wall_route_photo.jpg");mat.roughness=0.74
    mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    var mesh := QuadMesh.new();mesh.size=Vector2(5.85,0.84);mesh.material=mat
    var node := MeshInstance3D.new();node.name="PhotographedRouteBoard"
    node.mesh=mesh;node.position=p
    node.basis=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-APRON_TILT)
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func _shell_apron(side: float,z0: float,z1: float) -> void:
    # The vault folds down over the granite as a separate solid plaster skin.
    # Its lower edge projects further into the hall; the exposed underside is real geometry.
    var front_top := Vector2(CX+side*(RX-SHELL_FRONT_INSET),SPRING)
    var front_lower := Vector2(CX+side*(RX-APRON_LOWER_INSET),APRON_BOTTOM+0.018)
    var bevel := Vector2(front_lower.x+side*0.018,APRON_BOTTOM)
    var back_lower := Vector2(CX+side*(RX-APRON_LOWER_INSET+SHELL_FRONT_INSET-SHELL_BACK_INSET),APRON_BOTTOM)
    var back_top := Vector2(CX+side*(RX-SHELL_BACK_INSET),SPRING)
    var points: Array[Vector2]=[front_top,front_lower,bevel,back_lower,back_top]
    var normals: Array[Vector3]=[Vector3(-side,APRON_TILT,0).normalized(),Vector3(-side,-1,0).normalized(),Vector3.DOWN,Vector3(side,0,0)]
    for j in range(points.size()-1):
        var a: Vector2=points[j];var b: Vector2=points[j+1]
        quad(Vector3(a.x,a.y,z0),Vector3(b.x,b.y,z0),Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z1),plaster,normals[j])
    # Close both ends of each apron beside the recessed mosaic.
    for edge in range(2):
        var z: float=z0 if edge==0 else z1
        var normal := Vector3(0,0,-1 if edge==0 else 1)
        for j in range(1,points.size()-1):
            triangle(Vector3(front_top.x,front_top.y,z),Vector3(points[j].x,points[j].y,z),Vector3(points[j+1].x,points[j+1].y,z),plaster,normal)

func _vault_bay(z0: float,z1: float) -> void:
    # One continuous curved skin from both granite aprons up to the ceiling.
    # Every bay, including empty signage bays, has the same thickness and plaster finish.
    var coffer_a: float=acos(2.6/RX)
    var angles: Array[float]=[0.0,coffer_a,PI-coffer_a,PI]
    for j in range(1,96):angles.append(float(j)*PI/96.0)
    angles.sort()
    for j in range(angles.size()-1):
        var a: float=angles[j];var b: float=angles[j+1]
        if b-a<0.00001:continue
        var middle: bool=(a+b)*0.5>coffer_a and (a+b)*0.5<PI-coffer_a
        var inset: float=SHELL_FRONT_INSET-(COFFER_DEPTH if middle else 0.0)
        var back: float=SHELL_BACK_INSET-(COFFER_DEPTH if middle else 0.0)
        var normal: Vector3=_vault_normal((a+b)*0.5)
        quad(_roof(a,z0,inset),_roof(b,z0,inset),_roof(b,z1,inset),_roof(a,z1,inset),plaster,normal)
        quad(_roof(a,z0,back),_roof(a,z1,back),_roof(b,z1,back),_roof(b,z0,back),white,-normal)
        for edge in range(2):
            var z: float=z0 if edge==0 else z1
            quad(_roof(a,z,inset),_roof(b,z,inset),_roof(b,z,back),_roof(a,z,back),plaster,Vector3(0,0,-1 if edge==0 else 1))
    for a in [coffer_a,PI-coffer_a]:
        quad(_roof(a,z0,SHELL_FRONT_INSET),_roof(a,z1,SHELL_FRONT_INSET),_roof(a,z1,SHELL_FRONT_INSET-COFFER_DEPTH),_roof(a,z0,SHELL_FRONT_INSET-COFFER_DEPTH),plaster,Vector3.RIGHT if a>PI/2 else Vector3.LEFT)
        var p: Vector3=_roof(a,(z0+z1)*0.5,SHELL_FRONT_INSET-COFFER_DEPTH*0.5)
        box(Vector3(0.023,0.018,z1-z0),p,glow)
    for z in [z0,z1]:
        _arc_strip(coffer_a,PI-coffer_a,z-0.025,z+0.025,SHELL_FRONT_INSET,white)
    _shell_apron(-1.0,z0,z1);_shell_apron(1.0,z0,z1)

func _vault() -> void:
    var cursor: float=NORTH
    for i in range(ARCH_COUNT):
        var z: float=ARCH_FIRST+float(i)*ARCH_PITCH
        _vault_bay(cursor,z-0.47)
        cursor=z+0.47
    _vault_bay(cursor,SOUTH)

func _recess_reveal(z: float) -> void:
    # A real opening in the vault; light and glass sit beyond its plaster lip.
    _arc_strip(0,PI,z-0.39,z+0.39,VITRAL_RECESS-0.02,black)
    for side in [-1.0,1.0]:
        var coffer_a: float=acos(2.6/RX)
        var angles: Array[float]=[0.0,coffer_a,PI-coffer_a,PI]
        for j in range(1,96):angles.append(float(j)*PI/96.0)
        angles.sort()
        for j in range(angles.size()-1):
            var a: float=angles[j];var b: float=angles[j+1]
            if b-a<0.00001:continue
            var face: float=_shell_inset((a+b)*0.5)
            quad(_roof(a,z+side*0.47,face),_roof(b,z+side*0.47,face),_roof(b,z+side*0.39,VITRAL_RECESS),_roof(a,z+side*0.39,VITRAL_RECESS),plaster,Vector3(0,0,-side))
        _arc_strip(0,PI,z+side*0.39-0.009,z+side*0.39+0.009,VITRAL_RECESS+0.012,metal)

func _arc_strip(a0: float,a1: float,z0: float,z1: float,inset: float,mat: Material) -> void:
    var count: int=maxi(1,int(ceil((a1-a0)*55.0)))
    for j in range(count):
        var a: float=lerpf(a0,a1,float(j)/float(count));var b: float=lerpf(a0,a1,float(j+1)/float(count))
        quad(_roof(a,z0,inset),_roof(b,z0,inset),_roof(b,z1,inset),_roof(a,z1,inset),mat,_vault_normal((a+b)*0.5))

func _vitral_arch(z: float,index: int) -> void:
    _recess_reveal(z)
    for side in range(2):
        var offset: float=0.0 if side==0 else PI-1.18
        # Native amber glass tiles: thin silver leading, fine ribbed surfaces, no disconnected luminous cubes.
        for row in range(34):
            var a: float=offset+float(row)*1.18/34.0
            var b: float=offset+float(row+1)*1.18/34.0
            for col in range(8):
                var z0: float=z-0.375+float(col)*0.75/8.0
                var z1: float=z0+0.75/8.0
                var mat: Material=glass_palette[(row*7+col*3+index*5+side)%glass_palette.size()]
                _arc_strip(a+0.002,b-0.002,z0+0.004,z1-0.004,VITRAL_RECESS+0.010,mat)
                for rib in range(4):
                    var zr: float=lerpf(z0,z1,(float(rib)+0.5)/4.0)
                    _arc_strip(a+0.003,b-0.003,zr-0.0014,zr+0.0014,VITRAL_RECESS+0.013,glass_palette[(row*7+col*3+index*5+side+1)%glass_palette.size()])
            _arc_strip(a,a+0.0025,z-0.38,z+0.38,VITRAL_RECESS+0.021,metal)
        for col in range(9):
            var zz: float=z-0.38+float(col)*0.76/8.0
            _arc_strip(offset,offset+1.18,zz-0.004,zz+0.004,VITRAL_RECESS+0.024,metal)
        var file: String=["glass_builder.jpg","glass_musician.jpg","glass_player.jpg","glass_reader.jpg"][(index+side)%4]
        _figure(file,z,side==0)
    # The centre of each arch carries a curved bank of prismatic white fluorescent luminaires.
    for j in range(44):
        var a: float=lerpf(1.18,PI-1.18,(float(j)+0.5)/44.0)
        var p: Vector3=_roof(a,z,VITRAL_RECESS+0.045)
        var tangent := Vector3(-RX*sin(a),RY*cos(a),0).normalized()
        var inward := Vector3(-tangent.y,tangent.x,0)
        var basis := Basis(tangent,inward,Vector3.BACK)
        box(Vector3(0.072,0.045,0.79),p,metal,basis)
        box(Vector3(0.024,0.026,0.72),p+inward*0.035,glow,basis)
        for segment in range(8):
            box(Vector3(0.058,0.023,0.068),p+inward*0.028+Vector3(0,0,-0.315+float(segment)*0.09),_lens_material(),basis)
        for end in [-1.0,1.0]:box(Vector3(0.085,0.07,0.045),p+Vector3(0,0,float(end)*0.38),black,basis)
    var light := OmniLight3D.new();light.name="ArchLight"+str(index);light.position=Vector3(CX,6.65,z)
    light.light_color=Color(1.0,0.98,0.94);light.light_energy=0.95;light.omni_range=9.0;light.omni_attenuation=0.95;add_child(light)
    # Shadow sources are confined to three arch groups; remaining arches use the diffuse light above.
    if index not in [1,6,11]:return
    for side in [-1.0,1.0]:
        var wash := SpotLight3D.new();wash.name="VaultWash"+str(index)
        wash.position=Vector3(CX+side*2.1,6.55,z);add_child(wash)
        wash.look_at(Vector3(CX+side*7.9,2.15,z),Vector3.UP)
        wash.light_color=Color(0.98,1.0,0.96);wash.light_energy=0.70
        wash.spot_range=11.0;wash.spot_angle=65.0;wash.spot_attenuation=0.8
        wash.shadow_enabled=true
        wash.shadow_bias=0.035;wash.shadow_normal_bias=0.25

var lens: StandardMaterial3D
func _lens_material() -> StandardMaterial3D:
    if lens==null:
        lens=_material(Color("#d8ddd6"),0.18,0.20);lens.emission_enabled=true;lens.emission=Color("#f0f4e8");lens.emission_energy_multiplier=0.48
    return lens

func _figure(file: String,z: float,right: bool) -> void:
    for j in range(14):
        var t0: float=float(j)/14.0;var t1: float=float(j+1)/14.0
        var a: float=lerpf(0.015,0.33,t0);var b: float=lerpf(0.015,0.33,t1)
        if not right:a=PI-a;b=PI-b
        _art_quad(file,_roof(a,z-0.369,VITRAL_RECESS+0.030),_roof(a,z+0.369,VITRAL_RECESS+0.030),_roof(b,z+0.369,VITRAL_RECESS+0.030),_roof(b,z-0.369,VITRAL_RECESS+0.030),Rect2(0,1.0-t1,1,t1-t0),true)

func _art_quad(file: String,a: Vector3,b: Vector3,c: Vector3,d: Vector3,uv: Rect2,emitting: bool=false) -> void:
    if not picture_surfaces.has(file):
        var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var mat := StandardMaterial3D.new();mat.albedo_texture=load(ART+file);mat.roughness=0.30;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
        if emitting:mat.emission_enabled=true;mat.emission_texture=mat.albedo_texture;mat.emission=Color.WHITE;mat.emission_energy_multiplier=0.12
        picture_surfaces[file]={"surface":st,"material":mat}
    var st: SurfaceTool=picture_surfaces[file].surface
    var normal := (b-a).cross(d-a).normalized()
    if normal.dot(Vector3(CX-(a.x+b.x+c.x+d.x)*0.25,-1,0))<0.0:normal=-normal
    var points: Array[Vector3]=[a,c,b,a,d,c]
    var uvs: Array[Vector2]=[uv.position+Vector2(0,uv.size.y),uv.position+Vector2(uv.size.x,0),uv.end,uv.position+Vector2(0,uv.size.y),uv.position,uv.position+Vector2(uv.size.x,0)]
    for i in range(6):st.set_normal(normal);st.set_uv(uvs[i]);st.add_vertex(points[i])

func _finish_pictures() -> void:
    for file in picture_surfaces:
        var data: Dictionary=picture_surfaces[file];var st: SurfaceTool=data.surface
        var mesh := st.commit();mesh.surface_set_material(0,data.material)
        var node := MeshInstance3D.new();node.name="PhotoVitralFigures";node.mesh=mesh;add_child(node)
    picture_surfaces.clear()

func _vault_y(x: float) -> float:
    return SPRING+RY*sqrt(maxf(0.0,1.0-pow(x/RX,2.0)))

func _end(direction: float,start: float) -> void:
    # Exact arch-shaped tympanum, closed above the staircase and the two independent track mouths.
    var xs: Array[float]=[-RX,-8.212,-4.512,-3.70,3.70,4.512,8.212,RX]
    for i in range(1,96):xs.append(-RX+float(i)*RX*2.0/96.0)
    xs.sort()
    for i in range(xs.size()-1):
        var a: float=xs[i];var b: float=xs[i+1]
        if b-a<0.0001:continue
        var x: float=(a+b)*0.5
        var bottom: float=5.30 if absf(x)<3.70 else 4.62 if absf(x)>4.512 and absf(x)<8.212 else 0.0
        var ya: float=maxf(bottom,_vault_y(a));var yb: float=maxf(bottom,_vault_y(b))
        var z0: float=start;var z1: float=start+direction*0.30
        for z in [z0,z1]:quad(Vector3(CX+a,bottom,float(z)),Vector3(CX+b,bottom,float(z)),Vector3(CX+b,yb,float(z)),Vector3(CX+a,ya,float(z)),white,Vector3(0,0,-direction))
        quad(Vector3(CX+a,bottom,z0),Vector3(CX+a,bottom,z1),Vector3(CX+b,bottom,z1),Vector3(CX+b,bottom,z0),white,Vector3.DOWN)
    # 172154: two broad stair flights, intermediate landing, yellow first/last nosings and wall handrails.
    for flight in range(2):
        for i in range(18):
            var y: float=FY+float(flight)*2.70+float(i+1)*0.15
            var distance: float=float(flight)*6.60+(float(i)+0.5)*0.30
            _solid(Vector3(7.20,0.18,0.30),Vector3(CX,y-0.09,start+direction*distance),stair_stone)
            box(Vector3(7.18,0.010,0.055),Vector3(CX,y+0.007,start+direction*(distance-0.117)),yellow if i in [0,17] else floor_light)
        if flight==0:_solid(Vector3(7.20,0.20,1.20),Vector3(CX,FY+2.60,start+direction*6.0),floor_taupe)
        for side in [-1.0,1.0]:
            for h in [0.76,1.02]:
                var a := Vector3(CX+side*3.43,FY+float(flight)*2.70+float(h),start+direction*(float(flight)*6.60-0.10))
                var b := Vector3(a.x,FY+float(flight+1)*2.70+float(h),start+direction*(float(flight)*6.60+5.40))
                rod(a,b,0.028,metal)
                for j in range(5):
                    var p: Vector3=a.lerp(b,float(j)/4.0)
                    rod(p,p+Vector3(side*0.15,-0.10,0),0.018,metal)
                if flight==0:rod(b,b+Vector3(0,0,direction*1.2),0.028,metal)
    var top: float=FY+5.40
    _solid(Vector3(7.20,0.20,4.0),Vector3(CX,top-0.10,start+direction*14.0),floor_taupe)
    for side in [-1.0,1.0]:
        _solid(Vector3(0.30,9.0,15.8),Vector3(CX+side*3.76,FY+4.50,start+direction*7.8),vestibule_stone)
        for row in range(10):box(Vector3(0.008,0.004,15.5),Vector3(CX+side*3.60,FY+float(row)*0.60,start+direction*7.75),floor_taupe)
    # Rising soffit leaves continuous headroom all the way up to the upper hall.
    for j in range(10):
        var a: float=float(j)*1.60;var b: float=float(j+1)*1.60
        var ya: float=5.40+a*0.28;var yb: float=5.40+b*0.28
        quad(Vector3(CX-3.9,ya,start+direction*a),Vector3(CX+3.9,ya,start+direction*a),Vector3(CX+3.9,yb,start+direction*b),Vector3(CX-3.9,yb,start+direction*b),white,Vector3.DOWN)
        box(Vector3(7.5,0.15,0.18),Vector3(CX,ya-0.10,start+direction*a),white)
        box(Vector3(5.8,0.027,0.055),Vector3(CX,ya-0.19,start+direction*a),glow)
    var sign_file: String="exit_surazhskaya.svg" if direction<0 else "exit_tolstogo.svg"
    var sign := Vector3(CX,4.66,start-direction*0.38)
    box(Vector3(4.25,0.78,0.10),sign,metal)
    picture(sign_file,Vector2(4.12,0.66),sign+Vector3(0,0,-direction*0.058),0 if direction<0 else PI)
    for x in [-1.65,1.65]:rod(Vector3(CX+float(x),5.15,start-direction*0.38),Vector3(CX+float(x),5.02,start-direction*0.38),0.024,metal)
    foot_grille(start-direction*0.30,7.1)
    _upper_hall(direction,start,top)

func _upper_hall(direction: float,start: float,floor_y: float) -> void:
    # Upper vestibule has side continuations beyond the fare gates, not a wall sealing the stairs.
    _solid(Vector3(19.0,0.20,10.0),Vector3(CX,floor_y-0.10,start+direction*21.0),floor_taupe)
    box(Vector3(19.3,0.22,10.0),Vector3(CX,9.72,start+direction*21.0),white)
    _solid(Vector3(19.0,3.13,0.25),Vector3(CX,floor_y+1.565,start+direction*26.12),vestibule_stone)
    for side in [-1.0,1.0]:
        _solid(Vector3(5.9,3.13,0.25),Vector3(CX+side*6.55,floor_y+1.565,start+direction*15.88),vestibule_stone)
        box(Vector3(0.15,3.13,10.0),Vector3(CX+side*9.6,floor_y+1.565,start+direction*21.0),black)
        for z in [18.7,23.3]:_solid(Vector3(0.42,3.13,0.42),Vector3(CX+side*4.05,floor_y+1.565,start+direction*float(z)),vestibule_stone)
        var continuation := Marker3D.new();continuation.name=("North" if direction<0 else "South")+("Left" if side<0 else "Right")+"ExitContinuation"
        continuation.position=Vector3(CX+side*8.2,floor_y,start+direction*21.0);get_node("PassengerAnchors").add_child(continuation)
    for i in range(6):
        var z: float=start+direction*(16.4+float(i)*1.65)
        box(Vector3(18.5,0.13,0.16),Vector3(CX,9.55,z),white)
        box(Vector3(5.6,0.028,0.06),Vector3(CX,9.46,z),glow)
    for lane in range(5):
        var x: float=CX-2.48+float(lane)*1.24
        var z: float=start+direction*18.3
        box(Vector3(0.26,0.91,0.96),Vector3(x,floor_y+0.455,z),metal)
        box(Vector3(0.28,0.055,0.98),Vector3(x,floor_y+0.94,z),black)
        box(Vector3(0.09,0.04,0.15),Vector3(x,floor_y+1.00,z-direction*0.28),glow)
        rod(Vector3(x,floor_y+0.78,z),Vector3(x+0.47,floor_y+0.78,z-direction*0.08),0.023,metal)
        rod(Vector3(x,floor_y+0.78,z),Vector3(x+0.16,floor_y+0.40,z+direction*0.28),0.023,metal)
    _controller_booth(Vector3(CX-5.6,floor_y,start+direction*18.8))
    var light := OmniLight3D.new();light.position=Vector3(CX,8.9,start+direction*18.8);light.light_energy=1.10;light.omni_range=9.0;add_child(light)

func _controller_booth(p: Vector3) -> void:
    box(Vector3(1.80,0.70,1.50),p+Vector3(0,0.35,0),vestibule_stone)
    box(Vector3(1.88,0.12,1.58),p+Vector3(0,2.23,0),metal)
    var glass := _material(Color(0.52,0.65,0.63,0.26),0.10,0.14);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    box(Vector3(1.74,1.44,0.018),p+Vector3(0,1.45,0.73),glass)
    for side in [-1.0,1.0]:
        box(Vector3(0.018,1.44,1.42),p+Vector3(side*0.88,1.45,0),glass)
        for z in [-0.73,0.73]:box(Vector3(0.035,1.58,0.035),p+Vector3(side*0.88,1.45,float(z)),metal)
    box(Vector3(1.55,0.06,0.55),p+Vector3(0,1.0,0.22),timber)
    box(Vector3(0.38,0.28,0.035),p+Vector3(0.3,1.19,0.15),black)

func _information_furniture(z: float) -> void:
    # Three square information pylons, readable from all four platform approaches.
    for side in [-1.0,1.0]:box(Vector3(0.48,0.39,1.72),Vector3(CX,FY+0.195,z+side*1.42),wall_stone)
    for i in range(15):
        if i in [6,7,8]:continue
        box(Vector3(0.66,0.065,0.273),Vector3(CX,FY+0.43,z-2.04+float(i)*0.292),timber)
    var steel := _material(Color("#79756b"),0.64,0.40)
    box(Vector3(0.66,3.85,0.66),Vector3(CX,FY+1.925,z),steel)
    var panel := Vector3(CX,FY+2.08,z)
    box(Vector3(1.01,2.30,1.01),panel,metal)
    for face in range(4):
        var yaw: float=float(face)*PI/2.0
        var outward := Vector3(sin(yaw),0,cos(yaw))
        var file: String="pylon_routes.jpg" if face%2==0 else "pylon_exits.jpg"
        picture(file,Vector2(0.89,2.10),panel+outward*0.512,yaw)
        # Separate extruded corner rails and illuminated poster surround.
        var basis := Basis(Vector3.UP,yaw)
        for edge in [-1.0,1.0]:
            box(Vector3(0.035,2.20,0.028),panel+outward*0.526+basis.x*edge*0.462,steel,basis)
        for edge in [-1.0,1.0]:
            box(Vector3(0.93,0.035,0.028),panel+outward*0.526+Vector3(0,edge*1.075,0),steel,basis)
        var head := Vector3(CX,FY+3.57,z)
        box(Vector3(0.90,0.52,0.045),head+outward*0.38,black,basis)
        for i in range(15):box(Vector3(0.029,0.47,0.025),head+outward*0.410+basis.x*(-0.42+float(i)*0.06),metal,basis)
    for side in [-1.0,1.0]:
        var p := Vector3(CX,FY+4.41,z+side*0.18)
        box(Vector3(1.87,1.10,0.10),p,black)
        picture("advert.jpg",Vector2(1.76,0.98),p+Vector3(0,0,side*0.056),0 if side>0 else PI)
    for side in [-1.0,1.0]:
        var pts: Array[Vector3]=[Vector3(CX-0.58,FY+1.03,z),Vector3(CX-0.63,FY+0.98,z+side*0.48),Vector3(CX-0.54,FY+0.93,z+side*0.62),Vector3(CX+0.54,FY+0.93,z+side*0.62),Vector3(CX+0.63,FY+0.98,z+side*0.48),Vector3(CX+0.58,FY+1.03,z)]
        for j in range(pts.size()-1):rod(pts[j],pts[j+1],0.026,metal)

func _railway() -> void:
    var detail := preload("res://modules/stations/institut_kultury/track_detail.gd").new();detail.name="DetailedStationTracks"
    detail.start_z=track_min_z;detail.finish_z=track_max_z;add_child(detail)
    for x in [0.992,-11.732]:
        for direction in [-1.0,1.0]:
            var end: float=NORTH if direction<0 else SOUTH
            var length: float=absf((track_min_z if direction<0 else track_max_z)-end)
            var mid: float=end+direction*length*0.5
            box(Vector3(3.8,0.20,length),Vector3(float(x),4.70,mid),black)
            for side in [-1.0,1.0]:
                box(Vector3(0.20,4.60,length),Vector3(float(x)+side*1.95,2.30,mid),vestibule_stone)
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
        var root := Node3D.new();root.name="HeadDriverMirror";root.position=Vector3(CX+side*4.66,FY+1.36,end-direction*3.1);root.rotation.y=yaw-side*0.13;add_child(root)
        var mirror := MeshInstance3D.new();mirror.set_script(preload("res://modules/stations/institut_kultury/driver_mirrors.gd"));mirror.name="ReflectingSurface"
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
