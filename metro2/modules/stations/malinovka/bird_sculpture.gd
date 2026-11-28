extends Node3D
## Small solid bronze bird sculptures. Local +Z is the beak direction.
const ART := "res://modules/stations/malinovka/art/"
@export var variant := 0
static var profiles: Dictionary={}
static var bronze: StandardMaterial3D
static var feather_bronze: StandardMaterial3D
static var eye_material: StandardMaterial3D
static var wing_meshes: Dictionary={}

func _ready() -> void:
    if profiles.is_empty():profiles=JSON.parse_string(FileAccess.get_file_as_string(ART+"bird_profiles.json"))
    if bronze==null:
        bronze=_material(Color("#66523a"),0.83,0.32)
        feather_bronze=_material(Color("#4c3c29"),0.80,0.43)
        eye_material=_material(Color("#131613"),0.30,0.23)
    _ellipsoid("TaperedBody",Vector3(float(profiles.body_width_m),0.085,float(profiles.body_length_m)),Vector3.ZERO,bronze)
    _ellipsoid("BronzeBreast",Vector3(0.065,0.065,0.14),Vector3(0,-0.021,0.04),feather_bronze)
    var r=float(profiles.head_radius_m)
    _ellipsoid("Head",Vector3(r*2,r*1.82,r*2.1),Vector3(0,0.035,0.119),bronze)
    _rod("PointedBeak",Vector3(0,0.035,0.148),Vector3(0,0.029,0.148+float(profiles.beak_length_m)),0.013,0.001,bronze)
    for side in [-1.0,1.0]:
        _ellipsoid("Eye",Vector3(0.007,0.007,0.007),Vector3(side*0.029,0.049,0.135),eye_material)
        var key=str(variant)+str(side)
        if not wing_meshes.has(key):wing_meshes[key]=_wing(side)
        var wing=MeshInstance3D.new();wing.name="SweptWingLeft" if side<0 else "SweptWingRight"
        wing.mesh=wing_meshes[key];add_child(wing)
        _feathers(side)
        _tail(side)
        var foot=Vector3(side*0.026,-0.074,0.009)
        _rod("Leg",Vector3(side*0.026,-0.026,0.03),foot,0.006,0.004,feather_bronze)
        for offset in [-1.0,0.0,1.0]:_rod("Toe",foot,foot+Vector3(float(offset)*0.012,-0.003,0.032),0.003,0.0015,feather_bronze)

func _material(colour: Color,metallic: float,roughness: float) -> StandardMaterial3D:
    var m=StandardMaterial3D.new();m.albedo_color=colour;m.metallic=metallic;m.roughness=roughness;return m

func _ellipsoid(label: String,size: Vector3,p: Vector3,mat: Material) -> void:
    var mesh=SphereMesh.new();mesh.radius=0.5;mesh.height=1;mesh.radial_segments=24;mesh.rings=12;mesh.material=mat
    var node=MeshInstance3D.new();node.name=label;node.mesh=mesh;node.position=p;node.scale=size;add_child(node)

func _rod(label: String,a: Vector3,b: Vector3,bottom: float,top: float,mat: Material) -> void:
    var mesh=CylinderMesh.new();mesh.bottom_radius=bottom;mesh.top_radius=top;mesh.height=a.distance_to(b);mesh.radial_segments=10;mesh.material=mat
    var node=MeshInstance3D.new();node.name=label;node.mesh=mesh;node.position=(a+b)*0.5
    var direction=(b-a).normalized();var axis=Vector3.UP.cross(direction)
    if axis.length_squared()>0.000001:node.basis=Basis(axis.normalized(),Vector3.UP.angle_to(direction))
    elif direction.y<0:node.basis=Basis(Vector3.RIGHT,PI)
    add_child(node)

func _face(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
    var normal=(b-a).cross(c-a).normalized()
    for p in [a,c,b]:st.set_normal(normal);st.set_uv(Vector2(p.x,p.z));st.add_vertex(p)

func _wing(side: float) -> ArrayMesh:
    var spec: Dictionary=profiles.variants[variant%profiles.variants.size()]
    var span=float(profiles.wing_halfspan_m)*(0.68 if variant==2 else 1.0)
    var points: Array[Vector3]=[]
    for value in profiles.wing_outline_normalized:
        var u=float(value[0]);var v=float(value[1])
        points.append(Vector3(side*u*span,0.016+sin(u*PI*0.6)*float(spec.wing_lift_m),v*0.22-u*float(spec.wing_sweep_m)))
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var centre=Vector3(side*span*0.40,0.049+float(spec.wing_lift_m)*0.36,-0.015)
    for i in range(points.size()):
        var a: Vector3=points[i];var b: Vector3=points[(i+1)%points.size()]
        _face(st,centre,a,b);_face(st,centre-Vector3(0,0.019,0),b-Vector3(0,0.012,0),a-Vector3(0,0.012,0))
        _face(st,a,a-Vector3(0,0.012,0),b);_face(st,b,a-Vector3(0,0.012,0),b-Vector3(0,0.012,0))
    st.index();var mesh=st.commit();mesh.surface_set_material(0,bronze)
    return mesh

func _feathers(side: float) -> void:
    var spec: Dictionary=profiles.variants[variant%profiles.variants.size()]
    var span=float(profiles.wing_halfspan_m)*(0.68 if variant==2 else 1.0)
    # Narrow cast feather ridges remain physical bronze parts, not a texture.
    for i in range(5):
        var u=0.28+float(i)*0.115
        _rod("WingFeather",Vector3(side*u*span,0.028+sin(u*PI*0.6)*float(spec.wing_lift_m),0.008-u*float(spec.wing_sweep_m)),Vector3(side*minf(0.96,u+0.15)*span,0.023+sin(minf(0.96,u+0.15)*PI*0.6)*float(spec.wing_lift_m),-0.058-u*float(spec.wing_sweep_m)),0.0027,0.0015,feather_bronze)


func _tail(side: float) -> void:
    var length=float(profiles.forked_tail_length_m)
    var points=[Vector3(side*0.010,0.002,-0.08),Vector3(side*0.057,-0.007,-0.08-length),Vector3(side*0.003,-0.012,-0.155)]
    var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    _face(st,points[0],points[1],points[2]);_face(st,points[2]-Vector3(0,0.008,0),points[1]-Vector3(0,0.008,0),points[0]-Vector3(0,0.008,0))
    for i in range(3):
        var a: Vector3=points[i];var b: Vector3=points[(i+1)%3]
        _face(st,a,a-Vector3(0,0.008,0),b);_face(st,b,a-Vector3(0,0.008,0),b-Vector3(0,0.008,0))
    var mesh=st.commit();mesh.surface_set_material(0,feather_bronze)
    var node=MeshInstance3D.new();node.name="ForkedTail";node.mesh=mesh;add_child(node)
