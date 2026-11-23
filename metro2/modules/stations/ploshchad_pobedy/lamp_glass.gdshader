shader_type spatial;
render_mode cull_disabled;
// A single UV domain across the complete diffuser, continuing through its crown.
uniform vec4 white_center : source_color = vec4(1.0,0.96,0.85,1.0);
uniform vec4 amber_edge : source_color = vec4(1.0,0.65,0.22,1.0);
uniform float emission_strength = 1.25;
uniform float upper_light_fraction = 0.13;
uniform float prism_lanes = 6.0;
void fragment() {
    float y=clamp(UV.y,0.0,1.0);
    float edge=pow(clamp(abs(UV.x-0.5)*2.0,0.0,1.0),1.15);
    float upper=smoothstep(0.50,1.0,y);
    float amber=clamp(edge*0.94+upper*0.40,0.0,1.0);
    vec3 glass=mix(white_center.rgb,amber_edge.rgb,amber);
    float attenuation=mix(1.0,upper_light_fraction,upper);
    float centre=pow(1.0-edge,0.55);
    // Pressed-glass detail has shallow seams, without dark gaps between modules.
    float prism=fract(UV.x*prism_lanes);
    float rib=1.0-smoothstep(0.004,0.020,min(prism,1.0-prism));
    float cross_phase=fract(y*3.0);
    float cross_rib=1.0-smoothstep(0.002,0.009,min(cross_phase,1.0-cross_phase));
    float detail=(1.0-0.12*rib)*(1.0-0.08*cross_rib);
    ALBEDO=glass*mix(0.52,0.30,upper);
    METALLIC=0.08;
    ROUGHNESS=mix(0.22,0.31,upper);
    SPECULAR=0.65;
    NORMAL_MAP=normalize(vec3((prism-0.5)*0.18,0.0,1.0))*0.5+0.5;
    EMISSION=glass*emission_strength*(0.42+1.12*centre)*attenuation*detail;
}
