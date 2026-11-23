shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float origin_z;
uniform float outward_direction;
uniform float fade_start_m = 8.0;
uniform float fade_finish_m = 23.0;
uniform float branch_start_x = 4.65;
uniform float branch_finish_x = 12.60;
uniform float station_center_x = -5.37;
varying vec3 world_point;
varying vec3 world_normal;
void vertex() {
    world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=abs(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    float distance_out=(world_point.z-origin_z)*outward_direction;
    float illumination=0.76*(1.0-smoothstep(fade_start_m,fade_finish_m,distance_out));
    vec2 coord=world_normal.y>0.5?world_point.xz:world_normal.x>0.5?world_point.zy:world_point.xy;
    float side_turn=1.0-smoothstep(branch_start_x,branch_finish_x,world_point.x-station_center_x);
    ALBEDO=texture(surface_texture,coord).rgb*illumination*side_turn;
}
