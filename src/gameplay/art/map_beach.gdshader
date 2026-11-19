shader_type canvas_item;
render_mode unshaded;
#include "res://src/gameplay/art/rock_contact.gdshaderinc"
uniform sampler2D coast_field : filter_linear, repeat_disable;
uniform sampler2D sand_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_contact : filter_linear, repeat_enable;
uniform sampler2D grass_detail : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 field_rect;
uniform float coast_length;
uniform float end_fade=180.0;
uniform float width_scale=1.3;
uniform float mountain_sand_extension=0.0;
uniform vec2 world_size=vec2(7056.0,2880.0);
uniform float elapsed=0.0;
uniform bool animated=true;
uniform bool foam_enabled=true;
uniform vec2 render_min=vec2(0.0);
uniform vec2 render_max=vec2(7056.0,2880.0);
varying vec2 world_pos;
void vertex(){world_pos=VERTEX;}

vec4 front(float along,float cross,float offset){
    float p=fract(elapsed/4.0+offset+.045*sin(along*.012));
    float center=455.0-102.0*sin(p*3.1415926536);
    vec2 uv=vec2(along/1070.0+offset*.19,(cross-center)/68.0+.45);
    vec4 foam=texture(foam_texture,vec2(uv.x,clamp(uv.y,0.0,1.0)));
    foam.a*=step(0.0,uv.y)*step(uv.y,1.0)*smoothstep(0.0,.14,p)*(1.0-smoothstep(.72,1.0,p))*.78;
    return foam;
}
void fragment(){
    vec4 field=texture(coast_field,(world_pos-field_rect.xy)/field_rect.zw);
    float along=(field.r*65280.0+field.g*255.0)/65535.0*16384.0;
    float distance=(field.b*65280.0+field.a*255.0)/65535.0*1024.0-512.0;
    // 山脚沙带向水侧展开，南端平滑接回原沙滩，山体由共用遮罩保护。
    float mountain_coast=smoothstep(5400.0,5700.0,world_pos.x)*(1.0-smoothstep(1666.0,1900.0,world_pos.y));
    float land_across=410.0+distance*width_scale;
    float across=land_across-mountain_sand_extension*mountain_coast*width_scale;
    float ends=smoothstep(40.0,end_fade,along)*(1.0-smoothstep(coast_length-end_fade,coast_length-40.0,along));
    // 岸线最近点在凸岬中轴两侧会跳转，弧长只用于端点，纹理按连续世界坐标采样。
    float texture_u=(world_pos.x+world_pos.y*.37)/1070.0;
    vec2 uv=vec2(texture_u,(across-180.0)/325.0);
    vec4 sand=texture(sand_texture,vec2(uv.x,clamp(uv.y,0.0,1.0)));
    // 固定原陆侧的草沙边缘，仅外推水侧，避免整体平移沙层后在山脚留下水缝。
    float fixed_land_alpha=texture(sand_texture,vec2(uv.x,clamp((land_across-180.0)/325.0,0.0,.6))).a;
    sand.a=mix(sand.a,fixed_land_alpha,smoothstep(0.0,12.0,mountain_sand_extension*mountain_coast));
    // 色纹二维投射到世界平面，避免有符号距离中轴的梯度折角把沙纹挤成V形。
    sand.rgb=texture(sand_texture,vec2(texture_u,.38+.10*sin(world_pos.y*.012))).rgb;
    float top=180.0+texture(grass_contact,vec2(uv.x,.5)).r*325.0;
    float blade=texture(grass_detail,world_pos/360.0).g;
    float edge=top+26.0+(blade-.2)*90.0;
    float land=smoothstep(edge-7.0,edge+10.0,land_across);
    float sea=1.0-smoothstep(408.0,490.0,across);
    float pulse=animated?.5+.5*sin(elapsed*1.5707963268):.5;
    float wet=smoothstep(330.0-15.0*pulse,430.0-15.0*pulse,across);
    sand.rgb*=mix(vec3(.72,.79,.85),vec3(.37,.57,.69),wet*.8);
    sand.a*=land*sea*step(180.0,land_across)*step(uv.y,1.0);
    vec4 a=front(texture_u*1070.0,across,0.0);
    vec4 b=front(texture_u*1070.0,across,.5);
    if(!foam_enabled){a.a=0.0;b.a=0.0;}
    // 静态小地图保留一个可辨识的拍岸相位，时钟不推进。
    float foam_alpha=a.a+b.a*(1.0-a.a);
    vec3 foam_color=(a.rgb*a.a+b.rgb*b.a*(1.0-a.a))/max(foam_alpha,.001);
    float alpha=foam_alpha+sand.a*(1.0-foam_alpha);
    vec3 rgb=(foam_color*foam_alpha+sand.rgb*sand.a*(1.0-foam_alpha))/max(alpha,.001);
    float inside=step(render_min.x,world_pos.x)*step(render_min.y,world_pos.y)*step(world_pos.x,render_max.x)*step(world_pos.y,render_max.y);
    COLOR=vec4(rgb,alpha*ends*inside*water_visibility(world_pos));
}
