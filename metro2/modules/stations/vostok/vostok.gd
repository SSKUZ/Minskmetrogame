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
    for z in [19.0,43.0,67.0]:
        information_pylon(float(z))
        for side in [-1.0,1.0]:
            for j in range(18):
                box(Vector3(0.43,0.05,0.058),Vector3(CX+side*0.50,FY+0.47,float(z)-0.62+float(j)*0.073),timber)
            box(Vector3(0.40,0.10,1.35),Vector3(CX+side*0.50,FY+0.40,float(z)),metal)
            for dz in [-0.47,0.47]:
                box(Vector3(0.19,0.35,0.15),Vector3(CX+side*0.50,FY+0.20,float(z)+float(dz)),granite)
    vestibule(-1.0,-3.5,"vostok")
    vestibule(1.0,82.5,"vostok")
    finish_hall()
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
        var lower: Array[Vector2]=[]
        for j in range(25):
            var t: float=float(j)/24.0
            lower.append(Vector2(x-side*0.20*sin(t*PI),1.48+t*1.98))
        profile(lower,ZA,ZB,white)
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
            picture("line.svg",Vector2(4.6,0.78),Vector3(x-side*0.29,2.17,float(z)),-side*PI/2.0)

func _vault() -> void:
    # Smooth uninterrupted crown. Petals are local ribs, not ribs across the entire arch.
    for side in [-1.0,1.0]:curved_band(float(side),0.0,PI/2.0,ZA,ZB,3.94,3.50,0.0,white)
    var shadow := _material(Color("#92968e"),0.0,0.82)
    for i in range(35):
        var z: float=ZA+0.20+float(i)*3.0
        for side in [-1.0,1.0]:
            # Broad rounded return at the top of each petal and a recessed lower light bay.
            curved_band(float(side),0.0,0.69,z,z+0.14,3.94,3.50,0.095,white)
            for j in range(16):
                var a: float=0.67+float(j)*0.0038
                var w: float=0.14+0.24*sqrt(maxf(0.0,1.0-pow((a-0.696)/0.030,2.0)))
                curved_band(float(side),a,a+0.0038,z-(w-0.14)*0.5,z+0.14+(w-0.14)*0.5,3.94,3.50,0.095,white)
            for j in range(4):
                var zz: float=z+0.25+float(j)*0.66
                # Curved diffusers sit in reveal boxes. Their long axes follow the vault.
                curved_band(float(side),0.025,0.34,zz,zz+0.59,3.94,3.50,0.022,shadow)
                curved_band(float(side),0.045,0.325,zz+0.035,zz+0.555,3.94,3.50,0.042,glow)
                curved_band(float(side),0.025,0.34,zz,zz+0.025,3.94,3.50,0.068,white)
                curved_band(float(side),0.025,0.34,zz+0.565,zz+0.59,3.94,3.50,0.068,white)
                curved_band(float(side),0.025,0.047,zz,zz+0.59,3.94,3.50,0.068,white)
                curved_band(float(side),0.323,0.345,zz,zz+0.59,3.94,3.50,0.068,white)
            curved_band(float(side),0.355,0.365,z+0.22,z+2.90,3.94,3.50,0.05,metal)