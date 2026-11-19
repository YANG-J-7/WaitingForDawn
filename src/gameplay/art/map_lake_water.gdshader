shader_type canvas_item;
render_mode unshaded;
uniform sampler2D water_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D water_control : filter_linear, repeat_disable;
uniform vec2 world_size=vec2(7056.0,2880.0);
uniform float elapsed=0.0;
uniform bool animated=true;
uniform bool extend_boundary=false;
uniform sampler2D coast_field : filter_linear, repeat_disable;
uniform vec4 field_rect;
uniform float north_coast_x=5494.0;
varying vec2 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
    vec4 control=texture(water_control,world_pos/world_size);
    if(extend_boundary && (world_pos.y<0.0 || world_pos.x>world_size.x)){
        vec4 field=texture(coast_field,(world_pos-field_rect.xy)/field_rect.zw);
        float distance=(field.b*65280.0+field.a*255.0)/65535.0*1024.0-512.0;
        // 北侧只延长现有短岸，远处草地不能由开放岸线的切线误判为湖水。
        if(world_pos.y<0.0){distance=abs(distance)*sign(world_pos.x-north_coast_x);}
        float coverage=world_pos.x>world_size.x?1.0:smoothstep(-70.0,-35.0,distance);
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
        base+=vec3(0.32,0.48,0.60)*glint*region*0.55;
    }
    COLOR=vec4(base,control.r);
}
