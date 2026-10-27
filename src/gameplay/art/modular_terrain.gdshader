shader_type canvas_item;
render_mode unshaded;

// 控制图只保存几何权重；草、岩、水的可见细节均来自生成或复用美术。
uniform sampler2D grass_detail : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_detail : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D water_detail : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_detail : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D control_map : filter_linear, repeat_disable;
uniform vec2 module_origin = vec2(0.0);
uniform vec2 module_size = vec2(7056.0,2880.0);
uniform vec2 world_size = vec2(7056.0,2880.0);
uniform vec2 rock_coverage = vec2(156.0,156.0);
uniform vec2 water_coverage = vec2(156.0,156.0);
uniform int surface_kind = 0;
varying vec2 local_position;
varying vec2 world_position;

vec2 offset_for(vec2 p) {
    return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}

vec3 grass_at(vec2 position) {
    vec2 uv = position/vec2(216.0,162.0);
    vec2 dx = dFdx(uv); vec2 dy = dFdy(uv);
    vec2 grid = vec2(uv.x-uv.y*.57735027,uv.y*1.15470054);
    vec2 cell=floor(grid); vec2 f=fract(grid);
    vec2 a; vec2 b; vec2 c; vec3 w;
    if(f.x+f.y<1.0) {
        a=cell;b=cell+vec2(1,0);c=cell+vec2(0,1);w=vec3(1.0-f.x-f.y,f.x,f.y);
    } else {
        a=cell+vec2(1);b=cell+vec2(0,1);c=cell+vec2(1,0);w=vec3(f.x+f.y-1.0,1.0-f.x,1.0-f.y);
    }
    w=w*w*w;w/=w.x+w.y+w.z;
    vec3 detail=textureGrad(grass_detail,uv+offset_for(a),dx,dy).rgb*w.x
        +textureGrad(grass_detail,uv+offset_for(b),dx,dy).rgb*w.y
        +textureGrad(grass_detail,uv+offset_for(c),dx,dy).rgb*w.z;
    detail=(detail-vec3(128.0/255.0))/sqrt(dot(w,w));
    // 大色场连续且低对比，不随组件重新起纹理或产生竖向拼贴。
    float macro=1.0+.028*sin(position.x/610.0+position.y/430.0)+.018*cos(position.y/720.0-position.x/940.0);
    return clamp(vec3(.135,.235,.205)*macro+detail*.72,vec3(0),vec3(1));
}

void vertex() {
    local_position=VERTEX;
    world_position=VERTEX+module_origin;
}

void fragment() {
    vec3 grass=grass_at(world_position);
    vec2 uv=local_position/module_size;
    vec4 mask=texture(control_map,uv);
    vec3 color=grass;
    float alpha=1.0;
    if(surface_kind==0) {
        // 关外持续有景观；压暗缓慢发生在自然地貌之外，不画矩形框。
        vec2 outside=max(-world_position,world_position-world_size);
        float edge=max(outside.x,outside.y);
        color*=mix(1.0,.50,smoothstep(0.0,1800.0,edge));
    } else if(surface_kind==1) {
        vec3 rock=pow(texture(rock_detail,world_position/rock_coverage).rgb,vec3(.74))*vec3(.72,.85,.99);
        float above=texture(control_map,uv-vec2(0,12.0)/module_size).r;
        float below=texture(control_map,uv+vec2(0,12.0)/module_size).r;
        float lip=max(mask.r-above,0.0);
        float foot=max(mask.r-below,0.0);
        rock*=.85+lip*.25-foot*.32;
        float cast=texture(control_map,uv-vec2(9,14)/module_size).r;
        color=grass*1.06;
        color*=1.0-max(cast-mask.r,0.0)*.48;
        color=mix(color,rock,smoothstep(.08,.92,mask.r));
        color=mix(color,grass,lip*.20);
        // 路域由同一通行组件提供，浅土路不会开放硬岩。
        vec3 soil=texture(soil_detail,world_position/vec2(144.0,144.0)).rgb;
        soil=mix(vec3(.17,.195,.18),vec3(.32,.34,.30),dot(soil,vec3(.333)));
        float path=max(mask.g,mask.b);
        color=mix(color,soil,smoothstep(.15,.8,path)*.72);
        alpha=mask.a;
    } else if(surface_kind==2) {
        float wet=mask.r;
        float bank=mask.g;
        vec3 stone=texture(rock_detail,world_position/rock_coverage).rgb;
        vec3 water=pow(texture(water_detail,world_position/water_coverage).rgb,vec3(.55))*vec3(.95,1.05,1.2);
        water*=mix(1.12,.88,mask.b);
        vec3 shore=mix(vec3(.16,.205,.20),vec3(.32,.355,.34),dot(stone,vec3(.333)));
        float fringe=smoothstep(.015,.23,bank)*(1.0-smoothstep(.6,.95,bank));
        color=mix(grass,shore,fringe*.82);
        float water_edge=(1.0-smoothstep(.42,.58,bank))*wet;
        water+=vec3(.12,.15,.145)*water_edge;
        color=mix(color,water,wet);
        alpha=max(wet,fringe);
    }
    COLOR=vec4(color,alpha);
}
