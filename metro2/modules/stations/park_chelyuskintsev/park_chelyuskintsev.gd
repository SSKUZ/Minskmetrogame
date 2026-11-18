extends "res://modules/stations/park_chelyuskintsev/station_builder.gd"
## Photo-derived segmented vault and shared sculpted cast-glass chandelier meshes.
var _chandelier_meshes: Array[Mesh]=[]
func _ready() -> void:
    super._ready()
    begin_station()
    _floor()
    platform_edges()
    _walls()
    _build_chandelier()
    _vault()
    portals(7.95)
    stairs(-1.0,-3.5)
    stairs(1.0,82.5)
    for z in [24.0,57.0]:information_pylon(float(z))
    vestibule(-1.0,-3.5,"park")
    vestibule(1.0,82.5,"park")
    finish_hall()
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
    var channel := _material(Color("#574f37"),0.6,0.4)
    # Each six metre section has an independent sculpted transition to the light niche.
    for i in range(18):
        var z: float=ZA+float(i)*6.0
        var end: float=minf(ZB,z+6.0)
        for side in [-1.0,1.0]:
            curved_band(float(side),0.0,1.363,z,end,2.91,4.72,0.0,white)
            curved_band(float(side),0.0,1.363,z,z+0.095,2.91,4.72,0.025,channel)
            for j in range(4):
                curved_band(float(side),0.0,1.363,z+0.011+float(j)*0.021,z+0.020+float(j)*0.021,2.91,4.72,0.047,brass)
            # Coved edge has a thick white return instead of the former open slit.
            var cove: Array[Vector2]=[]
            for j in range(17):
                var a: float=float(j)*PI/32.0
                cove.append(Vector2(CX+side*(1.87-0.28*sin(a)),7.50+0.28*(1.0-cos(a))))
            profile(cove,z,end,white)
            box(Vector3(0.045,0.040,maxf(0.05,end-z)),Vector3(CX+side*1.60,7.76,(z+end)*0.5),glow)
            # Decorative cast-glass inserts in the transverse recess, following its curve.
            for j in range(32):
                var a: float=0.65+float(j)*0.020
                var pos := arc_point(float(side),a,2.91,4.72,0.065)
                box(Vector3(0.06,0.065,0.10),Vector3(pos.x,pos.y,z+0.05),brass)
        box(Vector3(3.20,0.10,maxf(0.05,end-z)),Vector3(CX,7.89,(z+end)*0.5),white)
        # Rounded transverse cove at the end of each coffer.
        for j in range(16):
            var a: float=float(j)*PI/32.0
            var b: float=float(j+1)*PI/32.0
            var za: float=z+0.24*sin(a)
            var zb: float=z+0.24*sin(b)
            var ya: float=7.53+0.26*(1.0-cos(a))
            var yb: float=7.53+0.26*(1.0-cos(b))
            quad(Vector3(CX-1.62,ya,za),Vector3(CX+1.62,ya,za),Vector3(CX+1.62,yb,zb),Vector3(CX-1.62,yb,zb),white,Vector3.DOWN)
        if z+3.0<ZB:_chandelier(z+3.0)

func _build_chandelier() -> void:
    var shader := Shader.new()
    shader.code="""shader_type spatial;render_mode cull_disabled;
varying vec3 local_p;
void vertex(){local_p=VERTEX;}
void fragment(){
vec2 q=UV*2.0-1.0;float emboss=sin(q.x*10.0+sin(q.y*6.0)*2.4)*sin(q.y*10.0+cos(q.x*7.0)*1.8);
float rim=smoothstep(0.65,0.98,max(abs(q.x),abs(q.y)));
vec3 amber=COLOR.rgb*(0.78+emboss*0.16)+vec3(rim*0.10);
ALBEDO=amber;METALLIC=0.15;ROUGHNESS=0.20+0.08*abs(emboss);SPECULAR=0.8;
EMISSION=COLOR.rgb*(0.25+0.16*(1.0-rim));
NORMAL_MAP=normalize(vec3(cos(q.x*10.0+sin(q.y*6.0))*0.23,sin(q.y*10.0+cos(q.x*7.0))*0.23,1.0))*0.5+0.5;
}
"""
    var glass := ShaderMaterial.new();glass.shader=shader
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
                    st.add_vertex(v[face[index]])
    st.generate_tangents()
    var mesh := st.commit();mesh.surface_set_material(0,glass);_chandelier_meshes.append(mesh)

func _chandelier(z: float) -> void:
    var center := Vector3(CX,6.96,z)
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