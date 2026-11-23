shader_type spatial;
render_mode unshaded,cull_back,fog_disabled;
uniform sampler2D poster_a : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D poster_b : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D poster_c : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform float slide_seconds=8.0;
uniform float crossfade_seconds=0.85;
uniform float phase_offset=0.0;
uniform float screen_aspect=1.777778;
uniform float poster_aspect=1.777778;
vec3 poster(float number,vec2 uv){
if(number<0.5){return texture(poster_a,uv).rgb;}
if(number<1.5){return texture(poster_b,uv).rgb;}
return texture(poster_c,uv).rgb;
}
void fragment(){
vec2 uv=UV;
if(screen_aspect<poster_aspect){uv.y=(uv.y-0.5)*poster_aspect/screen_aspect+0.5;}
else{uv.x=(uv.x-0.5)*screen_aspect/poster_aspect+0.5;}
float seconds=max(slide_seconds,1.0);
float phase=mod(TIME+phase_offset,seconds*3.0);
float current=floor(phase/seconds);
float fade=smoothstep(seconds-min(crossfade_seconds,seconds*0.5),seconds,mod(phase,seconds));
vec3 c=mix(poster(current,uv),poster(mod(current+1.0,3.0),uv),fade);
if(uv.x<0.0||uv.x>1.0||uv.y<0.0||uv.y>1.0){c=vec3(0.006,0.009,0.014);}
ALBEDO=c;EMISSION=c*0.12;ROUGHNESS=0.20;SPECULAR=0.45;
}
