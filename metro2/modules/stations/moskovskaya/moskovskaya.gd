extends "res://modules/stations/moskovskaya/station_builder.gd"
## Three spans, two rows of square fluted marble columns, low coffered ceiling.
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
            bench(Vector3(CX+side*1.7,FY,float(z)),PI/2.0 if side>0.0 else -PI/2.0)
    for z in [15.0,42.0,69.0]:
        for side in [-1.0,1.0]:
            board("direction_north.svg" if side>0.0 else "direction_south.svg",Vector3(CX+side*3.70,4.02,float(z)),Vector2(3.3,0.62))
    for z in [26.0,55.0]:
        rod(Vector3(CX,5.1,float(z)),Vector3(CX,4.35,float(z)),0.022,metal)
        box(Vector3(1.02,0.63,0.14),Vector3(CX,4.12,float(z)),black)
    _end_clock(-1.0,-14.7)
    _end_clock(1.0,94.0)
    flush()

func _floor() -> void:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
vec2 q=abs(fract(vec2(p.x+5.37,p.z)/vec2(5.0,6.0))-0.5);
float line=step(0.482,max(q.x,q.y));
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
            picture("name_be.svg" if side>0.0 else "name_ru.svg",Vector2(7.1,0.43),Vector3(x-side*0.15,2.12,float(z)),-side*PI/2.0,true)
        for z in [28.0,78.0]:
            picture("line.svg",Vector2(4.6,0.80),Vector3(x-side*0.15,2.25,float(z)),-side*PI/2.0)
        # Original vector interpretation of the photographed marble skyline composition.
        for i in range(4):
            picture("mosaic_"+str(i%2)+".svg",Vector2(21.0,1.76),Vector3(x-side*0.145,3.48,-0.5+float(i)*26.0),-side*PI/2.0)
        for i in range(53):
            var z: float=ZA+float(i)*2.0
            box(Vector3(0.40,0.14,0.21),Vector3(x-side*0.12,4.53,z),metal)
            box(Vector3(0.41,0.04,0.16),Vector3(x-side*0.12,4.45,z),glow)

func _columns() -> void:
    var seam := _material(Color("#777d76"),0.2,0.65)
    for side in [-1.0,1.0]:
        var x: float=CX+side*2.25
        for i in range(20):
            var z: float=-7.0+float(i)*4.9
            if z>81.0:continue
            box(Vector3(0.64,3.65,0.64),Vector3(x,FY+1.825,z),marble)
            box(Vector3(0.66,0.10,0.66),Vector3(x,FY+0.05,z),granite)
            box(Vector3(0.68,0.10,0.68),Vector3(x,4.82,z),white)
            for face in [-1.0,1.0]:
                for d in [-0.24,-0.06,0.0,0.06,0.24]:
                    box(Vector3(0.012,3.40,0.008),Vector3(x+float(d),FY+1.88,z+face*0.323),seam)
                    box(Vector3(0.008,3.40,0.012),Vector3(x+face*0.323,FY+1.88,z+float(d)),seam)
            for h in [1.24,2.48]:
                box(Vector3(0.645,0.005,0.645),Vector3(x,FY+float(h),z),seam)

func _ceiling() -> void:
    box(Vector3(4.6,0.15,84.0),Vector3(CX,5.23,39.5),white)
    var recess := _material(Color("#b8b8ad"),0.0,0.82)
    var diffuser := _material(Color("#b5b8b0"),0.0,0.5)
    for side in [-1.0,1.0]:
        box(Vector3(6.65,0.15,105),Vector3(CX+side*5.65,4.99,MID),white)
        box(Vector3(0.25,0.33,90),Vector3(CX+side*2.25,4.90,39.5),white)
        box(Vector3(0.12,0.09,90),Vector3(CX+side*2.38,4.72,39.5),glow)
    for i in range(43):
        var z: float=-1.0+float(i)*1.9
        box(Vector3(4.45,0.28,0.18),Vector3(CX,5.02,z),white)
        box(Vector3(3.85,0.035,1.66),Vector3(CX,5.14,z+0.91),recess)
        for x in [-1.37,0.0,1.37]:
            box(Vector3(0.065,0.028,1.45),Vector3(CX+float(x),5.105,z+0.91),brass)
        box(Vector3(0.60,0.028,0.55),Vector3(CX,5.08,z+0.91),diffuser)
        for side in [-1.0,1.0]:
            box(Vector3(6.55,0.15,0.14),Vector3(CX+side*5.65,4.81,z),white)
    for z in [-8.0,87.0]:
        box(Vector3(9.5,0.18,13.0),Vector3(CX,7.65,float(z)),white)

func _end_clock(direction: float,z: float) -> void:
    box(Vector3(1.32,1.32,0.08),Vector3(CX,6.9,z),brass)
    for side in [-1.0,1.0]:
        picture("kremlin_clock.svg",Vector2(1.20,1.20),Vector3(CX,6.9,z+side*0.05),0.0 if side>0.0 else PI)
