extends "res://modules/stations/park_chelyuskintsev/station_builder.gd"
## Column-free vault with central recessed amber cast-glass chandeliers.
func _ready() -> void:
    super._ready()
    begin_station()
    _floor()
    platform_edges()
    _walls()
    _vault()
    portals(7.95)
    stairs(-1.0,-3.5)
    stairs(1.0,82.5)
    for z in [24.0,57.0]:information_pylon(float(z))
    for z in [12.0,43.0,74.0]:
        for side in [-1.0,1.0]:
            board("direction_north.svg" if side>0.0 else "direction_south.svg",Vector3(CX+side*2.55,4.04,float(z)),Vector2(3.45,0.62))
    flush()

func _floor() -> void:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
float x=abs(p.x+5.37);float z=abs(mod(p.z,16.0)-8.0);
float width=z<1.4?3.15:z<2.6?2.53:z<3.8?1.92:1.30;
float red=1.0-step(width,x);float outline=step(width-0.28,x)*(1.0-step(width+0.12,x));
float inset=(1.0-step(0.68,x))*(1.0-step(1.22,z));
vec3 base=mix(vec3(0.52,0.52,0.46),vec3(0.44,0.23,0.19),red);
base=mix(base,vec3(0.17,0.21,0.19),outline);base=mix(base,vec3(0.58,0.56,0.49),inset);
float grain=fract(sin(dot(floor(p.xz*180.0),vec2(12.9898,78.233)))*43758.5453);
vec2 tile=fract(p.xz/0.62);float joint=1.0-smoothstep(0.001,0.003,min(min(tile.x,1.0-tile.x),min(tile.y,1.0-tile.y)));
ALBEDO=base*(0.88+grain*0.22)-vec3(joint*0.035);ROUGHNESS=0.40;SPECULAR=0.55;
}
"""
    var m := ShaderMaterial.new();m.shader=shader
    (get_node("IslandPlatform") as MeshInstance3D).material_override=m

func _walls() -> void:
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.90
        box(Vector3(0.30,1.65,105),Vector3(x,0.83,MID),granite)
        box(Vector3(0.23,1.28,105),Vector3(x,2.26,MID),white)
        box(Vector3(0.36,0.10,105),Vector3(x-side*0.015,1.68,MID),granite)
        rod(Vector3(x-side*0.14,2.93,ZA),Vector3(x-side*0.14,2.93,ZB),0.012,metal)
        for z in [14.0,63.0]:
            picture("name_be.svg" if side>0.0 else "name_ru.svg",Vector2(7.0,0.47),Vector3(x-side*0.14,2.19,float(z)),-side*PI/2.0,true)
        for z in [35.0,79.0]:
            picture("line.svg",Vector2(4.7,0.84),Vector3(x-side*0.15,2.26,float(z)),-side*PI/2.0)

func _vault() -> void:
    for side in [-1.0,1.0]:
        var shell: Array[Vector2]=[]
        for j in range(41):
            var a: float=1.363*float(j)/40.0
            shell.append(Vector2(CX+side*8.99*cos(a),2.91+4.72*sin(a)))
        profile(shell,ZA,ZB,white)
    var recess := _material(Color("#6f6d60"),0.45,0.45)
    box(Vector3(3.7,0.12,105),Vector3(CX,7.85,MID),white)
    for side in [-1.0,1.0]:
        box(Vector3(0.055,0.06,105),Vector3(CX+side*1.85,7.56,MID),glow)
    for i in range(18):
        var z: float=ZA+float(i)*6.0
        for side in [-1.0,1.0]:
            var line: Array[Vector2]=[]
            for j in range(25):
                var a: float=float(j)/24.0*1.36
                line.append(Vector2(CX+side*(8.96*cos(a)-0.025),2.91+4.72*sin(a)-0.055))
            profile(line,z,z+0.085,recess)
            profile(line,z+0.027,z+0.047,brass)
            for j in range(14):
                var a: float=0.80+float(j)*0.032
                box(Vector3(0.085,0.045,0.24),Vector3(CX+side*8.91*cos(a),2.91+4.72*sin(a)-0.075,z+0.04),brass)
        _chandelier(z+3.0)

func _chandelier(z: float) -> void:
    cylinder(0.18,0.26,Vector3(CX,7.44,z),brass)
    # Terraced shallow bowl, five rings of separate textured amber/clear glass pieces.
    var clear := _material(Color("#b6ac86"),0.22,0.28)
    var amber := _material(Color("#b57c22"),0.26,0.3)
    var lit := _material(Color("#d8a33b"),0.1,0.35)
    lit.emission_enabled=true;lit.emission=Color(0.65,0.32,0.055);lit.emission_energy_multiplier=0.65
    for ring in range(5):
        var radius: float=0.25+float(ring)*0.18
        var count: int=16+ring*8
        var y: float=6.89+float(ring)*0.105
        for j in range(count):
            var a: float=float(j)*TAU/float(count)
            var pose := Basis(Vector3.UP,-a)
            var p := Vector3(CX+sin(a)*radius,y,z+cos(a)*radius)
            box(Vector3(0.11,0.105,0.17),p,clear if ring==4 else amber if j%3==0 else lit,pose)
            box(Vector3(0.014,0.115,0.18),p+Vector3(0,0.018,0),brass,pose)
    cylinder(0.12,0.06,Vector3(CX,6.85,z),lit)
