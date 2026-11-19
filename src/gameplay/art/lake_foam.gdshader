shader_type canvas_item;
render_mode unshaded;
uniform float elapsed = 0.0;
uniform sampler2D water_only : filter_nearest, repeat_disable;
uniform sampler2D rock_only : filter_nearest, repeat_disable;
void fragment(){
    // 共享世界岸段横向相位，两端收束；水线在岩脚附近推进与退回。
    float phase=elapsed*0.5235987756+UV.x*6.2831853;
    float pulse=pow(0.5+0.5*sin(phase*2.0),2.0);
    // 提取层也不能平移原画中的碎石，水线只在纯水遮罩内明暗循环。
    vec4 foam=texture(TEXTURE,UV);
    foam.a*=texture(water_only,UV).r;
    foam.a*=1.0-texture(rock_only,UV).r;
    foam.a*=pulse*smoothstep(0.0,0.05,UV.x)*(1.0-smoothstep(0.95,1.0,UV.x));
    COLOR=foam;
}
