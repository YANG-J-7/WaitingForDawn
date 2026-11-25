shader_type canvas_item;
uniform sampler2D water_only : filter_linear, repeat_disable;
uniform sampler2D ripple_texture : source_color, filter_linear, repeat_enable;
uniform vec2 shore_origin=vec2(3500.0,0.0);
uniform vec2 shore_size=vec2(3556.0,2880.0);
uniform float elapsed=0.0;
uniform bool animated=true;
uniform bool beach_enabled=false;
uniform sampler2D beach_cutout : filter_linear, repeat_disable;
void fragment(){
    // 始终固定岸石原画UV，只在纯水像素内叠加独立反射亮度。
    vec4 art=texture(TEXTURE,UV);
    if(beach_enabled){art.a*=1.0-texture(beach_cutout,(shore_origin+UV*shore_size)/vec2(7056.0,2880.0)).r;}
    if(animated){
        float mask=texture(water_only,UV).r;
        float t=floor(elapsed*60.0+0.0001)/60.0*0.5235987756;
        vec2 sample_uv=(shore_origin+UV*shore_size)/500.0;
        vec2 offset=vec2(sin(sample_uv.y*6.2831853+t)*0.032,cos(sample_uv.x*6.2831853+t*2.0)*0.015);
        float difference=texture(ripple_texture,sample_uv+offset).b-texture(ripple_texture,sample_uv).b;
        art.rgb+=vec3(0.22,0.36,0.45)*difference*mask;
    }
    COLOR=art;
}
