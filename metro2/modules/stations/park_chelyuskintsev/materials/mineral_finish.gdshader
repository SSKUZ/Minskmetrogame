shader_type spatial;
// Bounded neutral stone colours: photo detail never carries the photographed shadows.
uniform vec4 base_colour : source_color = vec4(0.70,0.69,0.66,1.0);
uniform sampler2D detail_tex : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float photo_detail_amount=0.0;
uniform float grain_contrast=0.045;
uniform float veining_amount=0.0;
uniform float surface_roughness=0.58;
uniform bool joints=false;
uniform bool staggered=false;
uniform vec2 slab=vec2(0.9,0.6);
varying vec3 p;
varying vec3 world_normal;
void vertex(){
 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
float hash(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 q){
 vec2 i=floor(q),f=fract(q);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),f.x),f.y);
}
void fragment(){
 vec3 axis=abs(normalize(world_normal));
 vec2 q=p.xy;
 if(axis.x>=axis.y && axis.x>=axis.z){q=p.zy;}
 else if(axis.y>=axis.z){q=p.xz;}
 vec2 grid=q/slab;
 if(staggered){grid.x+=mod(floor(grid.y),2.0)*0.5;}
 vec2 cell=floor(grid);
 float block=hash(cell);
 float fine=noise(q*170.0);
 float crystal=noise(q*65.0+vec2(5.3,9.1));
 float photo=dot(texture(detail_tex,q*1.8+vec2(block*0.31,block*0.17)).rgb,vec3(0.3333));
 float grain=(fine-0.5)*grain_contrast+(crystal-0.5)*grain_contrast*0.55;
 grain+=(photo-0.5)*photo_detail_amount*0.12;
 float drift=noise(q*1.3+vec2(noise(q*2.1),noise(q.yx*1.7))*0.8);
 float vein=smoothstep(0.43,0.49,drift)*(1.0-smoothstep(0.49,0.57,drift));
 vec2 f=fract(grid);vec2 border=min(f,1.0-f)*slab;
 float seam=0.0;
 if(joints){seam=1.0-smoothstep(0.0005,0.0018,min(border.x,border.y));}
 float variation=0.0;
 if(joints){variation=(block-0.5)*0.055;}
 float value=clamp(1.0+grain+variation-vein*veining_amount,0.88,1.10);
 ALBEDO=base_colour.rgb*value*(1.0-seam*0.12);
 ROUGHNESS=clamp(surface_roughness+(fine-0.5)*0.07+seam*0.08,0.30,0.90);
 SPECULAR=0.42;
 // No emission or painted side darkening: the stairs receive real lights and shadows.
 AO=1.0-seam*0.06;AO_LIGHT_AFFECT=0.18;
 float height=grain*0.0009;
 vec3 sx=dFdx(VERTEX),sy=dFdy(VERTEX);
 vec3 rx=cross(sy,NORMAL),ry=cross(NORMAL,sx);float det=dot(sx,rx);
 NORMAL=normalize(max(abs(det),0.0000001)*NORMAL-sign(det)*(dFdx(height)*rx+dFdy(height)*ry));
}
