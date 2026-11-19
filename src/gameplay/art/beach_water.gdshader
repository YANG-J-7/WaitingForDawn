shader_type canvas_item;
render_mode unshaded;
uniform sampler2D water_texture : source_color,filter_linear_mipmap,repeat_enable;
uniform float elapsed=0.0;
uniform bool animated=true;
varying vec2 world_pos;
void vertex(){world_pos=VERTEX;}
void fragment(){
    float t=elapsed*0.5235987756;
    vec2 uv=world_pos/500.0;
    vec2 offset=animated?vec2(0.018*sin(uv.y*6.2831853+t),0.009*cos(uv.x*6.2831853+t*2.0)):vec2(0.0);
    vec3 water=texture(water_texture,uv+offset).rgb;
    COLOR=vec4(water,smoothstep(366.0,450.0,world_pos.y));
}
