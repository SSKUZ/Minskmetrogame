extends "res://modules/stations/park_chelyuskintsev/station_builder.gd"
## Owner-photo refinement: continuous end masonry, recessed bronze fittings and cast-glass lights.
const ART := "res://modules/stations/park_chelyuskintsev/art/"
const P := preload("res://modules/stations/park_chelyuskintsev/interior_profile.gd")
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
var _side_glass_meshes: Array[Mesh]=[]
var niche_plaster: ShaderMaterial
var soffit_plaster: ShaderMaterial
var tunnel_concrete: ShaderMaterial
var cage_metal: Material
var _mineral_profiles: Dictionary={}

func _ready() -> void:
    super._ready()
    begin_station()
    white.albedo_color=Color("#e8e8df")
    metal=_satin_metal(Color("#a8aaa5"),0.27)
    brass=_satin_metal(Color("#786b4c"),0.38)
    cage_metal=_satin_metal(Color("#40382b"),0.42)
    glow.albedo_color=Color("#fffdf7");glow.emission=Color(1.0,0.99,0.95)
    glow.emission_energy_multiplier=2.25
    yellow=_material(Color("#d9b24b"),0.0,0.64)
    dark_stone=_mineral_finish("wall_lower")
    dark_stone.set_shader_parameter("staggered",true)
    stair_wall=_mineral_finish("stair_wall")
    stair_stone=_mineral_finish("stair_tread")
    plaster=_plaster(Color(0.96,0.96,0.93))
    vault_field=_plaster(Color(0.87,0.88,0.86))
    niche_plaster=_plaster(Color(0.77,0.78,0.75))
    soffit_plaster=_plaster(Color(0.66,0.67,0.64))
    tunnel_concrete=_photo_stone("vault_plaster.jpg",Color(0.66,0.65,0.60),Vector2(2.5,1.2),0.93,false)
    _hall_lighting()
    construction_group="PlatformFinish";_floor();_edges()
    construction_group="TrackWalls";_walls()
    _build_chandelier();_vault()
    construction_group="NorthStair";_stairs(-1.0,NORTH)
    construction_group="SouthStair";_stairs(1.0,SOUTH)
    construction_group="NorthEndMasonry";_end_arch(-1.0,NORTH)
    construction_group="SouthEndMasonry";_end_arch(1.0,SOUTH)
    construction_group="Trackwork";_track_details()
    construction_group="PortalEquipment";_portal_equipment();_advert_material()
    for i in range(3):
        construction_group="InformationPylon%02d"%i
        _pylon(12.0+float(i)*27.6,i!=0)
    for i in range(2):
        construction_group="IslandBench%02d"%i
        _island_bench([25.8,53.4][i])
    construction_group="PlatformFittings";_fittings()
    flush()

func _plaster(tint: Color) -> ShaderMaterial:
    var mat := ShaderMaterial.new()
    mat.shader=preload("res://modules/stations/park_chelyuskintsev/materials/plaster.gdshader")
    mat.set_shader_parameter("plaster_tex",load(ART+"vault_plaster.jpg"))
    mat.set_shader_parameter("tint",tint)
    mat.resource_name="MineralPlaster"
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
    var edge := _mineral_finish("platform_edge")
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
            var z: float=ZA+float(i)*P.BAY_PITCH;var end: float=minf(z+P.BAY_PITCH,ZB)
            var a: float=z+P.RIB_HALF_WIDTH;var b: float=end-P.RIB_HALF_WIDTH
            if b>a:
                box(Vector3(0.45,0.30,b-a),Vector3(x-side*0.07,2.12,(a+b)*0.5),dark_stone)
                box(Vector3(0.09,0.94,b-a-0.04),Vector3(x-side*0.15,2.83,(a+b)*0.5),plaster)
                # A very shallow relief and dark underside give the white panel a physical edge.
                box(Vector3(0.025,0.018,b-a-0.04),Vector3(x-side*0.205,2.35,(a+b)*0.5),niche_plaster)
            box(Vector3(0.45,0.12,P.RIB_HALF_WIDTH*2.0),Vector3(x-side*0.07,2.03,z),dark_stone)
        box(Vector3(0.25,0.045,ZB-ZA),Vector3(x-side*0.01,3.215,MID),plaster)
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
    # Neutral broad fill plus two shadow-casting key lights, scoped to this station.
    for child in get_children():
        if child is OmniLight3D:
            child.position.y=6.25
            child.light_color=Color(1.0,0.985,0.95)
            child.light_energy=1.72
            child.omni_range=17.5
            child.omni_attenuation=0.72
            child.shadow_enabled=false
    for i in range(P.SHADOW_LIGHT_Z.size()):
        var light := SpotLight3D.new()
        light.name="CentralShadowLight%02d"%i
        light.position=Vector3(CX,6.72,P.SHADOW_LIGHT_Z[i])
        light.rotation_degrees.x=-90.0
        light.spot_range=24.0;light.spot_angle=68.0;light.spot_attenuation=0.65
        light.light_color=Color(1.0,0.985,0.95);light.light_energy=1.55
        light.shadow_enabled=true;light.shadow_bias=0.025;light.shadow_normal_bias=0.12
        add_child(light)

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
    # Each bay retains its own native meshes, materials and local hierarchy.
    for i in range(18):
        var rib: float=ZA+float(i)*P.BAY_PITCH
        var z: float=maxf(NORTH,rib)
        var end: float=minf(SOUTH,rib+P.BAY_PITCH)
        if end<=z:continue
        construction_group="VaultBay%02d"%i
        for side in [-1.0,1.0]:
            curved_band(float(side),0.0,1.314,z,end,3.20,4.48,0.0,vault_field)
            if rib>=NORTH and rib<=SOUTH:
                _recessed_rib(float(side),rib)
                _side_lantern(float(side),rib)
            # Cove has a recessed luminous diffuser and an opaque cut-off lip.
            box(Vector3(0.055,0.040,end-z),Vector3(CX+side*2.235,7.57,(z+end)*0.5),glow)
            box(Vector3(0.042,0.075,end-z),Vector3(CX+side*2.255,7.515,(z+end)*0.5),plaster)
        _central_vault(z,end)
        var lamp_z: float=rib+3.0
        if lamp_z>z+0.8 and lamp_z<end-0.8:_chandelier(lamp_z)

func _side_lantern(side: float,z: float) -> void:
    # Five glass columns, eleven rows, a separate dark cage, and upright clear end panes.
    if _side_glass_meshes.is_empty():
        for i in range(3):
            var mat := ShaderMaterial.new()
            mat.shader=preload("res://modules/stations/park_chelyuskintsev/materials/cast_glass.gdshader")
            mat.set_shader_parameter("glass_tex",load(ART+"side_glass.jpg"))
            mat.set_shader_parameter("sample_scale",Vector2(0.18,0.075))
            mat.set_shader_parameter("sample_offset",Vector2([0.02,0.26,0.72][i],0.35))
            mat.set_shader_parameter("emission_level",0.46 if i!=1 else 0.23)
            mat.set_shader_parameter("glass_tint",[Color(1.0,0.97,0.83),Color(0.72,0.76,0.73),Color(1.0,1.0,0.95)][i])
            mat.resource_name="SideCastGlass%02d"%i
            _side_glass_materials.append(mat)
            var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
            var footprint: Array[Vector2]=[Vector2(-0.070,-0.047),Vector2(0.070,-0.047),Vector2(0.070,0.047),Vector2(-0.070,0.047)]
            _glass_prism(st,footprint,0.0,0.0,0.060,0.007,false)
            st.generate_tangents()
            var mesh := st.commit();mesh.surface_set_material(0,mat)
            _side_glass_meshes.append(mesh)
    for row in range(11):
        var a: float=1.105+float(row)*0.0185
        var point := arc_point(side,a,3.20,4.48,0.070)
        var tangent := Vector3(-side*8.98*sin(a),4.48*cos(a),0).normalized()
        var inward := Vector3(-side*cos(a)/8.98,-sin(a)/4.48,0).normalized()
        var basis := Basis(tangent,inward,tangent.cross(inward))
        for col in range(5):
            var variant: int=0 if col in [0,4] else 2 if col==2 else 1
            instance_mesh("SideCastGlass%02d"%variant,_side_glass_meshes[variant],Vector3(point.x,point.y,z+(float(col)-2.0)*0.105),basis)
        rod(Vector3(point.x,point.y,z-0.29),Vector3(point.x,point.y,z+0.29),0.006,cage_metal)
    for col in range(6):
        var zz: float=z+(float(col)-2.5)*0.105
        for j in range(20):
            var a := arc_point(side,1.096+float(j)*0.205/20.0,3.20,4.48,0.073)
            var b := arc_point(side,1.096+float(j+1)*0.205/20.0,3.20,4.48,0.073)
            rod(Vector3(a.x,a.y,zz),Vector3(b.x,b.y,zz),0.006,cage_metal)
    var tip := arc_point(side,1.297,3.20,4.48,0.065)
    for col in range(5):
        # Rotate the same bevelled glass upright without projecting plaster onto the panes.
        var basis := Basis(Vector3(0,1,0),Vector3(-side,0,0),Vector3(0,0,side))
        var variant: int=2 if col in [1,2,3] else 0
        instance_mesh("UprightCastGlass%02d"%variant,_side_glass_meshes[variant],Vector3(tip.x,tip.y+0.08,z+(float(col)-2.0)*0.105),basis*Basis.from_scale(Vector3(2.0,1.0,1.0)))
    for col in range(6):
        var zz: float=z+(float(col)-2.5)*0.105
        rod(Vector3(tip.x,tip.y-0.07,zz),Vector3(tip.x,tip.y+0.23,zz),0.006,cage_metal)
    for h in [-0.07,0.23]:rod(Vector3(tip.x,tip.y+float(h),z-0.27),Vector3(tip.x,tip.y+float(h),z+0.27),0.006,cage_metal)

func _end_arch(direction: float,start: float) -> void:
    _end_masonry(direction,start)
    for side in [-1.0,1.0]:
        box(Vector3(0.797,2.99,0.55),Vector3(CX+side*4.0735,FY+1.495,start-direction*0.07),stair_wall)
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
    var base := _satin_metal(Color("#2c2823"),0.64)
    # Solid dark pedestals support a slightly dished, rounded wooden seat.
    for dz in [-0.94,0.94]:
        _rounded_plan_box(Vector3(0.76,0.39,0.36),p+Vector3(0,0.195,float(dz)),base,0.045)
        box(Vector3(0.72,0.018,0.33),p+Vector3(0,0.015,float(dz)),black)
    box(Vector3(0.70,0.065,2.57),p+Vector3(0,0.375,0),base)
    for i in range(12):
        var x: float=-0.505+float(i)*0.092
        var edge: float=maxf(0.0,absf(x)-(P.BENCH_WIDTH*0.5-P.BENCH_CORNER_RADIUS))
        var length: float=P.BENCH_LENGTH-2.0*P.BENCH_CORNER_RADIUS+2.0*sqrt(maxf(0.0,P.BENCH_CORNER_RADIUS*P.BENCH_CORNER_RADIUS-edge*edge))
        var y: float=P.BENCH_TOP-0.043*pow(absf(x)/0.55,5.0)
        _rounded_plan_box(Vector3(0.085,0.079,length),p+Vector3(x,y-0.0395,0),timber,0.032)
        for dz in [-0.94,0.94]:
            cylinder(0.0055,0.004,p+Vector3(x,y+0.002,float(dz)),cage_metal)
    # Rolled timber side edges, visible in the end view of photograph 7802.
    for side in [-1.0,1.0]:
        var profile_points := PackedVector2Array()
        for j in range(13):
            var angle: float=float(j)*PI/24.0
            profile_points.append(Vector2(CX+side*(0.49+0.06*sin(angle)),FY+0.43+0.06*cos(angle)))
        profile_points.append(Vector2(CX+side*0.55,FY+0.405))
        profile_points.append(Vector2(CX+side*0.49,FY+0.405))
        extrusion(profile_points,z-1.29,z+1.29,timber)
    var seat := Marker3D.new();seat.name="BenchSeatCentre"
    seat.position=p+Vector3(0,P.BENCH_TOP,0);seat.set_meta("portable_role","seat")
    _construction_root(construction_group).add_child(seat)

func _portal_equipment() -> void:
    var infra := get_node("StationInfrastructure");infra.set("_amber",Color(1.0,0.13,0.055))
    var displays: Array=infra.get("_displays")
    for display in displays:
        for i in range(70,76):display.set_instance_color(i,Color(1.0,0.13,0.055))
    for node in infra.get_children():
        if node is Node3D and "Portal" in str(node.name):
            node.position.y=4.35
            node.position.z=NORTH+0.46 if "Portal1" in str(node.name) else SOUTH-0.46
    for direction in [-1.0,1.0]:
        var end: float=NORTH if direction<0.0 else SOUTH
        var start: float=NORTH if direction<0.0 else SOUTH
        for side in [-1.0,1.0]:
            var tx: float=CX+side*6.362
            box(Vector3(3.95,0.15,0.40),Vector3(tx,4.02,end-direction*0.10),plaster)
            # Track 1 arrives toward -Z; track 2 toward +Z: one mirror at each leading cab stop.
            if side*direction<0.0:_driver_platform_mirror(side,end,direction)
            _camera_box(Vector3(CX+side*3.8,4.30,start-direction*0.4),0.0 if direction<0.0 else PI)

func _driver_platform_mirror(side: float,end: float,direction: float) -> void:
    var root := Node3D.new();root.name="WhiteBlueDriverMirrorTrack1" if side>0.0 else "WhiteBlueDriverMirrorTrack2";root.position=Vector3(CX+side*4.54,FY+1.39,end-direction*2.5);root.rotation.y=(0.0 if direction<0.0 else PI)-side*0.12;add_child(root)
    var mirror := MeshInstance3D.new();mirror.set_script(preload("res://modules/stations/park_chelyuskintsev/driver_mirrors.gd"));mirror.name="ReflectingSurface";mirror.position.z=0.016
    var q := QuadMesh.new();q.size=Vector2(0.56,1.54);mirror.mesh=q;mirror.set_meta("mirror_size",q.size);root.add_child(mirror)
    var pts: Array[Vector3]=[]
    for corner in range(4):
        var c := Vector2(0.215*(1.0 if corner in [0,3] else -1.0),0.69*(1.0 if corner in [0,1] else -1.0))
        for j in range(9):
            var a: float=float(corner)*PI/2.0+float(j)*PI/16.0;pts.append(Vector3(c.x+0.10*cos(a),c.y+0.10*sin(a),0))
    for i in range(pts.size()):_local_rod(root,pts[i],pts[(i+1)%pts.size()],0.030,white)
    _local_rod(root,Vector3(0,-1.39,0),Vector3(0,-0.80,0),0.065,_material(Color("#1d5688"),0.3,0.44))

func _fittings() -> void:
    for z in [5.2,34.5,62.8,78.0]:
        cylinder(0.17,0.014,Vector3(CX+0.54,FY+0.013,float(z)),dark_stone)
        for i in range(7):box(Vector3(0.012,0.02,0.23),Vector3(CX+0.45+float(i)*0.03,FY+0.023,float(z)),black)
        box(Vector3(0.30,0.014,0.30),Vector3(CX-0.52,FY+0.014,float(z)+2.1),dark_stone)
        for i in range(8):box(Vector3(0.014,0.02,0.26),Vector3(CX-0.63+float(i)*0.03,FY+0.023,float(z)+2.1),black)
    for side in [-1.0,1.0]:
        for z in [17.0,47.0,77.0]:box(Vector3(0.30,0.13,0.33),Vector3(CX+side*8.47,0.12,float(z)),black)
func _photo_stone(file: String,tint: Color,slab: Vector2,roughness: float,joints: bool=true) -> ShaderMaterial:
    var mat := ShaderMaterial.new()
    mat.shader=preload("res://modules/stations/park_chelyuskintsev/materials/stone.gdshader")
    mat.set_shader_parameter("stone_tex",load(ART+file));mat.set_shader_parameter("tint",tint)
    mat.set_shader_parameter("slab",slab);mat.set_shader_parameter("roughness",roughness)
    mat.set_shader_parameter("joints",joints)
    mat.resource_name=file.get_basename()
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
    # Reuse the actual Uruchye rail profile, timber ties, clips and bolts locally.
    for label in ["Track1","Track2"]:
        var root := get_node(label)
        for piece in ["Rails","Beds","Sleepers"]:
            (root.get_node(piece) as GeometryInstance3D).hide()
    var trackwork := preload("res://modules/stations/park_chelyuskintsev/trackwork.gd").new()
    trackwork.name="DetailedTrackwork";add_child(trackwork)
    trackwork.build(track_min_z,track_max_z)
    for direction in [-1.0,1.0]:
        construction_group="NorthTunnelThroats" if direction<0.0 else "SouthTunnelThroats"
        var end: float=NORTH if direction<0.0 else SOUTH
        for tx in [0.992,-11.732]:_tunnel_lining(float(tx),direction,end)

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
    var width: float=P.STAIR_HALF_WIDTH*2.0
    var rise: float=P.STAIR_RISE
    var run: float=P.STAIR_RUN
    var landing: float=P.STAIR_LANDING
    var top_y: float=FY+36.0*rise
    for i in range(36):
        var height: float=float(i+1)*rise
        var z: float=start+direction*(float(i)*run+(landing if i>=20 else 0.0))
        box(Vector3(width,height,run+0.002),Vector3(CX,FY+height*0.5,z),stair_stone)
        if i in [0,19,20,35]:box(Vector3(width,0.016,0.05),Vector3(CX,FY+height+0.009,z-direction*0.12),yellow)
    box(Vector3(width,0.18,landing),Vector3(CX,FY+20.0*rise-0.09,start+direction*6.0),stair_stone)
    var finish: float=start+direction*(35.0*run+landing+run*0.5)
    box(Vector3(width+0.3,0.22,4.20),Vector3(CX,top_y-0.11,finish+direction*2.05),stair_wall)
    var ceiling := 7.78
    for side in [-1.0,1.0]:
        var x: float=CX+side*(width*0.5+0.11)
        box(Vector3(0.22,ceiling-FY,15.2),Vector3(x,(ceiling+FY)*0.5,start+direction*7.35),stair_wall)
        var points: Array[Vector2]=[Vector2(-0.20,0.0),Vector2(5.56,2.25),Vector2(6.46,2.25),Vector2(11.02,4.05)]
        for i in range(points.size()-1):
            var a: Vector2=points[i];var b: Vector2=points[i+1]
            rod(Vector3(x-side*0.15,FY+a.y+0.82,start+direction*a.x),Vector3(x-side*0.15,FY+b.y+0.82,start+direction*b.x),0.026,metal)
            for j in range(5):
                var t: float=float(j+1)/6.0
                var yy: float=FY+lerpf(a.y,b.y,t)+0.82
                var zz: float=start+direction*lerpf(a.x,b.x,t)
                rod(Vector3(x-side*0.13,yy,zz),Vector3(x-side*0.035,yy-0.08,zz),0.010,metal)
                sphere(Vector3(0.012,0.06,0.06),Vector3(x-side*0.025,yy-0.08,zz),metal)
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
        if i%2==0:
            box(Vector3(5.92,0.085,0.12),Vector3(CX,ceiling-0.23,z+0.22),metal)
            box(Vector3(5.80,0.045,0.075),Vector3(CX,ceiling-0.29,z+0.22),glow)
    board("exit_north_v61.svg" if direction<0.0 else "exit_south_v61.svg",Vector3(CX,5.50,start-direction*0.43),Vector2(5.85,0.85))
    foot_grille(start-direction*0.45,7.45)
    var back: float=finish+direction*3.7
    box(Vector3(width+0.4,2.55,0.20),Vector3(CX,top_y+1.275,back),stair_wall)
    _landing_equipment(direction,finish,top_y)
    _stair_lighting(direction,start)


func _build_chandelier() -> void:
    var glass := ShaderMaterial.new()
    glass.shader=preload("res://modules/stations/park_chelyuskintsev/materials/cast_glass.gdshader")
    glass.set_shader_parameter("glass_tex",load(ART+"chandelier_glass.jpg"))
    glass.set_shader_parameter("emission_level",0.58)
    glass.resource_name="AmberPressedGlass"
    var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Eight stepped concentric tiers, each made from solid glass with a bevelled lower face.
    for ring in range(P.LAMP_RADII.size()-1):
        var r0: float=P.LAMP_RADII[ring]
        var r1: float=P.LAMP_RADII[ring+1]-0.008
        var y0: float=P.LAMP_HEIGHTS[ring]
        var y1: float=P.LAMP_HEIGHTS[ring+1]
        var count: int=24+ring*8
        for j in range(count):
            var a: float=(float(j)+0.045)*TAU/float(count)
            var b: float=(float(j)+0.955)*TAU/float(count)
            var footprint: Array[Vector2]=[Vector2(sin(a)*r0,cos(a)*r0),Vector2(sin(b)*r0,cos(b)*r0),Vector2(sin(b)*r1,cos(b)*r1),Vector2(sin(a)*r1,cos(a)*r1)]
            _glass_prism(st,footprint,y0,y1,P.LAMP_GLASS_THICKNESS,P.LAMP_GLASS_BEVEL,true)
    st.generate_tangents()
    var mesh := st.commit();mesh.surface_set_material(0,glass)
    mesh.resource_name="SteppedBevelledCastGlassBowl";_chandelier_meshes.append(mesh)

func _chandelier(z: float) -> void:
    var center := Vector3(CX,P.LAMP_CENTRE_Y,z)
    instance_mesh("RadialCastGlassChandeliers",_chandelier_meshes[0],center)
    cylinder(0.25,0.30,center+Vector3(0,0.38,0),white)
    cylinder(0.43,0.055,center+Vector3(0,0.21,0),cage_metal)
    cylinder(0.090,0.018,center+Vector3(0,-0.49,0),brass)
    for ring in range(P.LAMP_RADII.size()):
        var radius: float=P.LAMP_RADII[ring]
        var y: float=P.LAMP_HEIGHTS[ring]-0.003
        # Thin metal hoops follow the actual stepped bowl silhouette.
        annulus(center,radius-0.007,radius+0.007,y,y,cage_metal,80)
    for j in range(48):
        var a: float=float(j)*TAU/48.0
        for ring in range(P.LAMP_RADII.size()-1):
            var r0: float=P.LAMP_RADII[ring];var r1: float=P.LAMP_RADII[ring+1]
            var y0: float=P.LAMP_HEIGHTS[ring]-0.006;var y1: float=P.LAMP_HEIGHTS[ring+1]-0.006
            rod(center+Vector3(sin(a)*r0,y0,cos(a)*r0),center+Vector3(sin(a)*r1,y1,cos(a)*r1),0.0045,cage_metal)
    for j in range(8):
        var a: float=float(j)*TAU/8.0
        rod(center+Vector3(sin(a)*0.41,0.21,cos(a)*0.41),center+Vector3(sin(a)*1.24,0.145,cos(a)*1.24),0.008,cage_metal)

func _satin_metal(tint: Color,roughness: float) -> ShaderMaterial:
    var mat := ShaderMaterial.new()
    mat.shader=preload("res://modules/stations/park_chelyuskintsev/materials/satin_metal.gdshader")
    mat.set_shader_parameter("tint",tint);mat.set_shader_parameter("base_roughness",roughness)
    mat.resource_name="BrushedMetal"
    return mat

func _recessed_rib(side: float,z: float) -> void:
    for j in range(64):
        var a: float=float(j)*1.314/64.0
        var b: float=float(j+1)*1.314/64.0
        var hw: float=0.32 if a>1.095 else P.NICHE_HALF_WIDTH
        var outer: float=0.46 if a>1.095 else P.RIB_HALF_WIDTH
        curved_band(side,a,b,z-outer,z-hw,3.20,4.48,P.NICHE_DEPTH,plaster)
        curved_band(side,a,b,z+hw,z+outer,3.20,4.48,P.NICHE_DEPTH,plaster)
        curved_band(side,a,b,z-hw,z+hw,3.20,4.48,0.008,niche_plaster)
        var aa := arc_point(side,a,3.20,4.48,0.008)
        var bb := arc_point(side,b,3.20,4.48,0.008)
        var ai := arc_point(side,a,3.20,4.48,P.NICHE_DEPTH)
        var bi := arc_point(side,b,3.20,4.48,P.NICHE_DEPTH)
        for edge in [-1.0,1.0]:
            var zz: float=z+edge*hw
            quad(Vector3(aa.x,aa.y,zz),Vector3(bb.x,bb.y,zz),Vector3(bi.x,bi.y,zz),Vector3(ai.x,ai.y,zz),plaster,Vector3(0,0,-edge))
    # Four narrow square-section bronze bars with transverse ties, inside the recess.
    for col in range(4):
        var zz: float=z+(float(col)-1.5)*0.046
        for j in range(56):
            var a := arc_point(side,0.05+float(j)*1.055/56.0,3.20,4.48,0.031)
            var b := arc_point(side,0.05+float(j+1)*1.055/56.0,3.20,4.48,0.031)
            var pa := Vector3(a.x,a.y,zz);var pb := Vector3(b.x,b.y,zz)
            var tangent := (pb-pa).normalized()
            var normal := Vector3(-side*cos(0.05+float(j)*1.055/56.0)/8.98,-sin(0.05+float(j)*1.055/56.0)/4.48,0).normalized()
            box(Vector3(pa.distance_to(pb)+0.002,0.012,0.012),(pa+pb)*0.5,brass,Basis(tangent,normal,tangent.cross(normal)))
    for j in range(7):
        var a: float=0.13+float(j)*0.145
        var p := arc_point(side,a,3.20,4.48,0.032)
        rod(Vector3(p.x,p.y,z-0.105),Vector3(p.x,p.y,z+0.105),0.005,cage_metal)
    var wall_x: float=CX+side*8.70
    for col in range(4):
        var zz: float=z+(float(col)-1.5)*0.046
        box(Vector3(0.012,0.66,0.012),Vector3(wall_x,2.93,zz),brass)
        rod(Vector3(wall_x,3.26,zz),Vector3(CX+side*8.94,3.36,zz),0.005,brass)
    for h in [2.66,3.17]:rod(Vector3(wall_x,float(h),z-0.105),Vector3(wall_x,float(h),z+0.105),0.005,cage_metal)
    # Curved white returns rise into the central cove on either side of the glass.
    var cheek := PackedVector2Array()
    for j in range(17):
        var a: float=float(j)*PI/32.0
        cheek.append(Vector2(CX+side*(2.30-0.48*(1.0-cos(a))),7.53+0.44*sin(a)))
    for j in range(16,-1,-1):
        var a: float=float(j)*PI/32.0
        cheek.append(Vector2(CX+side*(2.30-0.48*(1.0-cos(a))),7.53+0.44*sin(a)+0.075))
    for edge in [-1.0,1.0]:extrusion(cheek,z+edge*0.36-0.026,z+edge*0.36+0.026,plaster)

func _vault_top(x: float) -> float:
    if absf(x)<=2.28:return _central_height(x)
    return 3.20+4.48*sqrt(maxf(0.0,1.0-pow(x/P.VAULT_RADIUS,2.0)))

func _end_masonry(direction: float,start: float) -> void:
    # Continuous closed wall: crown, stair arch, piers, and both tunnel spandrels.
    # Each horizontal span is bounded by the photographed opening below and the vault above.
    var ranges := [Vector2(-8.98,-8.252),Vector2(-8.252,-4.472),Vector2(-4.472,-3.675),Vector2(-3.675,3.675),Vector2(3.675,4.472),Vector2(4.472,8.252),Vector2(8.252,8.98)]
    var front: float=start-direction*0.32
    var back: float=front+direction*P.END_WALL_DEPTH
    for span in range(ranges.size()):
        var limits: Vector2=ranges[span]
        var pieces: int=maxi(4,int(ceil((limits.y-limits.x)/0.085)))
        for i in range(pieces):
            var xa: float=lerpf(limits.x,limits.y,float(i)/float(pieces))
            var xb: float=lerpf(limits.x,limits.y,float(i+1)/float(pieces))
            var ba: float=_opening_top(xa,span);var bb: float=_opening_top(xb,span)
            var ta: float=_vault_top(xa)+0.035;var tb: float=_vault_top(xb)+0.035
            var a := Vector3(CX+xa,ba,front);var b := Vector3(CX+xb,bb,front)
            var c := Vector3(CX+xb,tb,front);var d := Vector3(CX+xa,ta,front)
            var offset := Vector3(0,0,back-front)
            quad(a,b,c,d,plaster,Vector3(0,0,-direction))
            quad(a+offset,d+offset,c+offset,b+offset,plaster,Vector3(0,0,direction))
            quad(a,a+offset,b+offset,b,soffit_plaster,Vector3.DOWN)
            quad(d,c,c+offset,d+offset,plaster,Vector3.UP)
            if i==0 or i==pieces-1:
                var aa: Vector3=a if i==0 else b
                var dd: Vector3=d if i==0 else c
                quad(aa,dd,dd+offset,aa+offset,plaster)
    # Deep stair soffit joins the lintel and makes its thickness visible from below.
    for i in range(64):
        var xa: float=-P.STAIR_HALF_WIDTH+float(i)*P.STAIR_HALF_WIDTH/32.0
        var xb: float=-P.STAIR_HALF_WIDTH+float(i+1)*P.STAIR_HALF_WIDTH/32.0
        var ya: float=_opening_top(xa,3);var yb: float=_opening_top(xb,3)
        quad(Vector3(CX+xa,ya,front),Vector3(CX+xb,yb,front),Vector3(CX+xb,yb,back+direction*0.45),Vector3(CX+xa,ya,back+direction*0.45),soffit_plaster,Vector3.DOWN)
    # Real stair lintel fittings: linear board light, cable conduit and vent grille.
    box(Vector3(5.90,0.055,0.09),Vector3(CX,6.02,front-direction*0.025),metal)
    box(Vector3(5.70,0.025,0.055),Vector3(CX,6.00,front-direction*0.077),glow)
    for dx in [-0.20,-0.12,-0.04,0.04,0.12,0.20]:
        box(Vector3(0.038,0.012,0.24),Vector3(CX+float(dx),4.89,back-direction*0.14),cage_metal)

func _opening_top(x: float,span: int) -> float:
    if span==3:return 4.30+0.60*sqrt(maxf(0.0,1.0-pow(x/P.STAIR_HALF_WIDTH,2.0)))
    if span in [1,5]:return P.PORTAL_TOP
    return FY

func _rounded_plan_box(size: Vector3,p: Vector3,mat: Material,radius: float) -> void:
    var r: float=minf(radius,minf(size.x,size.z)*0.49)
    var loop: Array[Vector2]=[]
    for corner in range(4):
        var center := Vector2((size.x*0.5-r)*(1.0 if corner in [0,3] else -1.0),(size.z*0.5-r)*(1.0 if corner in [0,1] else -1.0))
        for j in range(7):
            var a: float=float(corner)*PI/2.0+float(j)*PI/12.0
            loop.append(center+Vector2(cos(a),sin(a))*r)
    var bevel: float=minf(0.012,size.y*0.20)
    var lower: float=p.y-size.y*0.5;var upper: float=p.y+size.y*0.5
    for j in range(loop.size()):
        var aa: Vector2=loop[j];var bb: Vector2=loop[(j+1)%loop.size()]
        var ia := aa*Vector2((size.x-2.0*bevel)/size.x,(size.z-2.0*bevel)/size.z)
        var ib := bb*Vector2((size.x-2.0*bevel)/size.x,(size.z-2.0*bevel)/size.z)
        var a := Vector3(p.x+aa.x,lower+bevel,p.z+aa.y)
        var b := Vector3(p.x+bb.x,lower+bevel,p.z+bb.y)
        var c := Vector3(p.x+bb.x,upper-bevel,p.z+bb.y)
        var d := Vector3(p.x+aa.x,upper-bevel,p.z+aa.y)
        quad(a,b,c,d,mat,Vector3(aa.x,0,aa.y))
        quad(d,c,Vector3(p.x+ib.x,upper,p.z+ib.y),Vector3(p.x+ia.x,upper,p.z+ia.y),mat,Vector3.UP)
        quad(a,Vector3(p.x+ia.x,lower,p.z+ia.y),Vector3(p.x+ib.x,lower,p.z+ib.y),b,mat,Vector3.DOWN)
        triangle(Vector3(p.x,upper,p.z),Vector3(p.x+ia.x,upper,p.z+ia.y),Vector3(p.x+ib.x,upper,p.z+ib.y),mat,Vector3.UP)
        triangle(Vector3(p.x,lower,p.z),Vector3(p.x+ib.x,lower,p.z+ib.y),Vector3(p.x+ia.x,lower,p.z+ia.y),mat,Vector3.DOWN)

func _tunnel_lining(tx: float,direction: float,start: float) -> void:
    var length := 18.1
    # Short rectangular throat under the actual clock shelf, then curved segmental lining.
    box(Vector3(3.78,0.20,4.0),Vector3(tx,4.02,start+direction*2.0),tunnel_concrete)
    for side in [-1.0,1.0]:
        box(Vector3(0.18,4.12,length),Vector3(tx+side*1.98,1.86,start+direction*length*0.5),tunnel_concrete)
        for h in [0.70,1.1,1.5,1.9,2.35,2.65]:
            rod(Vector3(tx+side*1.84,float(h),start),Vector3(tx+side*1.84,float(h),start+direction*(length-0.20)),0.015,black)
        for i in range(12):
            var zz: float=start+direction*(float(i)+0.4)*1.45
            rod(Vector3(tx+side*1.87,0.60,zz),Vector3(tx+side*1.87,2.78,zz),0.012,cage_metal)
            for h in [0.70,1.5,2.35]:
                rod(Vector3(tx+side*1.88,float(h),zz),Vector3(tx+side*1.96,float(h),zz),0.012,metal)
    for i in range(48):
        var a: float=float(i)*PI/48.0;var b: float=float(i+1)*PI/48.0
        var pa := Vector2(tx+cos(a)*1.89,2.30+sin(a)*1.62)
        var pb := Vector2(tx+cos(b)*1.89,2.30+sin(b)*1.62)
        quad(Vector3(pa.x,pa.y,start+direction*4.0),Vector3(pb.x,pb.y,start+direction*4.0),Vector3(pb.x,pb.y,start+direction*length),Vector3(pa.x,pa.y,start+direction*length),tunnel_concrete,Vector3(tx-(pa.x+pb.x)*0.5,-1,0))
    for ring in range(7):
        var zz: float=start+direction*(4.1+float(ring)*2.0)
        for i in range(32):
            var a: float=float(i)*PI/32.0;var b: float=float(i+1)*PI/32.0
            rod(Vector3(tx+cos(a)*1.875,2.30+sin(a)*1.60,zz),Vector3(tx+cos(b)*1.875,2.30+sin(b)*1.60,zz),0.007,cage_metal)
    box(Vector3(3.85,4.10,0.10),Vector3(tx,1.96,start+direction*length),black)

func _landing_equipment(direction: float,finish: float,top_y: float) -> void:
    var parent_group: String=construction_group
    construction_group=parent_group+"Turnstiles"
    var reader := _material(Color("#171d20"),0.22,0.19)
    var green := _material(Color("#4eae68"),0.1,0.30)
    green.emission_enabled=true;green.emission=Color("#327c43")
    var zz: float=finish+direction*1.70
    for i in range(6):
        var x: float=CX-3.20+float(i)*0.87
        _rounded_plan_box(Vector3(0.26,0.96,0.96),Vector3(x,top_y+0.48,zz),metal,0.05)
        box(Vector3(0.22,0.045,0.35),Vector3(x,top_y+0.986,zz-direction*0.23),reader,Basis(Vector3.RIGHT,-direction*0.12))
        box(Vector3(0.055,0.018,0.082),Vector3(x,top_y+1.013,zz-direction*0.32),green)
        for sign in [-1.0,1.0]:
            var face_z: float=zz+sign*0.486
            sphere(Vector3(0.037,0.037,0.009),Vector3(x,top_y+0.69,face_z),reader)
            box(Vector3(0.025,0.025,0.008),Vector3(x,top_y+0.69,face_z+sign*0.006),green)
        # Three-arm hub behind the front face, with narrow stainless bars into the lane.
        var hub := Vector3(x+0.15,top_y+0.62,zz)
        if i<5:
            for arm in range(3):
                var a: float=float(arm)*TAU/3.0
                rod(hub,hub+Vector3(0.42,sin(a)*0.26,cos(a)*0.26),0.017,metal)
        var marker := Marker3D.new();marker.name="Gate%02d"%i
        marker.position=Vector3(x+0.40,top_y,zz);marker.set_meta("portable_role","equipment")
        _construction_root(construction_group).add_child(marker)
    # A full-width accessible gate closes the lane beside the controller booth.
    for x in [CX+1.31,CX+2.16]:
        rod(Vector3(float(x),top_y,zz),Vector3(float(x),top_y+1.0,zz),0.023,metal)
    for h in [0.25,0.67,0.99]:rod(Vector3(CX+1.31,top_y+float(h),zz),Vector3(CX+2.16,top_y+float(h),zz),0.019,metal)
    construction_group=parent_group+"ControllerBooth"
    _controller_booth(direction,Vector3(CX+2.95,top_y,finish+direction*2.23))
    construction_group=parent_group+"LandingFinish"
    var vent := _material(Color("#373936"),0.28,0.66)
    var back: float=finish+direction*3.56
    box(Vector3(5.1,1.05,0.05),Vector3(CX-0.35,top_y+1.75,back),vent)
    for i in range(75):box(Vector3(0.022,1.04,0.035),Vector3(CX-2.85+float(i)*0.068,top_y+1.75,back-direction*0.034),metal)
    # Cased linear lamps continue into the visible vestibule.
    for side in [-1.0,1.0]:
        box(Vector3(0.13,0.10,3.4),Vector3(CX+side*3.18,7.55,finish+direction*1.6),metal)
        box(Vector3(0.09,0.055,3.3),Vector3(CX+side*3.18,7.49,finish+direction*1.6),glow)
    var light := OmniLight3D.new();light.name=parent_group+"LandingLight"
    light.position=Vector3(CX,7.25,finish+direction*1.5)
    light.light_color=Color(1.0,0.985,0.95);light.light_energy=1.25;light.omni_range=6.0
    light.shadow_enabled=false;add_child(light)
    construction_group=parent_group

func _controller_booth(direction: float,p: Vector3) -> void:
    var blue := _material(Color("#244452"),0.35,0.43)
    var glass := _material(Color(0.28,0.36,0.35,0.40),0.08,0.13)
    glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    glass.cull_mode=BaseMaterial3D.CULL_DISABLED
    var root := _construction_root(construction_group)
    _rounded_plan_box(Vector3(1.48,0.87,1.55),p+Vector3(0,0.435,0),blue,0.045)
    _rounded_plan_box(Vector3(1.54,0.10,1.61),p+Vector3(0,2.30,0),metal,0.035)
    for dx in [-0.70,0.70]:
        for dz in [-0.735,0.735]:rod(p+Vector3(float(dx),0.80,float(dz)),p+Vector3(float(dx),2.26,float(dz)),0.023,metal)
    for h in [0.87,2.23]:
        for side in [-1.0,1.0]:
            rod(p+Vector3(-0.70,float(h),side*0.735),p+Vector3(0.70,float(h),side*0.735),0.021,metal)
            rod(p+Vector3(side*0.70,float(h),-0.735),p+Vector3(side*0.70,float(h),0.735),0.021,metal)
    # Interior is modelled behind actual glazed panels, with clear sight of the stairs.
    box(Vector3(1.21,0.055,0.45),p+Vector3(0,1.03,-direction*0.44),black)
    box(Vector3(0.29,0.22,0.08),p+Vector3(-0.22,1.19,-direction*0.43),black)
    cylinder(0.22,0.09,p+Vector3(0,0.54,0.19),black)
    rod(p+Vector3(0,0.05,0.19),p+Vector3(0,0.50,0.19),0.034,metal)
    for side in [-1.0,1.0]:
        _local_glass(root,p+Vector3(0,1.55,side*0.736),Vector2(1.36,1.28),0.0 if side>0.0 else PI,glass)
        _local_glass(root,p+Vector3(side*0.701,1.55,0),Vector2(1.43,1.28),side*PI/2.0,glass)
    # Door seam, handle and counter opening frame visible on the side wall.
    rod(p+Vector3(-0.721,0.12,-0.47),p+Vector3(-0.721,2.20,-0.47),0.012,metal)
    rod(p+Vector3(-0.744,0.99,-0.39),p+Vector3(-0.744,1.15,-0.39),0.012,metal)
    var marker := Marker3D.new();marker.name="ControllerWorkplace"
    marker.position=p+Vector3(0,0.55,0.19);marker.set_meta("portable_role","equipment");root.add_child(marker)

func _local_glass(parent: Node3D,p: Vector3,size: Vector2,yaw: float,mat: Material) -> void:
    var mesh := QuadMesh.new();mesh.size=size;mesh.material=mat
    var node := MeshInstance3D.new();node.name="BoothGlazing";node.mesh=mesh
    node.position=p;node.rotation.y=yaw;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(node)


func _glass_prism(st: SurfaceTool,footprint: Array[Vector2],y0: float,y1: float,thickness: float,bevel: float,radial: bool) -> void:
    var center := Vector2.ZERO
    for point in footprint:center+=point
    center/=float(footprint.size())
    var loops: Array=[]
    # Two recessed face loops and two full-width body loops give actual glass edge highlights.
    for level in range(4):
        var loop: Array[Vector3]=[]
        for j in range(4):
            var q: Vector2=footprint[j]
            if level in [0,3]:q=q+(center-q).normalized()*bevel
            var y: float=y0 if j<2 else y1
            if not radial:y=y0
            y+=[0.0,bevel,thickness-bevel,thickness][level]
            loop.append(Vector3(q.x,y,q.y))
        loops.append(loop)
    _lamp_quad(st,loops[0][0],loops[0][3],loops[0][2],loops[0][1],radial,Vector3.DOWN)
    _lamp_quad(st,loops[3][0],loops[3][1],loops[3][2],loops[3][3],radial,Vector3.UP)
    for layer in range(3):
        for j in range(4):
            var next: int=(j+1)%4
            var middle: Vector3=(loops[layer][j]+loops[layer][next])*0.5
            _lamp_quad(st,loops[layer][j],loops[layer][next],loops[layer+1][next],loops[layer+1][j],radial,Vector3(middle.x-center.x,0,middle.z-center.y))

func _lamp_quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,radial: bool,hint: Vector3) -> void:
    var points: Array[Vector3]=[a,b,c,d]
    var normal := (b-a).cross(c-a).normalized()
    if normal.dot(hint)<0.0:
        normal=-normal;points=[a,d,c,b]
    for index in [0,2,1,0,3,2]:
        var point: Vector3=points[index]
        st.set_normal(normal)
        st.set_uv([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN][index])
        st.set_uv2(Vector2(point.x/2.50+0.5,point.z/2.50+0.5) if radial else Vector2(point.x/0.14+0.5,point.z/0.094+0.5))
        st.add_vertex(point)


func _mineral_finish(finish_id: String) -> ShaderMaterial:
    # Colours and microtexture are explicit portable data; the narrow tread crop is unused.
    if _mineral_profiles.is_empty():
        _mineral_profiles=JSON.parse_string(FileAccess.get_file_as_string("res://modules/stations/park_chelyuskintsev/materials/mineral_finishes.json"))
    var profile: Dictionary=_mineral_profiles[finish_id]
    var mat := ShaderMaterial.new()
    mat.shader=preload("res://modules/stations/park_chelyuskintsev/materials/mineral_finish.gdshader")
    mat.resource_name=finish_id
    mat.set_shader_parameter("base_colour",Color(profile["base_colour"]))
    for key in ["photo_detail_amount","grain_contrast","veining_amount","surface_roughness","joints","staggered"]:
        mat.set_shader_parameter(key,profile[key])
    mat.set_shader_parameter("slab",Vector2(profile["slab_m"][0],profile["slab_m"][1]))
    mat.set_shader_parameter("detail_tex",load(ART+profile["detail_texture"]))
    return mat

func _stair_lighting(direction: float,start: float) -> void:
    var label: String="North" if direction<0.0 else "South"
    # Broad local fill keeps the neutral treads legible below the entrance soffit.
    var fill := OmniLight3D.new();fill.name=label+"StairFill"
    fill.position=Vector3(CX,5.40,start+direction*3.20)
    fill.light_color=Color(1.0,0.985,0.96);fill.light_energy=0.80
    fill.omni_range=7.8;fill.omni_attenuation=0.80;fill.shadow_enabled=false
    add_child(fill)
    # A ceiling source casts the actual handrail and pier shadows onto the pale marble.
    var key := SpotLight3D.new();key.name=label+"StairShadowLight"
    key.position=Vector3(CX,7.34,start+direction*4.0)
    key.rotation_degrees.x=-90.0
    key.light_color=Color(1.0,0.985,0.96);key.light_energy=0.95
    key.spot_range=11.0;key.spot_angle=72.0;key.spot_attenuation=0.70
    key.shadow_enabled=true;key.shadow_bias=0.025;key.shadow_normal_bias=0.12
    add_child(key)
