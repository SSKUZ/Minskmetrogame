shader_type spatial;
render_mode unshaded, cull_disabled;
// Static diffuse bounce from the four joined corner fixtures on every capital.
// World-space metres keep the pool anchored to the actual column lattice.
uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float station_center_x;
uniform float column_x;
uniform float column_pitch;
uniform float first_column_z;
uniform float last_column_z;
uniform float pool_radius;
varying vec3 world_position;
void vertex() {
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
float corner_pool(vec2 delta) {
    vec2 q=(abs(delta)-vec2(1.13))/pool_radius;
    // A compact bright patch with a smooth broad penumbra.
    return exp(-dot(q,q)*3.1);
}
void fragment() {
    float x=world_position.x-station_center_x;
    float row=clamp(round((world_position.z-first_column_z)/column_pitch),0.0,round((last_column_z-first_column_z)/column_pitch));
    float z_center=first_column_z+row*column_pitch;
    float pool=0.0;
    for(int j=-1;j<=1;j++) {
        float z=z_center+float(j)*column_pitch;
        float valid=step(first_column_z-0.01,z)*step(z,last_column_z+0.01);
        pool+=valid*(corner_pool(vec2(x-column_x,world_position.z-z))+corner_pool(vec2(x+column_x,world_position.z-z)));
    }
    pool=clamp(pool,0.0,1.0);
    // Recessed fields stay darker between fixtures; the narrow beam footprint is shaded.
    float beam_x=1.0-smoothstep(0.19,0.40,abs(abs(x)-column_x));
    float beam_z=1.0-smoothstep(0.19,0.40,abs(world_position.z-z_center));
    float occlusion=1.0-0.28*max(beam_x,beam_z);
    float illumination=(0.34+0.69*pool)*occlusion;
    vec3 paint_color=texture(paint,world_position.xz).rgb;
    vec3 tint=mix(vec3(0.87,0.89,0.92),vec3(1.0,0.97,0.89),pool);
    // Texture sampling is linear; tonality remains independent of global viewer exposure.
    ALBEDO=paint_color*tint*illumination;
}
