shader_type spatial;
render_mode cull_disabled;
uniform vec4 bronze_face : source_color = vec4(0.79,0.66,0.36,1.0);
uniform vec4 bronze_side : source_color = vec4(0.33,0.24,0.10,1.0);
varying vec3 world_point;
varying vec3 letter_normal;
void vertex() {
    world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    letter_normal=NORMAL;
}
float grain_hash(vec3 p) {
    return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);
}
void fragment() {
    // Face and extruded sidewalls use different bronze finishes. No painted-on photo background.
    float front=smoothstep(0.55,0.95,letter_normal.z);
    float fine=grain_hash(floor(world_point*1250.0));
    float patina=grain_hash(floor(world_point*38.0));
    float brushing=sin(world_point.y*3100.0+sin(world_point.z*90.0)*1.4);
    vec3 bronze=mix(bronze_side.rgb,bronze_face.rgb,front);
    ALBEDO=bronze*(0.95+fine*0.065+patina*0.025+brushing*0.009);
    METALLIC=mix(0.64,0.48,front);
    ROUGHNESS=0.55+fine*0.07+(1.0-front)*0.10;
    SPECULAR=0.54;
}
