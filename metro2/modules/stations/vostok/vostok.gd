extends "res://modules/stations/vostok/station_builder.gd"
## Owner-photo reconstruction, 19 November 2026. Station Base rail/connection datum retained.
const ART := "res://modules/stations/vostok/art/"
const SPRING := 4.25
const CROWN_RISE := 4.05
const STAIR_NORTH := -0.30
const STAIR_SOUTH := 79.524
var pale_stone: ShaderMaterial
var stair_stone: ShaderMaterial
var housing: StandardMaterial3D
var cream: StandardMaterial3D
var red_guard: StandardMaterial3D

func _ready() -> void:
    super._ready()
    begin_station()
    white.albedo_color=Color("#e4e5df")
    pale_stone=stone(Color("#c7c7bb"),true)
    stair_stone=_stair_material()
    housing=_material(Color("#827b69"),0.58,0.38)
    cream=_material(Color("#ebe9db"),0.0,0.70)
    red_guard=_material(Color("#a9353e"),0.32,0.39)
    _floor()
    _photo_platform_edges()
    _walls()
    _vault()
    _ends()
    for z in [14.0,39.612,65.2]:
        _photo_pylon(float(z))
        _five_seat_bench(Vector3(CX,FY,float(z)+1.95))
    _suspended_monitor()
    _track_finishes()
    _floor_fittings()
    _photo_clocks()
    flush()

func _floor() -> void:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
uniform sampler2D grey_tex : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D red_tex : source_color,filter_linear_mipmap,repeat_enable;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float h(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
float x=abs(p.x+5.37);float zz=mod(p.z+2.4,7.2)-3.6;float z=abs(zz);
// Three rectangular tiers form the stepped red granite motif, not a painted star.
float w=z<0.47?1.70:z<0.94?1.18:z<1.41?0.64:0.0;
float motif=(1.0-step(w,x))*(1.0-step(1.41,z));
float connector=(1.0-step(0.36,x))*(1.0-step(0.24,abs(z-2.65)));
float red=max(motif,connector);
float band=1.0-step(0.105,z);float inner=1.0-step(0.025,z);
float edge=1.0-step(0.14,abs(x-4.28));
red=max(red,max(band,edge));
vec3 grey=texture(grey_tex,p.xz*1.65).rgb;
float slab=h(floor(p.xz/vec2(0.60,1.20)));
grey*=0.87+slab*0.22;
vec3 stone=texture(red_tex,p.xz*1.4).rgb;
vec3 base=mix(grey,stone,red);
float center=(1.0-step(0.36,x))*(1.0-step(0.20,z));
float creamline=inner*step(1.74,x)*(1.0-step(4.26,x));
base=mix(base,vec3(0.79,0.78,0.67),max(center,creamline));
vec2 t=fract(p.xz/vec2(0.60,1.20));float joint=1.0-smoothstep(0.0007,0.003,min(min(t.x,1.0-t.x),min(t.y,1.0-t.y)));
ALBEDO=base-vec3(joint*0.036);ROUGHNESS=0.33+slab*0.12;SPECULAR=0.62;
}
"""
    var m := ShaderMaterial.new();m.shader=shader
    m.set_shader_parameter("grey_tex",load(ART+"grey_granite.jpg"))
    m.set_shader_parameter("red_tex",load(ART+"red_granite.jpg"))
    (get_node("IslandPlatform") as MeshInstance3D).material_override=m

func _photo_platform_edges() -> void:
    var edge := stone(Color("#696d68"),true)
    var yellow := _material(Color("#d5ae43"),0.0,0.77)
    for side in [-1.0,1.0]:
        box(Vector3(0.40,0.018,105),Vector3(CX+side*4.80,FY+0.010,MID),edge)
        box(Vector3(0.21,0.012,105),Vector3(CX+side*4.47,FY+0.014,MID),yellow)
        # Shallow tactile studs, instanced in a single material batch.
        for i in range(1312):
            var z: float=ZA+0.04+float(i)*0.08
            for dx in [-0.065,0.0,0.065]:
                cylinder(0.013,0.006,Vector3(CX+side*4.47+float(dx),FY+0.023,z),yellow)
        for i in range(175):
            box(Vector3(0.212,0.001,0.002),Vector3(CX+side*4.47,FY+0.021,ZA+float(i)*0.60),edge)

func _walls() -> void:
    var seam := _material(Color("#bdc0b9"),0.0,0.9)
    var plinth := stone(Color("#363632"),false)
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.90
        box(Vector3(0.30,0.46,105),Vector3(x,0.23,MID),plinth)
        for row in range(4):
            var tint := Color("#655957") if row%2==0 else Color("#574e4b")
            box(Vector3(0.31,0.40,105),Vector3(x,0.64+float(row)*0.40,MID),stone(tint,false))
        var lower: Array[Vector2]=[]
        for j in range(25):
            var t: float=float(j)/24.0
            lower.append(Vector2(x-side*0.22*sin(t*PI),2.02+t*1.65))
        profile(lower,ZA,ZB,white)
        for i in range(51):
            var zz: float=ZA+float(i)*2.10
            # Hairline panel joints follow the curved wall face.
            profile(lower,zz,zz+0.007,seam)
        box(Vector3(0.44,0.50,105),Vector3(x-side*0.10,3.99,MID),pale_stone)
        box(Vector3(0.47,0.025,105),Vector3(x-side*0.12,3.84,MID),housing)
        rod(Vector3(x-side*0.17,3.56,ZA),Vector3(x-side*0.17,3.56,ZB),0.012,cream)
        for i in range(71):
            var zz: float=ZA+float(i)*1.5
            rod(Vector3(x-side*0.14,3.56,zz),Vector3(x-side*0.14,3.68,zz),0.008,metal)
        for z in [12.0,39.612,67.2]:
            box(Vector3(0.52,0.78,4.00),Vector3(x-side*0.15,3.98,float(z)),pale_stone)
            _wall_letters("УСХОД" if side>0.0 else "ВОСТОК",Vector3(x-side*0.43,3.98,float(z)),-side*PI/2.0)
        for z in [12.0,39.612,67.2]:
            picture("line_to_uruchye.svg" if side>0.0 else "line_to_malinovka.svg",Vector2(4.30,0.68),Vector3(x-side*0.26,2.51,float(z)),-side*PI/2.0,true)

func _wall_letters(value: String,p: Vector3,yaw: float) -> void:
    var mesh := TextMesh.new()
    mesh.text=value;mesh.font=load(ART+"station_letters.ttf")
    mesh.font_size=96;mesh.pixel_size=0.0071;mesh.depth=0.045
    mesh.material=brass
    var n := MeshInstance3D.new()
    n.name="RaisedStationName_"+value;n.mesh=mesh;n.position=p;n.rotation.y=yaw
    add_child(n)

func _vault() -> void:
    var coffer := _material(Color("#d5d7d1"),0.0,0.86)
    var joint := _material(Color("#d7d9d3"),0.0,0.88)
    for side in [-1.0,1.0]:
        curved_band(float(side),0.0,PI/2.0,ZA,ZB,SPRING,CROWN_RISE,0.0,white)
    # Fifty bays; each has three rounded diffusers. Crown remains uninterrupted.
    for i in range(50):
        var z: float=ZA+float(i)*2.10
        for side in [-1.0,1.0]:
            curved_band(float(side),0.0,0.69,z,z+0.16,SPRING,CROWN_RISE,0.14,white)
            for j in range(12):
                var a: float=0.67+float(j)*0.005
                var w: float=0.16+0.28*sqrt(maxf(0.0,1.0-pow((a-0.70)/0.04,2.0)))
                curved_band(float(side),a,a+0.005,z-(w-0.16)*0.5,z+0.16+(w-0.16)*0.5,SPRING,CROWN_RISE,0.14,white)
            curved_band(float(side),0.012,0.355,z+0.21,z+1.99,SPRING,CROWN_RISE,0.012,coffer)
            for j in range(3):
                var zz: float=z+0.29+float(j)*0.56
                _rounded_diffuser(float(side),zz,zz+0.48)
        if i%3==0:
            for side in [-1.0,1.0]:curved_band(float(side),0.74,PI/2.0,z,z+0.004,SPRING,CROWN_RISE,0.002,joint)

func _rounded_diffuser(side: float,z0: float,z1: float) -> void:
    for j in range(20):
        var a0: float=0.025+float(j)*0.30/20.0
        var a1: float=0.025+float(j+1)*0.30/20.0
        var t: float=(float(j)+0.5)/20.0
        var inset: float=0.065*(1.0-sqrt(maxf(0.0,1.0-pow(maxf(0.0,absf(t-0.5)-0.36)/0.14,2.0))))
        curved_band(side,a0,a1,z0+inset,z1-inset,SPRING,CROWN_RISE,0.040,glow)

func _ends() -> void:
    for direction in [-1.0,1.0]:
        var start: float=STAIR_NORTH if direction<0.0 else STAIR_SOUTH
        var end: float=ZA if direction<0.0 else ZB
        _photo_stairs(direction,start)
        _upper_landing(direction,end)
        for side in [-1.0,1.0]:
            var tx: float=CX+side*6.362
            _tunnel_mouth(tx,end,direction)
            var p := Vector3(CX+side*4.60,FY+1.39,end-direction*2.0)
            _driver_mirror(p,direction,side)

func _photo_stairs(direction: float,start: float) -> void:
    var width := 8.10
    var rise := 0.115
    var run := 0.255
    var landing := 0.95
    var yellow := _material(Color("#d5b12c"),0.0,0.7)
    for i in range(40):
        var height: float=float(i+1)*rise
        var z: float=start+direction*(float(i)*run+(landing if i>=22 else 0.0))
        box(Vector3(width,height,run+0.002),Vector3(CX,FY+height*0.5,z),stair_stone)
        if i in [0,21,22,39]:box(Vector3(width,0.012,0.045),Vector3(CX,FY+height+0.007,z-direction*0.106),yellow)
    var offsets: Array[Vector2]=[Vector2(-0.13,0),Vector2(5.48,2.53),Vector2(6.43,2.53),Vector2(11.10,4.60)]
    box(Vector3(width,0.17,landing),Vector3(CX,FY+2.53-0.085,start+direction*5.95),stair_stone)
    for side in [-1.0,1.0]:
        var x: float=CX+side*(width*0.5+0.12)
        for i in range(offsets.size()-1):
            var a: Vector2=offsets[i];var b: Vector2=offsets[i+1]
            for face in [-1.0,1.0]:
                var xx: float=x+face*0.12
                quad(Vector3(xx,FY+a.y,start+direction*a.x),Vector3(xx,FY+b.y,start+direction*b.x),Vector3(xx,FY+b.y+0.89,start+direction*b.x),Vector3(xx,FY+a.y+0.89,start+direction*a.x),pale_stone,Vector3(face,0,0))
            quad(Vector3(x-0.15,FY+a.y+0.90,start+direction*a.x),Vector3(x+0.15,FY+a.y+0.90,start+direction*a.x),Vector3(x+0.15,FY+b.y+0.90,start+direction*b.x),Vector3(x-0.15,FY+b.y+0.90,start+direction*b.x),redstone,Vector3.UP)
            rod(Vector3(x,FY+a.y+0.94,start+direction*a.x),Vector3(x,FY+b.y+0.94,start+direction*b.x),0.033,housing)
        picture("stair_caution.svg",Vector2(0.16,0.23),Vector3(x-direction*0.01,FY+0.61,start-direction*0.135),0.0 if direction<0.0 else PI)
    foot_grille(start-direction*0.40,8.0)
    board("exit_north.svg" if direction<0.0 else "exit_south.svg",Vector3(CX,6.89,start+direction*6.4),Vector2(5.65,0.82))

func _upper_landing(direction: float,end: float) -> void:
    var y: float=FY+4.60
    box(Vector3(17.9,0.32,5.4),Vector3(CX,y-0.16,end+direction*1.10),pale_stone)
    # Gallery balustrades stand above both tunnel mouths, beside the staircase.
    for side in [-1.0,1.0]:
        var x: float=CX+side*6.60
        box(Vector3(4.5,0.63,0.24),Vector3(x,y+0.27,end-direction*0.44),pale_stone)
        for height in [0.65,0.89,1.10]:
            rod(Vector3(x-2.20,y+float(height),end-direction*0.44),Vector3(x+2.20,y+float(height),end-direction*0.44),0.022,metal)
        for dx in [-2.18,0.0,2.18]:rod(Vector3(x+float(dx),y+0.55,end-direction*0.44),Vector3(x+float(dx),y+1.10,end-direction*0.44),0.022,metal)
    box(Vector3(17.9,2.6,0.22),Vector3(CX,y+1.30,end+direction*3.4),pale_stone)
    # A real vestibule threshold, with turnstile cabinets and glazed attendant cabin.
    for i in range(7):
        var x: float=CX-2.8+float(i)*0.93
        box(Vector3(0.22,0.95,1.0),Vector3(x,y+0.475,end+direction*2.25),metal)
        box(Vector3(0.25,0.07,0.42),Vector3(x,y+0.96,end+direction*2.02),black)
        rod(Vector3(x,y+0.71,end+direction*2.0),Vector3(x+0.44,y+0.71,end+direction*2.0),0.018,metal)
    var blue := _material(Color("#274f75"),0.35,0.30)
    var glass := _material(Color(0.19,0.27,0.30,0.28),0.3,0.15)
    glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    var cabin_x: float=CX+3.40*direction
    box(Vector3(1.18,0.75,1.20),Vector3(cabin_x,y+0.375,end+direction*1.50),blue)
    box(Vector3(1.18,1.25,0.035),Vector3(cabin_x,y+1.375,end+direction*0.90),glass)
    for dx in [-0.59,0.59]:rod(Vector3(cabin_x+float(dx),y+0.75,end+direction*0.90),Vector3(cabin_x+float(dx),y+2.0,end+direction*0.90),0.025,blue)
    for j in range(10):
        var zz: float=end-direction*10.5+direction*float(j)*1.45
        # Curved transverse strip lights belong only to the lower end canopy.
        for k in range(24):
            var x0: float=-4.1+float(k)*8.2/24.0
            var x1: float=-4.1+float(k+1)*8.2/24.0
            var h0: float=8.10-0.50*pow(x0/4.1,2.0)
            var h1: float=8.10-0.50*pow(x1/4.1,2.0)
            rod(Vector3(CX+x0,h0,zz),Vector3(CX+x1,h1,zz),0.026,glow)
    box(Vector3(6.8,0.19,0.10),Vector3(CX,7.76,end+direction*3.24),black)
    for i in range(70):box(Vector3(0.025,0.24,0.07),Vector3(CX-3.35+float(i)*0.096,7.60,end+direction*3.16),black)

func _tunnel_mouth(x: float,z: float,direction: float) -> void:
    for j in range(48):
        var a: float=float(j)*TAU/48.0
        var b: float=float(j+1)*TAU/48.0
        var p0 := Vector3(x+2.04*cos(a),2.13+2.35*sin(a),z)
        var p1 := Vector3(x+2.04*cos(b),2.13+2.35*sin(b),z)
        quad(p0,p1,p1+Vector3(0,0,direction*8.0),p0+Vector3(0,0,direction*8.0),black,Vector3(-cos(a),-sin(a),0))
        for depth in [0.08,1.50,3.0,4.5,6.0]:
            var offset := Vector3(0,0,direction*float(depth))
            rod(p0+offset,p1+offset,0.035,housing)
    box(Vector3(4.12,4.8,0.08),Vector3(x,2.13,z+direction*8.0),black)
    for side in [-1.0,1.0]:
        for y in [1.2,1.6,2.0,2.4]:
            rod(Vector3(x+side*1.99,float(y),z),Vector3(x+side*1.99,float(y),z+direction*7.8),0.018,black)

func _rounded_box(size: Vector3,p: Vector3,mat: Material,r: float=0.05) -> void:
    var pts := PackedVector2Array()
    for corner in range(4):
        var center := Vector2(p.x+(size.x*0.5-r)*(1.0 if corner in [0,3] else -1.0),p.y+(size.y*0.5-r)*(1.0 if corner in [0,1] else -1.0))
        for j in range(7):
            var a: float=float(corner)*PI/2.0+float(j)*PI/12.0
            pts.append(center+Vector2(cos(a),sin(a))*r)
    extrusion(pts,p.z-size.z*0.5,p.z+size.z*0.5,mat)

func _photo_pylon(z: float) -> void:
    _rounded_box(Vector3(0.54,1.0,0.54),Vector3(CX,FY+0.50,z),housing,0.05)
    _rounded_box(Vector3(0.91,2.16,0.85),Vector3(CX,FY+2.08,z),housing,0.065)
    for face in [-1.0,1.0]:
        var yaw: float=0.0 if face>0.0 else PI
        picture("pylon_track1.svg" if face>0.0 else "pylon_track2.svg",Vector2(0.70,1.99),Vector3(CX,FY+2.08,z+face*0.434),yaw)
        picture("pylon_exit_a.svg" if face>0.0 else "pylon_exit_b.svg",Vector2(0.74,1.99),Vector3(CX+face*0.463,FY+2.08,z),face*PI/2.0)
        # Panel screws and red protective tubular cradle around the ribbed top unit.
        for dx in [-0.405,0.405]:
            for y in [FY+1.08,FY+3.08]:sphere(Vector3(0.018,0.018,0.014),Vector3(CX+float(dx),float(y),z+face*0.435),metal)
        _rounded_tube(Vector3(CX,FY+3.51,z+face*0.35),Vector2(0.98,0.69),0.12,0.031,red_guard)
    _rounded_box(Vector3(0.86,0.62,0.70),Vector3(CX,FY+3.51,z),housing,0.09)
    for face in [-1.0,1.0]:
        for i in range(13):
            box(Vector3(0.018,0.48,0.015),Vector3(CX-0.34+float(i)*0.056,FY+3.51,z+face*0.358),black)
        sphere(Vector3(0.115,0.115,0.008),Vector3(CX,FY+3.37,z+face*0.37),black)
    box(Vector3(0.18,0.22,0.18),Vector3(CX,FY+3.93,z),metal)
    _rounded_box(Vector3(1.45,0.84,0.075),Vector3(CX,FY+4.40,z),black,0.014)
    for face in [-1.0,1.0]:picture("screen_year_2026.jpg",Vector2(1.39,0.782),Vector3(CX,FY+4.40,z+face*0.044),0.0 if face>0.0 else PI)
    # Stainless waist rail wraps the pedestal and bends away at the two ends.
    for side in [-1.0,1.0]:
        var x: float=CX+side*0.27
        rod(Vector3(x,FY+0.10,z),Vector3(x,FY+0.89,z),0.026,metal)
        rod(Vector3(x,FY+0.89,z),Vector3(x+side*0.32,FY+1.02,z),0.026,metal)
        rod(Vector3(x+side*0.32,FY+1.02,z-0.48),Vector3(x+side*0.32,FY+1.02,z+0.48),0.026,metal)
        rod(Vector3(x+side*0.32,FY+1.02,z-0.48),Vector3(CX,FY+1.02,z-0.58),0.026,metal)
        rod(Vector3(x+side*0.32,FY+1.02,z+0.48),Vector3(CX,FY+1.02,z+0.58),0.026,metal)
    _cctv(Vector3(CX+0.62,FY+3.70,z))

func _rounded_tube(p: Vector3,size: Vector2,r: float,tube: float,mat: Material) -> void:
    var pts: Array[Vector3]=[]
    for i in range(4):
        var c := Vector2((size.x*0.5-r)*(1.0 if i in [0,3] else -1.0),(size.y*0.5-r)*(1.0 if i in [0,1] else -1.0))
        for j in range(9):
            var a: float=float(i)*PI/2.0+float(j)*PI/16.0
            pts.append(p+Vector3(c.x+r*cos(a),c.y+r*sin(a),0))
    for i in range(pts.size()):rod(pts[i],pts[(i+1)%pts.size()],tube,mat)

func _cctv(p: Vector3) -> void:
    rod(p-Vector3(0.2,0.2,0),p,0.016,metal)
    box(Vector3(0.12,0.10,0.26),p+Vector3(0,0.06,0),cream)
    box(Vector3(0.15,0.018,0.30),p+Vector3(0,0.12,-0.018),cream)
    sphere(Vector3(0.056,0.056,0.012),p+Vector3(0,0.06,0.135),black)

func _five_seat_bench(p: Vector3) -> void:
    # Five separate wide wooden seat modules, longitudinal on the platform centreline.
    var oak := wood_material()
    for i in range(5):
        var z: float=p.z-0.96+float(i)*0.48
        box(Vector3(0.68,0.10,0.45),Vector3(p.x,p.y+0.47,z),oak)
        for d in [-0.13,0.13]:box(Vector3(0.69,0.006,0.009),Vector3(p.x,p.y+0.523,z+float(d)),housing)
        box(Vector3(0.65,0.07,0.035),Vector3(p.x,p.y+0.40,z-0.235),housing)
    for z in [-0.86,0.86]:box(Vector3(0.49,0.40,0.16),p+Vector3(0,0.20,float(z)),housing)

func _driver_mirror(p: Vector3,direction: float,side: float) -> void:
    var root := Node3D.new()
    root.name="DriverMirror";root.position=p;root.rotation.y=(0.0 if direction<0.0 else PI)-side*0.16
    add_child(root)
    var frame := _material(Color("#e3e9df"),0.12,0.38)
    var blue := _material(Color("#265785"),0.3,0.42)
    # Build in local coordinates so both portal ends face back into the hall.
    var script := preload("res://modules/stations/vostok/driver_mirrors.gd")
    var mirror := MeshInstance3D.new();mirror.set_script(script)
    mirror.name="ReflectingSurface";mirror.position=Vector3(0,0,0.014)
    var q := QuadMesh.new();q.size=Vector2(0.55,1.53)
    mirror.mesh=q;mirror.set_meta("mirror_size",q.size);root.add_child(mirror)
    # White rounded rectangular frame, blue pedestal, stainless track-edge guard.
    var frame_path: Array[Vector3]=[]
    for i in range(4):
        var c := Vector2(0.235*(1.0 if i in [0,3] else -1.0),0.70*(1.0 if i in [0,1] else -1.0))
        for j in range(9):
            var a: float=float(i)*PI/2.0+float(j)*PI/16.0
            frame_path.append(Vector3(c.x+0.09*cos(a),c.y+0.09*sin(a),0))
    for i in range(frame_path.size()):_local_rod(root,frame_path[i],frame_path[(i+1)%frame_path.size()],0.028,frame)
    _local_rod(root,Vector3(0,-1.30,0),Vector3(0,-0.78,0),0.075,blue)
    for dx in [-0.41,0.41]:
        _local_rod(root,Vector3(float(dx),-1.39,-0.02),Vector3(float(dx),-0.51,-0.02),0.025,metal)
        _local_rod(root,Vector3(float(dx),-0.51,-0.02),Vector3(float(dx),-0.51,0.30),0.025,metal)
    _local_rod(root,Vector3(-0.41,-0.51,0.30),Vector3(0.41,-0.51,0.30),0.025,metal)

func _local_rod(parent: Node3D,a: Vector3,b: Vector3,r: float,mat: Material) -> void:
    var mesh := CylinderMesh.new();mesh.top_radius=r;mesh.bottom_radius=r;mesh.height=a.distance_to(b);mesh.radial_segments=12;mesh.material=mat
    var n := MeshInstance3D.new();n.mesh=mesh;n.position=(a+b)*0.5
    var axis := Vector3.UP.cross((b-a).normalized())
    if axis.length_squared()>0.00001:n.basis=Basis(axis.normalized(),Vector3.UP.angle_to((b-a).normalized()))
    parent.add_child(n)

func _suspended_monitor() -> void:
    var z := 51.0
    box(Vector3(1.30,0.76,0.09),Vector3(CX,6.65,z),black)
    for dx in [-0.43,0.43]:rod(Vector3(CX+float(dx),7.90,z),Vector3(CX+float(dx),7.04,z),0.012,black)
    for i in range(15):
        var a: float=float(i)*PI/30.0
        var b: float=float(i+1)*PI/30.0
        rod(Vector3(CX-8.9*cos(a),SPRING+CROWN_RISE*sin(a)-0.08,z),Vector3(CX-8.9*cos(b),SPRING+CROWN_RISE*sin(b)-0.08,z),0.014,housing)

func _track_finishes() -> void:
    for track_name in ["Track1","Track2"]:
        var root := get_node(track_name)
        (root.get_node("Beds") as MultiMeshInstance3D).multimesh.mesh.material=stone(Color("#302e28"),false)
        (root.get_node("Sleepers") as MultiMeshInstance3D).multimesh.mesh.material=stone(Color("#3c3830"),false)
        var tx: float=0.992 if track_name=="Track1" else -11.732
        for i in range(161):
            var z: float=ZA+float(i)*0.65
            for x in [-0.8075,0.8075]:
                box(Vector3(0.22,0.023,0.15),Vector3(tx+float(x),-0.11,z),black)
        for z in [-5.0,84.0]:
            box(Vector3(0.55,0.015,2.20),Vector3(tx,-0.12,float(z)),black)
            for i in range(4):box(Vector3(0.13,0.018,0.13),Vector3(tx,-0.10,float(z)-0.72+float(i)*0.48),cream)

func _floor_fittings() -> void:
    for z in [7.0,29.0,53.0,75.0]:
        cylinder(0.17,0.011,Vector3(CX+1.42,FY+0.011,float(z)),housing)
        for i in range(7):box(Vector3(0.010,0.014,0.24),Vector3(CX+1.33+float(i)*0.03,FY+0.019,float(z)),black)
        box(Vector3(0.30,0.015,0.30),Vector3(CX+0.85,FY+0.014,float(z)+2.0),housing)
        for i in range(8):box(Vector3(0.012,0.019,0.24),Vector3(CX+0.74+float(i)*0.03,FY+0.022,float(z)+2.0),black)

func _photo_clocks() -> void:
    # Retain the existing Minsk-time and per-track departure logic; match red displays.
    var infrastructure := get_node("StationInfrastructure")
    infrastructure.set("_amber",Color(1.0,0.12,0.045))
    var displays: Array=infrastructure.get("_displays")
    for display in displays:
        for i in range(70,76):display.set_instance_color(i,Color(1.0,0.12,0.045))
    for node in infrastructure.get_children():
        if node is Node3D and "Portal" in str(node.name):
            node.position.y=4.76
            var s: float=1.0 if node.position.x>CX else -1.0
            node.position.x=CX+s*6.40

func _stair_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
uniform sampler2D stone_tex : source_color,filter_linear_mipmap,repeat_enable;
varying vec3 p;void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){vec3 c=texture(stone_tex,vec2(p.x*0.65,p.z*1.8+p.y*2.4)).rgb;ALBEDO=c*0.88;ROUGHNESS=0.36;SPECULAR=0.55;}
"""
    var m := ShaderMaterial.new();m.shader=shader;m.set_shader_parameter("stone_tex",load(ART+"stair_marble.jpg"));return m
