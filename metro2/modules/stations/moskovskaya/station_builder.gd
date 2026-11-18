extends "res://modules/stations/moskovskaya/station_base.gd"
## Local construction helpers, without a dependency on any other station module.
const CX := -5.37
const FY := 1.1805
const ZA := -12.888
const ZB := 92.112
const MID := 39.612
var batches: Dictionary = {}
var surfaces: Dictionary = {}
var white: StandardMaterial3D
var metal: StandardMaterial3D
var brass: StandardMaterial3D
var black: StandardMaterial3D
var marble: ShaderMaterial
var granite: ShaderMaterial
var redstone: ShaderMaterial
var glow: StandardMaterial3D
var timber: ShaderMaterial

func begin_station() -> void:
    white=_material(Color("#deded6"),0.0,0.75)
    metal=_material(Color("#abb0b0"),0.78,0.30)
    brass=_material(Color("#9c7d38"),0.78,0.32)
    black=_material(Color("#171b1a"),0.1,0.58)
    marble=stone(Color("#c9c7b9"),true)
    granite=stone(Color("#252824"),false)
    redstone=stone(Color("#75493c"),false)
    timber=stone(Color("#96643a"),false)
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
uniform vec4 tint : source_color;
uniform bool veined=false;
varying vec3 p; varying vec3 n;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;n=abs(MODEL_NORMAL_MATRIX*NORMAL);}
float hash(vec3 q){return fract(sin(dot(q,vec3(12.9898,78.233,37.719)))*43758.5453);}
void fragment(){
vec2 q=n.x>0.5?p.zy:n.y>0.5?p.xz:p.xy;
float grain=hash(floor(p*180.0));
float vein=pow(1.0-abs(sin(q.x*3.7+q.y*2.4+sin(q.x*1.3-q.y*2.1)*2.0)),18.0);
vec2 tile=fract(q/vec2(1.20,0.62));float joint=1.0-smoothstep(0.001,0.004,min(min(tile.x,1.0-tile.x),min(tile.y,1.0-tile.y)));
ALBEDO=tint.rgb*(0.88+grain*0.20)-vec3(veined?vein*0.11:0.0)-vec3(joint*0.035);
ROUGHNESS=veined?0.32:0.43;SPECULAR=0.55;
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
        for v in [Vector3(a.x,a.y,z0),Vector3(b.x,b.y,z0),Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z0),Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z1)]:st.add_vertex(v)

func flush() -> void:
    for key in batches:
        var data: Dictionary=batches[key]
        var mesh: PrimitiveMesh
        if data.kind=="cylinder":
            var c := CylinderMesh.new()
            c.top_radius=0.5;c.bottom_radius=0.5;c.height=1.0;c.radial_segments=16
            mesh=c
        elif data.kind=="sphere":
            var s := SphereMesh.new()
            s.radius=0.5;s.height=1.0;s.radial_segments=12;s.rings=6
            mesh=s
        else:
            var b := BoxMesh.new()
            b.size=Vector3.ONE
            mesh=b
        mesh.material=data.mat
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
        st.generate_normals()
        var mesh := st.commit()
        var mat: Material=data.mat.duplicate()
        mat.set("cull_mode",BaseMaterial3D.CULL_DISABLED)
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
    n.mesh=q;n.position=p;n.rotation.y=yaw
    n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(n)

func board(file: String,p: Vector3,size: Vector2) -> void:
    box(Vector3(size.x+0.09,size.y+0.08,0.09),p,metal)
    for side in [-1.0,1.0]:
        picture(file,size,p+Vector3(0,0,side*0.052),0.0 if side>0.0 else PI)
    for dx in [-0.44,0.44]:
        rod(p+Vector3(size.x*float(dx),size.y*0.5,0),p+Vector3(size.x*float(dx),size.y*0.5+0.70,0),0.018,metal)

func platform_edges() -> void:
    var yellow := _material(Color("#d6ad35"),0.0,0.68)
    for side in [-1.0,1.0]:
        box(Vector3(0.25,0.012,105),Vector3(CX+side*4.84,FY+0.007,MID),marble)
        box(Vector3(0.10,0.008,105),Vector3(CX+side*4.55,FY+0.009,MID),yellow)

func portals(top: float) -> void:
    for direction in [-1.0,1.0]:
        var end: float=ZA if direction<0.0 else ZB
        box(Vector3(9.4,0.22,0.30),Vector3(CX,top+0.11,end+direction*0.16),white)
        for side in [-1.0,1.0]:
            var tx: float=0.992 if side>0.0 else -11.732
            box(Vector3(3.8,top-4.5,0.30),Vector3(tx,(top+4.5)*0.5,end+direction*0.16),white)
            box(Vector3(0.45,4.7,0.30),Vector3(tx+side*2.0,2.0,end+direction*0.16),granite)
            box(Vector3(3.65,0.18,7.0),Vector3(tx,4.48,end+direction*3.5),black)
            for edge in [-1.0,1.0]:
                box(Vector3(0.18,4.6,7.0),Vector3(tx+edge*1.84,2.10,end+direction*3.5),granite)
            box(Vector3(3.65,4.6,0.12),Vector3(tx,2.10,end+direction*7.0),black)

func stairs(direction: float,start: float,width: float=7.5) -> void:
    var run := 0.30
    var rise := 0.145
    var landing := 1.20
    var yellow := _material(Color("#d4ae35"))
    for i in range(28):
        var height := float(i+1)*rise
        var z: float=start+direction*(float(i)*run+(landing if i>=14 else 0.0))
        box(Vector3(width,height,run+0.008),Vector3(CX,FY+height*0.5,z),marble)
        box(Vector3(width,0.016,0.045),Vector3(CX,FY+height+0.009,z-direction*0.13),yellow if i in [0,13,27] else metal)
    box(Vector3(width,0.18,landing),Vector3(CX,FY+14.0*rise-0.09,start+direction*(13.5*run+landing*0.5)),marble)
    box(Vector3(width,0.20,3.2),Vector3(CX,FY+28.0*rise-0.10,start+direction*11.0),marble)
    box(Vector3(width+0.4,3.5,0.18),Vector3(CX,FY+28.0*rise+1.65,start+direction*12.6),marble)
    for edge in [-1.0,1.0]:
        box(Vector3(0.22,4.0,10.0),Vector3(CX+edge*(width*0.5+0.15),FY+2.0,start+direction*4.7),marble)
    for rx in [CX-width*0.48,CX,CX+width*0.48]:
        for h in [0.70,1.02]:
            var a := Vector3(float(rx),FY+float(h),start-0.30*direction)
            var b := Vector3(float(rx),FY+14.0*rise+float(h),start+direction*13.5*run)
            var c := b+Vector3(0,0,direction*landing)
            var d := Vector3(float(rx),FY+28.0*rise+float(h),start+direction*(27.5*run+landing))
            rod(a,b,0.025,metal);rod(b,c,0.025,metal);rod(c,d,0.025,metal)
        for i in range(8):
            var fraction := float(i)/7.0
            var y: float=FY+28.0*rise*fraction
            var z: float=start+direction*(27.5*run+landing)*fraction
            rod(Vector3(float(rx),y,z),Vector3(float(rx),y+1.02,z),0.023,metal)
    board("exit.svg",Vector3(CX,4.10,start-direction*0.45),Vector2(5.4,0.62))

func information_pylon(z: float) -> void:
    # Platform display column visible in the Internet platform views; no random ads.
    box(Vector3(0.50,0.10,0.55),Vector3(CX,FY+0.05,z),metal)
    box(Vector3(0.22,2.45,0.20),Vector3(CX,FY+1.25,z),metal)
    box(Vector3(0.65,1.40,0.25),Vector3(CX,3.0,z),metal)
    box(Vector3(0.80,0.48,0.18),Vector3(CX,4.25,z),black)
    for side in [-1.0,1.0]:
        picture("network.svg",Vector2(0.55,1.28),Vector3(CX,3.0,z+side*0.132),0.0 if side>0.0 else PI)
    for dx in [-0.16,0.0,0.16]:
        box(Vector3(0.015,0.20,0.26),Vector3(CX+float(dx),3.90,z),brass)

func bench(p: Vector3,yaw: float=0.0) -> void:
    var basis := Basis(Vector3.UP,yaw)
    box(Vector3(1.65,0.10,0.48),p+Vector3(0,0.45,0),metal,basis)
    for i in range(20):
        box(Vector3(0.068,0.05,0.45),p+basis*Vector3(-0.77+float(i)*0.081,0.51,0),timber,basis)
    for dx in [-0.61,0.61]:
        box(Vector3(0.10,0.43,0.30),p+basis*Vector3(float(dx),0.22,0),black,basis)
