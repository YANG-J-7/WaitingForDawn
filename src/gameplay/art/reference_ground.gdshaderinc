// 所有地形片共用世界坐标与草叶密度；三角随机偏移抑制整齐平铺。
uniform sampler2D grass_art : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_low : source_color, filter_linear_mipmap, repeat_enable;
uniform float detail_strength=.35;
varying vec2 world_point;
vec2 offset_for(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}
vec3 grass_sample(vec2 uv){
    vec2 cell=floor(uv),f=fract(uv);
    vec2 a=cell,b=cell+vec2(1,0),c=cell+vec2(0,1);
    vec3 weights=vec3(1.0-f.x-f.y,f.x,f.y);
    if(f.x+f.y>1.0){a=cell+vec2(1);b=cell+vec2(0,1);c=cell+vec2(1,0);weights=vec3(f.x+f.y-1.0,1.0-f.x,1.0-f.y);}
    weights=weights*weights*weights;weights/=dot(weights,vec3(1));
    vec2 dx=dFdx(uv),dy=dFdy(uv);
    vec2 ua=uv+offset_for(a),ub=uv+offset_for(b),uc=uv+offset_for(c);
    vec3 da=textureGrad(grass_art,ua,dx,dy).rgb/max(textureGrad(grass_low,ua,dx,dy).rgb,vec3(.01));
    vec3 db=textureGrad(grass_art,ub,dx,dy).rgb/max(textureGrad(grass_low,ub,dx,dy).rgb,vec3(.01));
    vec3 dc=textureGrad(grass_art,uc,dx,dy).rgb/max(textureGrad(grass_low,uc,dx,dy).rgb,vec3(.01));
    // 只传递明暗细节，避免分通道除法在暗叶间隙放大蓝色噪点。
    float detail=dot(da*weights.x+db*weights.y+dc*weights.z,vec3(.2126,.7152,.0722));
    return vec3(clamp(detail,.45,1.7));
}
vec3 ground_color(vec3 base){
    // 原图始终完整保留；草地只叠加近景明暗细节，不再用多边形替换平原。
    float green=smoothstep(1.02,1.18,base.g/max(base.r,.001))*(1.0-smoothstep(.95,1.15,base.b/max(base.g,.001)));
    float density=1.0/max(length(dFdx(world_point)),.001);
    float close=smoothstep(.9,1.8,density);
    float detail=grass_sample(world_point/156.0).r;
    return base*mix(1.0,detail,green*close*detail_strength);
}
