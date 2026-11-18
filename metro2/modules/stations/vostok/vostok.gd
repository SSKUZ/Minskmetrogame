extends "res://modules/stations/vostok/station_builder.gd"
## Internet-reference first pass. No columns: the petal vault spans the whole hall.
func _ready() -> void:
    super._ready()
    begin_station()
    _floor()
    platform_edges()
    _walls()
    _vault()
    portals(7.55)
    stairs(-1.0,-3.5)
    stairs(1.0,82.5)
    for z in [21.0,57.0]:information_pylon(float(z))
    for z in [10.0,36.0,70.0]:
        for side in [-1.0,1.0]:
            board("direction_north.svg" if side>0.0 else "direction_south.svg",Vector3(CX+side*2.5,4.28,float(z)),Vector2(3.45,0.61))
    flush()

func _floor() -> void:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 q){return fract(sin(dot(q,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){
float x=abs(p.x+5.37);float z=abs(mod(p.z+1.0,14.0)-7.0);
float stepwidth=z<0.62?2.25:z<1.24?1.60:z<1.86?0.98:0.20;
float pattern=1.0-step(stepwidth,x);
float pale=(1.0-step(0.24,x))*(1.0-step(0.33,z));
vec3 base=mix(vec3(0.49,0.49,0.42),vec3(0.41,0.20,0.12),pattern);
base=mix(base,vec3(0.84,0.82,0.68),pale);
vec2 tile=fract(p.xz/0.62);float joint=1.0-smoothstep(0.001,0.003,min(min(tile.x,1.0-tile.x),min(tile.y,1.0-tile.y)));
ALBEDO=base*(0.83+hash(floor(p.xz*190.0))*0.26)-vec3(joint*0.04);ROUGHNESS=0.44;SPECULAR=0.55;
}
"""
    var m := ShaderMaterial.new();m.shader=shader
    (get_node("IslandPlatform") as MeshInstance3D).material_override=m

func _walls() -> void:
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.90
        box(Vector3(0.30,1.48,105),Vector3(x,0.75,MID),redstone)
        box(Vector3(0.18,2.0,105),Vector3(x,2.48,MID),white)
        box(Vector3(0.44,0.55,105),Vector3(x-side*0.10,3.68,MID),marble)
        box(Vector3(0.47,0.025,105),Vector3(x-side*0.11,3.57,MID),brass)
        box(Vector3(0.56,0.035,105),Vector3(x-side*0.14,3.98,MID),glow)
        rod(Vector3(x-side*0.14,3.34,ZA),Vector3(x-side*0.14,3.34,ZB),0.012,metal)
        for i in range(35):
            box(Vector3(0.195,1.88,0.008),Vector3(x-side*0.01,2.45,ZA+float(i)*3.0),marble)
        for z in [15.0,65.0]:
            box(Vector3(0.52,0.76,4.5),Vector3(x-side*0.14,3.70,float(z)),marble)
            picture("name_be.svg" if side>0.0 else "name_ru.svg",Vector2(3.8,0.48),Vector3(x-side*0.41,3.69,float(z)),-side*PI/2.0,true)
        for z in [34.0,79.0]:
            picture("line.svg",Vector2(4.6,0.78),Vector3(x-side*0.13,2.17,float(z)),-side*PI/2.0)

func _vault() -> void:
    var shell: Array[Vector2]=[]
    for j in range(49):
        var a: float=PI*float(j)/48.0
        shell.append(Vector2(CX+8.98*cos(a),3.94+3.50*sin(a)))
    profile(shell,ZA,ZB,white)
    var reveal := _material(Color("#a4a69e"),0.0,0.75)
    # Four broad light portals occupy each petal bay; vertical ribs turn into the vault.
    for i in range(35):
        var z: float=ZA+0.25+float(i)*3.0
        for side in [-1.0,1.0]:
            var rib: Array[Vector2]=[]
            for j in range(17):
                var a: float=float(j)/16.0*0.82
                rib.append(Vector2(CX+side*(8.96*cos(a)-0.075),3.94+3.50*sin(a)-0.055))
            profile(rib,z,z+0.13,white)
            for j in range(4):
                var zz: float=z+0.27+float(j)*0.64
                box(Vector3(0.08,1.20,0.58),Vector3(CX+side*8.70,4.56,zz),reveal)
                box(Vector3(0.035,1.10,0.51),Vector3(CX+side*8.64,4.56,zz),glow)
                box(Vector3(0.12,0.035,0.60),Vector3(CX+side*8.67,5.17,zz),metal)
