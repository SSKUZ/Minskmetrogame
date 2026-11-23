shader_type spatial;
render_mode cull_disabled;
uniform sampler2D glass_tex : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform float emission_level=0.48;
uniform vec2 sample_scale=vec2(1.0);
uniform vec2 sample_offset=vec2(0.0);
uniform vec4 glass_tint : source_color = vec4(1.0);
void fragment(){
 vec3 measured=texture(glass_tex,UV2*sample_scale+sample_offset).rgb*glass_tint.rgb;
 vec2 q=UV*2.0-1.0;
 float relief=sin(q.x*14.0+sin(q.y*7.0))*sin(q.y*19.0+cos(q.x*5.0));
 float rim=smoothstep(0.73,0.99,max(abs(q.x),abs(q.y)));
 ALBEDO=measured*(0.97+relief*0.045);METALLIC=0.06;
 ROUGHNESS=0.19+abs(relief)*0.065+rim*0.07;SPECULAR=0.82;
 EMISSION=measured*emission_level*(1.0-rim*0.36);
 AO=1.0-rim*0.22;AO_LIGHT_AFFECT=0.18;
 float height=relief*0.00055;
 vec3 sx=dFdx(VERTEX),sy=dFdy(VERTEX);vec3 rx=cross(sy,NORMAL),ry=cross(NORMAL,sx);float det=dot(sx,rx);
 NORMAL=normalize(max(abs(det),0.0000001)*NORMAL-sign(det)*(dFdx(height)*rx+dFdy(height)*ry));
}
