extends "res://modules/stations/mihalovo/station_base.gd"
## Local construction helpers, without a dependency on any other station module.
const CX := -5.37
const FY := 1.1805
const ZA := -12.888
const ZB := 92.112
const MID := 39.612
var construction_transform := Transform3D.IDENTITY
var batches: Dictionary = {}
var surfaces: Dictionary = {}
var white: StandardMaterial3D
var metal: StandardMaterial3D
var brass: StandardMaterial3D
var black: StandardMaterial3D
var marble: ShaderMaterial
var granite: Material
var redstone: ShaderMaterial
var glow: StandardMaterial3D
var timber: ShaderMaterial

func begin_station() -> void:
    white=_material(Color("#eeeee8"),0.0,0.75)
    metal=_material(Color("#abb0b0"),0.78,0.30)
    brass=_material(Color("#9c7d38"),0.78,0.32)
    black=_material(Color("#171b1a"),0.1,0.58)
    marble=stone(Color("#c9c7b9"),true)
    granite=stone(Color("#252824"),false)
    redstone=stone(Color("#75493c"),false)
    timber=wood_material()
    glow=_material(Color("#f0f3e9"),0.0,0.6)
    glow.emission_enabled=true
    glow.emission=Color(0.91,0.96,0.88)
    glow.emission_energy_multiplier=1.25
    for key in ["SafetyEdgeTrack1","SafetyEdgeTrack2","TrainStopMarker"]:
        (get_node(key) as MeshInstance3D).hide()
    for child in get_children():
        if child is OmniLight3D:
            child.position.y=5.4
            child.light_color=Color(1.0,0.97,0.90)
            child.light_energy=1.65
            child.omni_range=19.0
            child.omni_attenuation=0.65

func stone(tint: Color,veined: bool) -> ShaderMaterial:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
uniform vec4 tint : source_color;uniform bool veined=false;
varying vec3 p;varying vec3 n;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;n=abs(MODEL_NORMAL_MATRIX*NORMAL);}
float h(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 q){vec2 i=floor(q),f=fract(q);f=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 q){return noise(q)*0.55+noise(q*2.03)*0.26+noise(q*4.01)*0.13+noise(q*8.03)*0.06;}
void fragment(){
vec2 q=n.x>0.5?p.zy:n.y>0.5?p.xz:p.xy;
vec2 slab=floor(q/vec2(1.20,0.62));float variation=h(slab)*0.05;
vec2 warped=q+vec2(fbm(q*1.7),fbm(q.yx*2.3))*0.7;
float vein=pow(1.0-abs(sin(warped.x*5.4+warped.y*2.7+fbm(q*4.2)*5.0)),25.0);
float crystal=noise(q*95.0);float aggregate=fbm(q*24.0);
vec2 tile=fract(q/vec2(1.20,0.62));float joint=1.0-smoothstep(0.001,0.004,min(min(tile.x,1.0-tile.x),min(tile.y,1.0-tile.y)));
vec3 marble=tint.rgb*(0.95+variation)-vec3(vein*0.13)+vec3((fbm(q*5.0)-0.5)*0.07);
vec3 granite=tint.rgb*(0.72+aggregate*0.48)+vec3(pow(crystal,7.0)*0.13)-vec3(pow(1.0-crystal,7.0)*0.09);
ALBEDO=(veined?marble:granite)-vec3(joint*0.035);ROUGHNESS=(veined?0.27:0.40)+crystal*0.09;SPECULAR=0.58;
}
"""
    var m := ShaderMaterial.new()
    m.shader=shader
    m.set_shader_parameter("tint",tint)
    m.set_shader_parameter("veined",veined)
    return m

func box(size: Vector3,p: Vector3,mat: Material,basis: Basis=Basis.IDENTITY) -> void:
    batch("box",mat,Transform3D(basis*Basis.from_scale(size),p))

func cylinder(radius: float,height: float,p: Vector3,mat: Material) -> void:
    batch("cylinder",mat,Transform3D(Basis.from_scale(Vector3(radius*2,height,radius*2)),p))

func sphere(size: Vector3,p: Vector3,mat: Material) -> void:
    batch("sphere",mat,Transform3D(Basis.from_scale(size),p))

func batch(kind: String,mat: Material,pose: Transform3D) -> void:
    pose=construction_transform*pose
    var key := kind+str(mat.get_instance_id())
    if not batches.has(key):batches[key]={"kind":kind,"mat":mat,"poses":[]}
    batches[key].poses.append(pose)

func rod(a: Vector3,b: Vector3,r: float,mat: Material) -> void:
    var direction := (b-a).normalized()
    var axis := Vector3.UP.cross(direction)
    var basis := Basis.IDENTITY
    if axis.length_squared()>0.00001:basis=Basis(axis.normalized(),Vector3.UP.angle_to(direction))
    batch("cylinder",mat,Transform3D(basis*Basis.from_scale(Vector3(r*2,a.distance_to(b),r*2)),(a+b)*0.5))

func profile(points: Array[Vector2],z0: float,z1: float,mat: Material) -> void:
    var key := str(mat.get_instance_id())
    if not surfaces.has(key):
        var new_surface := SurfaceTool.new()
        new_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        surfaces[key]={"surface":new_surface,"mat":mat}
    var st: SurfaceTool=surfaces[key].surface
    for i in range(points.size()-1):
        var a: Vector2=points[i]
        var b: Vector2=points[i+1]
        quad(Vector3(a.x,a.y,z0),Vector3(b.x,b.y,z0),Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z1),mat,Vector3(CX-(a.x+b.x)*0.5,-1,0))

func flush() -> void:
    for key in batches:
        var data: Dictionary=batches[key]
        var mesh: Mesh
        if data.has("mesh"):
            mesh=data.mesh.duplicate()
            mesh.surface_set_material(0,data.mat)
        elif data.kind=="cylinder":
            var c := CylinderMesh.new()
            c.top_radius=0.5;c.bottom_radius=0.5;c.height=1.0;c.radial_segments=8
            mesh=c
        elif data.kind=="sphere":
            var s := SphereMesh.new()
            s.radius=0.5;s.height=1.0;s.radial_segments=12;s.rings=6
            mesh=s
        else:
            var b := BoxMesh.new()
            b.size=Vector3.ONE
            mesh=b
        if mesh is PrimitiveMesh:(mesh as PrimitiveMesh).material=data.mat
        var mm := MultiMesh.new()
        mm.transform_format=MultiMesh.TRANSFORM_3D
        mm.mesh=mesh;mm.instance_count=data.poses.size()
        for i in range(mm.instance_count):mm.set_instance_transform(i,data.poses[i])
        var n := MultiMeshInstance3D.new()
        n.name="Repeated"+str(data.kind)
        n.multimesh=mm
        add_child(n)
    for key in surfaces:
        var data: Dictionary=surfaces[key]
        var st: SurfaceTool=data.surface
        # Normals were assigned while constructing the interior faces.
        var mesh := st.commit()
        var mat: Material=data.mat.duplicate()
        if mat is BaseMaterial3D:(mat as BaseMaterial3D).cull_mode=BaseMaterial3D.CULL_DISABLED
        mesh.surface_set_material(0,mat)
        var n := MeshInstance3D.new()
        n.name="VaultSections";n.mesh=mesh
        add_child(n)
    batches.clear();surfaces.clear()

func picture(file: String,size: Vector2,p: Vector3,yaw: float,cutout: bool=false) -> void:
    var m := StandardMaterial3D.new()
    m.albedo_texture=load(get_script().resource_path.get_base_dir()+"/art/"+file)
    m.roughness=0.55
    m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    if cutout:m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    else:m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    var q := QuadMesh.new()
    q.size=size;q.material=m
    var n := MeshInstance3D.new()
    n.mesh=q;n.position=p;n.rotation.y=yaw;n.transform=construction_transform*n.transform
    n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(n)

func board(file: String,p: Vector3,size: Vector2) -> void:
    box(Vector3(size.x+0.09,size.y+0.08,0.09),p,metal)
    for side in [-1.0,1.0]:
        picture(file,size,p+Vector3(0,0,side*0.052),0.0 if side>0.0 else PI)
    box(Vector3(0.22,0.72,0.07),p+Vector3(0,size.y*0.5+0.36,0),black)

func extrusion(points: PackedVector2Array,z0: float,z1: float,mat: Material) -> void:
    for i in range(points.size()):
        var a: Vector2=points[i]
        var b: Vector2=points[(i+1)%points.size()]
        quad(Vector3(a.x,a.y,z0),Vector3(b.x,b.y,z0),Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z1),mat)
    var indices := Geometry2D.triangulate_polygon(points)
    for face in [-1.0,1.0]:
        var z: float=z0 if face<0.0 else z1
        for i in range(0,indices.size(),3):
            var a: Vector2=points[indices[i]]
            var b: Vector2=points[indices[i+1]]
            var c: Vector2=points[indices[i+2]]
            triangle(Vector3(a.x,a.y,z),Vector3(b.x,b.y,z),Vector3(c.x,c.y,z),mat,Vector3(0,0,face))

func triangle(a: Vector3,b: Vector3,c: Vector3,mat: Material,hint: Vector3=Vector3.ZERO) -> void:
    a=construction_transform*a;b=construction_transform*b;c=construction_transform*c;hint=construction_transform.basis*hint
    var key := str(mat.get_instance_id())
    if not surfaces.has(key):
        var surface := SurfaceTool.new()
        surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        surfaces[key]={"surface":surface,"mat":mat}
    var st: SurfaceTool=surfaces[key].surface
    var normal := (b-a).cross(c-a).normalized()
    var reverse: bool=hint!=Vector3.ZERO and normal.dot(hint)<0.0
    if reverse:normal=-normal
    # Godot front faces are clockwise; retain the outward/inward normal hint.
    for p in [a,b if reverse else c,c if reverse else b]:
        st.set_normal(normal)
        st.set_uv(Vector2(p.x,p.z))
        st.add_vertex(p)

func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,mat: Material,hint: Vector3=Vector3.ZERO) -> void:
    triangle(a,b,c,mat,hint)
    triangle(a,c,d,mat,hint)

func annulus(center: Vector3,r0: float,r1: float,y0: float,y1: float,mat: Material,segments: int=96) -> void:
    for j in range(segments):
        var a: float=float(j)*TAU/float(segments)
        var b: float=float(j+1)*TAU/float(segments)
        quad(center+Vector3(sin(a)*r0,y0,cos(a)*r0),center+Vector3(sin(b)*r0,y0,cos(b)*r0),center+Vector3(sin(b)*r1,y1,cos(b)*r1),center+Vector3(sin(a)*r1,y1,cos(a)*r1),mat,Vector3.DOWN)

func wood_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float w=sin(p.z*47.0+sin(p.x*2.3+p.y*4.0)*3.0);float fine=sin(p.z*290.0+sin(p.x*8.0)*4.0);float grain=pow(abs(w),4.0)*0.45+fine*0.06;
ALBEDO=mix(vec3(0.46,0.31,0.16),vec3(0.77,0.62,0.40),0.64+grain*0.35);ROUGHNESS=0.35+grain*0.12;SPECULAR=0.5;}
"""
    var mat := ShaderMaterial.new();mat.shader=shader;return mat
