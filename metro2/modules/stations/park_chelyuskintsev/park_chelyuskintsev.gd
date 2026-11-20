extends "res://modules/stations/park_chelyuskintsev/station_builder.gd"
## V61.1: corrected inward faces, closed white vault and photo-matched cove transitions.
const ART := "res://modules/stations/park_chelyuskintsev/art/"
const NORTH := -2.8
const SOUTH := 82.024
var stair_wall: ShaderMaterial
var stair_stone: ShaderMaterial
var dark_stone: ShaderMaterial
var yellow: StandardMaterial3D
var plaster: ShaderMaterial
var vault_field: ShaderMaterial
var _advert: ShaderMaterial
var _chandelier_meshes: Array[Mesh]=[]
var _side_glass_materials: Array[Material]=[]

func _ready() -> void:
    super._ready()
    begin_station()
    white.albedo_color=Color("#e8e8df")
    glow.albedo_color=Color("#fffdf1");glow.emission=Color(1.0,0.99,0.91)
    yellow=_material(Color("#d9b24b"),0.0,0.64)
    dark_stone=_photo_stone("wall_dark_granite.jpg",Color(0.91,0.93,0.92),Vector2(0.83,0.43),0.36)
    stair_wall=_photo_stone("stair_side_marble.jpg",Color(1.0,0.98,0.91),Vector2(0.9,0.6),0.35)
    stair_stone=_photo_stone("stair_tread.jpg",Color(0.96,0.95,0.88),Vector2(1.4,0.6),0.51)
    plaster=_plaster(Color(0.96,0.96,0.93));vault_field=_plaster(Color(0.88,0.89,0.87))
    _hall_lighting()
    _floor();_edges();_walls();_build_chandelier();_vault()
    _stairs(-1.0,NORTH);_stairs(1.0,SOUTH)
    _end_arch(-1.0,NORTH);_end_arch(1.0,SOUTH)
    _track_details();_portal_equipment();_advert_material()
    for i in range(3):_pylon(12.0+float(i)*27.6,i!=0)
    for z in [25.8,53.4]:_island_bench(float(z))
    _fittings();flush()

func _plaster(tint: Color) -> ShaderMaterial:
    var shader := Shader.new()
    shader.code="""shader_type spatial;render_mode cull_disabled;
uniform sampler2D plaster_tex : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 tint : source_color;
varying vec3 p;void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float grain=texture(plaster_tex,p.xz*0.5+p.xy*0.2).r;
vec3 colour=tint.rgb*(0.975+grain*0.032);
float cove=1.0-smoothstep(1.92,2.50,abs(p.x+5.37));
// Low-cost indirect bounce from the white coves; visible even in the Web renderer.
ALBEDO=colour;EMISSION=colour*mix(0.11,0.25,cove);ROUGHNESS=0.89;SPECULAR=0.19;}
"""
    var mat := ShaderMaterial.new();mat.shader=shader
    mat.set_shader_parameter("plaster_tex",load(ART+"vault_plaster.jpg"));mat.set_shader_parameter("tint",tint)
    return mat

func _floor() -> void:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
uniform sampler2D rose_tex : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D aggregate_tex : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D dark_tex : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 p;void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float h(vec2 q){return fract(sin(dot(q,vec2(12.9898,78.233)))*43758.5453);}
float motif(vec2 q,float shrink){q=abs(q);return max(step(q.x,3.18-shrink)*step(q.y,2.68-shrink),max(step(q.x,2.58-shrink)*step(q.y,3.28-shrink),step(q.x,1.98-shrink)*step(q.y,3.88-shrink)));}
void fragment(){vec2 q=vec2(p.x+5.37,mod(p.z-1.8+6.6,13.2)-6.6);
vec2 cell=floor(p.xz/0.60);float v=h(cell);vec2 uv=p.xz*1.25+vec2(v*0.47,v*0.21);
vec3 rose=texture(rose_tex,uv).rgb;vec3 aggregate=texture(aggregate_tex,p.xz*1.7).rgb;
vec3 dark=texture(dark_tex,p.xz*1.25).rgb*0.81;
float outer=motif(q,-0.32),inner=motif(q,0.0);vec3 c=mix(aggregate,dark,outer);c=mix(c,rose,inner);
float ring=step(max(abs(q.x),abs(q.y)),1.31)*step(1.03,max(abs(q.x),abs(q.y)));c=mix(c,aggregate,ring);
vec2 tile=fract(p.xz/vec2(0.6,0.6));float joint=1.0-smoothstep(0.0008,0.003,min(min(tile.x,1.0-tile.x),min(tile.y,1.0-tile.y)));
ALBEDO=c*(0.95+v*0.10)-vec3(joint*0.027);ROUGHNESS=0.35+v*0.09;SPECULAR=0.63;}
"""
    var mat := ShaderMaterial.new();mat.shader=shader
    mat.set_shader_parameter("rose_tex",load(ART+"floor_rose.jpg"));mat.set_shader_parameter("aggregate_tex",load(ART+"floor_aggregate.jpg"));mat.set_shader_parameter("dark_tex",load(ART+"wall_dark_granite.jpg"))
    (get_node("IslandPlatform") as MeshInstance3D).material_override=mat

func _edges() -> void:
    var edge := _photo_stone("stair_tread.jpg",Color(0.89,0.89,0.85),Vector2(0.60,1.20),0.48)
    var faded := _material(Color("#c7b49b"),0.0,0.76)
    for side in [-1.0,1.0]:
        box(Vector3(0.43,0.014,105),Vector3(CX+side*4.785,FY+0.009,MID),edge)
        box(Vector3(0.18,0.014,105),Vector3(CX+side*4.47,FY+0.016,MID),yellow)
        for i in range(1312):
            for dx in [-0.05,0.01,0.065]:cylinder(0.0115,0.005,Vector3(CX+side*4.47+float(dx),FY+0.025,ZA+0.04+float(i)*0.08),yellow)
        for z in [9.6,29.4,49.2,69.0]:
            for dz in [-0.39,0.39]:box(Vector3(0.40,0.008,0.055),Vector3(CX+side*4.08,FY+0.014,float(z)+float(dz)),faded)
            box(Vector3(0.055,0.008,0.80),Vector3(CX+side*3.90,FY+0.014,float(z)),faded)

func _walls() -> void:
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.90
        box(Vector3(0.28,1.97,105),Vector3(x,0.985,MID),dark_stone)
        box(Vector3(0.22,1.32,105),Vector3(x,2.63,MID),plaster)
        for i in range(18):
            var z: float=ZA+float(i)*6.0;var end: float=minf(z+6.0,ZB)
            box(Vector3(0.45,0.30,maxf(0.1,end-z-0.43)),Vector3(x-side*0.07,2.12,(z+end)*0.5+0.10),dark_stone)
            box(Vector3(0.45,0.12,0.43),Vector3(x-side*0.07,2.03,z+0.11),dark_stone)
            box(Vector3(0.09,0.94,maxf(0.1,end-z-0.52)),Vector3(x-side*0.15,2.83,(z+end)*0.5+0.10),plaster)
        for i in range(7):
            var z: float=1.6+float(i)*12.0
            if i%2==0:
                var be: bool=(i/2)%2==0 if side>0.0 else (i/2)%2!=0
                _name("bronze_name_be.png" if be else "bronze_name_ru.png",Vector3(x-side*0.22,2.96,z),-side*PI/2.0)
            else:picture("route_track1_v61.svg" if side>0.0 else "route_track2_v61.svg",Vector2(4.70,0.75),Vector3(x-side*0.23,2.92,z),-side*PI/2.0,true)
        var cable_x: float=CX+side*8.89
        rod(Vector3(cable_x,3.65,ZA),Vector3(cable_x,3.65,ZB),0.012,metal)
        for j in range(68):
            var z: float=ZA+float(j)*1.56
            rod(Vector3(cable_x,3.65,z),Vector3(cable_x+side*0.04,3.73,z),0.006,metal)

func _name(file: String,p: Vector3,yaw: float) -> void:
    var basis := Basis(Vector3.UP,yaw)
    box(Vector3(1.43,0.30,0.024),p+basis*Vector3(-1.92,0,0),brass,basis)
    box(Vector3(3.31,0.30,0.024),p+basis*Vector3(0.89,0,0),brass,basis)
    picture(file,Vector2(5.35,0.56),p+basis*Vector3(0,0,0.020),yaw,true)

func _hall_lighting() -> void:
    # Reuse the six existing lights; emission alone does not illuminate plaster in GLES.
    for child in get_children():
        if child is OmniLight3D:
            child.position.y=6.15
            child.light_color=Color(1.0,0.985,0.95)
            child.light_energy=1.80
            child.omni_range=20.0
            child.omni_attenuation=0.60
            child.shadow_enabled=false

func _central_height(x: float) -> float:
    var ax: float=absf(x)
    if ax>1.98:
        var t: float=clampf((ax-1.98)/0.30,0.0,1.0)
        return 7.53+0.30*sqrt(maxf(0.0,1.0-t*t))
    return 7.83+0.15*(1.0-pow(ax/1.98,2.0))

func _central_vault(z0: float,z1: float) -> void:
    # Continuous curved crown with rounded transverse ends; no flat central box.
    var length: float=z1-z0
    var strips := PackedFloat32Array([0.0,0.04,0.10,0.18,0.28,length-0.28,length-0.18,length-0.10,length-0.04,length])
    for k in range(strips.size()-1):
        var a: float=strips[k];var b: float=strips[k+1]
        for j in range(64):
            var xa: float=-2.28+float(j)*4.56/64.0
            var xb: float=-2.28+float(j+1)*4.56/64.0
            var da: float=0.18*(1.0-smoothstep(0.0,0.28,minf(a,length-a)))
            var db: float=0.18*(1.0-smoothstep(0.0,0.28,minf(b,length-b)))
            var ha: float=1.0-pow(absf(xa)/2.28,4.0)
            var hb: float=1.0-pow(absf(xb)/2.28,4.0)
            quad(Vector3(CX+xa,_central_height(xa)-da*ha,z0+a),Vector3(CX+xb,_central_height(xb)-da*hb,z0+a),Vector3(CX+xb,_central_height(xb)-db*hb,z0+b),Vector3(CX+xa,_central_height(xa)-db*ha,z0+b),plaster,Vector3.DOWN)

func _vault() -> void:
    for i in range(18):
        var z: float=ZA+float(i)*6.0;var end: float=minf(ZB,z+6.0)
        for side in [-1.0,1.0]:
            # Arch joins the rounded central shoulder at x=+/-2.28, y=7.53.
            curved_band(float(side),0.0,1.314,z,end,3.20,4.48,0.0,vault_field)
            curved_band(float(side),0.0,1.314,z,z+0.22,3.20,4.48,0.045,plaster)
            # Narrow bronze rods descend the WHITE rib; no dark ceiling channels.
            for j in range(3):curved_band(float(side),0.08,1.095,z+0.058+float(j)*0.041,z+0.070+float(j)*0.041,3.20,4.48,0.061,brass)
            box(Vector3(0.065,0.035,maxf(0.05,end-z-0.08)),Vector3(CX+side*2.23,7.535,(z+end)*0.5),glow)
            _side_lantern(float(side),z+0.11)
        _central_vault(z,end)
        if z+3.0<ZB:_chandelier(z+3.0)

func _side_lantern(side: float,z: float) -> void:
    # Five glass columns in bronze cages follow the vault, with upright clear end panes.
    if _side_glass_materials.is_empty():
        for i in range(3):
            var mat := _material([Color("#d7a447"),Color("#7c643b"),Color("#c1b991")][i],0.24,0.25)
            mat.albedo_texture=load(ART+"side_glass.jpg")
            mat.uv1_scale=Vector3(0.18,0.075,1);mat.uv1_offset=Vector3([0.02,0.26,0.72][i],0.35,0)
            mat.emission_enabled=true;mat.emission=mat.albedo_color*0.24;mat.emission_texture=mat.albedo_texture
            _side_glass_materials.append(mat)
    for row in range(11):
        var a: float=1.105+float(row)*0.0185
        var p := arc_point(side,a,3.20,4.48,0.12)
        var tangent := Vector3(-side*8.98*sin(a),4.48*cos(a),0).normalized()
        var basis := Basis(Vector3.BACK,atan2(tangent.y,tangent.x))
        for col in range(5):box(Vector3(0.14,0.06,0.094),Vector3(p.x,p.y,z+(float(col)-2.0)*0.105),_side_glass_materials[0 if col in [0,2,4] else 1],basis)
        rod(Vector3(p.x,p.y-0.012,z-0.29),Vector3(p.x,p.y-0.012,z+0.29),0.008,brass)
    var tip := arc_point(side,1.297,3.20,4.48,0.09)
    box(Vector3(0.04,0.34,0.58),Vector3(tip.x,tip.y+0.08,z),brass)
    for col in range(5):box(Vector3(0.055,0.29,0.094),Vector3(tip.x-side*0.025,tip.y+0.10,z+(float(col)-2.0)*0.105),_side_glass_materials[2 if col in [1,2,3] else 0])
    for col in [-2.5,2.5]:
        var a := arc_point(side,1.10,3.20,4.48,0.12);var b := arc_point(side,1.30,3.20,4.48,0.12)
        rod(Vector3(a.x,a.y,z+float(col)*0.105),Vector3(b.x,b.y,z+float(col)*0.105),0.009,brass)

func _end_arch(direction: float,start: float) -> void:
    var pts := PackedVector2Array([Vector2(CX-3.85,7.88),Vector2(CX+3.85,7.88)])
    for i in range(33):
        var x: float=3.85-float(i)*7.70/32.0
        pts.append(Vector2(CX+x,4.30+0.60*sqrt(maxf(0.0,1.0-x*x/(3.85*3.85)))))
    extrusion(pts,start-0.40,start+0.02,plaster)
    for side in [-1.0,1.0]:
        var x: float=CX+side*3.82
        box(Vector3(0.38,3.0,0.48),Vector3(x,FY+1.5,start-direction*0.14),stair_wall)
        var a := Vector3(x-side*0.20,4.17,start-direction*0.38)
        var b := Vector3(x-side*0.20,6.20,start-direction*0.38)
        var c := Vector3(x-side*0.20,6.20,start-direction*0.98)
        var d := Vector3(x-side*0.20,5.66,start-direction*0.98)
        var offset := Vector3(side*0.40,0,0)
        quad(a,b,c,d,stair_wall,Vector3(-side,0,0))
        quad(a+offset,d+offset,c+offset,b+offset,stair_wall,Vector3(side,0,0))
        quad(a,d,d+offset,a+offset,stair_wall,Vector3(0,-1,0))
        quad(d,c,c+offset,d+offset,stair_wall,Vector3(0,0,-direction))
        box(Vector3(0.45,0.68,0.12),Vector3(x,5.92,start-direction*0.98),stair_wall)
    box(Vector3(5.90,0.045,0.07),Vector3(CX,6.02,start-direction*0.55),glow)
    box(Vector3(0.62,0.035,0.35),Vector3(CX,4.89,start-direction*0.09),black)

func _pylon(z: float,television: bool) -> void:
    var body := _material(Color("#70685c"),0.40,0.46)
    var dark := _material(Color("#211f1b"),0.36,0.45)
    var p := Vector3(CX,FY,z)
    _round_box(Vector3(0.54,1.02,0.49),p+Vector3(0,0.51,0),body,0.08)
    box(Vector3(0.57,0.08,0.53),p+Vector3(0,0.04,0),metal)
    _round_box(Vector3(0.89,2.15,0.76),p+Vector3(0,2.16,0),body,0.04)
    for face in [-1.0,1.0]:
        var yaw: float=0.0 if face>0.0 else PI
        picture("pylon_track1_v61.svg" if face>0.0 else "pylon_track2_v61.svg",Vector2(0.77,2.01),p+Vector3(0,2.16,face*0.386),yaw)
        for dx in [-0.405,0.405]:
            for y in [1.14,2.15,3.18]:sphere(Vector3(0.015,0.015,0.008),p+Vector3(float(dx),float(y),face*0.39),metal)
    for side in [-1.0,1.0]:picture("pylon_exit_a_v61.svg" if side>0.0 else "pylon_exit_b_v61.svg",Vector2(0.65,2.01),p+Vector3(side*0.451,2.16,0),side*PI/2.0)
    _round_box(Vector3(0.91,0.48,0.80),p+Vector3(0,3.53,0),body,0.08)
    for face in [-1.0,1.0]:
        for i in range(14):box(Vector3(0.018,0.35,0.014),p+Vector3(-0.40+float(i)*0.062,3.56,face*0.405),dark)
        sphere(Vector3(0.10,0.10,0.016),p+Vector3(0,3.43,face*0.417),black)
    # Split chrome surrounding rail curls up from the central pedestal.
    for side in [-1.0,1.0]:
        var points: Array[Vector3]=[p+Vector3(side*0.15,0.09,-0.20),p+Vector3(side*0.15,0.76,-0.20)]
        for i in range(13):
            var a: float=float(i)*PI/24.0
            points.append(p+Vector3(side*(0.15+0.28*(1.0-cos(a))),0.76+0.28*sin(a),-0.20-0.20*sin(a)))
        points.append(p+Vector3(side*0.64,1.04,-0.40))
        for i in range(17):
            var a: float=-PI/2.0+float(i)*PI/16.0
            points.append(p+Vector3(side*(0.64+0.18*cos(a)),1.04,0.40*sin(a)))
        points.append(p+Vector3(side*0.43,1.04,0.40));points.append(p+Vector3(side*0.15,0.76,0.20));points.append(p+Vector3(side*0.15,0.09,0.20))
        for i in range(points.size()-1):rod(points[i],points[i+1],0.025,metal)
    picture("pylon_voltage_v61.svg",Vector2(0.12,0.085),p+Vector3(0,0.18,0.252),0.0)
    if television:_television(z)

func _television(z: float) -> void:
    var p := Vector3(CX,FY+4.15,z)
    _round_box(Vector3(1.63,0.97,0.16),p,black,0.025)
    rod(Vector3(CX,FY+3.76,z),Vector3(CX,FY+4.70,z),0.035,metal)
    for face in [-1.0,1.0]:
        var q := QuadMesh.new();q.size=Vector2(1.55,0.872);q.material=_advert
        var n := MeshInstance3D.new();n.name="AnimatedPylonTelevision";n.mesh=q;n.position=p+Vector3(0,0,face*0.086);n.rotation.y=0.0 if face>0.0 else PI
        n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(n)

func _island_bench(z: float) -> void:
    var p := Vector3(CX,FY,z)
    var base := _material(Color("#463b32"),0.15,0.58)
    box(Vector3(1.00,0.39,2.88),p+Vector3(0,0.195,0),base)
    for i in range(6):
        var zz: float=z-1.215+float(i)*0.486
        _round_box(Vector3(1.10,0.105,0.454),Vector3(CX,FY+0.45,zz),timber,0.025)
        for dx in [-0.33,0.0,0.33]:box(Vector3(0.008,0.005,0.448),Vector3(CX+float(dx),FY+0.505,zz),base)
        if i<5:box(Vector3(1.12,0.055,0.024),Vector3(CX,FY+0.47,zz+0.243),base)

func _portal_equipment() -> void:
    var infra := get_node("StationInfrastructure");infra.set("_amber",Color(1.0,0.13,0.055))
    var displays: Array=infra.get("_displays")
    for display in displays:
        for i in range(70,76):display.set_instance_color(i,Color(1.0,0.13,0.055))
    for node in infra.get_children():
        if node is Node3D and "Portal" in str(node.name):
            node.position.y=4.35
            node.position.z=NORTH+0.20 if "Portal1" in str(node.name) else SOUTH-0.20
    for direction in [-1.0,1.0]:
        var end: float=NORTH if direction<0.0 else SOUTH
        var start: float=NORTH if direction<0.0 else SOUTH
        for side in [-1.0,1.0]:
            var tx: float=CX+side*6.362
            box(Vector3(3.95,0.68,0.30),Vector3(tx,4.35,end),plaster)
            var root := Node3D.new();root.name="WhiteBlueDriverMirror";root.position=Vector3(CX+side*4.54,FY+1.39,end-direction*2.5);root.rotation.y=(0.0 if direction<0.0 else PI)-side*0.12;add_child(root)
            var mirror := MeshInstance3D.new();mirror.set_script(preload("res://modules/stations/park_chelyuskintsev/driver_mirrors.gd"));mirror.name="ReflectingSurface";mirror.position.z=0.016
            var q := QuadMesh.new();q.size=Vector2(0.56,1.54);mirror.mesh=q;mirror.set_meta("mirror_size",q.size);root.add_child(mirror)
            var pts: Array[Vector3]=[]
            for corner in range(4):
                var c := Vector2(0.215*(1.0 if corner in [0,3] else -1.0),0.69*(1.0 if corner in [0,1] else -1.0))
                for j in range(9):
                    var a: float=float(corner)*PI/2.0+float(j)*PI/16.0;pts.append(Vector3(c.x+0.10*cos(a),c.y+0.10*sin(a),0))
            for i in range(pts.size()):_local_rod(root,pts[i],pts[(i+1)%pts.size()],0.030,white)
            _local_rod(root,Vector3(0,-1.39,0),Vector3(0,-0.80,0),0.065,_material(Color("#1d5688"),0.3,0.44))
            for dx in [-0.39,0.39]:_local_rod(root,Vector3(float(dx),-1.39,0),Vector3(float(dx),-0.51,0.10),0.023,metal)
            _local_rod(root,Vector3(-0.39,-0.51,0.10),Vector3(0.39,-0.51,0.10),0.023,metal)
            _camera_box(Vector3(CX+side*3.8,4.30,start-direction*0.4),0.0 if direction<0.0 else PI)

func _fittings() -> void:
    for z in [5.2,34.5,62.8,78.0]:
        cylinder(0.17,0.014,Vector3(CX+0.54,FY+0.013,float(z)),dark_stone)
        for i in range(7):box(Vector3(0.012,0.02,0.23),Vector3(CX+0.45+float(i)*0.03,FY+0.023,float(z)),black)
        box(Vector3(0.30,0.014,0.30),Vector3(CX-0.52,FY+0.014,float(z)+2.1),dark_stone)
        for i in range(8):box(Vector3(0.014,0.02,0.26),Vector3(CX-0.63+float(i)*0.03,FY+0.023,float(z)+2.1),black)
    for side in [-1.0,1.0]:
        for z in [17.0,47.0,77.0]:box(Vector3(0.30,0.13,0.33),Vector3(CX+side*8.47,0.12,float(z)),black)
func _photo_stone(file: String,tint: Color,slab: Vector2,roughness: float,joints: bool=true) -> ShaderMaterial:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
uniform sampler2D stone_tex : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 tint : source_color;uniform vec2 slab=vec2(1.2,0.6);uniform float roughness=0.35;uniform bool joints=true;
varying vec3 p;varying vec3 n;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;n=abs(MODEL_NORMAL_MATRIX*NORMAL);}
float h(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}
void fragment(){vec2 q=n.x>0.5?p.zy:n.y>0.5?p.xz:p.xy;
vec2 cell=floor(q/slab);float v=h(cell);vec2 uv=q/slab+vec2(v,v*0.71);
vec3 c=texture(stone_tex,uv).rgb*0.73+texture(stone_tex,q/slab*0.61+vec2(0.21,0.17)).rgb*0.27;
vec2 f=fract(q/slab);float seam=1.0-smoothstep(0.001,0.003,min(min(f.x,1.0-f.x),min(f.y,1.0-f.y)));
ALBEDO=c*tint.rgb*(0.97+v*0.06)-vec3(joints?seam*0.043:0.0);ROUGHNESS=roughness+v*0.055;SPECULAR=0.63;}
"""
    var mat := ShaderMaterial.new();mat.shader=shader
    mat.set_shader_parameter("stone_tex",load(ART+file));mat.set_shader_parameter("tint",tint)
    mat.set_shader_parameter("slab",slab);mat.set_shader_parameter("roughness",roughness);mat.set_shader_parameter("joints",joints)
    return mat


func _round_box(size: Vector3,p: Vector3,mat: Material,radius: float=0.03) -> void:
    var r: float=minf(radius,minf(size.x,size.y)*0.49)
    var pts := PackedVector2Array()
    for corner in range(4):
        var center := Vector2(p.x+(size.x*0.5-r)*(1.0 if corner in [0,3] else -1.0),p.y+(size.y*0.5-r)*(1.0 if corner in [0,1] else -1.0))
        for j in range(7):
            var a: float=float(corner)*PI/2.0+float(j)*PI/12.0;pts.append(center+Vector2(cos(a),sin(a))*r)
    extrusion(pts,p.z-size.z*0.5,p.z+size.z*0.5,mat)


func _advert_material() -> void:
    var shader := Shader.new()
    shader.code="""shader_type spatial;render_mode unshaded,cull_disabled;
uniform sampler2D cards : source_color,filter_linear_mipmap,repeat_disable;
uniform float phase=0.0;
void fragment(){float t=(TIME+phase)/7.0;float card=mod(floor(t),3.0);float next=mod(card+1.0,3.0);float f=fract(t);float blend=smoothstep(0.82,1.0,f);
vec3 a=texture(cards,vec2((UV.x+card)/3.0,UV.y)).rgb;vec3 b=texture(cards,vec2((UV.x+next)/3.0,UV.y)).rgb;
vec3 c=mix(a,b,blend);
// Moving glint and a travelling lower progress bar make this an actual animation.
float sweep=pow(max(0.0,1.0-abs(UV.x+UV.y*0.18-mod(TIME*0.13,1.6)+0.18)*8.0),8.0)*0.10;
float bar=step(0.973,UV.y)*(1.0-step(f,UV.x));ALBEDO=c+vec3(sweep)+bar*vec3(0.24,0.50,0.42);}
"""
    _advert=ShaderMaterial.new();_advert.shader=shader;_advert.set_shader_parameter("cards",load(ART+"advert_atlas.svg"))


func _track_details() -> void:
    for name in ["Track1","Track2"]:
        var root := get_node(name)
        (root.get_node("Beds") as MultiMeshInstance3D).multimesh.mesh.material=_material(Color("#34322c"),0.0,0.92)
        (root.get_node("Sleepers") as MultiMeshInstance3D).multimesh.mesh.material=_material(Color("#3b3730"),0.0,0.91)
        var x: float=0.992 if name=="Track1" else -11.732
        for i in range(161):
            var z: float=ZA+float(i)*0.65
            for dx in [-0.8075,0.8075]:box(Vector3(0.21,0.025,0.15),Vector3(x+float(dx),-0.11,z),black)
        for direction in [-1.0,1.0]:
            var end: float=NORTH if direction<0.0 else SOUTH
            var length := 18.1
            box(Vector3(3.78,0.20,length),Vector3(x,4.02,end+direction*length*0.5),stair_wall)
            for side in [-1.0,1.0]:
                box(Vector3(0.14,4.10,length),Vector3(x+side*1.94,1.96,end+direction*length*0.5),stair_wall)
                for h in [0.70,1.1,1.5,1.9,2.35,2.65]:rod(Vector3(x+side*1.84,float(h),end),Vector3(x+side*1.84,float(h),end+direction*(length-0.20)),0.015,black)
            box(Vector3(3.85,4.10,0.10),Vector3(x,1.96,end+direction*length),black)


func _local_rod(parent: Node3D,a: Vector3,b: Vector3,r: float,mat: Material) -> void:
    var mesh := CylinderMesh.new();mesh.top_radius=r;mesh.bottom_radius=r;mesh.height=a.distance_to(b);mesh.radial_segments=10;mesh.material=mat
    var n := MeshInstance3D.new();n.mesh=mesh;n.position=(a+b)*0.5
    var d := (b-a).normalized();var axis := Vector3.UP.cross(d)
    if axis.length_squared()>0.00001:n.basis=Basis(axis.normalized(),Vector3.UP.angle_to(d))
    parent.add_child(n)


func _camera_box(p: Vector3,yaw: float) -> void:
    var b := Basis(Vector3.UP,yaw)
    box(Vector3(0.17,0.13,0.30),p,white,b)
    box(Vector3(0.19,0.02,0.34),p+Vector3(0,0.09,0),white,b)
    sphere(Vector3(0.075,0.075,0.015),p+b*Vector3(0,0,0.16),black)
    rod(p+Vector3(0,0.1,0),p+Vector3(0,0.3,0),0.014,metal)


func _stairs(direction: float,start: float) -> void:
    var width := 7.35
    var rise := 0.1125
    var run := 0.285
    var landing := 0.90
    var top_y: float=FY+36.0*rise
    for i in range(36):
        var height: float=float(i+1)*rise
        var z: float=start+direction*(float(i)*run+(landing if i>=20 else 0.0))
        box(Vector3(width,height,run+0.002),Vector3(CX,FY+height*0.5,z),stair_stone)
        if i in [0,19,20,35]:box(Vector3(width,0.016,0.05),Vector3(CX,FY+height+0.009,z-direction*0.12),yellow)
    box(Vector3(width,0.18,landing),Vector3(CX,FY+20.0*rise-0.09,start+direction*6.0),stair_stone)
    var finish: float=start+direction*(35.0*run+landing+run*0.5)
    box(Vector3(width+0.3,0.22,4.0),Vector3(CX,top_y-0.11,finish+direction*1.95),stair_wall)
    var ceiling := 7.78
    for side in [-1.0,1.0]:
        var x: float=CX+side*(width*0.5+0.11)
        box(Vector3(0.22,ceiling-FY,15.2),Vector3(x,(ceiling+FY)*0.5,start+direction*7.35),stair_wall)
        var points: Array[Vector2]=[Vector2(-0.20,0.0),Vector2(5.56,2.25),Vector2(6.46,2.25),Vector2(11.02,4.05)]
        for i in range(points.size()-1):
            var a: Vector2=points[i];var b: Vector2=points[i+1]
            rod(Vector3(x-side*0.15,FY+a.y+0.82,start+direction*a.x),Vector3(x-side*0.15,FY+b.y+0.82,start+direction*b.x),0.026,metal)
        # Low stainless return on the front of each marble pier.
        for j in range(10):
            var a: float=float(j)*PI/10.0;var b: float=float(j+1)*PI/10.0
            rod(Vector3(x-side*0.16,FY+0.83-0.17*sin(a),start-direction*(0.20+0.17*cos(a))),Vector3(x-side*0.16,FY+0.83-0.17*sin(b),start-direction*(0.20+0.17*cos(b))),0.026,metal)
        picture("no_smoking.svg",Vector2(0.23,0.23),Vector3(x,FY+1.72,start-direction*0.30),0.0 if direction<0.0 else PI)
        picture("sos_info.svg",Vector2(0.29,0.45),Vector3(x,FY+0.83,start-direction*0.302),0.0 if direction<0.0 else PI)
    box(Vector3(width+0.5,0.16,15.3),Vector3(CX,ceiling+0.08,start+direction*7.35),white)
    for i in range(12):
        var z: float=start+direction*(float(i)*1.3)
        box(Vector3(width,0.23,0.14),Vector3(CX,ceiling-0.12,z),white)
        if i%2==0:box(Vector3(5.80,0.045,0.075),Vector3(CX,ceiling-0.26,z+0.22),glow)
    board("exit_north_v61.svg" if direction<0.0 else "exit_south_v61.svg",Vector3(CX,5.50,start-direction*0.43),Vector2(5.85,0.85))
    foot_grille(start-direction*0.45,7.45)
    var back: float=finish+direction*3.7
    box(Vector3(width+0.4,2.55,0.20),Vector3(CX,top_y+1.275,back),stair_wall)
    for i in range(7):
        var x: float=CX-2.70+float(i)*0.90
        box(Vector3(0.24,0.92,0.95),Vector3(x,top_y+0.46,finish+direction*2.0),metal)
        rod(Vector3(x,top_y+0.69,finish+direction*1.72),Vector3(x+0.40,top_y+0.69,finish+direction*1.72),0.019,metal)
        box(Vector3(0.23,0.045,0.36),Vector3(x,top_y+0.94,finish+direction*1.95),black)


func _build_chandelier() -> void:
    var shader := Shader.new()
    shader.code="""shader_type spatial;render_mode cull_disabled;
uniform sampler2D glass_tex : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
varying vec3 local_p;
void vertex(){local_p=VERTEX;}
void fragment(){
vec2 q=UV*2.0-1.0;float emboss=sin(q.x*10.0+sin(q.y*6.0)*2.4)*sin(q.y*10.0+cos(q.x*7.0)*1.8);
float rim=smoothstep(0.65,0.98,max(abs(q.x),abs(q.y)));
vec3 measured=texture(glass_tex,UV2).rgb;
vec3 amber=measured*(0.94+emboss*0.12)+vec3(rim*0.06);
ALBEDO=amber;METALLIC=0.15;ROUGHNESS=0.20+0.08*abs(emboss);SPECULAR=0.8;
EMISSION=amber*(0.42+0.26*(1.0-rim));
NORMAL_MAP=normalize(vec3(cos(q.x*10.0+sin(q.y*6.0))*0.23,sin(q.y*10.0+cos(q.x*7.0))*0.23,1.0))*0.5+0.5;
}
"""
    var glass := ShaderMaterial.new();glass.shader=shader;glass.set_shader_parameter("glass_tex",load(ART+"chandelier_glass.jpg"))
    var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var shades := [Color("#c89231"),Color("#a3651b"),Color("#e4be5a"),Color("#c3b582")]
    # Eight concentric rows of tapered radial glass blocks; side faces carry the relief too.
    for ring in range(8):
        var r0: float=0.12+float(ring)*0.136
        var r1: float=r0+0.128
        var y0: float=-0.28+0.50*pow(r0/1.2,1.45)
        var y1: float=-0.28+0.50*pow(r1/1.2,1.45)
        var count: int=24+ring*8
        for j in range(count):
            var a: float=(float(j)+0.035)*TAU/float(count)
            var b: float=(float(j)+0.965)*TAU/float(count)
            var v: Array[Vector3]=[
                Vector3(sin(a)*r0,y0,cos(a)*r0),Vector3(sin(b)*r0,y0,cos(b)*r0),
                Vector3(sin(b)*r1,y1,cos(b)*r1),Vector3(sin(a)*r1,y1,cos(a)*r1)]
            for k in range(4):v.append(v[k]+Vector3(0,0.065,0))
            var faces := [[0,1,2,3],[4,7,6,5],[0,4,5,1],[3,2,6,7],[0,3,7,4],[1,5,6,2]]
            for face in faces:
                var normal: Vector3=(v[face[1]]-v[face[0]]).cross(v[face[2]]-v[face[0]]).normalized()
                for index in [0,1,2,0,2,3]:
                    st.set_color(shades[(j+ring)%shades.size()])
                    st.set_normal(normal)
                    st.set_uv([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN][index])
                    st.set_uv2(Vector2(v[face[index]].x/2.46+0.5,v[face[index]].z/2.46+0.5))
                    st.add_vertex(v[face[index]])
    st.generate_tangents()
    var mesh := st.commit();mesh.surface_set_material(0,glass);_chandelier_meshes.append(mesh)


func _chandelier(z: float) -> void:
    var center := Vector3(CX,7.42,z)
    instance_mesh("RadialCastGlassChandeliers",_chandelier_meshes[0],center)
    cylinder(0.39,0.27,center+Vector3(0,0.50,0),white)
    annulus(center,0.05,0.14,-0.30,-0.28,brass)
    for ring in range(8):
        var radius: float=0.12+float(ring)*0.136
        var y: float=-0.27+0.50*pow(radius/1.2,1.45)
        annulus(center,radius-0.007,radius+0.007,y,y,brass)
    annulus(center,1.20,1.225,0.23,0.23,brass)
    for j in range(48):
        var a: float=float(j)*TAU/48.0
        var previous := center+Vector3(sin(a)*0.12,-0.27,cos(a)*0.12)
        for ring in range(1,9):
            var r: float=0.12+float(ring)*0.136
            var next := center+Vector3(sin(a)*r,-0.27+0.50*pow(r/1.2,1.45),cos(a)*r)
            rod(previous,next,0.006,brass);previous=next
