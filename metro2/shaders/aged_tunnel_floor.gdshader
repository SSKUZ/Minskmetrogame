shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 concrete_tint : source_color = vec4(0.31, 0.30, 0.28, 1.0);
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise2(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),f.x),
               mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0,1.0)),f.x),f.y);
}
void fragment() {
    vec2 p = world_pos.xz;
    float grit = noise2(p*9.0)*0.28 + noise2(p*35.0)*0.10;
    float patches = noise2(p*0.65);
    float stains = smoothstep(0.57,0.83,noise2(p*1.8));
    float joint = 1.0 - smoothstep(0.012,0.034,abs(fract(p.y/5.0)-0.5));
    float crack_noise = noise2(vec2(p.x*3.0,p.y*0.9));
    float crack = 1.0-smoothstep(0.009,0.027,abs(fract(p.y*0.17 + crack_noise*0.17)-0.5));
    float worn = grit + (patches-0.5)*0.18 - stains*0.20 - max(joint*0.17,crack*0.23);
    ALBEDO = concrete_tint.rgb * clamp(0.72+worn,0.25,1.12);
    ROUGHNESS = 0.98;
}
