shader_type spatial;
render_mode cull_disabled;
uniform sampler2D glass_photo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 amber_tint : source_color = vec4(1.0,0.73,0.07,1.0);
uniform float emission_strength = 1.7;
uniform vec2 grid_count = vec2(8.0,8.0);
float cell_hash(vec2 cell) {
    return fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
}
void fragment() {
    vec2 cell=floor(UV*grid_count);
    vec2 f=fract(UV*grid_count);
    float seam_distance=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
    float grid=1.0-smoothstep(0.005,0.025,seam_distance);
    float variation=mix(0.88,1.08,cell_hash(cell));
    vec3 photo=texture(glass_photo,UV*vec2(2.0,1.8)).rgb;
    float mottling=0.91+0.09*dot(photo,vec3(0.299,0.587,0.114));
    // Bright lamp cores remain behind yellow glass instead of bleaching the entire basket.
    float core=exp(-pow((UV.x-0.50)*6.0,2.0)-pow((UV.y-0.43)*7.5,2.0));
    vec3 gold=mix(amber_tint.rgb,vec3(1.0,0.90,0.48),core*0.60);
    ALBEDO=gold*variation*mottling*mix(0.65,0.19,grid);
    EMISSION=gold*emission_strength*(0.88+core*1.85)*variation*mottling*(1.0-grid*0.92);
    ROUGHNESS=0.23+grid*0.16;
    METALLIC=0.06;
    SPECULAR=0.68;
    NORMAL_MAP=normalize(vec3((f.x-0.5)*0.10,(f.y-0.5)*0.10,1.0))*0.5+0.5;
}
