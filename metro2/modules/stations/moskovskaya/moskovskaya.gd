extends "res://modules/stations/moskovskaya/station_builder.gd"
## Owner-photo revision: plain stone paving, pale ribbed hall and working platform equipment.
const ART := "res://modules/stations/moskovskaya/art/"
const NORTH := -2.8
const SOUTH := 82.024
var column_stone: StandardMaterial3D
var wall_stone: StandardMaterial3D
var stair_stone: StandardMaterial3D
var oak: StandardMaterial3D
var trim: StandardMaterial3D
var yellow: StandardMaterial3D
var _advert: StandardMaterial3D

func _ready() -> void:
    super._ready()
    begin_station()
    white=_paint_material()
    granite=_photo_stone("dark_plinth_v60_2.jpg",Color.WHITE,Vector2(0.90,0.35),0.48,false)
    glow.albedo_color=Color("#f7f8ee")
    glow.emission=Color(0.97,1.0,0.95)
    trim=_material(Color("#aaa79b"),0.45,0.34)
    yellow=_material(Color("#d7b34a"),0.0,0.7)
    wall_stone=_photo_stone("wall_marble_v60_1.jpg",Color(1.0,1.0,0.99),Vector2(2.40,1.80),0.36,false)
    column_stone=_photo_stone("column_pale.jpg",Color.WHITE,Vector2(0.32,0.74),0.33,false)
    stair_stone=_photo_stone("stair_granite_pale.jpg",Color.WHITE,Vector2(1.2,0.6),0.48)
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

func _photo_stone(file: String,tint: Color,slab: Vector2,roughness: float,_joints: bool=true) -> StandardMaterial3D:
    # Native Godot material: no custom architectural shader or grey shader fallback.
    var mat := StandardMaterial3D.new()
    mat.albedo_texture=load(ART+file)
    mat.albedo_color=tint
    mat.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED
    mat.roughness=roughness
    mat.metallic=0.0
    mat.uv1_triplanar=true
    mat.uv1_world_triplanar=true
    mat.uv1_triplanar_sharpness=8.0
    mat.uv1_scale=Vector3(1.0/slab.x,1.0/slab.y,1.0/slab.x)
    mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return mat

func _paint_material() -> StandardMaterial3D:
    var mat := _photo_stone("ceiling_pale.jpg",Color.WHITE,Vector2(0.85,0.85),0.88,false)
    mat.normal_enabled=true
    mat.normal_texture=load(ART+"ceiling_normal_v60_2.png")
    mat.normal_scale=0.16
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
    var mat := ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("red_tex",load(ART+"floor_red.jpg"));mat.set_shader_parameter("grey_tex",load(ART+"floor_grey_plain.jpg"))
    (get_node("IslandPlatform") as MeshInstance3D).material_override=mat

func _edges() -> void:
    var grey := _photo_stone("floor_grey_plain.jpg",Color(0.88,0.90,0.90),Vector2(0.6,1.2),0.45)
    for side in [-1.0,1.0]:
        box(Vector3(0.52,0.014,105),Vector3(CX+side*4.74,FY+0.009,MID),grey)
        box(Vector3(0.20,0.012,105),Vector3(CX+side*4.39,FY+0.014,MID),yellow)
        for i in range(1312):
            var z: float=ZA+0.04+float(i)*0.08
            for dx in [-0.061,0.0,0.061]:cylinder(0.0125,0.005,Vector3(CX+side*4.39+float(dx),FY+0.022,z),yellow)

func _walls() -> void:
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.90
        box(Vector3(0.28,0.55,105),Vector3(x,0.275,MID),granite)
        box(Vector3(0.26,4.45,105),Vector3(x,2.775,MID),wall_stone)
        # Actual lower marble courses continue to the low dark plinth.
        for j in range(9):
            var z0: float=ZA+float(j)*12.2
            var z1: float=minf(z0+12.2,ZB)
            _mural("lower_clean_v60_2.jpg",Vector2(z1-z0,1.06),Vector3(x-side*0.142,1.08,(z0+z1)*0.5),-side*PI/2.0)
        # Raised narrow stone mouldings bracket the station lettering band.
        for y in [1.61,1.65,2.19,2.23]:box(Vector3(0.30,0.016,105),Vector3(x-side*0.03,float(y),MID),trim)
        # Low-contrast inlaid architecture is sampled from the owner's actual marble.
        var files := ["mural_domes_clean_v60_2.jpg","mural_kremlin_clean_v60_2.jpg","mural_university_clean_v60_2.jpg","mural_kremlin_clean_v60_2.jpg","mural_university_clean_v60_2.jpg","mural_kremlin_clean_v60_2.jpg","mural_domes_clean_v60_2.jpg"]
        for i in range(files.size()):
            var index: int=i if side>0.0 else files.size()-1-i
            var z: float=3.0+float(i)*12.2
            _mural(files[index],Vector2(12.2,2.72),Vector3(x-side*0.142,3.59,z),-side*PI/2.0)
        # Plain stone sections remain at the two ends, as seen in the long views.
        for z in [15.2,39.6,64.0]:_station_name("МАСКОЎСКАЯ" if side>0.0 else "МОСКОВСКАЯ",Vector3(x-side*0.18,1.90,float(z)),-side*PI/2.0)
        for z in [3.0,27.4,51.8,76.2]:
            picture("route_track1.svg" if side>0.0 else "route_track2.svg",Vector2(4.35,0.76),Vector3(x-side*0.20,1.99,float(z)),-side*PI/2.0,true)
        rod(Vector3(x-side*0.25,4.88,ZA),Vector3(x-side*0.25,4.88,ZB),0.012,black)
        for i in range(58):
            var z: float=ZA+float(i)*1.83
            box(Vector3(0.31,0.11,0.19),Vector3(x-side*0.12,4.85,z),white)
            rod(Vector3(x-side*0.27,4.88,z),Vector3(x-side*0.27,5.03,z),0.009,metal)

func _mural(file: String,size: Vector2,p: Vector3,yaw: float) -> void:
    var mat := StandardMaterial3D.new();mat.albedo_texture=load(ART+file)
    mat.albedo_color=Color(1.0,1.0,0.99);mat.roughness=0.36;mat.metallic=0.0
    mat.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED
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
    # Two shallow rounded flutes per broad face, bevelled corners and flat marble fields.
    # The earlier five grooves per face did not match the owner's close-up 7875.
    var profile_points := [Vector2(-0.40,0.020),Vector2(-0.38,0),Vector2(-0.13,0),Vector2(-0.12,0.008),Vector2(-0.115,0.022),Vector2(-0.10,0.029),Vector2(-0.085,0.022),Vector2(-0.08,0.008),Vector2(-0.07,0),Vector2(0.07,0),Vector2(0.08,0.008),Vector2(0.085,0.022),Vector2(0.10,0.029),Vector2(0.115,0.022),Vector2(0.12,0.008),Vector2(0.13,0),Vector2(0.38,0),Vector2(0.40,0.020)]
    var outline := PackedVector2Array()
    for face in range(4):
        for point in profile_points:outline.append(Vector2(point.x,-0.40+point.y).rotated(float(face)*PI/2.0))
    var caps := Geometry2D.triangulate_polygon(outline)
    var bottom: float=FY+0.075
    var top := 4.82
    var seam := _material(Color("#b0afa4"),0.0,0.75)
    for side in [-1.0,1.0]:
        var x: float=CX+side*2.25
        # End bays are clear approaches to the full-width stairs (7867, 7891).
        for i in range(1,19):
            var z: float=-1.5+float(i)*4.35
            # Opaque solid core closes every sightline behind the fluted facing.
            box(Vector3(0.738,top-bottom,0.738),Vector3(x,(top+bottom)*0.5,z),column_stone)
            for edge in range(outline.size()):
                var a: Vector2=outline[edge];var b: Vector2=outline[(edge+1)%outline.size()]
                if a.distance_squared_to(b)<0.00000001:continue
                quad(Vector3(x+a.x,bottom,z+a.y),Vector3(x+b.x,bottom,z+b.y),Vector3(x+b.x,top,z+b.y),Vector3(x+a.x,top,z+a.y),column_stone,Vector3((a.x+b.x)*0.5,0,(a.y+b.y)*0.5))
            for height in [bottom,top]:
                for k in range(0,caps.size(),3):
                    var a: Vector2=outline[caps[k]];var b: Vector2=outline[caps[k+1]];var c: Vector2=outline[caps[k+2]]
                    triangle(Vector3(x+a.x,float(height),z+a.y),Vector3(x+b.x,float(height),z+b.y),Vector3(x+c.x,float(height),z+c.y),column_stone,Vector3.DOWN if height==bottom else Vector3.UP)
            box(Vector3(0.81,0.075,0.81),Vector3(x,FY+0.0375,z),granite)
            for j in range(1,6):
                var height: float=bottom+float(j)*0.70
                if height<top-0.08:box(Vector3(0.8005,0.0015,0.8005),Vector3(x,height,z),seam)

func _ceiling() -> void:
    # Three structural fields share one paint tone; only the height changes.
    # The centre slab and both column girders stop before the stair openings.
    var z0: float=NORTH+0.55
    var z1: float=SOUTH-0.55
    var length: float=z1-z0
    box(Vector3(4.52,0.11,length),Vector3(CX,5.44,(z0+z1)*0.5),white)
    for side in [-1.0,1.0]:
        var beam_x: float=CX+side*2.25
        box(Vector3(0.44,0.48,length),Vector3(beam_x,4.91,(z0+z1)*0.5),white)
        box(Vector3(6.42,0.11,length),Vector3(CX+side*5.67,5.10,(z0+z1)*0.5),white)
        # Over the portal ends retain the track soffit outside the stairwell.
        for ends in [Vector2(ZA,z0),Vector2(z1,ZB)]:
            box(Vector3(4.93,0.11,ends.y-ends.x),Vector3(CX+side*6.415,5.10,(ends.x+ends.y)*0.5),white)
    for i in range(int(ceil(length/1.80))):
        var z: float=z0+0.22+float(i)*1.80
        if z>z1-0.12:continue
        # Deep, closed ribs with rounded haunches, rather than thin strips.
        _rib(CX,4.46,5.39,5.08,z,0.24,0.30)
        for side in [-1.0,1.0]:
            _rib(CX+side*5.67,6.42,5.05,4.80,z,0.19,0.22)
            var x: float=CX+side*2.25
            _luminaire(Vector3(x-side*0.275,5.17,z+0.80),1.43,side)
    for side in [-1.0,1.0]:
        for z in [ZA+1.8,ZA+3.6,ZA+5.4,ZA+7.2,ZB-1.8,ZB-3.6,ZB-5.4,ZB-7.2]:
            _rib(CX+side*6.415,4.93,5.05,4.80,float(z),0.19,0.22)
    # Light reflects off the rounded soffits; it is not a different white paint.
    for child in get_children():
        if child is OmniLight3D:
            child.position.y=4.66
            child.light_color=Color(0.98,0.985,0.96)
            child.light_energy=1.05
            child.omni_range=17.0
    for z in [6.0,22.8,39.6,56.4,73.2]:
        for side in [-1.0,1.0]:
            var light := OmniLight3D.new()
            light.name="GirderDiffuserBounce"
            light.position=Vector3(CX+side*2.02,5.23,float(z))
            light.light_color=Color(0.97,0.985,0.96)
            light.light_energy=0.46;light.omni_range=10.0
            light.omni_attenuation=1.35;light.shadow_enabled=false
            add_child(light)
    for z in [12.3,39.3,66.3]:
        box(Vector3(0.24,0.006,0.19),Vector3(CX+0.42,5.381,float(z)),white)

func _luminaire(p: Vector3,length: float,side: float) -> void:
    # Photographs 7875/7887: raised elongated diffuser on a slim grey tray.
    var housing: StandardMaterial3D=trim
    _round_box(Vector3(0.13,0.12,length+0.065),p+Vector3(side*0.035,0,0),housing,0.022)
    _round_box(Vector3(0.12,0.102,length),p+Vector3(-side*0.035,0.020,0),glow,0.033)
    for dz in [-length*0.5,length*0.5]:
        box(Vector3(0.163,0.119,0.032),p+Vector3(0,0,float(dz)),white)
        box(Vector3(0.05,0.035,0.07),p+Vector3(0,-0.076,float(dz)*0.82),metal)

func _rib(x: float,width: float,top: float,underside: float,z: float,depth: float,radius: float) -> void:
    var left: float=x-width*0.5;var right: float=x+width*0.5
    var pts := PackedVector2Array([Vector2(left,top),Vector2(right,top)])
    # A continuous quarter-circle joins each lower girder to the rib soffit.
    for j in range(13):
        var a: float=float(j)*PI/24.0
        pts.append(Vector2(right-radius+radius*cos(a),underside-radius+radius*sin(a)))
    pts.append(Vector2(left+radius,underside))
    for j in range(1,13):
        var a: float=float(j)*PI/24.0
        pts.append(Vector2(left+radius-radius*sin(a),underside-radius+radius*cos(a)))
    extrusion(pts,z-depth*0.5,z+depth*0.5,white)

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
    var nosing := _material(Color("#8b897f"),0.0,0.54)
    for i in range(36):
        var height: float=float(i+1)*rise
        var z: float=start+direction*(float(i)*run+(landing if i>=20 else 0.0))
        box(Vector3(width,height,run+0.002),Vector3(CX,FY+height*0.5,z),stair_stone)
        box(Vector3(width,0.012,0.032),Vector3(CX,FY+height+0.006,z-direction*0.125),nosing)
        if i in [0,19,20,35]:box(Vector3(width,0.016,0.05),Vector3(CX,FY+height+0.009,z-direction*0.12),yellow)
    box(Vector3(width,0.18,landing),Vector3(CX,FY+20.0*rise-0.09,start+direction*6.0075),stair_stone)
    var finish: float=start+direction*(35.0*run+landing+run*0.5)
    var upper_floor := _photo_stone("floor_grey_plain.jpg",Color(0.96,0.97,0.95),Vector2(0.8,0.8),0.43)
    box(Vector3(width+0.3,0.22,7.0),Vector3(CX,top_y-0.11,finish+direction*3.48),upper_floor)
    var ceiling := 7.88
    for side in [-1.0,1.0]:
        var x: float=CX+side*(width*0.5+0.11)
        box(Vector3(0.22,ceiling-FY,18.3),Vector3(x,(ceiling+FY)*0.5,start+direction*8.95),wall_stone)
        var points: Array[Vector2]=[Vector2(-0.20,0.0),Vector2(5.56,2.25),Vector2(6.46,2.25),Vector2(11.02,4.05),Vector2(12.00,4.05)]
        for i in range(points.size()-1):
            var a: Vector2=points[i];var b: Vector2=points[i+1]
            rod(Vector3(x-side*0.18,FY+a.y+0.90,start+direction*a.x),Vector3(x-side*0.18,FY+b.y+0.90,start+direction*b.x),0.027,metal)
        # Wall brackets and circular rosettes keep the continuous rail attached.
        for j in range(11):
            var t: float=float(j)*1.08
            var height: float=minf(t,5.56)*2.25/5.56+maxf(0.0,t-6.46)*1.80/4.56
            var p := Vector3(x-side*0.18,FY+height+0.86,start+direction*t)
            rod(p,p+Vector3(side*0.15,-0.065,0),0.013,metal)
            sphere(Vector3(0.035,0.075,0.075),p+Vector3(side*0.15,-0.065,0),metal)
        for j in range(12):
            var a: float=float(j)*PI/12.0;var b: float=float(j+1)*PI/12.0
            rod(Vector3(x-side*0.18,FY+0.90-0.18*sin(a),start-direction*(0.20+0.18*cos(a))),Vector3(x-side*0.18,FY+0.90-0.18*sin(b),start-direction*(0.20+0.18*cos(b))),0.027,metal)
        picture("no_smoking.svg",Vector2(0.23,0.23),Vector3(x,FY+1.72,start-direction*0.302),0.0 if direction<0.0 else PI)
        picture("sos_info.svg",Vector2(0.29,0.45),Vector3(x,FY+0.83,start-direction*0.303),0.0 if direction<0.0 else PI)
    # Independent stair soffit. No continuation of the platform column girders.
    box(Vector3(width+0.5,2.82,0.35),Vector3(CX,6.37,start-direction*0.22),white)
    box(Vector3(width+0.5,0.16,18.3),Vector3(CX,ceiling+0.08,start+direction*8.95),white)
    for i in range(14):
        var z: float=start+direction*(float(i)*1.3)
        box(Vector3(width,0.09,0.10),Vector3(CX,ceiling-0.045,z),white)
        if i%2==0:
            box(Vector3(5.65,0.07,0.15),Vector3(CX,ceiling-0.13,z+direction*0.20),metal)
            box(Vector3(5.53,0.04,0.105),Vector3(CX,ceiling-0.185,z+direction*0.20),glow)
    # Two actual linear entrance luminaires above the suspended exit board.
    for dz in [-0.26,0.26]:
        box(Vector3(5.75,0.085,0.12),Vector3(CX,4.93,start-direction*(0.40+float(dz))),metal)
        box(Vector3(5.61,0.045,0.09),Vector3(CX,4.875,start-direction*(0.40+float(dz))),glow)
    board("exit_north_v60.svg" if direction<0.0 else "exit_south_v60.svg",Vector3(CX,4.43,start-direction*0.43),Vector2(5.85,0.85))
    foot_grille(start-direction*0.45,7.45)
    _upper_control_area(direction,finish,top_y,width)

func _upper_control_area(direction: float,finish: float,floor_y: float,width: float) -> void:
    var gate_z: float=finish+direction*2.3
    var reader := _material(Color("#283336"),0.26,0.30)
    var green := _material(Color("#46cf95"));green.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    var red := _material(Color("#e55345"));red.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    # Seven cabinets define six usable lanes, including a wider side gate.
    for i in range(7):
        var x: float=CX-2.75+float(i)*0.80
        box(Vector3(0.22,0.94,1.05),Vector3(x,floor_y+0.47,gate_z),metal)
        _round_box(Vector3(0.245,0.07,1.08),Vector3(x,floor_y+0.955,gate_z),reader,0.025)
        box(Vector3(0.14,0.025,0.21),Vector3(x,floor_y+1.00,gate_z-direction*0.29),black)
        for d in [-1.0,1.0]:
            box(Vector3(0.075,0.045,0.012),Vector3(x,floor_y+0.79,gate_z+d*0.531),green if i%3!=0 else red)
        if i<6:
            # Three-arm turnstile hub, connected to the cabinet side.
            sphere(Vector3(0.14,0.14,0.14),Vector3(x+0.13,floor_y+0.65,gate_z),metal)
            for j in range(3):
                var a: float=float(j)*TAU/3.0
                rod(Vector3(x+0.13,floor_y+0.65,gate_z),Vector3(x+0.60,floor_y+0.65+sin(a)*0.24,gate_z+cos(a)*0.24),0.023,metal)
    for side in [-1.0,1.0]:
        var x: float=CX+side*(width*0.5-0.12)
        for z in [finish+direction*0.10,gate_z+direction*0.70]:
            cylinder(0.06,0.025,Vector3(x,floor_y+0.012,float(z)),metal)
            rod(Vector3(x,floor_y,float(z)),Vector3(x,floor_y+1.05,float(z)),0.026,metal)
        for h in [0.48,1.05]:
            rod(Vector3(x,floor_y+float(h),finish+direction*0.10),Vector3(x,floor_y+float(h),gate_z+direction*0.70),0.026,metal)
    # Glazed controller booth behind the gates, visible from the platform.
    var bx: float=CX+2.65
    var bz: float=finish+direction*4.65
    var glass := _material(Color(0.28,0.43,0.44,0.26),0.0,0.16)
    glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    glass.cull_mode=BaseMaterial3D.CULL_DISABLED
    box(Vector3(1.50,0.78,1.55),Vector3(bx,floor_y+0.39,bz),white)
    box(Vector3(1.55,0.14,1.60),Vector3(bx,floor_y+2.30,bz),white)
    for dx in [-0.73,0.73]:
        for dz in [-0.755,0.755]:
            box(Vector3(0.045,1.48,0.045),Vector3(bx+float(dx),floor_y+1.51,bz+float(dz)),metal)
        box(Vector3(0.018,1.40,1.45),Vector3(bx+float(dx),floor_y+1.50,bz),glass)
    for dz in [-0.755,0.755]:
        box(Vector3(1.40,1.40,0.018),Vector3(bx,floor_y+1.50,bz+float(dz)),glass)
        for h in [0.79,2.22]:box(Vector3(1.50,0.035,0.04),Vector3(bx,floor_y+float(h),bz+float(dz)),metal)
    box(Vector3(1.25,0.055,0.45),Vector3(bx,floor_y+0.94,bz-direction*0.45),oak)
    box(Vector3(0.39,0.25,0.045),Vector3(bx-0.26,floor_y+1.13,bz-direction*0.52),black)
    box(Vector3(0.34,0.20,0.01),Vector3(bx-0.26,floor_y+1.13,bz-direction*0.549),reader)
    box(Vector3(width+0.4,2.65,0.22),Vector3(CX,floor_y+1.325,finish+direction*6.85),wall_stone)
    for dx in [-1.9,0.1]:
        box(Vector3(1.55,2.12,0.045),Vector3(CX+float(dx),floor_y+1.06,finish+direction*6.72),metal)
        box(Vector3(1.40,1.95,0.025),Vector3(CX+float(dx),floor_y+1.06,finish+direction*6.68),reader)
    var light := OmniLight3D.new();light.name="UpperLandingLight"
    light.position=Vector3(CX,floor_y+2.20,finish+direction*2.8)
    light.light_color=Color(0.98,0.97,0.91);light.light_energy=1.25;light.omni_range=8.0;light.shadow_enabled=false;add_child(light)

func _signs() -> void:
    # Column centres: -1.5 + i*4.35, half-width 0.40. Each board including its
    # frame is 3.26m long inside the 3.55m clear gap; no structural column removed.
    for bay in [2,8,15]:
        var z: float=-1.5+(float(bay)+0.5)*4.35
        for side in [-1.0,1.0]:
            var size := Vector2(3.18,0.56)
            var p := Vector3(CX+side*2.25,4.23,z)
            box(Vector3(0.08,size.y+0.07,size.x+0.08),p,metal)
            for face in [-1.0,1.0]:picture("platform_track1.svg" if side>0.0 else "platform_track2.svg",size,p+Vector3(face*0.047,0,0),face*PI/2.0)
            for dz in [-1.30,1.30]:rod(p+Vector3(0,size.y*0.5,float(dz)),p+Vector3(0,4.67-p.y,float(dz)),0.019,metal)

func _bench(p: Vector3) -> void:
    var brown := _material(Color("#514339"),0.25,0.61)
    box(Vector3(0.60,0.38,2.45),p+Vector3(0,0.19,0),brown)
    for i in range(5):
        var z: float=p.z-0.98+float(i)*0.49
        _round_box(Vector3(0.63,0.10,0.46),Vector3(p.x,p.y+0.43,z),oak,0.025)
        for dx in [-0.14,0.14]:box(Vector3(0.009,0.008,0.455),Vector3(p.x+float(dx),p.y+0.485,z),brown)
        if i<4:box(Vector3(0.68,0.065,0.037),Vector3(p.x,p.y+0.46,z+0.244),brown)

func _advert_material() -> void:
    # Native lit-up artwork also works on Web without a custom animation shader.
    _advert=StandardMaterial3D.new()
    _advert.albedo_texture=load(ART+"advert_atlas.svg")
    _advert.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    _advert.cull_mode=BaseMaterial3D.CULL_DISABLED
    _advert.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    _advert.uv1_scale=Vector3(1.0/3.0,1.0,1.0)

func _television(z: float) -> void:
    var p := Vector3(CX,4.02,z)
    _round_box(Vector3(1.48,0.88,0.15),p,black,0.025)
    for dx in [-0.48,0.48]:
        rod(p+Vector3(float(dx),0.46,0),Vector3(CX+float(dx),5.38,z),0.012,black)
        box(Vector3(0.12,0.025,0.12),Vector3(CX+float(dx),5.36,z),metal)
    for face in [-1.0,1.0]:
        var card := _advert.duplicate() as StandardMaterial3D
        card.uv1_offset=Vector3((0.0 if z<40.0 else 1.0)/3.0,0,0)
        var q := QuadMesh.new();q.size=Vector2(1.40,0.7875);q.material=card
        var n := MeshInstance3D.new();n.name="PoweredAdvertisingScreen";n.mesh=q;n.position=p+Vector3(0,0,face*0.081);n.rotation.y=0.0 if face>0.0 else PI
        n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(n)
    var led := _material(Color("#45ce8f"));led.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    for face in [-1.0,1.0]:box(Vector3(0.018,0.008,0.006),p+Vector3(0.62,-0.416,face*0.079),led)
    for side in [-1.0,1.0]:
        box(Vector3(0.13,0.24,0.13),Vector3(CX+side*0.90,4.89,z),white)
        rod(Vector3(CX+side*0.90,4.89,z),Vector3(CX+side*0.90,5.20,z),0.009,metal)

func _track_details() -> void:
    # Preserve the portal shells/cables; running tracks are built by Station Base.
    for track in range(2):
        var x: float=0.992 if track==0 else -11.732
        for direction in [-1.0,1.0]:
            var end: float=ZA if direction<0.0 else ZB
            box(Vector3(3.78,0.20,8.0),Vector3(x,4.50,end+direction*3.9),wall_stone)
            for side in [-1.0,1.0]:
                box(Vector3(0.14,4.60,8.0),Vector3(x+side*1.94,2.12,end+direction*3.9),wall_stone)
                for h in [0.70,1.1,1.5,1.9,2.35,2.65]:rod(Vector3(x+side*1.84,float(h),end),Vector3(x+side*1.84,float(h),end+direction*7.8),0.015,black)
            box(Vector3(3.85,4.65,0.10),Vector3(x,2.13,end+direction*8.0),black)

func _portal_equipment() -> void:
    # Keep the common station clock geometry and per-track departure hooks.
    var infra := get_node("StationInfrastructure")
    infra.set("_amber",Color(1.0,0.12,0.045))
    var displays: Array=infra.get("_displays")
    for display in displays:
        for i in range(70,76):display.set_instance_color(i,Color(1.0,0.12,0.045))
    for node in infra.get_children():
        if node is Node3D and "Portal" in str(node.name):node.position.y=4.16
    for direction in [-1.0,1.0]:
        var end: float=ZA if direction<0.0 else ZB
        for side in [-1.0,1.0]:
            var tx: float=CX+side*6.362
            box(Vector3(3.90,0.48,0.25),Vector3(tx,4.15,end),wall_stone)
            for dx in [-1.12,1.12]:
                rod(Vector3(tx+float(dx),4.40,end),Vector3(tx+float(dx),4.75,end),0.022,metal)
        # Track 1 heads towards -Z, track 2 towards +Z. Equipment faces the cab.
        var side: float=1.0 if direction<0.0 else -1.0
        var tx: float=CX+side*6.362
        var yaw: float=0.0 if direction<0.0 else PI
        _driver_mirror(Vector3(CX+side*4.58,FY+1.50,end-direction*2.6),yaw-side*0.13)
        var p := Vector3(tx-side*1.63,4.15,end-direction*0.18)
        box(Vector3(0.82,0.52,0.095),p,black)
        var monitor := MeshInstance3D.new()
        monitor.name="LiveRearPlatformMonitor"
        monitor.set_script(preload("res://modules/stations/moskovskaya/platform_monitor.gd"))
        var q := QuadMesh.new();q.size=Vector2(0.75,0.422)
        monitor.mesh=q;monitor.position=p+Vector3(0,0,-direction*0.055);monitor.rotation.y=yaw
        var tail: float=ZB if direction<0.0 else ZA
        monitor.set("camera_position",Vector3(CX+side*4.13,3.65,tail+direction*1.2))
        monitor.set("camera_target",Vector3(CX+side*5.60,1.35,tail+direction*23.0))
        add_child(monitor)
        rod(p+Vector3(0,0.25,0.04),p+Vector3(0,0.55,0.04),0.017,metal)
        # Physical camera housing is at the opposite (rear) platform end.
        _camera_box(Vector3(CX+side*4.13,3.65,tail+direction*1.2),yaw+PI)

func _driver_mirror(p: Vector3,yaw: float) -> void:
    var root := Node3D.new();root.name="HeadOfTrainDriverMirror";root.position=p;root.rotation.y=yaw;add_child(root)
    var mirror := MeshInstance3D.new()
    mirror.set_script(preload("res://modules/stations/moskovskaya/driver_mirrors.gd"))
    mirror.name="ReflectingPlatformSurface";mirror.position.z=0.022
    var q := QuadMesh.new();q.size=Vector2(0.72,1.88)
    mirror.mesh=q;mirror.set_meta("mirror_size",q.size);root.add_child(mirror)
    var pts: Array[Vector3]=[]
    for corner in range(4):
        var c := Vector2(0.30*(1.0 if corner in [0,3] else -1.0),0.86*(1.0 if corner in [0,1] else -1.0))
        for j in range(9):
            var a: float=float(corner)*PI/2.0+float(j)*PI/16.0
            pts.append(Vector3(c.x+0.11*cos(a),c.y+0.11*sin(a),0))
    for i in range(pts.size()):_local_rod(root,pts[i],pts[(i+1)%pts.size()],0.033,white)
    _local_rod(root,Vector3(0,-1.50,-0.06),Vector3(0,-0.93,-0.06),0.065,_material(Color("#285476"),0.3,0.42))
    _local_rod(root,Vector3(0,-0.93,-0.06),Vector3(0,0.45,-0.06),0.025,metal)
    for dx in [-0.48,0.48]:
        _local_rod(root,Vector3(float(dx),-1.50,0.10),Vector3(float(dx),-0.56,0.10),0.022,yellow)
    _local_rod(root,Vector3(-0.48,-0.56,0.10),Vector3(0.48,-0.56,0.10),0.022,yellow)

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
