shader_type canvas_item;
render_mode unshaded;
uniform sampler2D shore_control : filter_linear, repeat_disable;
uniform bool foam_enabled = true;
uniform bool waves_enabled = true;
uniform float elapsed = 0.0;
uniform sampler2D water_only : filter_nearest, repeat_disable;
uniform sampler2D ripple_texture : source_color, filter_linear, repeat_enable;
void fragment(){
    vec4 art=texture(TEXTURE,UV);
    vec4 control=texture(shore_control,UV);
    // 混合原画始终固定UV；单独水纹只改变保守水域中的细微反射。
    float shallow=texture(water_only,UV).r;
    float t=elapsed*0.5235987756;
    vec2 offset=vec2(sin(UV.y*25.0+t)*0.003,cos(UV.x*18.0+t*2.0)*0.004);
    if(waves_enabled){
        float ripple=texture(ripple_texture,UV*vec2(3.45,0.954)+offset*5.0).b;
        float neutral=texture(ripple_texture,UV*vec2(3.45,0.954)).b;
        art.rgb+=vec3(0.22,0.36,0.45)*(ripple-neutral)*shallow;
    }
    // 岸上缘转接；抽出的静态白线略减弱，由独立动态水线补充。
    art.a*=mix(1.0,control.b,control.r);
    art.a*=control.a;
    art.rgb*=1.0-control.g*(foam_enabled ? 0.25 : 0.0);
    COLOR=art;
}
