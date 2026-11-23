shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float station_center_x;
uniform float column_x;
uniform float column_pitch;
uniform float transfer_mid_z;
varying vec3 world_point;
void vertex() {
    world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
float halo(vec2 d) {
    float r2=dot(d,d);
    float angle=atan(d.y+0.00001,d.x+0.00001);
    float prong=pow(abs(cos(angle*2.0)),28.0);
    // Four stone prongs cast radiating sectors; pressed glass breaks up the light softly.
    float shadow=1.0-0.60*prong*(1.0-exp(-r2*5.0));
    float glass_rays=0.97+0.04*cos(angle*32.0+sqrt(r2)*5.0);
    return (0.78*exp(-r2/1.15)+0.26*exp(-r2/5.4))*shadow*glass_rays;
}
void fragment() {
    float x=world_point.x-station_center_x;
    float nearest=clamp(round((world_point.z+1.2)/column_pitch),0.0,17.0);
    float light_sum=0.0;
    for(int row=-1;row<=1;row++) {
        float index=nearest+float(row);
        if(index<1.0 || index>16.0) continue;
        float z=-1.2+index*column_pitch;
        light_sum+=halo(vec2(x+column_x,world_point.z-z));
        // Omitted right-row balcony columns have no phantom ceiling light.
        if(abs(z-transfer_mid_z)>=2.56)
            light_sum+=halo(vec2(x-column_x,world_point.z-z));
    }
    float light_level=clamp(light_sum,0.0,1.15);
    // The ceiling paint has one neutral hue; shadows affect brightness alone.
    vec3 sample_color=texture(paint,world_point.xz/1.2).rgb;
    float paint_value=dot(sample_color,vec3(0.2126,0.7152,0.0722));
    vec3 neutral_paint=vec3(paint_value);
    float illumination=clamp(0.58+light_level*0.43,0.58,1.02);
    ALBEDO=neutral_paint*illumination;
}
