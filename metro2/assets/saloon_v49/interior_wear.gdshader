shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float original_roughness = 0.7;
uniform float original_metallic = 0.0;
uniform int surface_kind = 0; // 0 floor, 1 upholstery, 2 wall, 3 handrail
uniform mat4 mesh_to_car;
uniform vec2 passenger_z;
uniform vec4 doorway_z;
uniform float car_seed;
varying vec3 car_position;
varying vec3 car_normal;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise21(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
    car_position=(mesh_to_car*vec4(VERTEX,1.0)).xyz;
    car_normal=normalize(mat3(mesh_to_car)*NORMAL);
}
void fragment() {
    vec3 p=car_position;
    float zone=step(passenger_z.x,p.z)*step(p.z,passenger_z.y)*step(abs(p.x),1.33)*step(0.94,p.y);
    float inward=step(0.05,-car_normal.x*p.x);
    if (surface_kind==0) { inward=step(0.7,car_normal.y); }
    if (surface_kind==1 || surface_kind==3) { inward=1.0; }
    float enabled=zone*inward;
    float seed=car_seed*17.13;
    float patch=smoothstep(0.69,0.85,noise21(p.xz*2.7+vec2(seed,0)));
    float grain=noise21(p.xz*170.0+vec2(seed,p.y*19.0));
    float near_door=1.0-smoothstep(0.35,1.05,min(min(abs(p.z-doorway_z.x),abs(p.z-doorway_z.y)),min(abs(p.z-doorway_z.z),abs(p.z-doorway_z.w))));
    float tint=1.0;
    float rough=original_roughness;
    if (surface_kind==0) {
        // Sparse, soft sole marks, with a little more wear in the vestibules.
        vec2 cell=p.xz*vec2(2.2,2.8)+vec2(seed,0);
        vec2 sole=fract(cell)-vec2(0.5);
        float selected=step(0.84,hash21(floor(cell)));
        float footprint=(1.0-smoothstep(0.35,1.0,length(sole/vec2(0.21,0.39))))*selected;
        tint=1.0-0.055*patch-0.065*footprint*(0.4+0.6*near_door)+(grain-0.5)*0.012;
        rough=clamp(0.88+grain*0.06-patch*0.025,0.0,1.0);
    } else if (surface_kind==1) {
        float seat=hash21(vec2(floor(p.z/0.48),sign(p.x)+seed));
        tint=0.988+0.024*seat+0.028*patch;
        rough=clamp(0.79+grain*0.045+patch*0.035,0.0,1.0);
    } else if (surface_kind==2) {
        float scratches=step(0.986,noise21(vec2(p.z*330.0,p.y*35.0)+seed))*patch;
        tint=1.0-0.018*patch-0.018*patch*near_door-0.016*scratches;
        rough=clamp(max(original_roughness,0.66)+grain*0.025+patch*0.035,0.0,1.0);
    } else {
        tint=1.0-0.012*patch;
        rough=clamp(0.30+grain*0.035+patch*0.045,0.0,1.0);
    }
    ALBEDO=base_color.rgb*mix(1.0,tint,enabled);
    METALLIC=original_metallic;
    ROUGHNESS=mix(original_roughness,rough,enabled);
}
