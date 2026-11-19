shader_type canvas_item;
render_mode unshaded;
uniform sampler2D foam_texture : source_color,filter_linear,repeat_enable;
uniform float elapsed=0.0;
uniform bool animated=true;
varying vec2 world_pos;
void vertex(){world_pos=VERTEX;}
vec4 front(float offset){
    float p=fract(elapsed/4.0+offset);
    float advance=sin(p*3.1415926536);
    float center=455.0-102.0*advance;
    vec2 uv=vec2(world_pos.x/1070.0+offset*0.19,(world_pos.y-center)/68.0+0.45);
    vec4 foam=texture(foam_texture,vec2(uv.x,clamp(uv.y,0.0,1.0)));
    float envelope=smoothstep(0.0,0.14,p)*(1.0-smoothstep(0.72,1.0,p));
    foam.a*=step(0.0,uv.y)*step(uv.y,1.0)*envelope*0.78;
    return foam;
}
void fragment(){
    vec4 a=front(0.0);
    vec4 b=front(0.5);
    float alpha=a.a+b.a*(1.0-a.a);
    vec3 color=(a.rgb*a.a+b.rgb*b.a*(1.0-a.a))/max(alpha,0.001);
    COLOR=vec4(color,animated?alpha:0.0);
}
