shader_type canvas_item;
render_mode unshaded;
#include "res://src/gameplay/art/rock_contact.gdshaderinc"
uniform vec2 atlas_grid=vec2(2.0,3.0);
uniform float frame_count=6.0;
uniform float elapsed=0.0;
uniform float cycle=4.0;
uniform float active_duration=2.25;
uniform float phase_offset=0.0;
uniform float intensity=1.0;
uniform float water_floor=714.0;
uniform float playback_fps=60.0;
uniform sampler2D splash_texture : source_color, filter_linear, repeat_disable;
uniform bool water_mask_enabled=false;
uniform sampler2D world_water_control : filter_linear, repeat_disable;
uniform vec2 world_size=vec2(7056.0,2880.0);
varying vec2 world_pos;
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy; }
vec4 frame_at(float index,vec2 uv){
    vec2 cell=vec2(mod(index,atlas_grid.x),floor(index/atlas_grid.x));
    vec2 safe=clamp(uv,vec2(0.002),vec2(0.998));
    return texture(splash_texture,(safe+cell)/atlas_grid);
}
void fragment(){
    // 连续时间驱动；60fps是导出采样率，不把高刷新率运行锁成台阶。
    float phase=mod(elapsed+phase_offset,cycle);
    float last=frame_count-1.0;
    float progress=clamp(phase/active_duration,0.0,1.0)*last;
    float current=floor(progress);
    float u=fract(progress);
    // 三次B样条跨四阶段过渡，速度/加速度连续，去掉每张关键帧处的停顿。
    float w0=pow(1.0-u,3.0)/6.0;
    float w1=(3.0*u*u*u-6.0*u*u+4.0)/6.0;
    float w2=(-3.0*u*u*u+3.0*u*u+3.0*u+1.0)/6.0;
    float w3=u*u*u/6.0;
    vec4 a=frame_at(max(current-1.0,0.0),UV);
    vec4 b=frame_at(current,UV);
    vec4 c=frame_at(min(current+1.0,last),UV);
    vec4 d=frame_at(min(current+2.0,last),UV);
    float opacity=a.a*w0+b.a*w1+c.a*w2+d.a*w3;
    vec3 color=(a.rgb*a.a*w0+b.rgb*b.a*w1+c.rgb*c.a*w2+d.rgb*d.a*w3)/max(opacity,0.001);
    float envelope=smoothstep(0.0,0.18,phase)*(1.0-smoothstep(active_duration-0.5,active_duration,phase));
    // 三样点人工复核的水侧裁切平面；粒子不会穿过背后的岸石。
    float water_side=smoothstep(water_floor,water_floor+3.0,world_pos.y);
    if(water_mask_enabled){
        vec4 control=texture(world_water_control,world_pos/world_size);
        water_side*=control.r*(1.0-control.g);
    }
    float inside=step(0.0,world_pos.x)*step(0.0,world_pos.y)*step(world_pos.x,world_size.x)*step(world_pos.y,world_size.y);
    COLOR=vec4(color*1.15,clamp(opacity*1.8,0.0,1.0)*envelope*intensity*water_side*water_visibility(world_pos)*inside);
}
