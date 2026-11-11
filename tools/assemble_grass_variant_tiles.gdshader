shader_type canvas_item;
render_mode unshaded;

// 只装配已有图像：偏移采样隐藏原稿边缘，所有款式共用这一静态底草。
uniform sampler2D base_grass : filter_linear, repeat_enable;
uniform sampler2D dressed_grass : filter_linear, repeat_disable;
uniform bool plain_grass = false;
uniform float tile_size = 1254.0;

void fragment() {
    // 将首末像素中心映射到同一周期端点，避免闭边的一像素误差。
    vec2 uv = (UV * tile_size - vec2(0.5)) / (tile_size - 1.0);
    vec2 inside = min(uv, vec2(1.0) - uv);
    vec2 w = smoothstep(vec2(0.025), vec2(0.15), inside);
    vec3 a = texture(base_grass, uv).rgb;
    vec3 b = texture(base_grass, uv + vec2(0.5, 0.0)).rgb;
    vec3 c = texture(base_grass, uv + vec2(0.0, 0.5)).rgb;
    vec3 d = texture(base_grass, uv + vec2(0.5)).rgb;
    vec3 common_grass = mix(mix(d, c, w.x), mix(b, a, w.x), w.y);
    float dressing_weight = plain_grass ? 0.0 : smoothstep(0.04, 0.17, min(inside.x, inside.y));
    COLOR = vec4(mix(common_grass, texture(dressed_grass, uv).rgb, dressing_weight), 1.0);
}
