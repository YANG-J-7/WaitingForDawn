shader_type canvas_item;
render_mode unshaded;
uniform sampler2D water_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D contact_texture : filter_linear, repeat_disable;
uniform sampler2D rock_only : filter_nearest, repeat_disable;
uniform vec2 shore_origin = vec2(100.0,220.0);
uniform vec2 shore_size = vec2(1724.0,477.0);
uniform float elapsed = 0.0;
uniform bool waves_enabled = true;
uniform bool moon_enabled = true;
uniform vec2 moon_center = vec2(1430.0,780.0);
varying vec2 world_pos;
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy; }
void fragment(){
    vec2 shore_uv=(world_pos-shore_origin)/shore_size;
    float inside=step(0.0,shore_uv.x)*step(shore_uv.x,1.0)*step(0.0,shore_uv.y)*step(shore_uv.y,1.0);
    float protected_rock=texture(rock_only,shore_uv).r*inside;
    float near_shore=texture(contact_texture,vec2(clamp(shore_uv.x,0.0,1.0),0.5)).r*shore_size.y+shore_origin.y;
    float depth=smoothstep(near_shore+12.0,near_shore+140.0,world_pos.y);
    float t=elapsed*0.5235987756;
    vec2 uv=world_pos/500.0;
    // 两组整数周期运动，12秒回环；不使用不受暂停控制的内置TIME。
    // 全湖共享可读的细波运动，浅水减弱但不归零；月光范围不限制波纹。
    float strength=mix(0.35,1.0,depth)*(1.0-protected_rock);
    vec2 delta=waves_enabled ? vec2(sin(uv.y*6.2831853+t)*0.032,cos(uv.x*6.2831853+t*2.0)*0.015)*strength : vec2(0.0);
    vec3 base=texture(water_texture,uv+delta).rgb;
    if(waves_enabled){
        vec3 secondary=texture(water_texture,uv+vec2(-delta.x*0.6,delta.y*1.3)).rgb;
        base=mix(base,secondary,0.22);
    }
    float wave=texture(water_texture,uv+delta+vec2(0.013*sin(t),0.006*cos(t))).b;
    float region=exp(-pow((world_pos.x-moon_center.x)/260.0,2.0))*smoothstep(near_shore+45.0,near_shore+180.0,world_pos.y);
    region*=1.0-protected_rock;
    float glint=smoothstep(0.27,0.43,wave)*pow(max(0.0,sin(world_pos.y*0.17+sin(world_pos.x*0.025+t)*2.0+t*2.0)),12.0);
    if(moon_enabled) base+=vec3(0.32,0.48,0.60)*glint*region*0.55;
    COLOR=vec4(base,1.0);
}
