shader_type spatial;
uniform sampler2D stone_tex : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 tint : source_color;
uniform vec2 slab=vec2(1.2,0.6);
uniform float roughness=0.35;
uniform bool joints=true;
uniform bool staggered=false;
uniform float bump_depth=0.0005;
varying vec3 p;varying vec3 n;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;n=abs(MODEL_NORMAL_MATRIX*NORMAL);}
float h(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 q = n.x > 0.5 ? p.zy : (n.y > 0.5 ? p.xz : p.xy);
 vec2 grid=q/slab;grid.x+=staggered?mod(floor(grid.y),2.0)*0.5:0.0;
 vec2 cell=floor(grid);float v=h(cell);
 vec2 uv=fract(grid)+vec2(v*0.23,v*0.17);
 vec3 raw=texture(stone_tex,uv).rgb;
 vec3 detail=texture(stone_tex,q/slab*3.7+vec2(0.21,0.17)).rgb;
 vec3 c=raw*0.92+detail*0.08;
 vec2 f=fract(grid);vec2 dist=min(f,1.0-f)*slab;
 float seam=(1.0-smoothstep(0.0006,0.0020,min(dist.x,dist.y)))*(joints?1.0:0.0);
 float edge=1.0-smoothstep(0.001,0.006,min(dist.x,dist.y));
 float grain=dot(detail,vec3(0.333));
 float base=smoothstep(0.12,0.65,p.y);
 ALBEDO=c*tint.rgb*(0.89+v*0.19)*(0.91+base*0.09)*(1.0-seam*0.38);
 ROUGHNESS=clamp(roughness+(grain-0.5)*0.18+seam*0.22,0.05,0.98);SPECULAR=0.52;
 AO=1.0-edge*(joints?0.17:0.0);AO_LIGHT_AFFECT=0.25;
 float height=grain*bump_depth-seam*0.0007;
 vec3 sx=dFdx(VERTEX),sy=dFdy(VERTEX);vec3 rx=cross(sy,NORMAL),ry=cross(NORMAL,sx);float det=dot(sx,rx);
 NORMAL=normalize(max(abs(det),0.0000001)*NORMAL-sign(det)*(dFdx(height)*rx+dFdy(height)*ry));
}
