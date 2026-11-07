extends Node3D
## Uruchye: photo-based medium detail fitted to the retained 10 m Station Base.
## References: Commons Minsk-Metro-Uruch'e-05.jpg; Wikimapia 1212345/1215435;
## bymetro.narod.ru/estet/uruchye.htm. Spacing is fitted, not a measured survey.
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
    blue = _mat(Color("#9fc6dd"),0.24,0.48)
    steel = _mat(Color("#b9c1c6"),0.80,0.26)
    dark = _mat(Color("#29333c"),0.15,0.5)
    stone = _stone(Color("#b5b6ae"),false)
    glow = _mat(Color("#fff5dc"),0.0,0.6,Color(1.0,0.94,0.79))
    wood = _mat(Color("#875532"),0.0,0.45)
    _floor_and_walls()
    _columns_and_ceiling()
    _stairs(1.0,Z1-18.0)
    _stairs(-1.0,Z0+18.0)
    _navigation()
    _flush()

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
    var base := get_parent().get_node("IslandPlatform") as MeshInstance3D
    base.material_override=_stone(Color("#a9aaa4"),false)
    var burgundy := _mat(Color("#68514b"),0.0,0.45)
    var granite := _stone(Color("#40464e"),false)
    var marble := _stone(Color("#d0d2cc"),true)
    var cobalt := _mat(Color("#244c99"),0.22,0.4)
    for name in ["SafetyEdgeTrack1","SafetyEdgeTrack2"]:
        (get_parent().get_node(name) as MeshInstance3D).visible=false
    for x in [-0.57,-10.17]:
        _box(Vector3(0.40,0.012,105),Vector3(x,FLOOR+0.006,39.612),stone)
    for x in [-0.93,-9.81]:
        _box(Vector3(0.11,0.014,105),Vector3(x,FLOOR+0.007,39.612),burgundy)
    for i in range(8):
        var z := 7.2+float(i)*9.2
        _box(Vector3(3.1,0.008,3.1),Vector3(CX,FLOOR+0.006,z),granite,Basis(Vector3.UP,PI/4.0))
        _triangle(Vector3(CX-1.55,FLOOR+0.012,z),Vector3(CX,FLOOR+0.012,z-1.55),Vector3(CX+1.55,FLOOR+0.012,z),stone)
    for side in [-1.0,1.0]:
        var wall_x := CX+side*8.85
        _box(Vector3(0.28,7.6,112),Vector3(wall_x,3.5,36.112),white)
        _box(Vector3(0.03,1.0,112),Vector3(wall_x-side*0.16,0.5,36.112),granite)
        _box(Vector3(0.035,0.30,112),Vector3(wall_x-side*0.18,1.15,36.112),cobalt)
        _box(Vector3(0.04,0.37,112),Vector3(wall_x-side*0.19,1.49,36.112),blue)
        for i in range(54):
            var z := Z0+float(i)*2.0
            _box(Vector3(0.04,2.0,1.98),Vector3(wall_x-side*0.19,2.72,z+1.0),marble)
        for y in [1.70,2.40,3.75]:
            _box(Vector3(0.045,0.027,112),Vector3(wall_x-side*0.22,y,36.112),steel)
        for z in [17.0,62.0]:
            var title := _label("УРУЧЬЕ",Vector3(wall_x-side*0.23,2.82,z),0.014,Color("#969da2"))
            title.rotation.y = -side*PI/2.0
            # Blue water motif, based on the wall sign's horizontal wave.
            for j in range(24):
                var zz := z-3.2+float(j)*0.27
                var yy := 2.45+0.10*sin(float(j)*0.31)
                _box(Vector3(0.025,0.035,0.28),Vector3(wall_x-side*0.25,yy,zz),cobalt)

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
    var navy := _mat(Color("#254b68"),0.3,0.65)
    var ochre := _mat(Color("#a2945b"),0.15,0.7)
    for i in range(8):
        var z := 7.2+float(i)*9.2
        _cylinder(0.61,4.55,Vector3(CX,FLOOR+2.275,z),blue)
        _cylinder(0.64,0.16,Vector3(CX,FLOOR+0.08,z),steel)
        _cylinder(0.63,0.40,Vector3(CX,5.52,z),steel)
        _ring_seat(z)
        # Photographed dark ventilation cap at the column head.
        _cylinder(0.65,0.46,Vector3(CX,5.37,z),dark)
        for y in [5.20,5.29,5.38,5.47]:
            _cylinder(0.66,0.025,Vector3(CX,y,z),steel)
    # Opaque roof and light side bays; the blue central strip has a shallow wave.
    _box(Vector3(17.8,0.18,112),Vector3(CX,7.65,36.112),white)
    for x in [CX-6.3,CX+6.3]:
        _box(Vector3(5.1,0.12,105),Vector3(x,5.96,39.612),white)
    for i in range(525):
        var z := Z0+float(i)*0.20+0.1
        var height := 5.64+0.18*cos((z-Z0)/105.0*TAU)
        if z > Z0+13 and z < Z1-13:
            _box(Vector3(4.6,0.085,0.15),Vector3(CX,height,z),blue)
        for side in [-1.0,1.0]:
            _box(Vector3(2.4,0.045,0.12),Vector3(CX+side*3.5,5.87,z),white)
    # Existing colour distinction at the two double-height vestibules.
    for end in [0,1]:
        var z: float = Z0+6.0 if end == 0 else Z1-6.0
        var color: Material = navy if end == 0 else ochre
        for i in range(25):
            _box(Vector3(9.5,0.055,0.035),Vector3(CX,7.30,z-6+float(i)*0.5),color)
        for i in range(20):
            _box(Vector3(0.035,0.055,12),Vector3(CX-4.75+float(i)*0.5,7.30,z),color)
    for side in [-1.0,1.0]:
        var x := CX+side*4.78
        _box(Vector3(0.24,0.09,105),Vector3(x,5.50,39.612),steel)
        for i in range(53):
            var z := Z0+1.0+float(i)*1.98
            _batch("sphere",glow,Transform3D(Basis.from_scale(Vector3(0.30,0.30,0.30)),Vector3(x,5.70,z)))
            _cylinder(0.10,0.09,Vector3(x,5.53,z),steel)
    for i in range(27):
        var z := Z0+2.0+float(i)*3.8
        for x in [CX-2.65,CX+2.65]:
            _box(Vector3(1.55,0.065,0.16),Vector3(x,5.80,z),steel)
            _box(Vector3(1.45,0.025,0.105),Vector3(x,5.75,z),glow)
    # Reuse the Base's six light sources instead of adding dozens of lights.
    for i in range(6):
        var light := get_parent().get_node("PlatformLight%02d" % (i+1)) as OmniLight3D
        light.position.x=CX+(-1.6 if i%2 == 0 else 1.6)
        light.position.y=4.9
        light.light_color=Color(1.0,0.96,0.87)
        light.light_energy=2.1
        light.omni_range=17.5
        light.omni_attenuation=0.8

func _ring_seat(z: float) -> void:
    for i in range(32):
        var angle := float(i)*TAU/32.0
        var pos := Vector3(CX+sin(angle)*0.94,FLOOR+0.47,z+cos(angle)*0.94)
        _box(Vector3(0.20,0.13,0.57),pos,wood,Basis(Vector3.UP,angle))
        _box(Vector3(0.11,0.62,0.10),Vector3(CX+sin(angle)*0.67,FLOOR+0.75,z+cos(angle)*0.67),wood,Basis(Vector3.UP,angle))
        if i%8 == 0: _cylinder(0.04,0.39,Vector3(pos.x,FLOOR+0.20,pos.z),steel)

func _stairs(direction: float, start_z: float) -> void:
    var width := 3.8
    var rise := 0.18
    var run := 0.38
    var count := 18
    for i in range(count):
        var height := float(i+1)*rise
        var z := start_z+direction*(float(i)+0.5)*run
        _box(Vector3(width,height,run+0.005),Vector3(CX,FLOOR+height*0.5,z),stone)
        _box(Vector3(width,0.012,0.045),Vector3(CX,FLOOR+height+0.007,z-direction*run*0.4),steel)
    var end_z := start_z+direction*float(count)*run
    var landing_z := end_z+direction*2.0
    _box(Vector3(9.6,0.22,4.0),Vector3(CX,FLOOR+3.24-0.11,landing_z),stone)
    var glass := _mat(Color(0.29,0.40,0.46,0.32),0.1,0.25)
    glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    glass.cull_mode=BaseMaterial3D.CULL_DISABLED
    for side in [-1.0,1.0]:
        var x := CX+side*2.02
        var mid := Vector3(x,FLOOR+2.15,start_z+direction*3.42)
        _box(Vector3(0.035,0.80,7.56),mid,glass,Basis(Vector3.RIGHT,-direction*atan(rise/run)))
        for i in range(7):
            var u := float(i)/6.0
            _cylinder(0.025,1.02,Vector3(x,FLOOR+3.24*u+0.51,start_z+direction*6.84*u),steel)
        _bar(Vector3(x,FLOOR+1.0,start_z),Vector3(x,FLOOR+4.24,end_z),0.035,steel)
    # Only the visible gallery: no invented city exits or underground network.
    _box(Vector3(9.5,0.16,0.18),Vector3(CX,FLOOR+4.31,end_z+direction*3.7),steel)
    _box(Vector3(9.5,0.9,0.025),Vector3(CX,FLOOR+3.75,end_z+direction*3.7),glass)
    var sign := _label("ВЫХОД  ↑",Vector3(CX,FLOOR+5.12,end_z),0.008,Color.WHITE)
    sign.rotation.y=PI if direction > 0 else 0.0
    _box(Vector3(2.5,0.58,0.08),sign.position+Vector3(0,0,direction*0.045),_mat(Color("#1b436d")))

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
    var sign_mat := _mat(Color("#1d436e"),0.15,0.6)
    for z in [19.0,59.0]:
        _box(Vector3(5.4,0.62,0.07),Vector3(CX,4.68,z),sign_mat)
        for face in [-1.0,1.0]:
            var sign := _label("УРУЧЬЕ   •   ВЫХОД  ↑",Vector3(CX,4.68,z+face*0.043),0.0058,Color.WHITE)
            sign.rotation.y=PI if face < 0 else 0.0
        for x in [CX-2.4,CX+2.4]:
            _cylinder(0.015,1.0,Vector3(x,5.4,z),steel)
