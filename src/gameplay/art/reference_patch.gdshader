shader_type canvas_item;
render_mode unshaded;
uniform float detail_lod=1.0;
void fragment(){
    vec4 art=texture(TEXTURE,UV);
    vec2 d=min(UV,vec2(1)-UV);
    float ground=smoothstep(1.02,1.18,art.g/max(art.r,.001))*(1.0-smoothstep(1.0,1.2,art.b/max(art.g,.001)));
    float edge=smoothstep(0.0,mix(.006,.18,ground),min(d.x,d.y));
    // 仅处理原图透明边缘，RGB直接使用地图原稿，不叠草地贴图。
    COLOR=vec4(art.rgb,art.a*edge*detail_lod);
}
