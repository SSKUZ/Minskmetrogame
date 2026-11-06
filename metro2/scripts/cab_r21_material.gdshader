shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D color_map : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_color_map = false;
uniform sampler2D roughness_map : filter_linear_mipmap, repeat_enable;
uniform bool has_roughness_map = false;
uniform vec4 roughness_channel = vec4(0,1,0,0);
uniform float original_roughness = 1.0;
uniform sampler2D metallic_map : filter_linear_mipmap, repeat_enable;
uniform bool has_metallic_map = false;
uniform vec4 metallic_channel = vec4(0,0,1,0);
uniform float original_metallic = 0.0;
uniform float original_specular = 0.5;
uniform float original_clearcoat = 0.0;
uniform float original_clearcoat_roughness = 0.0;
uniform sampler2D height_map : filter_linear_mipmap, repeat_enable;
uniform bool has_height_map = false;
uniform float bump_scale = 0.0;
uniform samplerCube cab_environment : source_color, filter_linear_mipmap;
uniform float env_intensity = 0.52;
uniform float cab_light_on = 1.0;
void fragment(){
    ALBEDO=base_color.rgb;
    if(has_color_map) ALBEDO*=texture(color_map,UV).rgb;
    ROUGHNESS=original_roughness;
    if(has_roughness_map) ROUGHNESS*=dot(texture(roughness_map,UV),roughness_channel);
    METALLIC=original_metallic;
    if(has_metallic_map) METALLIC*=dot(texture(metallic_map,UV),metallic_channel);
    SPECULAR=original_specular;
    CLEARCOAT=original_clearcoat;
    CLEARCOAT_ROUGHNESS=original_clearcoat_roughness;
    if(has_height_map){
        vec2 dx=dFdx(UV),dy=dFdy(UV);
        float h=texture(height_map,UV).r;
        vec2 dH=bump_scale*vec2(texture(height_map,UV+dx).r-h,texture(height_map,UV+dy).r-h);
        vec3 sx=normalize(dFdx(VERTEX)),sy=normalize(dFdy(VERTEX));
        vec3 r1=cross(sy,NORMAL),r2=cross(NORMAL,sx);
        float det=dot(sx,r1);
        vec3 perturbed=abs(det)*NORMAL-sign(det)*(dH.x*r1+dH.y*r2);
        if(abs(det)>0.000001 && dot(perturbed,perturbed)>0.000000000001){
            NORMAL=normalize(perturbed);
        }
    }
    vec3 reflection=mat3(INV_VIEW_MATRIX)*reflect(-VIEW,NORMAL);
    vec3 reflected=textureLod(cab_environment,reflection,clamp(ROUGHNESS,0.0,1.0)*7.0).rgb;
    // Source station AmbientLight (.95 + .15) / PI, restricted to cab materials.
    // Preserve the authored six-face window/ceiling reflection map locally.
    vec3 indirect=ALBEDO*(1.0-METALLIC)*vec3(0.35,0.36,0.38);
    vec3 fresnel=mix(vec3(0.04),ALBEDO,METALLIC);
    EMISSION=cab_light_on*(indirect+reflected*fresnel*env_intensity);
}
