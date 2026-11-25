shader_type canvas_item;
#include "res://src/gameplay/art/map_water_coverage.gdshaderinc"
uniform sampler2D water_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D water_control : filter_linear, repeat_disable;
uniform vec2 world_size=vec2(7056.0,2880.0);
uniform float elapsed=0.0;
uniform bool animated=true;
uniform bool extend_boundary=false;
uniform sampler2D coast_field : filter_linear, repeat_disable;
uniform vec4 field_rect;
uniform float north_coast_x=5494.0;
uniform float dawn_progress=0.0;
uniform float dawn_east=7488.0;
varying vec2 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
    vec4 control=texture(water_control,world_pos/world_size);
    if(extend_boundary && (world_pos.y<0.0 || world_pos.x>world_size.x)){
        vec4 field=texture(coast_field,(world_pos-field_rect.xy)/field_rect.zw);
        float coverage=extended_water_coverage(field,world_pos,world_size,north_coast_x);
        float outward=max(-world_pos.y,world_pos.x-world_size.x);
        vec2 depth=mix(control.gb,vec2(0.0,1.0),smoothstep(0.0,180.0,outward));
        control=vec4(coverage,depth,1.0);
    }
    float t=floor(elapsed*60.0+0.0001)/60.0*0.5235987756;
    vec2 uv=world_pos/500.0;
    float strength=(1.0-control.g)*mix(0.35,1.0,smoothstep(0.5,0.95,control.b));
    vec2 offset=animated?vec2(sin(uv.y*6.2831853+t)*0.032,cos(uv.x*6.2831853+t*2.0)*0.015)*strength:vec2(0.0);
    vec3 base=texture(water_texture,uv+offset).rgb;
    if(animated){
        base=mix(base,texture(water_texture,uv+vec2(-offset.x*0.6,offset.y*1.3)).rgb,0.22);
        float region=exp(-pow((world_pos.x-6660.0)/420.0,2.0))*smoothstep(0.6,0.98,control.b)*(1.0-control.g);
        float wave=texture(water_texture,uv+offset+vec2(0.013*sin(t),0.006*cos(t))).b;
        float glint=smoothstep(0.27,0.43,wave)*pow(max(0.0,sin(world_pos.y*0.17+sin(world_pos.x*0.025+t)*2.0+t*2.0)),12.0);
        base+=vec3(0.32,0.48,0.60)*glint*region*0.55*(1.0-smoothstep(0.0,1.0,dawn_progress));
        if (dawn_progress > 0.43) {
            // 从东侧向湖里延伸一条断续反光，沿用同一组水纹和时钟。
            float grow = smoothstep(0.43, 1.0, dawn_progress);
            float distance_west = dawn_east - world_pos.x;
            float reach = mix(155.0, 1460.0, grow);
            float taper = 1.0 - smoothstep(reach * 0.23, reach, distance_west);
            float band_y = 1300.0 + distance_west * 0.32;
            float band_offset = (world_pos.y - band_y) / mix(130.0, 445.0, grow);
            float band = exp(-band_offset * band_offset);
            float ripple = smoothstep(0.23, 0.42, wave) * pow(0.5 + 0.5 * sin(world_pos.y * 0.17 + sin(world_pos.x * 0.025 + t) * 2.0 + t * 2.0), 6.0);
            float facets = 0.5 + 0.5 * sin(world_pos.x * 0.083 + sin(world_pos.y * 0.043 + t) * 3.0);
            ripple *= smoothstep(0.10, 0.67, facets);
            float surface_glow = band * taper * grow * (1.0 - 0.70 * control.g);
            base += vec3(0.94, 0.62, 0.28) * surface_glow * (0.13 + 0.89 * ripple);
        }
    }
    COLOR=vec4(base,control.r);
}
