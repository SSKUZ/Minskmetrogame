extends Node3D
## Mihalovo local Uruchye-style track detail. Same gauge, rail top and station centreline as Station Base.
const PATH := preload("res://scripts/playable_track_path.gd")
const TRACKS := [0.992,-11.732]
var start_z: float=-22.888
var finish_z: float=102.112
const GAUGE_HALF := 0.8075
var batches: Dictionary={}
var metal: StandardMaterial3D
var rust: StandardMaterial3D
var tie: ShaderMaterial
var ballast: ShaderMaterial
var fixing: StandardMaterial3D

func _ready() -> void:
    metal=_mat(Color("#9ca9af"),0.83,0.27)
    rust=_mat(Color("#4d443b"),0.63,0.57)
    fixing=_mat(Color("#292d2e"),0.65,0.52)
    tie=_grain(Color("#292d2b"),true)
    ballast=_grain(Color("#383b38"),false)
    var station := get_parent()
    for name in ["Track1","Track2"]:
        var original := station.get_node(name)
        for key in ["Rails","Beds","Sleepers"]:(original.get_node(key) as GeometryInstance3D).hide()
    _running_tracks()
    _flush()
    # StationInfrastructure is added after the architecture in Station Base's _ready.
    call_deferred("_contact_rails")

func _mat(tint: Color,metallic: float,roughness: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new();m.albedo_color=tint;m.metallic=metallic;m.roughness=roughness;return m

func _grain(tint: Color,sleeper: bool) -> ShaderMaterial:
    var s := Shader.new()
    s.code="""shader_type spatial;
uniform vec4 tint : source_color;
uniform bool sleeper=false;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float h(vec3 q){return fract(sin(dot(q,vec3(127.1,311.7,74.7)))*43758.5453);}
void fragment(){
float coarse=h(floor(p*(sleeper?95.0:24.0)));float fine=h(floor(p*390.0));
float grooves=pow(abs(sin(p.x*51.0+sin(p.z*19.0)*1.9)),16.0);
ALBEDO=tint.rgb*(0.82+coarse*0.31)+(fine-0.5)*0.035-vec3(sleeper?grooves*0.025:0.0);
ROUGHNESS=sleeper?0.88:0.96;SPECULAR=0.22;
}
"""
    var m := ShaderMaterial.new();m.shader=s;m.set_shader_parameter("tint",tint);m.set_shader_parameter("sleeper",sleeper);return m

func _box(size: Vector3,p: Vector3,mat: Material,basis: Basis=Basis.IDENTITY) -> void:
    _batch("box",mat,Transform3D(basis*Basis.from_scale(size),p))

func _cylinder(radius: float,height: float,p: Vector3,mat: Material) -> void:
    _batch("cylinder",mat,Transform3D(Basis.from_scale(Vector3(radius*2,height,radius*2)),p))

func _batch(kind: String,mat: Material,t: Transform3D) -> void:
    var key: String=kind+str(mat.get_instance_id())
    if not batches.has(key):batches[key]={"kind":kind,"mat":mat,"poses":[]}
    batches[key].poses.append(t)

func _flush() -> void:
    for key in batches:
        var data: Dictionary=batches[key]
        var mesh: PrimitiveMesh
        if data.kind=="cylinder":
            var c := CylinderMesh.new();c.top_radius=0.5;c.bottom_radius=0.5;c.height=1.0;c.radial_segments=10;mesh=c
        else:
            var b := BoxMesh.new();b.size=Vector3.ONE;mesh=b
        mesh.material=data.mat
        var mm := MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=data.poses.size()
        for i in range(mm.instance_count):mm.set_instance_transform(i,data.poses[i])
        var n := MultiMeshInstance3D.new();n.name="TrackDetail"+str(data.kind);n.multimesh=mm;add_child(n)
    batches.clear()

func _running_tracks() -> void:
    for track in range(2):
        var x: float=TRACKS[track]
        for i in range(int(ceil(finish_z-start_z))):
            var z0: float=start_z+float(i);var z1: float=minf(finish_z,z0+1.0);var z: float=(z0+z1)*0.5
            var lateral: float=PATH.offset(z) if track==0 else 0.0
            var b := Basis(Vector3.UP,PATH.heading(z) if track==0 else 0.0)
            var centre := Vector3(x+lateral,0,z)
            _box(Vector3(3.18,0.22,z1-z0),centre+Vector3(0,-0.44,0),ballast,b)
            for side in [-1.0,1.0]:
                var rail: Vector3=centre+b*Vector3(side*GAUGE_HALF,0,0)
                # Separate foot, narrow web, underside of head and worn crown. Rail top remains y=0.
                _box(Vector3(0.145,0.032,z1-z0),rail+Vector3(0,-0.166,0),rust,b)
                _box(Vector3(0.021,0.100,z1-z0),rail+Vector3(0,-0.100,0),rust,b)
                _box(Vector3(0.081,0.022,z1-z0),rail+Vector3(0,-0.040,0),rust,b)
                _box(Vector3(0.068,0.029,z1-z0),rail+Vector3(0,-0.0145,0),metal,b)
        var n: int=int(floor((finish_z-start_z)/0.65))
        for i in range(n):
            var z: float=start_z+(float(i)+0.5)*0.65
            var lateral: float=PATH.offset(z) if track==0 else 0.0
            var b := Basis(Vector3.UP,PATH.heading(z) if track==0 else 0.0)
            var centre := Vector3(x+lateral,-0.28,z)
            _box(Vector3(2.72,0.20,0.285),centre,tie,b)
            # Shoulder/end caps, bearing plates, retaining clips and bolts give the ties a raised silhouette.
            for side in [-1.0,1.0]:
                var rail: Vector3=Vector3(x+lateral,0,z)+b*Vector3(side*GAUGE_HALF,0,0)
                _box(Vector3(0.30,0.023,0.235),rail+Vector3(0,-0.176,0),fixing,b)
                for offset in [-0.108,0.108]:
                    var p: Vector3=rail+b*Vector3(float(offset),-0.143,0)
                    _box(Vector3(0.043,0.047,0.16),p,fixing,b)
                    for dz in [-0.071,0.071]:_cylinder(0.018,0.019,p+b*Vector3(0,0.032,float(dz)),metal)
            for side in [-1.0,1.0]:_box(Vector3(0.08,0.012,0.25),centre+b*Vector3(side*1.28,0.106,0),fixing,b)

func _contact_rails() -> void:
    var station := get_parent()
    var infrastructure := station.get_node_or_null("StationInfrastructure")
    if infrastructure!=null:
        # Replace the old plain conductor/cover pieces only; leave all four portal clocks intact.
        for child in infrastructure.get_children():
            if child is MeshInstance3D or (child is MultiMeshInstance3D and str(child.name).begins_with("ContactRailInsulators")):child.hide()
    var porcelain := _mat(Color("#c0c1b1"),0.05,0.48)
    var cover := _grain(Color("#5d5343"),true)
    var length: float=finish_z-start_z
    for track in range(2):
        var side: float=1.0 if track==0 else -1.0
        var x: float=TRACKS[track]+side*1.48
        _box(Vector3(0.085,0.12,length),Vector3(x,0.225,(start_z+finish_z)*0.5),rust)
        _box(Vector3(0.13,0.035,length),Vector3(x,0.15,(start_z+finish_z)*0.5),metal)
        for i in range(int(ceil(length/4.0))):
            var a: float=start_z+float(i)*4.0;var b: float=minf(finish_z,a+4.0)
            _box(Vector3(0.27,0.055,b-a-0.015),Vector3(x,0.325,(a+b)*0.5),cover)
            _box(Vector3(0.025,0.16,b-a-0.015),Vector3(x+side*0.145,0.245,(a+b)*0.5),cover)
            _box(Vector3(0.30,0.018,0.055),Vector3(x,0.363,a+0.04),fixing)
        for i in range(int(ceil(length/2.0))):
            var z: float=start_z+(float(i)+0.5)*2.0
            _box(Vector3(0.26,0.055,0.19),Vector3(x,-0.06,z),fixing)
            _cylinder(0.070,0.16,Vector3(x,0.025,z),porcelain)
            for y in [-0.010,0.040,0.082]:_cylinder(0.084,0.018,Vector3(x,float(y),z),porcelain)
            _box(Vector3(0.19,0.036,0.13),Vector3(x,0.118,z),metal)
    _flush()
