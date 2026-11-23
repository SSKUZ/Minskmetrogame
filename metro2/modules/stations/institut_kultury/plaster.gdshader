shader_type spatial;
render_mode cull_disabled;
uniform sampler2D paint : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 p;
varying vec3 n;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;n=abs(MODEL_NORMAL_MATRIX*NORMAL);}
float h(vec3 q){return fract(sin(dot(q,vec3(127.1,311.7,74.7)))*43758.5453);}
void fragment(){
vec3 w=pow(n,vec3(6.0));w/=max(dot(w,vec3(1.0)),0.001);
vec3 c=texture(paint,p.zy/1.4).rgb*w.x+texture(paint,p.xz/1.4).rgb*w.y+texture(paint,p.xy/1.4).rgb*w.z;
float dz=abs(mod(p.z+3.6+3.6,7.2)-3.6);
float wash=exp(-dz*dz/4.0);
float grain=h(floor(p*270.0))-0.5;float sand=h(floor(p*120.0))-0.5;
ALBEDO=c*(0.91+wash*0.09)+vec3(grain*0.015+ sand*0.008);
ROUGHNESS=0.87+grain*0.06;SPECULAR=0.23;
NORMAL_MAP=vec3(0.5+grain*0.035,0.5+sand*0.035,1.0);NORMAL_MAP_DEPTH=0.16;
EMISSION=c*wash*0.022;
}
