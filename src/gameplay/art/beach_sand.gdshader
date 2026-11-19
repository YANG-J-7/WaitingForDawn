shader_type canvas_item;
render_mode unshaded;
uniform sampler2D sand_texture : source_color, filter_linear, repeat_enable;
uniform sampler2D grass_contact : filter_linear, repeat_enable;
uniform sampler2D grass_detail : source_color, filter_linear, repeat_enable;
uniform float elapsed=0.0;
uniform bool animated=true;
varying vec2 world_pos;
void vertex(){world_pos=VERTEX;}
void fragment(){
    vec2 uv=vec2(world_pos.x/1070.0,(world_pos.y-180.0)/325.0);
    vec4 sand=texture(sand_texture,uv);
    float inside=step(0.0,uv.y)*step(uv.y,1.0);
    float top=180.0+texture(grass_contact,vec2(uv.x,0.5)).r*325.0;
    // 复用草叶纹理作为静态边缘遮罩，收窄半透明带，避免灰雾盖住草地。
    float blade=texture(grass_detail,world_pos/360.0).g;
    float edge=top+26.0+(blade-0.2)*90.0;
    float land_alpha=smoothstep(edge-7.0,edge+10.0,world_pos.y);
    float sea_alpha=1.0-smoothstep(408.0,490.0,world_pos.y);
    float pulse=animated?0.5+0.5*sin(elapsed*1.5707963268):0.5;
    float wet=smoothstep(330.0-15.0*pulse,430.0-15.0*pulse,world_pos.y);
    vec3 tone=mix(vec3(0.72,0.79,0.85),vec3(0.37,0.57,0.69),wet*0.8);
    COLOR=vec4(sand.rgb*tone,sand.a*land_alpha*sea_alpha*inside);
}
