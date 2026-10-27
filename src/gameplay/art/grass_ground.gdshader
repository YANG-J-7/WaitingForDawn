shader_type canvas_item;
render_mode unshaded;

// 细节是以128为中心的颜色差值，必须按数据读取，不能做sRGB解码。
uniform sampler2D grass_detail : filter_linear_mipmap, repeat_enable;
uniform sampler2D macro_mask : source_color, filter_linear, repeat_disable;
uniform vec2 map_size = vec2(7056.0, 2880.0);
uniform vec2 detail_world_size = vec2(216.0, 162.0);
uniform float detail_strength = 0.85;
varying vec2 map_position;

void vertex() {
    // 此节点位于地图原点；18个绘制矩形使用同一连续坐标。
    map_position = VERTEX;
}

vec2 offset_for(vec2 cell) {
    return fract(sin(vec2(dot(cell, vec2(127.1, 311.7)),
        dot(cell, vec2(269.5, 183.3)))) * 43758.5453);
}

void fragment() {
    vec4 original = COLOR;
    vec4 macro = texture(macro_mask, map_position / map_size);
    vec2 uv = map_position / detail_world_size;
    // 在求随机偏移之前计算导数，避免格子边界触发错误的模糊层级。
    vec2 dx = dFdx(uv);
    vec2 dy = dFdy(uv);
    vec2 grid = vec2(uv.x - uv.y * 0.57735027, uv.y * 1.15470054);
    vec2 cell = floor(grid);
    vec2 f = fract(grid);
    vec2 a;
    vec2 b;
    vec2 c;
    vec3 w;
    if (f.x + f.y < 1.0) {
        a = cell; b = cell + vec2(1.0, 0.0); c = cell + vec2(0.0, 1.0);
        w = vec3(1.0 - f.x - f.y, f.x, f.y);
    } else {
        a = cell + vec2(1.0); b = cell + vec2(0.0, 1.0); c = cell + vec2(1.0, 0.0);
        w = vec3(f.x + f.y - 1.0, 1.0 - f.x, 1.0 - f.y);
    }
    // 缩窄重叠区并补偿混合后的对比损失，保留短草的细叶轮廓。
    w = w * w * w;
    w /= w.x + w.y + w.z;
    vec3 d = textureGrad(grass_detail, uv + offset_for(a), dx, dy).rgb * w.x
        + textureGrad(grass_detail, uv + offset_for(b), dx, dy).rgb * w.y
        + textureGrad(grass_detail, uv + offset_for(c), dx, dy).rgb * w.z;
    d = (d - vec3(128.0 / 255.0)) / sqrt(dot(w, w));
    vec3 grass = clamp(macro.rgb + d * detail_strength, vec3(0.0), vec3(1.0));
    COLOR = vec4(mix(original.rgb, grass, macro.a), original.a);
}
