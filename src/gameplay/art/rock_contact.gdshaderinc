// 山体原生透明轮廓用于水侧裁切；不挪动岩石、不参与通行逻辑。
uniform sampler2D rock_texture : filter_linear, repeat_disable;
uniform vec4 rock_rect=vec4(3528.0,-108.0,3548.0,1774.0);
uniform bool rock_clip_enabled=false;
float rock_alpha(vec2 point){
    vec2 uv=(point-rock_rect.xy)/rock_rect.zw;
    float inside=step(0.0,uv.x)*step(0.0,uv.y)*step(uv.x,1.0)*step(uv.y,1.0);
    return texture(rock_texture,clamp(uv,vec2(0.0),vec2(1.0))).a*inside;
}
float water_visibility(vec2 point){
    if(!rock_clip_enabled){return 1.0;}
    float core=rock_alpha(point);
    // 向水侧扩两世界单位，消除半透明边缘透出的白线。
    core=max(core,max(rock_alpha(point+vec2(-2.0,0.0)),rock_alpha(point+vec2(0.0,-2.0))));
    return 1.0-smoothstep(.04,.7,core);
}
