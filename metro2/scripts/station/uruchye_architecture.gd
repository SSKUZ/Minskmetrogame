extends Node3D
## Owner photographs 6695–6709: platform, furniture, finishes and bilingual navigation.
## Retains the route rail datum; longitudinal spacing is inferred, not surveyed.
const CX := -5.37
const FLOOR := 1.1805
const Z0 := -12.888
const Z1 := 92.112
var batches: Dictionary = {}
var white: Material
var blue: Material
var steel: Material
var dark: Material
var stone: Material
var glow: Material
var wood: Material

func _ready() -> void:
    white = _mat(Color("#d4d8d5"),0.10,0.6)
    blue = _mat(Color("#a9c9de"),0.30,0.36)
    steel = _mat(Color("#b9c1c6"),0.80,0.26)
    dark = _mat(Color("#29333c"),0.15,0.5)
    stone = _granite(Color.WHITE)
    glow = _mat(Color("#fff5dc"),0.0,0.6,Color(1.0,0.94,0.79))
    wood = _wood_material()
    _floor_and_walls()
    _columns_and_ceiling()
    _stairs(1.0,Z1-11.0)
    _stairs(-1.0,Z0+11.0)
    _navigation()
    _lift()
    _advertising()
    _station_ends()
    _flush()
    var equipment := preload("res://scripts/station/uruchye_platform_equipment.gd").new()
    equipment.name="UruchyePlatformEquipment"
    add_child(equipment)

func _mat(color: Color, metal: float = 0.0, rough: float = 0.7, emission: Color = Color.BLACK) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metal
    m.roughness = rough
    if emission != Color.BLACK:
        m.emission_enabled = true
        m.emission = emission
        m.emission_energy_multiplier = 1.7
    return m

func _stone(color: Color, marble: bool) -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """shader_type spatial;
uniform vec4 tint : source_color;
uniform bool marble = false;
varying vec3 p;
void vertex(){ p=VERTEX; }
float hash(vec3 v){ return fract(sin(dot(v,vec3(12.9898,78.233,37.719)))*43758.5453); }
void fragment(){
    vec3 q=p*95.0;
    float grain=hash(floor(q));
    float vein=pow(abs(sin(p.z*3.1+p.y*6.7+sin(p.z*1.7+p.y*2.3)*2.1)),16.0);
    vec2 tile=abs(fract(p.xz/0.65+0.5)-0.5);
    float seam=step(0.498,max(tile.x,tile.y));
    ALBEDO=tint.rgb*(0.94+grain*0.10)-(marble?vec3(vein*0.12):vec3(seam*0.045));
    ROUGHNESS=marble?0.42:0.36; METALLIC=0.03;
}
"""
    var m := ShaderMaterial.new()
    m.shader = shader
    m.set_shader_parameter("tint",color)
    m.set_shader_parameter("marble",marble)
    return m

func _box(size: Vector3, pos: Vector3, material: Material, basis: Basis = Basis.IDENTITY) -> void:
    _batch("box",material,Transform3D(basis*Basis.from_scale(size),pos))

func _cylinder(radius: float, height: float, pos: Vector3, material: Material) -> void:
    _batch("cylinder",material,Transform3D(Basis.from_scale(Vector3(radius*2,height,radius*2)),pos))

func _batch(kind: String, material: Material, pose: Transform3D) -> void:
    var key := kind+str(material.get_instance_id())
    if not batches.has(key): batches[key] = {"kind":kind,"material":material,"poses":[]}
    batches[key]["poses"].append(pose)

func _flush() -> void:
    for key in batches:
        var data: Dictionary = batches[key]
        var mesh: PrimitiveMesh
        if data["kind"] == "cylinder":
            var cylinder := CylinderMesh.new()
            cylinder.top_radius=0.5; cylinder.bottom_radius=0.5
            cylinder.height=1.0; cylinder.radial_segments=24
            mesh=cylinder
        elif data["kind"] == "sphere":
            var sphere := SphereMesh.new()
            sphere.radius=0.5; sphere.height=1.0
            sphere.radial_segments=12; sphere.rings=6
            mesh=sphere
        else:
            var box := BoxMesh.new()
            box.size=Vector3.ONE
            mesh=box
        mesh.material=data["material"]
        var multi := MultiMesh.new()
        multi.transform_format=MultiMesh.TRANSFORM_3D
        multi.mesh=mesh
        multi.instance_count=data["poses"].size()
        for i in range(multi.instance_count): multi.set_instance_transform(i,data["poses"][i])
        var instance := MultiMeshInstance3D.new()
        instance.multimesh=multi
        add_child(instance)
    batches.clear()

func _floor_and_walls() -> void:
    (get_parent().get_node("IslandPlatform") as MeshInstance3D).material_override=_floor_material()
    var marble := _marble_material()
    var black_stone := _granite(Color("#252a2c"))
    var cobalt := _mat(Color("#214b8d"),0.16,0.38)
    var pale_band := _mat(Color("#9fbad2"),0.32,0.40)
    for node_name in ["SafetyEdgeTrack1","SafetyEdgeTrack2","TrainStopMarker"]:
        (get_parent().get_node(node_name) as MeshInstance3D).visible=false
    for x in [-0.57,-10.17]:
        _box(Vector3(0.40,0.012,105),Vector3(x,FLOOR+0.006,39.612),stone)
    var tactile := _tactile_material()
    for x in [-0.68,-10.06]:
        _box(Vector3(0.18,0.008,105),Vector3(x,FLOOR+0.018,39.612),tactile)
    for side in [-1.0,1.0]:
        var wall_x: float = CX+side*8.85
        var face: float = wall_x-side*0.19
        _box(Vector3(0.28,7.6,112),Vector3(wall_x,3.5,36.112),white)
        _box(Vector3(0.035,0.98,112),Vector3(face,0.55,36.112),black_stone)
        _box(Vector3(0.04,0.32,112),Vector3(face-side*0.008,1.20,36.112),cobalt)
        _box(Vector3(0.045,0.39,112),Vector3(face-side*0.012,1.57,36.112),pale_band)
        _box(Vector3(0.045,0.035,112),Vector3(face-side*0.02,1.78,36.112),dark)
        _box(Vector3(0.045,2.54,112),Vector3(face-side*0.015,3.065,36.112),marble)
        _box(Vector3(0.05,0.028,112),Vector3(face-side*0.025,4.36,36.112),dark)
        for y in [2.69,2.735]:
            _bar(Vector3(face-side*0.04,y,Z0-7),Vector3(face-side*0.04,y,Z1),0.016,steel)
        for z in [10.0,45.0,72.0]:
            _wall_title(side,face,z)
        for z in [25.5,59.0]:
            var board := _picture(preload("res://assets/station/photo_reference/route.png"),Vector2(4.8,1.11),Vector3(face-side*0.07,2.97,z),-side*PI/2.0)
            board.name="WallLineMap124Uruchye"
        for z in [2.0,33.0,63.0,84.0]:
            _ornament(side,face,z)

func _wall_title(side: float,face: float,z: float) -> void:
    # Raised Belarusian lettering and blue water silhouette, both track walls.
    var root := Node3D.new()
    root.position=Vector3(face-side*0.08,2.92,z)
    root.rotation.y=-side*PI/2.0
    root.name="UruchchaRaisedWallName"
    add_child(root)
    var cobalt := _mat(Color("#226398"),0.35,0.38)
    var shape := PackedVector2Array([Vector2(-2.45,-0.20),Vector2(-1.65,-0.13),Vector2(-0.7,0.35),Vector2(0.0,0.43),Vector2(0.75,0.20),Vector2(1.45,-0.08),Vector2(2.45,-0.18),Vector2(1.55,-0.25),Vector2(0.4,-0.34),Vector2(-0.8,-0.30)])
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var indices := Geometry2D.triangulate_polygon(shape)
    for index in indices:
        st.set_normal(Vector3.BACK)
        st.add_vertex(Vector3(shape[index].x,shape[index].y,0))
    var wave := MeshInstance3D.new()
    wave.mesh=st.commit(); wave.material_override=cobalt
    root.add_child(wave)
    var letters := MeshInstance3D.new()
    var mesh := TextMesh.new()
    mesh.text="УРУЧЧА"; mesh.font_size=100; mesh.pixel_size=0.0068
    mesh.depth=0.055
    mesh.material=steel
    letters.mesh=mesh; letters.position=Vector3(0,-0.02,0.045)
    root.add_child(letters)
    _ornament(side,face,z-3.15)
    _ornament(side,face,z+3.15)

func _ornament(side: float,face: float,z: float) -> void:
    var x: float=face-side*0.07
    for row in [-1.0,1.0]:
        for i in range(20):
            var u := float(i)/20.0
            var v := float(i+1)/20.0
            var a := Vector3(x,2.72+row*(0.09+0.11*sin(u*PI)),z-0.75+u*1.5)
            var b := Vector3(x,2.72+row*(0.09+0.11*sin(v*PI)),z-0.75+v*1.5)
            _bar(a,b,0.017,steel)
    for j in range(3):
        var zz := z-0.72+float(j)*0.72
        var yy := 3.07 if j==1 else 2.43
        for i in range(20):
            var a := float(i)*TAU/20.0
            var b := float(i+1)*TAU/20.0
            _bar(Vector3(x,yy+cos(a)*0.10,zz+sin(a)*0.10),Vector3(x,yy+cos(b)*0.10,zz+sin(b)*0.10),0.017,steel)


func _triangle(a: Vector3,b: Vector3,c: Vector3, material: Material) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_normal(Vector3.UP); st.add_vertex(a)
    st.set_normal(Vector3.UP); st.add_vertex(b)
    st.set_normal(Vector3.UP); st.add_vertex(c)
    var m := MeshInstance3D.new()
    m.mesh=st.commit(); m.material_override=material
    m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(m)

func _columns_and_ceiling() -> void:
    var ceiling_blue := _mat(Color("#536b83"),0.30,0.48)
    var seam := _mat(Color("#344757"),0.30,0.55)
    _box(Vector3(17.8,0.18,112),Vector3(CX,7.65,36.112),white)
    _box(Vector3(4.8,0.12,81),Vector3(CX,5.59,39.6),ceiling_blue)
    # Longitudinal narrow blue slats, not transverse strips or a wavy roof.
    for i in range(61):
        var x := CX-2.4+float(i)*0.08
        _box(Vector3(0.008,0.012,81),Vector3(x,5.522,39.6),seam)
    for side in [-1.0,1.0]:
        _box(Vector3(6.45,0.12,112),Vector3(CX+side*5.62,6.02,36.112),ceiling_blue)
        for j in range(61):
            _box(Vector3(0.008,0.014,112),Vector3(CX+side*(2.45+float(j)*0.105),5.952,36.112),seam)
        _box(Vector3(0.24,0.14,105),Vector3(CX+side*5.55,5.34,39.612),white)
    for i in range(19):
        var z := -1.0+float(i)*4.5
        if absf(z-17.0)<3.0 or absf(z-39.5)<3.0 or absf(z-62.0)<3.0 or z>74.0: continue
        _cylinder(0.43,3.64,Vector3(CX,FLOOR+1.99,z),blue)
        _cylinder(0.43,0.17,Vector3(CX,FLOOR+0.085,z),steel)
        _cylinder(0.44,0.48,Vector3(CX,5.22,z),steel)
        _cylinder(0.53,0.055,Vector3(CX,5.49,z),dark)
        for y in [FLOOR+0.09,FLOOR+0.18]:
            _torus(CX,y,z,0.49,0.024,steel)
        for j in range(32):
            var a := float(j)*TAU/32.0
            _bar(Vector3(CX+sin(a)*0.445,4.99,z+cos(a)*0.445),Vector3(CX+sin(a)*0.445,5.45,z+cos(a)*0.445),0.008,dark)
        for a in [0.0,PI]:
            _bar(Vector3(CX+sin(a)*0.432,FLOOR+0.18,z+cos(a)*0.432),Vector3(CX+sin(a)*0.432,4.98,z+cos(a)*0.432),0.006,steel)
    for z in [17.0,39.5,62.0]:
        _furniture_block(z)
    # White tapered ceiling ribs carry the strip lights; globes line the track cornice.
    for i in range(53):
        var z := Z0+1.0+float(i)*1.98
        for side in [-1.0,1.0]:
            _rib(side,z)
            _box(Vector3(2.25,0.09,0.15),Vector3(CX+side*3.60,5.47,z),steel)
            _box(Vector3(2.08,0.026,0.10),Vector3(CX+side*3.60,5.412,z),glow)
            var x := CX+side*5.55
            _batch("sphere",glow,Transform3D(Basis.from_scale(Vector3.ONE*0.28),Vector3(x,5.53,z)))
            _cylinder(0.075,0.08,Vector3(x,5.36,z),steel)
    for z in [-7.0,86.0]:
        _box(Vector3(9.7,0.10,12),Vector3(CX,7.24,z),dark)
        for i in range(40):
            _box(Vector3(0.025,0.09,12),Vector3(CX-4.8+float(i)*0.245,7.16,z),ceiling_blue)
        for i in range(49):
            _box(Vector3(9.7,0.09,0.025),Vector3(CX,7.16,z-6.0+float(i)*0.245),ceiling_blue)
    for i in range(6):
        var light := get_parent().get_node("PlatformLight%02d" % (i+1)) as OmniLight3D
        light.position.x=CX+(-1.7 if i%2==0 else 1.7)
        light.position.y=4.65; light.light_color=Color(1.0,0.97,0.90)
        light.light_energy=2.3; light.omni_range=19.0; light.omni_attenuation=0.65

func _rib(side: float,z: float) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var profile := [Vector2(2.4,5.53),Vector2(5.55,5.53),Vector2(5.55,5.96),Vector2(4.8,5.96)]
    for face in [-1.0,1.0]:
        for index in [0,1,2,0,2,3]:
            st.set_normal(Vector3(0,0,face))
            st.add_vertex(Vector3(CX+side*profile[index].x,profile[index].y,z+face*0.065))
    var mesh := MeshInstance3D.new()
    mesh.mesh=st.commit(); mesh.material_override=white
    # Side profiles are two-sided; the thin white underside closes the rib.
    var material := white.duplicate() as StandardMaterial3D
    material.cull_mode=BaseMaterial3D.CULL_DISABLED; mesh.material_override=material
    add_child(mesh)
    _box(Vector3(3.15,0.06,0.13),Vector3(CX+side*3.975,5.53,z),white)

func _torus(x: float,y: float,z: float,radius: float,tube: float,material: Material) -> void:
    for i in range(40):
        var a := float(i)*TAU/40.0
        var b := float(i+1)*TAU/40.0
        _bar(Vector3(x+sin(a)*radius,y,z+cos(a)*radius),Vector3(x+sin(b)*radius,y,z+cos(b)*radius),tube,material)

func _furniture_block(z: float) -> void:
    var plinth := _granite(Color("#22272a"))
    _box(Vector3(1.60,0.30,4.40),Vector3(CX,FLOOR+0.15,z),plinth)
    _box(Vector3(1.35,3.70,3.0),Vector3(CX,FLOOR+2.12,z),blue)
    _box(Vector3(1.39,0.74,3.04),Vector3(CX,5.12,z),steel)
    for side in [-1.0,1.0]:
        _box(Vector3(0.035,0.53,2.4),Vector3(CX+side*0.69,5.15,z),dark)
        for i in range(6):
            _box(Vector3(0.045,0.022,2.4),Vector3(CX+side*0.72,4.93+float(i)*0.085,z),steel)
        _box(Vector3(0.04,0.70,2.9),Vector3(CX+side*0.70,FLOOR+0.90,z),_mat(Color("#3068ad"),0.28,0.5))
    for end in [-1.0,1.0]:
        var ez: float=z+end*1.5
        _cylinder(0.67,3.30,Vector3(CX,FLOOR+2.10,ez),blue)
        _cylinder(0.69,0.10,Vector3(CX,FLOOR+0.73,ez),steel)
        _cylinder(0.69,0.58,Vector3(CX,5.13,ez),steel)
        # Semicircular wooden bench only around the two rounded block ends.
        for j in range(31):
            var a: float=-PI/2.0+float(j)*PI/30.0
            var radial := Vector3(sin(a),0,end*cos(a))
            var yaw := atan2(radial.x,radial.z)
            _box(Vector3(0.07,0.14,0.58),Vector3(CX,FLOOR+0.48,ez)+radial*0.92,wood,Basis(Vector3.UP,yaw))
            _box(Vector3(0.07,0.58,0.09),Vector3(CX,FLOOR+0.81,ez)+radial*0.67,wood,Basis(Vector3.UP,yaw))
            if j%5==0:
                _box(Vector3(0.06,0.31,0.44),Vector3(CX,FLOOR+0.21,ez)+radial*0.93,dark,Basis(Vector3.UP,yaw))
    for i in range(5):
        _box(Vector3(0.50,0.035,0.16),Vector3(CX,5.44,z-1.1+float(i)*0.55),dark)
        _batch("sphere",glow,Transform3D(Basis.from_scale(Vector3(0.14,0.035,0.14)),Vector3(CX,5.41,z-1.1+float(i)*0.55)))


func _stairs(direction: float,start_z: float) -> void:
    var rise := 0.17
    var run := 0.32
    var count := 20
    var yellow := _mat(Color("#e9bd3e"))
    for side in [-1.0,1.0]:
        var x: float=CX+side*2.65
        for i in range(count):
            var height := float(i+1)*rise
            var z := start_z+direction*(float(i)+0.5)*run
            _box(Vector3(3.35,height,run+0.005),Vector3(x,FLOOR+height*0.5,z),stone)
            _box(Vector3(3.35,0.012,0.05),Vector3(x,FLOOR+height+0.008,z-direction*run*0.42),yellow if i in [0,9,19] else steel)
        for rail_side in [-1.0,1.0]:
            var rx: float=x+rail_side*1.58
            _bar(Vector3(rx,FLOOR+0.92,start_z),Vector3(rx,FLOOR+4.32,start_z+direction*6.4),0.028,steel)
            for i in range(6):
                var u := float(i)/5.0
                _cylinder(0.021,0.92,Vector3(rx,FLOOR+3.4*u+0.46,start_z+direction*6.4*u),steel)
    var end_z := start_z+direction*6.4
    _box(Vector3(9.65,0.20,4.0),Vector3(CX,FLOOR+3.30,end_z+direction*2.0),stone)
    _box(Vector3(1.70,3.4,6.5),Vector3(CX,FLOOR+1.7,start_z+direction*3.3),_marble_material())
    _box(Vector3(1.05,2.15,0.05),Vector3(CX,FLOOR+1.075,start_z-direction*0.025),white)
    _box(Vector3(0.045,0.20,0.06),Vector3(CX+0.36,FLOOR+1.03,start_z-direction*0.065),dark)
    _cylinder(0.21,4.25,Vector3(CX,FLOOR+2.125,start_z-direction*1.25),steel)
    for side in [-1.0,1.0]:
        _box(Vector3(3.4,0.03,0.30),Vector3(CX+side*2.65,FLOOR+0.018,start_z-direction*0.26),yellow)


func _bar(a: Vector3,b: Vector3,radius: float,material: Material) -> void:
    var basis := Basis.IDENTITY
    var delta := b-a
    var axis := Vector3.UP.cross(delta.normalized())
    if axis.length_squared() > 0.00001: basis=Basis(axis.normalized(),Vector3.UP.angle_to(delta.normalized()))
    _batch("cylinder",material,Transform3D(basis*Basis.from_scale(Vector3(radius*2,delta.length(),radius*2)),(a+b)*0.5))

func _label(text: String,pos: Vector3,pixel: float,color: Color) -> Label3D:
    var label := Label3D.new()
    label.text=text; label.position=pos
    label.font_size=64; label.pixel_size=pixel
    label.modulate=color
    label.outline_size=0
    label.no_depth_test=false
    label.shaded=false
    add_child(label)
    return label

func _navigation() -> void:
    var route := preload("res://assets/station/photo_reference/route.png")
    var no_boarding := preload("res://assets/station/photo_reference/no_boarding.png")
    for z in [5.0,28.0,51.0,73.0]:
        _hanging_board(no_boarding,Vector3(CX+2.45,4.47,z),Vector2(2.85,0.61))
        _hanging_board(route,Vector3(CX-2.45,4.47,z),Vector2(3.35,0.78))
    _hanging_board(preload("res://assets/station/photo_reference/exit_a.png"),Vector3(CX,4.55,10.0),Vector2(3.65,0.76))
    _hanging_board(preload("res://assets/station/photo_reference/exit_b.png"),Vector3(CX,4.55,76.5),Vector2(3.65,0.76))

func _hanging_board(texture: Texture2D,pos: Vector3,size: Vector2) -> void:
    _box(Vector3(size.x+0.09,size.y+0.09,0.10),pos,steel)
    for face in [-1.0,1.0]:
        _picture(texture,size,pos+Vector3(0,0,face*0.057),0.0 if face>0.0 else PI)
    for x in [-size.x*0.47,size.x*0.47]:
        _cylinder(0.025,0.85,pos+Vector3(x,size.y*0.5+0.425,0),steel)
    for z in [-0.15,0.15]:
        _box(Vector3(size.x*0.89,0.035,0.085),pos+Vector3(0,size.y*0.5+0.16,z),glow)

func _picture(texture: Texture2D,size: Vector2,pos: Vector3,yaw: float) -> MeshInstance3D:
    var material := StandardMaterial3D.new()
    material.albedo_texture=texture
    material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    var quad := QuadMesh.new()
    quad.size=size; quad.material=material
    var image := MeshInstance3D.new()
    image.mesh=quad; image.position=pos; image.rotation.y=yaw
    image.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(image)
    return image

func _lift() -> void:
    var z := 80.8
    var metal := _mat(Color("#a8afb1"),0.83,0.32)
    var yellow := _mat(Color("#d9a939"),0.25,0.36)
    _box(Vector3(2.0,5.9,2.30),Vector3(CX,FLOOR+2.95,z),metal)
    for face in [-1.0,1.0]:
        var fz: float=z+face*1.17
        _box(Vector3(1.35,2.32,0.045),Vector3(CX,FLOOR+1.16,fz),dark)
        for side in [-1.0,1.0]:
            _box(Vector3(0.60,2.17,0.035),Vector3(CX+side*0.31,FLOOR+1.085,fz+face*0.027),metal)
            _box(Vector3(0.14,2.37,0.18),Vector3(CX+side*0.76,FLOOR+1.185,fz+face*0.065),yellow)
        _box(Vector3(1.66,0.18,0.18),Vector3(CX,FLOOR+2.41,fz+face*0.065),yellow)
        _box(Vector3(1.36,0.025,0.18),Vector3(CX,FLOOR+0.018,fz+face*0.06),steel)
        var icon := _label("♿",Vector3(CX,FLOOR+2.43,fz+face*0.17),0.0038,Color("#2066a6"))
        icon.rotation.y=0.0 if face>0.0 else PI
        _box(Vector3(0.10,0.28,0.045),Vector3(CX+0.91,FLOOR+1.15,fz+face*0.06),dark)
        _batch("sphere",glow,Transform3D(Basis.from_scale(Vector3.ONE*0.035),Vector3(CX+0.91,FLOOR+1.17,fz+face*0.10)))
    for y in [FLOOR+0.12,FLOOR+2.65,FLOOR+4.25]:
        for side in [-1.0,1.0]:
            _box(Vector3(0.018,0.012,2.30),Vector3(CX+side*1.007,y,z),dark)

var _screens: Array[MeshInstance3D] = []
var _ad_time := 0.0
var _ad_index := 0
var _ads: Array[Texture2D] = [preload("res://assets/station/photo_reference/ad_city.png"),preload("res://assets/station/photo_reference/ad_theatre.png"),preload("res://assets/station/photo_reference/ad_travel.png")]

func _advertising() -> void:
    for z in [12.0,34.5,57.0,76.0]:
        for side in [-1.0,1.0]:
            var x: float=CX+side*3.6
            _box(Vector3(1.54,0.90,0.12),Vector3(x,4.28,z),dark)
            _cylinder(0.025,0.78,Vector3(x,5.10,z),steel)
            for face in [-1.0,1.0]:
                var screen := _picture(_ads[_screens.size()%3],Vector2(1.43,0.804),Vector3(x,4.28,z+face*0.066),0.0 if face>0 else PI)
                screen.name="AdvertisingScreen"
                _screens.append(screen)

func _process(delta: float) -> void:
    _ad_time+=delta
    if _ad_time<9.0: return
    _ad_time=0.0; _ad_index=(_ad_index+1)%_ads.size()
    for i in range(_screens.size()):
        var material := (_screens[i].mesh as QuadMesh).material as StandardMaterial3D
        material.albedo_texture=_ads[(_ad_index+i)%_ads.size()]

func _wood_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float grain=sin(p.y*180.0+sin(p.z*12.0+p.x*27.0)*2.0)*0.5+0.5;ALBEDO=mix(vec3(0.39,0.22,0.09),vec3(0.68,0.44,0.21),grain*0.45+0.35);ROUGHNESS=0.34;}
"""
    var material := ShaderMaterial.new(); material.shader=shader
    return material

func _marble_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
vec2 q=p.zy; float warp=sin(q.x*2.3+sin(q.y*3.7))+0.4*sin(q.x*9.0-q.y*4.0);
float v=pow(1.0-abs(sin(q.x*4.3+q.y*2.7+warp*2.2)),17.0);
float fine=pow(1.0-abs(sin(q.x*17.0-q.y*9.0+warp*4.0)),27.0);
vec2 tile=fract(q/vec2(1.25,0.64)); float joint=1.0-step(0.004,min(min(tile.x,1.0-tile.x),min(tile.y,1.0-tile.y)));
ALBEDO=vec3(0.78,0.77,0.71)-vec3(v*0.18+fine*0.06+joint*0.07);ROUGHNESS=0.28;SPECULAR=0.65;
}
"""
    var material := ShaderMaterial.new(); material.shader=shader
    return material

func _floor_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
uniform sampler2D granite : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
float x=abs(p.x+5.37); float z=p.z; float central=1.0-step(1.23,x);
float panel=step(0.0,mod(z-2.0,18.0)-13.5)*(1.0-step(2.15,x));
float endzone=step(z,0.0)+step(78.0,z);float zig=1.0-step(0.63,abs(mod(z+x*0.75,2.7)-1.35));
float darkmask=max(central,panel);if(endzone>0.0){darkmask=max(central,zig);}
vec3 grain=texture(granite,p.xz/1.28).rgb;
vec3 light=vec3(0.78,0.78,0.71);vec3 dark=vec3(0.17,0.19,0.20);
vec2 tile=fract(p.xz/0.62);float joint=1.0-step(0.0017,min(min(tile.x,1.0-tile.x),min(tile.y,1.0-tile.y)));
ALBEDO=mix(light,dark,darkmask)*(0.57+grain*0.55)-vec3(joint*0.035);ROUGHNESS=0.40;SPECULAR=0.6;
}
"""
    var material := ShaderMaterial.new(); material.shader=shader
    material.set_shader_parameter("granite",preload("res://assets/station/uruchye_granite.png"))
    return material


func _granite(tint: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_texture=preload("res://assets/station/uruchye_granite.png")
    material.albedo_color=tint
    material.roughness=0.54
    material.uv1_triplanar=true
    material.uv1_world_triplanar=true
    material.uv1_scale=Vector3.ONE/1.28
    material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return material

func _tactile_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
varying vec2 ground;
void vertex(){ ground=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment(){
    vec2 cell=fract(ground/0.05)-0.5;
    float r=length(cell);
    float bump=1.0-smoothstep(0.14,0.20,r);
    float rim=smoothstep(0.18,0.21,r)*(1.0-smoothstep(0.21,0.25,r));
    ALBEDO=vec3(0.86,0.62,0.075)+vec3(bump*0.075)-vec3(rim*0.08);
    ROUGHNESS=0.78;
}
"""
    var material := ShaderMaterial.new()
    material.shader=shader
    return material

func _station_ends() -> void:
    # Solid end facades mask the round tunnel lining and the space above it.
    # Keep both train envelopes empty: the arch continues behind a short box throat.
    var lining := _mat(Color("#7b8080"),0.0,0.88)
    var facing := _stone(Color("#d0d2cc"),true)
    var cobalt := _mat(Color("#244c99"),0.22,0.4)
    var black := _mat(Color("#101519"))
    var track_centers := PackedFloat32Array([-11.732,0.992])
    var half_width := 1.675
    var portal_top := 4.55
    var left := CX-9.70
    var right := CX+9.70
    for direction in [-1.0,1.0]:
        var end_z: float = -19.888 if direction < 0.0 else Z1
        var face_z: float = end_z+direction*0.25
        _box(Vector3(right-left,7.75-portal_top,0.50),Vector3(CX,(7.75+portal_top)*0.5,face_z),white)
        var segments := [
            Vector2(left,track_centers[0]-half_width),
            Vector2(track_centers[0]+half_width,track_centers[1]-half_width),
            Vector2(track_centers[1]+half_width,right)
        ]
        for segment in segments:
            var a: float = segment.x
            var b: float = segment.y
            var x := (a+b)*0.5
            _box(Vector3(b-a,portal_top+0.40,0.50),Vector3(x,(portal_top-0.40)*0.5,face_z),white)
            var inside_z: float = end_z-direction*0.012
            _box(Vector3(b-a,1.0,0.025),Vector3(x,0.5,inside_z),dark)
            _box(Vector3(b-a,0.30,0.028),Vector3(x,1.15,inside_z),cobalt)
            _box(Vector3(b-a,0.37,0.030),Vector3(x,1.49,inside_z),blue)
            _box(Vector3(b-a,2.85,0.032),Vector3(x,3.105,inside_z),facing)
        for track_x in track_centers:
            var throat_z: float = end_z+direction*3.20
            for side in [-1.0,1.0]:
                var x: float = track_x+side*(half_width+0.09)
                _box(Vector3(0.18,portal_top+0.30,6.40),Vector3(x,(portal_top-0.30)*0.5,throat_z),lining)
            _box(Vector3(half_width*2.0+0.36,0.18,6.40),Vector3(track_x,portal_top+0.09,throat_z),lining)
            # Only the secondary non-playable track needs rails past its Base endpoint.
            if track_x < -5.0:
                for rail_side in [-1.0,1.0]:
                    var rail_x: float = track_x+rail_side*0.8075
                    _box(Vector3(0.095,0.16,6.40),Vector3(rail_x,-0.08,throat_z),steel)
                for i in range(11):
                    var tie_z: float = end_z+direction*(float(i)+0.5)*0.58
                    _box(Vector3(2.65,0.12,0.24),Vector3(track_x,-0.22,tie_z),dark)
                _box(Vector3(half_width*2.0,portal_top+0.30,0.12),Vector3(track_x,(portal_top-0.30)*0.5,end_z+direction*6.45),black)
