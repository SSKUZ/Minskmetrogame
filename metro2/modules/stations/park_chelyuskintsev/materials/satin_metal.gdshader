shader_type spatial;
uniform vec4 tint : source_color = vec4(0.43,0.39,0.29,1.0);
uniform float base_roughness=0.36;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float brushed=sin(p.y*2100.0+p.z*1300.0+sin(p.x*23.0))*0.5+0.5;
 float patina=sin(p.z*7.1+p.x*5.3)*sin(p.y*12.3)*0.025;
 ALBEDO=tint.rgb*(0.97+brushed*0.035+patina);
 METALLIC=0.82;ROUGHNESS=clamp(base_roughness+brushed*0.055,0.1,0.8);SPECULAR=0.56;
}
