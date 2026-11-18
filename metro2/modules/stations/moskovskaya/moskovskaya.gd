extends "res://modules/stations/moskovskaya/station_builder.gd"
## Photo-derived fluted marble columns, curved coffer beams and real marble compositions.
var _hour_hands: Array[Node3D]=[]
var _minute_hands: Array[Node3D]=[]
var _clock_second := -1
func _ready() -> void:
    super._ready()
    begin_station()
    _floor()
    platform_edges()
    _walls()
    _columns()
    _ceiling()
    portals(7.6)
    stairs(-1.0,-3.5)
    stairs(1.0,82.5)
    for z in [18.0,43.0,68.0]:
        for side in [-1.0,1.0]:
            detailed_bench(Vector3(CX+side*1.7,FY,float(z)),PI/2.0 if side>0.0 else -PI/2.0)
    for z in [10.0,72.0]:
        for side in [-1.0,1.0]:
            board("direction_north.svg" if side>0.0 else "direction_south.svg",Vector3(CX+side*3.70,4.02,float(z)),Vector2(3.3,0.62))
    for z in [26.0,55.0]:
        rod(Vector3(CX,5.1,float(z)),Vector3(CX,4.35,float(z)),0.022,metal)
        box(Vector3(1.02,0.63,0.14),Vector3(CX,4.12,float(z)),black)
    vestibule(-1.0,-3.5,"moskovskaya")
    vestibule(1.0,82.5,"moskovskaya")
    _end_clock(-1.0,-2.78)
    _end_clock(1.0,81.78)
    finish_hall()
    flush()

func _floor() -> void:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
float x=abs(p.x+5.37);float transverse=abs(mod(p.z+1.0,4.35)-2.175);
float line=max(1.0-step(0.020,abs(x-2.25)),1.0-step(0.022,transverse));
vec2 tiles=fract(p.xz/0.62);float joint=1.0-smoothstep(0.001,0.003,min(min(tiles.x,1.0-tiles.x),min(tiles.y,1.0-tiles.y)));
float grain=fract(sin(dot(floor(p.xz*180.0),vec2(12.9898,78.233)))*43758.5453);
ALBEDO=mix(vec3(0.40,0.25,0.21),vec3(0.61,0.62,0.55),line)*(0.87+grain*0.2)-vec3(joint*0.025);ROUGHNESS=0.48;SPECULAR=0.5;
}
"""
    var m := ShaderMaterial.new();m.shader=shader
    (get_node("IslandPlatform") as MeshInstance3D).material_override=m

func _walls() -> void:
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.9
        box(Vector3(0.28,0.85,105),Vector3(x,0.40,MID),granite)
        box(Vector3(0.26,3.65,105),Vector3(x,2.67,MID),marble)
        for y in [1.82,1.88,2.34,2.40]:
            box(Vector3(0.30,0.018,105),Vector3(x-side*0.02,float(y),MID),brass)
        for z in [14.0,65.0]:
            if side>0.0:
                crop_picture("moscow_mural_11.jpg",Vector2(7.1,0.43),Vector3(x-side*0.15,2.12,float(z)),-side*PI/2.0,Rect2(0.10,0.775,0.80,0.084),0.40)
            else:
                picture("name_ru.svg",Vector2(7.1,0.43),Vector3(x-side*0.15,2.12,float(z)),-side*PI/2.0,true)
        for z in [28.0,78.0]:
            picture("line.svg",Vector2(4.6,0.80),Vector3(x-side*0.15,2.25,float(z)),-side*PI/2.0)
        var files := ["moscow_mural_11.jpg","moscow_mural_10.jpg","moscow_mural_12.jpg","moscow_mural_13.jpg","moscow_mural_14.jpg","moscow_mural_21.jpg"]
        var crops := [Rect2(0.01,0.16,0.98,0.58),Rect2(0.01,0.12,0.98,0.69),Rect2(0.01,0.17,0.98,0.65),Rect2(0.01,0.08,0.98,0.80),Rect2(0.01,0.07,0.98,0.84),Rect2(0.01,0.09,0.98,0.79)]
        for i in range(6):
            var index: int=i if side>0.0 else 5-i
            crop_picture(files[index],Vector2(16.75,1.94),Vector3(x-side*0.146,3.45,ZA+8.5+float(i)*17.5),-side*PI/2.0,crops[index],0.42)
        for i in range(53):
            var z: float=ZA+float(i)*2.0
            box(Vector3(0.40,0.14,0.21),Vector3(x-side*0.12,4.53,z),metal)
            box(Vector3(0.41,0.04,0.16),Vector3(x-side*0.12,4.45,z),glow)

func _columns() -> void:
    # The flutes are cut into all four faces; painted lines do not replace the grooves.
    var seam := _material(Color("#8e9187"),0.0,0.8)
    var coords := PackedFloat32Array([-0.325,-0.267,-0.250,-0.233,-0.09,-0.075,-0.055,-0.035,-0.015,0.015,0.035,0.055,0.075,0.09,0.233,0.250,0.267,0.325])
    var outline := PackedVector2Array()
    for face in range(4):
        for x in coords:
            var inset: float=0.026 if absf(absf(x)-0.25)<0.002 or absf(absf(x)-0.055)<0.002 or absf(x)<0.02 else 0.0
            outline.append(Vector2(x,-0.325+inset).rotated(float(face)*PI/2.0))
    for side in [-1.0,1.0]:
        var x: float=CX+side*2.25
        for i in range(20):
            var z: float=-1.5+float(i)*4.35
            for edge in range(outline.size()):
                var a: Vector2=outline[edge]
                var b: Vector2=outline[(edge+1)%outline.size()]
                quad(Vector3(x+a.x,FY+0.10,z+a.y),Vector3(x+b.x,FY+0.10,z+b.y),Vector3(x+b.x,4.83,z+b.y),Vector3(x+a.x,4.83,z+a.y),marble,Vector3((a.x+b.x)*0.5,0,(a.y+b.y)*0.5))
            box(Vector3(0.67,0.10,0.67),Vector3(x,FY+0.05,z),granite)
            box(Vector3(0.68,0.09,0.68),Vector3(x,4.84,z),white)
            for h in [FY+1.24,FY+2.48]:
                box(Vector3(0.652,0.004,0.652),Vector3(x,float(h),z),seam)

func _ceiling() -> void:
    box(Vector3(4.55,0.12,85),Vector3(CX,5.31,39.5),white)
    var diffuser := _material(Color("#c0c1bb"),0.05,0.36)
    var recess := _material(Color("#77796f"),0.2,0.63)
    for side in [-1.0,1.0]:
        box(Vector3(6.55,0.13,105),Vector3(CX+side*5.65,5.04,MID),white)
        box(Vector3(0.29,0.32,88),Vector3(CX+side*2.25,4.91,39.5),white)
        box(Vector3(0.12,0.055,88),Vector3(CX+side*2.38,4.73,39.5),glow)
        for i in range(47):
            var z: float=-1.0+float(i)*1.83
            _rounded_beam(CX+side*5.65,6.50,4.87,z)
    for i in range(47):
        var z: float=-1.0+float(i)*1.83
        _rounded_beam(CX,4.50,5.12,z)
        for x in [-1.50,0.0,1.50]:
            box(Vector3(1.43,0.035,1.61),Vector3(CX+float(x),5.205,z+0.88),recess)
            box(Vector3(1.32,0.025,1.50),Vector3(CX+float(x),5.177,z+0.88),diffuser)
            box(Vector3(0.025,0.035,1.60),Vector3(CX+float(x)-0.70,5.165,z+0.88),brass)
            box(Vector3(0.025,0.035,1.60),Vector3(CX+float(x)+0.70,5.165,z+0.88),brass)
            box(Vector3(1.30,0.009,0.012),Vector3(CX+float(x),5.157,z+0.88),metal)

func _rounded_beam(x: float,width: float,y: float,z: float) -> void:
    var points := PackedVector2Array([Vector2(x-width*0.5,y+0.15),Vector2(x+width*0.5,y+0.15),Vector2(x+width*0.5,y-0.34)])
    for i in range(13):
        var a: float=float(i)*PI/24.0
        points.append(Vector2(x+width*0.5-0.12-0.20*sin(a),y-0.34+0.20*(1.0-cos(a))))
    for i in range(13):
        var a: float=float(12-i)*PI/24.0
        points.append(Vector2(x-width*0.5+0.12+0.20*sin(a),y-0.34+0.20*(1.0-cos(a))))
    points.append(Vector2(x-width*0.5,y-0.34))
    extrusion(points,z-0.075,z+0.075,white)

func _end_clock(direction: float,z: float) -> void:
    var root := Node3D.new();root.name="LiveKremlinStyleClock";root.position=Vector3(CX,6.48,z);root.rotation.y=0.0 if direction<0.0 else PI;add_child(root)
    var face := MeshInstance3D.new();var disk := CylinderMesh.new();disk.top_radius=0.63;disk.bottom_radius=0.63;disk.height=0.025;disk.radial_segments=80;disk.material=_material(Color("#c1bfad"),0.15,0.45);face.mesh=disk;face.rotation.x=PI/2.0;root.add_child(face)
    for i in range(64):
        var a: float=float(i)*TAU/64.0;var b: float=float(i+1)*TAU/64.0
        var n := MeshInstance3D.new();var mesh := CylinderMesh.new();mesh.top_radius=0.012;mesh.bottom_radius=0.012;mesh.height=Vector2(sin(a)-sin(b),cos(a)-cos(b)).length()*0.60;mesh.radial_segments=8;mesh.material=brass;n.mesh=mesh;n.position=Vector3((sin(a)+sin(b))*0.30,(cos(a)+cos(b))*0.30,0.024);n.rotation.z=-(a+b)*0.5;root.add_child(n)
    var romans := ["XII","I","II","III","IV","V","VI","VII","VIII","IX","X","XI"]
    for i in range(12):
        var a: float=float(i)*TAU/12.0;var label := Label3D.new();label.text=romans[i];label.font_size=32;label.pixel_size=0.0024;label.outline_size=0;label.modulate=Color("#d6b847");label.position=Vector3(sin(a)*0.49,cos(a)*0.49,0.025);root.add_child(label)
    for kind in range(2):
        var pivot := Node3D.new();root.add_child(pivot)
        var hand := MeshInstance3D.new();var mesh := BoxMesh.new();mesh.size=Vector3(0.025,0.37 if kind==0 else 0.48,0.014);mesh.material=brass;hand.mesh=mesh;hand.position=Vector3(0,0.16 if kind==0 else 0.21,0.045+float(kind)*0.015);pivot.add_child(hand)
        if kind==0:_hour_hands.append(pivot)
        else:_minute_hands.append(pivot)
    # Ornamental mosaic bands around the photographed stair clock.
    for dx in [-2.0,-1.12,1.12,2.0]:
        box(Vector3(0.13,2.90,0.035),Vector3(CX+float(dx),6.48,z),redstone)
        box(Vector3(0.035,2.90,0.04),Vector3(CX+float(dx)+0.17,6.48,z),granite)

func _process(_delta: float) -> void:
    var now := int(Time.get_unix_time_from_system())
    if now==_clock_second:return
    _clock_second=now
    var date := Time.get_datetime_dict_from_unix_time(now+3*3600)
    for n in _hour_hands:n.rotation.z=-(float(int(date.hour)%12)+float(date.minute)/60.0)*TAU/12.0
    for n in _minute_hands:n.rotation.z=-(float(date.minute)+float(date.second)/60.0)*TAU/60.0