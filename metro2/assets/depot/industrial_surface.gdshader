shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 tint : source_color = vec4(0.5,0.5,0.5,1.0);
uniform float roughness_value = 0.85;
uniform float metal_value = 0.0;
uniform float pattern = 0.0;
uniform float emission_value = 0.0;
varying vec3 p;
varying vec3 n;
float hash(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 v){vec2 i=floor(v),f=fract(v);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;n=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);}
void fragment(){
 vec2 uv=abs(n.y)>0.55?p.xz:(abs(n.x)>0.55?p.zy:p.xy);
 float grain=hash(floor(uv*70.0));
 float age=noise(uv*0.35);
 float tone=0.88+age*0.18+(grain-0.5)*0.055;
 if(pattern>0.5&&pattern<1.5){
  vec2 brick=uv*vec2(3.4,7.4);brick.x+=mod(floor(brick.y),2.0)*0.5;
  vec2 f=fract(brick);float seam=1.0-smoothstep(0.025,0.065,min(f.x,f.y));
  tone=mix(tone,0.62,seam);tone+=(hash(floor(brick))-0.5)*0.08;
 }
 if(pattern>1.5&&pattern<2.5){tone*=0.90+0.10*sin(uv.x*36.0);}
 if(pattern>2.5&&pattern<3.5){tone*=0.85+noise(uv*4.0)*0.3;}
 if(pattern>3.5&&pattern<4.5){
  vec2 f=abs(fract(uv/vec2(5.0,4.0)+0.5)-0.5);
  float seam=1.0-smoothstep(0.002,0.008,min(f.x,f.y));tone*=1.0-seam*0.17;
 }
 ALBEDO=tint.rgb*tone;
 ROUGHNESS=roughness_value;
 METALLIC=metal_value;
 EMISSION=tint.rgb*emission_value;
}
