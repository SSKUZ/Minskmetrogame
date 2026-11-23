shader_type spatial;
render_mode cull_disabled;
uniform sampler2D paint : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 p;
varying vec3 n;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;n=abs(MODEL_NORMAL_MATRIX*NORMAL);}
float h(vec3 q){return fract(sin(dot(q,vec3(127.1,311.7,74.7)))*43758.5453);}
void fragment(){
vec3 weights=pow(n,vec3(6.0));weights/=max(dot(weights,vec3(1.0)),0.001);
vec3 paint_color=texture(paint,p.zy/1.4).rgb*weights.x+texture(paint,p.xz/1.4).rgb*weights.y+texture(paint,p.xy/1.4).rgb*weights.z;
float sand=h(floor(p*210.0))-0.5;
float fine=h(floor(p*570.0))-0.5;
float pores=step(0.976,h(floor(p*135.0)));
ALBEDO=clamp(paint_color+vec3(sand*0.018+fine*0.009-pores*0.025),vec3(0.0),vec3(1.0));
ROUGHNESS=clamp(0.88+sand*0.08,0.0,1.0);SPECULAR=0.23;
NORMAL_MAP=vec3(0.5+sand*0.045,0.5+fine*0.035,1.0);NORMAL_MAP_DEPTH=0.18;
}
