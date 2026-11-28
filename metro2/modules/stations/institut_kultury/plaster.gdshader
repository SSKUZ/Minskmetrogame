shader_type spatial;
render_mode cull_disabled;
uniform vec4 paint_color : source_color = vec4(0.87,0.87,0.84,1.0);
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float h(vec3 q){return fract(sin(dot(q,vec3(127.1,311.7,74.7)))*43758.5453);}
void fragment(){
float grain=h(floor(p*270.0))-0.5;
// Only fine plaster grain: photographed perspective, seams and shadows are not tiled.
ALBEDO=paint_color.rgb+vec3(grain*0.009);
ROUGHNESS=0.88;SPECULAR=0.22;
}
