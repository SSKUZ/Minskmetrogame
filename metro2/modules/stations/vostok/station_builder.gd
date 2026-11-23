extends "res://modules/stations/vostok/station_base.gd"
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
var _mineral_normal: NoiseTexture2D

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
            child.light_energy=1.05
            child.omni_range=16.5
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

func sampled_stone(file: String,tint: Color,roughness: float,scale_uv: float=1.5) -> StandardMaterial3D:
    # Existing owner-photo mineral samples, with world metre scale rather than
    # stretching one small photograph over an entire platform or wall.
    var m := _material(tint,0.0,roughness)
    m.albedo_texture=load("res://modules/stations/vostok/art/"+file)
    m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    m.uv1_triplanar=true
    m.uv1_world_triplanar=true
    m.uv1_scale=Vector3.ONE*scale_uv
    m.metallic_specular=0.52
    return m

func mineral_normal() -> NoiseTexture2D:
    if _mineral_normal==null:
        var noise := FastNoiseLite.new()
        noise.seed=122
        noise.frequency=0.15
        noise.fractal_octaves=3
        _mineral_normal=NoiseTexture2D.new()
        _mineral_normal.width=128
        _mineral_normal.height=128
        _mineral_normal.seamless=true
        _mineral_normal.as_normal_map=true
        _mineral_normal.bump_strength=0.5
        _mineral_normal.noise=noise
    return _mineral_normal

func cylinder(radius: float,height: float,p: Vector3,mat: Material) -> void:
    batch("cylinder",mat,Transform3D(Basis.from_scale(Vector3(radius*2,height,radius*2)),p))

func sphere(size: Vector3,p: Vector3,mat: Material) -> void:
    batch("sphere",mat,Transform3D(Basis.from_scale(size),p))

func batch(kind: String,mat: Material,pose: Transform3D) -> void:
    # Compatibility renderer selects a bounded number of lights per object.
    # Keep material batching local so one 105 m object does not lose the lamps
    # illuminating its far end. Station geometry/coordinates are unchanged.
    var section := clampi(floori((pose.origin.z-ZA)/10.5),0,9)
    var key := kind+str(mat.get_instance_id())+"_"+str(section)
    if not batches.has(key):batches[key]={"kind":kind,"mat":mat,"poses":[]}
    batches[key].poses.append(pose)

func rod(a: Vector3,b: Vector3,r: float,mat: Material) -> void:
    var direction := (b-a).normalized()
    var axis := Vector3.UP.cross(direction)
    var basis := Basis.IDENTITY
    if axis.length_squared()>0.00001:basis=Basis(axis.normalized(),Vector3.UP.angle_to(direction))
    batch("cylinder",mat,Transform3D(basis*Basis.from_scale(Vector3(r*2,a.distance_to(b),r*2)),(a+b)*0.5))

func profile(points: Array[Vector2],z0: float,z1: float,mat: Material) -> void:
    var spans := maxi(1,ceili((z1-z0)/10.5))
    for span in range(spans):
        var za := lerpf(z0,z1,float(span)/float(spans))
        var zb := lerpf(z0,z1,float(span+1)/float(spans))
        for i in range(points.size()-1):
            var a: Vector2=points[i]
            var b: Vector2=points[i+1]
            quad(Vector3(a.x,a.y,za),Vector3(b.x,b.y,za),Vector3(b.x,b.y,zb),Vector3(a.x,a.y,zb),mat,Vector3(CX-(a.x+b.x)*0.5,-1,0))

func flush() -> void:
    for key in batches:
        var data: Dictionary=batches[key]
        var mesh: Mesh
        if data.has("mesh"):
            mesh=data.mesh
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
    stair_cheek(direction,start,width)
    for rx in [CX-width*0.48,CX+width*0.48]:
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
    board("direction_south.svg" if direction>0.0 else "direction_north.svg",Vector3(CX,4.12,start-direction*0.45),Vector2(5.4,0.62))

func information_pylon(z: float) -> void:
    # Platform display column visible in the Internet platform views; no random ads.
    box(Vector3(0.50,0.10,0.55),Vector3(CX,FY+0.05,z),metal)
    box(Vector3(0.22,2.45,0.20),Vector3(CX,FY+1.25,z),metal)
    box(Vector3(0.65,1.40,0.25),Vector3(CX,3.0,z),metal)
    var screen_glass := _material(Color("#18252b"),0.32,0.18)
    var heights: Array[float]=[4.42,5.16] if station_id=="vostok" else [4.42]
    for y in heights:
        box(Vector3(1.10,0.67,0.18),Vector3(CX,y,z),metal)
        for side in [-1.0,1.0]:
            box(Vector3(1.00,0.56,0.012),Vector3(CX,y,z+side*0.098),screen_glass)
        box(Vector3(0.15,0.58,0.20),Vector3(CX-0.63,y,z),metal)
        box(Vector3(0.15,0.58,0.20),Vector3(CX+0.63,y,z),metal)
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

# Closed cross-section extrusion with rounded corners and proper end caps.
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
    var section := clampi(floori(((a.z+b.z+c.z)/3.0-ZA)/10.5),0,9)
    var key := str(mat.get_instance_id())+"_"+str(section)
    if not surfaces.has(key):
        var surface := SurfaceTool.new()
        surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        surfaces[key]={"surface":surface,"mat":mat}
    var st: SurfaceTool=surfaces[key].surface
    var normal := (b-a).cross(c-a).normalized()
    var reverse: bool=hint!=Vector3.ZERO and normal.dot(hint)<0.0
    if reverse:normal=-normal
    for p in [a,c if reverse else b,b if reverse else c]:
        st.set_normal(normal)
        st.set_uv(Vector2(p.x,p.z))
        st.add_vertex(p)

func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,mat: Material,hint: Vector3=Vector3.ZERO) -> void:
    triangle(a,b,c,mat,hint)
    triangle(a,c,d,mat,hint)

func arc_point(side: float,a: float,y0: float,height: float,inset: float=0.0) -> Vector2:
    return Vector2(CX+side*(8.98*cos(a)-inset),y0+height*sin(a)-inset*0.4)

func curved_band(side: float,a0: float,a1: float,z0: float,z1: float,y0: float,height: float,inset: float,mat: Material) -> void:
    var spans := maxi(1,ceili((z1-z0)/10.5))
    for span in range(spans):
        var za := lerpf(z0,z1,float(span)/float(spans))
        var zb := lerpf(z0,z1,float(span+1)/float(spans))
        for j in range(32):
            var a: Vector2=arc_point(side,lerpf(a0,a1,float(j)/32.0),y0,height,inset)
            var b: Vector2=arc_point(side,lerpf(a0,a1,float(j+1)/32.0),y0,height,inset)
            quad(Vector3(a.x,a.y,za),Vector3(b.x,b.y,za),Vector3(b.x,b.y,zb),Vector3(a.x,a.y,zb),mat,Vector3(CX-(a.x+b.x)*0.5,-1,0))

func annulus(center: Vector3,r0: float,r1: float,y0: float,y1: float,mat: Material,segments: int=96) -> void:
    for j in range(segments):
        var a: float=float(j)*TAU/float(segments)
        var b: float=float(j+1)*TAU/float(segments)
        quad(center+Vector3(sin(a)*r0,y0,cos(a)*r0),center+Vector3(sin(b)*r0,y0,cos(b)*r0),center+Vector3(sin(b)*r1,y1,cos(b)*r1),center+Vector3(sin(a)*r1,y1,cos(a)*r1),mat,Vector3.DOWN)

func crop_picture(file: String,size: Vector2,p: Vector3,yaw: float,uv: Rect2,roughness: float=0.65) -> void:
    var m := StandardMaterial3D.new()
    m.albedo_texture=load(get_script().resource_path.get_base_dir()+"/art/"+file)
    m.uv1_scale=Vector3(uv.size.x,uv.size.y,1)
    m.uv1_offset=Vector3(uv.position.x,uv.position.y,0)
    m.roughness=roughness
    m.albedo_color=Color(0.91,0.91,0.89)
    m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    var mesh := QuadMesh.new();mesh.size=size;mesh.material=m
    var n := MeshInstance3D.new();n.name="PhotoReferencedMarblePanel";n.mesh=mesh;n.position=p;n.rotation.y=yaw
    add_child(n)

func foot_grille(z: float,width: float) -> void:
    box(Vector3(width,0.014,0.28),Vector3(CX,FY+0.012,z),black)
    for i in range(int(width/0.055)):
        box(Vector3(0.016,0.017,0.27),Vector3(CX-width*0.5+float(i)*0.055,FY+0.021,z),metal)

func detailed_bench(p: Vector3,yaw: float=0.0) -> void:
    var basis := Basis(Vector3.UP,yaw)
    for i in range(24):
        var x: float=-0.84+float(i)*0.073
        box(Vector3(0.06,0.055,0.48),p+basis*Vector3(x,0.48,0),timber,basis)
        box(Vector3(0.06,0.53,0.055),p+basis*Vector3(x,0.75,-0.23),timber,basis)
    for x in [-0.70,0.70]:
        box(Vector3(0.15,0.40,0.36),p+basis*Vector3(float(x),0.21,0),granite,basis)
        rod(p+basis*Vector3(float(x),0.43,-0.22),p+basis*Vector3(float(x),1.02,-0.22),0.022,metal)
    for x in [-0.84,0.84]:
        rod(p+basis*Vector3(float(x),0.69,-0.26),p+basis*Vector3(float(x),0.69,0.27),0.024,metal)

func finish_hall() -> void:
    # Thin cabinet seams, cable saddles, stair drainage and small physical fittings.
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.72
        for z in [3.0,51.0,79.0]:
            for dz in [-0.39,0.39]:
                box(Vector3(0.018,1.02,0.008),Vector3(x,2.02,float(z)+float(dz)),metal)
            for y in [1.51,2.53]:
                box(Vector3(0.018,0.009,0.78),Vector3(x,float(y),float(z)),metal)
            box(Vector3(0.04,0.13,0.025),Vector3(x-side*0.018,2.02,float(z)+0.27),metal)
        for i in range(54):
            box(Vector3(0.035,0.07,0.025),Vector3(x,2.96,ZA+float(i)*1.95),metal)
    for z in [-2.9,81.9]:foot_grille(float(z),7.0)
    for z in [9.0,37.0,66.0]:
        box(Vector3(0.32,0.018,0.32),Vector3(CX+0.96,FY+0.012,float(z)),granite)
        for d in [-0.13,0.13]:
            box(Vector3(0.012,0.021,0.28),Vector3(CX+0.96+float(d),FY+0.018,float(z)),metal)

func vestibule(direction: float,start: float,kind: String) -> void:
    var floor_y: float=FY+4.06
    var z: float=start+direction*11.7
    # Joined upper landing and vestibule; no isolated stair block or invisible gap.
    box(Vector3(8.1,0.22,5.0),Vector3(CX,floor_y-0.11,z+direction*1.8),marble)
    for side in [-1.0,1.0]:
        if kind=="vostok":
            box(Vector3(0.24,3.2,5.0),Vector3(CX+side*4.08,6.8,start+direction*11.5),marble)
        else:
            box(Vector3(0.24,7.22,13.4),Vector3(CX+side*4.08,4.79,start+direction*6.1),marble)
        box(Vector3(0.16,0.22,13.4),Vector3(CX+side*3.96,5.37,start+direction*6.1),granite)
    box(Vector3(8.4,0.20,13.6),Vector3(CX,8.45,start+direction*6.2),white)
    for i in range(8):
        var zz: float=start+direction*(float(i)*1.65)
        box(Vector3(7.9,0.18,0.17),Vector3(CX,8.22,zz),white)
        box(Vector3(5.6,0.04,0.075),Vector3(CX,8.11,zz),glow)
    # Over-stair lintel visible in both photographic end views.
    if kind!="vostok":
        box(Vector3(8.0,2.95,0.35),Vector3(CX,6.48,start-direction*0.5),marble)
    else:
        for side in [-1.0,1.0]:
            rod(Vector3(CX+side*3.8,floor_y+0.95,z-direction*1.7),Vector3(CX+side*3.8,floor_y+0.95,z+direction*3.9),0.028,metal)
    board("exit.svg",Vector3(CX,7.4,z+direction*1.9),Vector2(5.4,0.62))
    box(Vector3(8.35,3.4,0.20),Vector3(CX,6.9,z+direction*4.35),marble)
    for x in [-2.0,0.0,2.0]:
        box(Vector3(1.55,2.35,0.08),Vector3(CX+float(x),floor_y+1.175,z+direction*4.20),black)
        box(Vector3(1.41,2.21,0.04),Vector3(CX+float(x),floor_y+1.175,z+direction*4.15),metal)
        box(Vector3(0.025,0.40,0.10),Vector3(CX+float(x)+0.48,floor_y+1.1,z+direction*4.10),black)

func instance_mesh(label: String,mesh: Mesh,p: Vector3) -> void:
    if not batches.has(label):batches[label]={"kind":"custom","mesh":mesh,"mat":mesh.surface_get_material(0),"poses":[]}
    batches[label].poses.append(Transform3D(Basis.IDENTITY,p))

func stair_cheek(direction: float,start: float,width: float) -> void:
    var offsets := [Vector2(-0.15,0),Vector2(4.05,2.03),Vector2(5.25,2.03),Vector2(9.45,4.06)]
    for side in [-1.0,1.0]:
        var x: float=CX+side*(width*0.5+0.10)
        for i in range(offsets.size()-1):
            var a: Vector2=offsets[i];var b: Vector2=offsets[i+1]
            for face in [-1.0,1.0]:
                var xx: float=x+face*0.11
                quad(Vector3(xx,FY+a.y,start+direction*a.x),Vector3(xx,FY+b.y,start+direction*b.x),Vector3(xx,FY+b.y+0.87,start+direction*b.x),Vector3(xx,FY+a.y+0.87,start+direction*a.x),marble,Vector3(face,0,0))
            quad(Vector3(x-0.11,FY+a.y+0.87,start+direction*a.x),Vector3(x+0.11,FY+a.y+0.87,start+direction*a.x),Vector3(x+0.11,FY+b.y+0.87,start+direction*b.x),Vector3(x-0.11,FY+b.y+0.87,start+direction*b.x),marble,Vector3.UP)

func wood_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float w=sin(p.z*47.0+sin(p.x*2.3+p.y*4.0)*3.0);float fine=sin(p.z*290.0+sin(p.x*8.0)*4.0);float grain=pow(abs(w),4.0)*0.45+fine*0.06;
ALBEDO=mix(vec3(0.40,0.25,0.12),vec3(0.72,0.52,0.29),0.64+grain*0.35);ROUGHNESS=0.35+grain*0.12;SPECULAR=0.5;}
"""
    var mat := ShaderMaterial.new();mat.shader=shader;return mat
