shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color=vec4(0.39,0.37,0.33,1.0);
uniform float metalness=0.32;
varying vec3 p;
void vertex(){p=VERTEX;}
float h(vec3 v){return fract(sin(dot(v,vec3(127.1,311.7,74.7)))*43758.5453);}
void fragment(){
float grain=h(floor(p*420.0))-0.5;
float patina=h(floor(p*85.0))-0.5;
ALBEDO=tint.rgb+vec3(grain*0.026+patina*0.018);
METALLIC=metalness;ROUGHNESS=0.56+grain*0.08;SPECULAR=0.48;
}
