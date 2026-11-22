shader_type spatial;
render_mode cull_disabled;
uniform sampler2D plaster_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(0.94,0.94,0.92,1.0);
uniform float cove_bounce = 0.16;
varying vec3 p;
varying vec3 axis_normal;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;axis_normal=abs(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 q=axis_normal.z>0.6?p.xy:(axis_normal.x>0.6?p.zy:p.xz);
 float broad=texture(plaster_tex,q*0.32).r;
 float grain=texture(plaster_tex,q*2.4+vec2(0.13,0.47)).r;
 vec3 colour=tint.rgb*(0.955+broad*0.055+(grain-0.5)*0.018);
 float cove=(1.0-smoothstep(2.20,2.80,abs(p.x+5.37)))*smoothstep(7.2,7.8,p.y);
 float lip=1.0-smoothstep(0.0,0.045,abs(abs(p.x+5.37)-2.28));
 ALBEDO=colour;ROUGHNESS=0.87+grain*0.08;SPECULAR=0.20;
 // Keep most of the ceiling light-dependent; the narrow cove models indirect bounce.
 EMISSION=colour*(0.018+cove*cove_bounce);
 AO=1.0-lip*0.13;AO_LIGHT_AFFECT=0.22;
 float height=grain*0.00065;
 vec3 sx=dFdx(VERTEX),sy=dFdy(VERTEX);
 vec3 rx=cross(sy,NORMAL),ry=cross(NORMAL,sx);float det=dot(sx,rx);
 NORMAL=normalize(max(abs(det),0.0000001)*NORMAL-sign(det)*(dFdx(height)*rx+dFdy(height)*ry));
}
