shader_type spatial;
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 q){vec2 i=floor(q),f=fract(q);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 float warp=noise(p.xz*vec2(4.0,0.7))*3.0;
 float grain=noise(vec2(p.x*135.0+warp,p.z*1.7));
 float fibre=noise(vec2(p.x*460.0+warp,p.z*4.0));
 float pore=pow(abs(sin(p.x*287.0+warp*2.0)),22.0);
 float board=hash(vec2(floor((p.x+5.875)/0.092),0.0));
 ALBEDO=mix(vec3(0.29,0.145,0.055),vec3(0.57,0.34,0.14),0.44+grain*0.39+board*0.10)-vec3(pore*0.022);
 ROUGHNESS=0.39+fibre*0.12;SPECULAR=0.49;
}
