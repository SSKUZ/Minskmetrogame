shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
varying vec3 surface_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { surface_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 uv=vec2(surface_pos.z, surface_pos.y+abs(surface_pos.x)*0.5);
    float mottling=noise(uv*1.1)*0.55+noise(uv*4.1)*0.28+noise(uv*17.0)*0.17;
    float streak=noise(vec2(surface_pos.z*27.4,uv.y*0.44));
    float damp=smoothstep(0.49,0.8,streak)*(0.35+0.65*noise(vec2(surface_pos.z*1.6,uv.y*0.65)));
    damp*=smoothstep(0.23,0.65,noise(uv*2.3));
    float soot=0.16*(1.0-smoothstep(0.3,1.4,surface_pos.y));
    float ring=abs(fract(surface_pos.z+0.5)-0.5);
    float ring_line=1.0-smoothstep(0.006,0.018,ring);
    float angle=atan(surface_pos.x,surface_pos.y-3.3);
    float joint=abs(fract(angle*3.0+0.5)-0.5);
    float segment_line=1.0-smoothstep(0.003,0.013,joint);
    float pores=hash(floor(uv*160.0))*0.025;
    vec3 concrete=vec3(0.39,0.365,0.32)*(0.75+mottling*0.50);
    concrete*=1.0-damp*0.72-soot;
    concrete*=1.0-max(ring_line*0.55,segment_line*0.48);
    ALBEDO=max(concrete-vec3(pores),vec3(0.025));
    ROUGHNESS=0.92-damp*0.19;
    NORMAL_MAP=vec3(0.5+(noise(uv*45.0)-0.5)*0.10,0.5+(noise(uv.yx*49.0)-0.5)*0.10,1.0);
    NORMAL_MAP_DEPTH=0.45;
}
