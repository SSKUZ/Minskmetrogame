shader_type spatial;
render_mode cull_disabled, diffuse_burley;
vec2 random2(vec2 p) { return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453); }
void fragment() {
    vec2 p=UV*17.0, cell=floor(p), f=fract(p);
    float first=8.0, second=8.0, stone_id=0.0;
    vec2 delta=vec2(0.0);
    for(int y=-1;y<=1;y++) {
        for(int x=-1;x<=1;x++) {
            vec2 neighbour=vec2(float(x),float(y));
            vec2 seed=random2(cell+neighbour);
            vec2 d=neighbour+0.12+seed*0.76-f;
            float distance=dot(d,d);
            if(distance<first) { second=first; first=distance; delta=d; stone_id=seed.x; }
            else { second=min(second,distance); }
        }
    }
    float rim=smoothstep(0.015,0.13,sqrt(second)-sqrt(first));
    float facet=0.75+dot(normalize(delta+vec2(0.001)),vec2(0.14,0.12));
    ALBEDO=vec3(0.235,0.224,0.204)*(0.65+stone_id*0.8)*(0.32+rim*0.68)*facet;
    ROUGHNESS=0.98;
    NORMAL_MAP=vec3(0.5+delta*0.55,1.0);
    NORMAL_MAP_DEPTH=0.65;
}
