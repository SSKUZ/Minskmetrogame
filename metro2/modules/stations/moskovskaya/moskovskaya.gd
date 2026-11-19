extends "res://modules/stations/moskovskaya/station_builder.gd"
## V60: owner's 31 photographs and both platform videos replace V58 assumptions.
const ART := "res://modules/stations/moskovskaya/art/"
const NORTH := -2.8
const SOUTH := 82.024
var column_stone: ShaderMaterial
var wall_stone: ShaderMaterial
var stair_stone: ShaderMaterial
var oak: ShaderMaterial
var trim: StandardMaterial3D
var yellow: StandardMaterial3D
var _advert: ShaderMaterial

func _ready() -> void:
    super._ready()
    begin_station()
    white.albedo_color=Color("#e7e8e0")
    glow.albedo_color=Color("#f7f8ee")
    glow.emission=Color(0.97,1.0,0.95)
    trim=_material(Color("#aaa79b"),0.45,0.34)
    yellow=_material(Color("#d7b34a"),0.0,0.7)
    wall_stone=_photo_stone("wall_marble.jpg",Color(1.0,1.0,0.98),Vector2(1.25,0.63),0.31)
    column_stone=_photo_stone("column_marble.jpg",Color(1.10,1.10,1.05),Vector2(0.76,0.67),0.26)
    stair_stone=_photo_stone("stair_granite.jpg",Color(0.86,0.88,0.84),Vector2(1.2,0.6),0.48)
    oak=_photo_stone("bench_oak.jpg",Color(0.99,0.92,0.77),Vector2(0.48,0.60),0.40,false)
    _floor()
    _edges()
    _walls()
    _columns()
    _ceiling()
    _stairs(-1.0,NORTH)
    _stairs(1.0,SOUTH)
    _track_details()
    _portal_equipment()
    _signs()
    _advert_material()
    for z in [24.6,57.8]:_television(float(z))
    for z in [13.725,39.825,65.925]:
        for side in [-1.0,1.0]:_bench(Vector3(CX+side*2.36,FY,float(z)))
    _small_fittings()
    flush()

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

func _floor() -> void:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
uniform sampler2D red_tex : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D grey_tex : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 p;void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float h(vec2 q){return fract(sin(dot(q,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){float x=abs(p.x+5.37);float z=abs(mod(p.z+1.5+2.175,4.35)-2.175);
float stripe=1.0-step(0.44,abs(x-2.25));float transverse=1.0-step(0.38,z);float grey=max(stripe,transverse);
float line=max(1.0-step(0.018,abs(abs(x-2.25)-0.44)),1.0-step(0.020,abs(z-0.38)));
vec3 a=texture(red_tex,p.xz*1.7).rgb;vec3 b=texture(grey_tex,p.xz*1.4).rgb;
float v=h(floor(p.xz/vec2(0.60,0.60)));vec3 c=mix(a,b,grey)*(0.94+v*0.12);
c=mix(c,vec3(0.78,0.77,0.66),line);
vec2 t=fract(p.xz/0.6);float joint=1.0-smoothstep(0.0005,0.0025,min(min(t.x,1.0-t.x),min(t.y,1.0-t.y)));
ALBEDO=c-vec3(joint*0.035);ROUGHNESS=0.37+v*0.10;SPECULAR=0.6;}
"""
    var mat := ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("red_tex",load(ART+"floor_red.jpg"));mat.set_shader_parameter("grey_tex",load(ART+"floor_grey.jpg"))
    (get_node("IslandPlatform") as MeshInstance3D).material_override=mat

func _edges() -> void:
    var grey := _photo_stone("floor_grey.jpg",Color(0.88,0.90,0.90),Vector2(0.6,1.2),0.45)
    for side in [-1.0,1.0]:
        box(Vector3(0.52,0.014,105),Vector3(CX+side*4.74,FY+0.009,MID),grey)
        box(Vector3(0.20,0.012,105),Vector3(CX+side*4.39,FY+0.014,MID),yellow)
        for i in range(1312):
            var z: float=ZA+0.04+float(i)*0.08
            for dx in [-0.061,0.0,0.061]:cylinder(0.0125,0.005,Vector3(CX+side*4.39+float(dx),FY+0.022,z),yellow)

func _walls() -> void:
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.90
        box(Vector3(0.28,0.83,105),Vector3(x,0.415,MID),granite)
        box(Vector3(0.26,4.17,105),Vector3(x,2.915,MID),wall_stone)
        # Raised narrow stone mouldings bracket the station lettering band.
        for y in [1.87,1.91,2.45,2.49]:box(Vector3(0.30,0.016,105),Vector3(x-side*0.03,float(y),MID),trim)
        # Low-contrast inlaid architecture is sampled from the owner's actual marble.
        var files := ["owner_mural_domes.jpg","owner_mural_kremlin.jpg","owner_mural_university.jpg","owner_mural_video.jpg","owner_mural_panorama.jpg","owner_mural_kremlin.jpg","owner_mural_domes.jpg"]
        for i in range(files.size()):
            var index: int=i if side>0.0 else files.size()-1-i
            var z: float=3.0+float(i)*12.2
            _mural(files[index],Vector2(12.2,2.38),Vector3(x-side*0.142,3.72,z),-side*PI/2.0)
        # Plain stone sections remain at the two ends, as seen in the long views.
        for z in [15.2,39.6,64.0]:_station_name("МАСКОЎСКАЯ" if side>0.0 else "МОСКОВСКАЯ",Vector3(x-side*0.18,2.16,float(z)),-side*PI/2.0)
        for z in [3.0,27.4,51.8,76.2]:
            picture("route_track1.svg" if side>0.0 else "route_track2.svg",Vector2(4.35,0.76),Vector3(x-side*0.20,2.25,float(z)),-side*PI/2.0,true)
        rod(Vector3(x-side*0.25,4.88,ZA),Vector3(x-side*0.25,4.88,ZB),0.012,black)
        for i in range(58):
            var z: float=ZA+float(i)*1.83
            box(Vector3(0.31,0.11,0.19),Vector3(x-side*0.12,4.85,z),white)
            rod(Vector3(x-side*0.27,4.88,z),Vector3(x-side*0.27,5.03,z),0.009,metal)

func _mural(file: String,size: Vector2,p: Vector3,yaw: float) -> void:
    var mat := StandardMaterial3D.new();mat.albedo_texture=load(ART+file)
    mat.albedo_color=Color(1.0,1.0,0.98);mat.roughness=0.39;mat.metallic=0.0
    mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    var mesh := QuadMesh.new();mesh.size=size;mesh.material=mat
    var n := MeshInstance3D.new();n.name="OwnerMarbleInlay";n.mesh=mesh;n.position=p;n.rotation.y=yaw
    add_child(n)

func _station_name(value: String,p: Vector3,yaw: float) -> void:
    var font: Font=load(ART+"station_letters.ttf")
    var frame := Node3D.new();frame.name="BronzeStationLetters";frame.position=p;frame.rotation.y=yaw;add_child(frame)
    var total := 0.0
    for letter in value:total+=font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,72).x*0.006+0.13
    var cursor: float=-total*0.5
    var dark := _material(Color("#392f21"),0.55,0.36)
    for letter in value:
        var advance: float=font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,72).x*0.006
        for face in range(2):
            var mesh := TextMesh.new();mesh.font=font;mesh.text=letter;mesh.font_size=72;mesh.pixel_size=0.006;mesh.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
            mesh.depth=0.040 if face==0 else 0.007;mesh.material=brass if face==0 else dark
            var n := MeshInstance3D.new();n.mesh=mesh;n.position=Vector3(cursor+advance*0.5,0,0.0 if face==0 else 0.024)
            if face==1:n.scale=Vector3(0.88,0.88,1.0)
            frame.add_child(n)
        cursor+=advance+0.13

func _columns() -> void:
    # Rectangular section with shallow paired vertical channels on every face.
    var coords := PackedFloat32Array([-0.40,-0.355,-0.343,-0.329,-0.315,-0.285,-0.270,-0.256,-0.242,-0.035,-0.020,0.020,0.035,0.242,0.256,0.270,0.285,0.315,0.329,0.343,0.355,0.40])
    var outline := PackedVector2Array()
    for face in range(4):
        for x in coords:
            var ax: float=absf(x)
            var inset: float=0.026 if (ax>0.255 and ax<0.286) or (ax>0.328 and ax<0.356) or ax<0.022 else 0.0
            outline.append(Vector2(x,-0.40+inset).rotated(float(face)*PI/2.0))
    var seam := _material(Color("#9e9d91"),0.0,0.8)
    for side in [-1.0,1.0]:
        var x: float=CX+side*2.25
        for i in range(20):
            var z: float=-1.5+float(i)*4.35
            for edge in range(outline.size()):
                var a: Vector2=outline[edge];var b: Vector2=outline[(edge+1)%outline.size()]
                if a.distance_squared_to(b)<0.00000001:continue
                quad(Vector3(x+a.x,FY+0.08,z+a.y),Vector3(x+b.x,FY+0.08,z+b.y),Vector3(x+b.x,4.82,z+b.y),Vector3(x+a.x,4.82,z+a.y),column_stone,Vector3((a.x+b.x)*0.5,0,(a.y+b.y)*0.5))
            box(Vector3(0.81,0.08,0.81),Vector3(x,FY+0.04,z),granite)
            for y in [FY+0.67,FY+1.34,FY+2.01,FY+2.68]:box(Vector3(0.802,0.003,0.802),Vector3(x,float(y),z),seam)

func _ceiling() -> void:
    var z0 := NORTH-0.5
    var z1 := SOUTH+0.5
    var length: float=z1-z0
    box(Vector3(4.52,0.11,length),Vector3(CX,5.44,(z0+z1)*0.5),white)
    for side in [-1.0,1.0]:
        var beam_x: float=CX+side*2.25
        box(Vector3(0.44,0.48,length),Vector3(beam_x,4.91,(z0+z1)*0.5),white)
        box(Vector3(6.45,0.11,105),Vector3(CX+side*5.67,5.10,MID),white)
    for i in range(48):
        var z: float=z0+0.20+float(i)*1.80
        _rib(CX,4.46,5.39,4.99,z,0.18,0.22)
        for side in [-1.0,1.0]:
            _rib(CX+side*5.67,6.42,5.05,4.74,z,0.12,0.11)
            # Individual long white diffusers along the upper edges of the girders.
            var x: float=CX+side*2.25
            _round_box(Vector3(0.13,0.10,1.51),Vector3(x-side*0.26,5.18,z+0.85),glow,0.04)
    for z in [18.3,47.1,74.1]:
        for side in [-1.0,1.0]:box(Vector3(0.025,0.38,0.15),Vector3(CX+side*2.17,5.19,float(z)),white)

func _rib(x: float,width: float,top: float,underside: float,z: float,depth: float,radius: float) -> void:
    var left: float=x-width*0.5;var right: float=x+width*0.5
    var pts := PackedVector2Array([Vector2(left,top),Vector2(right,top),Vector2(right,underside-radius)])
    for j in range(13):
        var a: float=float(j)*PI/24.0
        pts.append(Vector2(right-radius*sin(a),underside-radius*cos(a)))
    pts.append(Vector2(left+radius,underside))
    for j in range(13):
        var a: float=float(j)*PI/24.0
        pts.append(Vector2(left+radius-radius*sin(a),underside-radius+radius*cos(a)))
    var clean := PackedVector2Array()
    for point in pts:
        if clean.is_empty() or clean[-1].distance_squared_to(point)>0.00000001:clean.append(point)
    extrusion(clean,z-depth*0.5,z+depth*0.5,white)

func _round_box(size: Vector3,p: Vector3,mat: Material,radius: float=0.03) -> void:
    var r: float=minf(radius,minf(size.x,size.y)*0.49)
    var pts := PackedVector2Array()
    for corner in range(4):
        var center := Vector2(p.x+(size.x*0.5-r)*(1.0 if corner in [0,3] else -1.0),p.y+(size.y*0.5-r)*(1.0 if corner in [0,1] else -1.0))
        for j in range(7):
            var a: float=float(corner)*PI/2.0+float(j)*PI/12.0;pts.append(center+Vector2(cos(a),sin(a))*r)
    extrusion(pts,p.z-size.z*0.5,p.z+size.z*0.5,mat)

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
    box(Vector3(width+0.3,0.22,4.0),Vector3(CX,top_y-0.11,finish+direction*1.95),wall_stone)
    var ceiling := 7.78
    for side in [-1.0,1.0]:
        var x: float=CX+side*(width*0.5+0.11)
        box(Vector3(0.22,ceiling-FY,15.2),Vector3(x,(ceiling+FY)*0.5,start+direction*7.35),wall_stone)
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
    box(Vector3(width+0.5,2.82,0.35),Vector3(CX,6.37,start-direction*0.22),wall_stone)
    box(Vector3(width+0.5,0.16,15.3),Vector3(CX,ceiling+0.08,start+direction*7.35),white)
    for i in range(12):
        var z: float=start+direction*(float(i)*1.3)
        box(Vector3(width,0.23,0.14),Vector3(CX,ceiling-0.12,z),white)
        if i%2==0:box(Vector3(5.80,0.045,0.075),Vector3(CX,ceiling-0.26,z+0.22),glow)
    board("exit_north_v60.svg" if direction<0.0 else "exit_south_v60.svg",Vector3(CX,4.43,start-direction*0.43),Vector2(5.85,0.85))
    foot_grille(start-direction*0.45,7.45)
    var back: float=finish+direction*3.7
    box(Vector3(width+0.4,2.55,0.20),Vector3(CX,top_y+1.275,back),wall_stone)
    for i in range(7):
        var x: float=CX-2.70+float(i)*0.90
        box(Vector3(0.24,0.92,0.95),Vector3(x,top_y+0.46,finish+direction*2.0),metal)
        rod(Vector3(x,top_y+0.69,finish+direction*1.72),Vector3(x+0.40,top_y+0.69,finish+direction*1.72),0.019,metal)
        box(Vector3(0.23,0.045,0.36),Vector3(x,top_y+0.94,finish+direction*1.95),black)

func _signs() -> void:
    for z in [6.8,32.9,67.7]:
        for side in [-1.0,1.0]:
            var size := Vector2(3.8,0.59)
            var p := Vector3(CX+side*2.25,4.25,float(z))
            box(Vector3(0.08,size.y+0.07,size.x+0.08),p,metal)
            for face in [-1.0,1.0]:picture("platform_track1.svg" if side>0.0 else "platform_track2.svg",size,p+Vector3(face*0.047,0,0),face*PI/2.0)
            for dz in [-1.60,1.60]:rod(p+Vector3(0,size.y*0.5,float(dz)),p+Vector3(0,4.67-p.y,float(dz)),0.019,metal)

func _bench(p: Vector3) -> void:
    var brown := _material(Color("#514339"),0.25,0.61)
    box(Vector3(0.60,0.38,2.45),p+Vector3(0,0.19,0),brown)
    for i in range(5):
        var z: float=p.z-0.98+float(i)*0.49
        _round_box(Vector3(0.63,0.10,0.46),Vector3(p.x,p.y+0.43,z),oak,0.025)
        for dx in [-0.14,0.14]:box(Vector3(0.009,0.008,0.455),Vector3(p.x+float(dx),p.y+0.485,z),brown)
        if i<4:box(Vector3(0.68,0.065,0.037),Vector3(p.x,p.y+0.46,z+0.244),brown)

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

func _television(z: float) -> void:
    var p := Vector3(CX,4.02,z)
    _round_box(Vector3(1.48,0.88,0.15),p,black,0.025)
    for dx in [-0.48,0.48]:
        rod(p+Vector3(float(dx),0.46,0),Vector3(CX+float(dx),5.38,z),0.012,black)
        box(Vector3(0.12,0.025,0.12),Vector3(CX+float(dx),5.36,z),metal)
    for face in [-1.0,1.0]:
        var q := QuadMesh.new();q.size=Vector2(1.40,0.7875);q.material=_advert
        var n := MeshInstance3D.new();n.name="AnimatedAdvertisingScreen";n.mesh=q;n.position=p+Vector3(0,0,face*0.081);n.rotation.y=0.0 if face>0.0 else PI
        n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(n)
    for side in [-1.0,1.0]:
        box(Vector3(0.13,0.24,0.13),Vector3(CX+side*0.90,4.89,z),white)
        rod(Vector3(CX+side*0.90,4.89,z),Vector3(CX+side*0.90,5.20,z),0.009,metal)

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
            var end: float=ZA if direction<0.0 else ZB
            box(Vector3(3.78,0.20,8.0),Vector3(x,4.50,end+direction*3.9),wall_stone)
            for side in [-1.0,1.0]:
                box(Vector3(0.14,4.60,8.0),Vector3(x+side*1.94,2.12,end+direction*3.9),wall_stone)
                for h in [0.70,1.1,1.5,1.9,2.35,2.65]:rod(Vector3(x+side*1.84,float(h),end),Vector3(x+side*1.84,float(h),end+direction*7.8),0.015,black)
            box(Vector3(3.85,4.65,0.10),Vector3(x,2.13,end+direction*8.0),black)

func _portal_equipment() -> void:
    var infra := get_node("StationInfrastructure")
    infra.set("_amber",Color(1.0,0.13,0.055))
    var displays: Array=infra.get("_displays")
    for display in displays:
        for i in range(70,76):display.set_instance_color(i,Color(1.0,0.13,0.055))
    for node in infra.get_children():
        if node is Node3D and "Portal" in str(node.name):node.position.y=4.16
    for direction in [-1.0,1.0]:
        var end: float=ZA if direction<0.0 else ZB
        for side in [-1.0,1.0]:
            var tx: float=CX+side*6.362
            var yaw: float=0.0 if direction<0.0 else PI
            box(Vector3(3.90,0.48,0.25),Vector3(tx,4.15,end),wall_stone)
            var root := Node3D.new();root.name="WhiteDriverMirror";root.position=Vector3(CX+side*4.58,FY+1.42,end-direction*2.6);root.rotation.y=yaw-side*0.12;add_child(root)
            var mirror := MeshInstance3D.new();mirror.set_script(preload("res://modules/stations/moskovskaya/driver_mirrors.gd"));mirror.name="ReflectingSurface";mirror.position.z=0.016
            var q := QuadMesh.new();q.size=Vector2(0.60,1.56);mirror.mesh=q;mirror.set_meta("mirror_size",q.size);root.add_child(mirror)
            var pts: Array[Vector3]=[]
            for corner in range(4):
                var c := Vector2(0.235*(1.0 if corner in [0,3] else -1.0),0.70*(1.0 if corner in [0,1] else -1.0))
                for j in range(9):
                    var a: float=float(corner)*PI/2.0+float(j)*PI/16.0;pts.append(Vector3(c.x+0.11*cos(a),c.y+0.11*sin(a),0))
            for i in range(pts.size()):_local_rod(root,pts[i],pts[(i+1)%pts.size()],0.032,white)
            _local_rod(root,Vector3(0,-1.42,0),Vector3(0,-0.80,0),0.075,_material(Color("#285476"),0.3,0.42))
            for dx in [-0.42,0.42]:_local_rod(root,Vector3(float(dx),-1.42,0),Vector3(float(dx),-0.52,0.10),0.023,metal)
            _local_rod(root,Vector3(-0.42,-0.52,0.10),Vector3(0.42,-0.52,0.10),0.023,metal)
            var p := Vector3(tx-side*1.42,4.15,end-direction*0.16)
            box(Vector3(0.72,0.46,0.08),p,black)
            picture("platform_cctv.jpg",Vector2(0.66,0.371),p+Vector3(0,0,-direction*0.048),yaw)
            _camera_box(Vector3(CX+side*3.95,4.56,end-direction*0.35),yaw)

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

func _small_fittings() -> void:
    for z in [11.0,32.75,54.5,76.25]:
        cylinder(0.18,0.014,Vector3(CX+0.6,FY+0.013,float(z)),trim)
        for i in range(7):box(Vector3(0.012,0.02,0.25),Vector3(CX+0.51+float(i)*0.03,FY+0.021,float(z)),black)
        box(Vector3(0.31,0.012,0.31),Vector3(CX-0.40,FY+0.012,float(z)+2.0),trim)
        for i in range(8):box(Vector3(0.012,0.02,0.26),Vector3(CX-0.51+float(i)*0.03,FY+0.023,float(z)+2.0),black)
    for side in [-1.0,1.0]:
        for z in [8.2,52.8]:
            var x: float=CX+side*8.755
            for dz in [-0.32,0.32]:box(Vector3(0.01,0.54,0.006),Vector3(x,3.1,float(z)+float(dz)),trim)
            for y in [2.83,3.37]:box(Vector3(0.01,0.006,0.64),Vector3(x,float(y),float(z)),trim)
            box(Vector3(0.018,0.08,0.016),Vector3(x-side*0.01,3.1,float(z)+0.22),trim)
