shader_type canvas_item;

// 第一关以中性环境光保留素材夜色，地表接收移动主光。
// 同密度偏移原图以打散大地图周期；高权重保留草叶，少量交界平滑过渡。
uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 detail_world_size = vec2(360.0);
varying vec2 map_position;

void vertex() {
    map_position = VERTEX;
}

vec2 source_offset(vec2 key) {
    return fract(sin(vec2(dot(key, vec2(127.1, 311.7)), dot(key, vec2(269.5, 183.3)))) * 43758.5453);
}

void fragment() {
    vec2 uv = map_position / detail_world_size;
    vec2 skew = vec2(uv.x - uv.y * 0.57735027, uv.y * 1.15470054);
    vec2 cell = floor(skew);
    vec2 part = fract(skew);
    vec2 a;
    vec2 b;
    vec2 c;
    vec3 weight;
    if (part.x + part.y < 1.0) {
        a = cell;
        b = cell + vec2(1.0, 0.0);
        c = cell + vec2(0.0, 1.0);
        weight = vec3(1.0 - part.x - part.y, part.x, part.y);
    } else {
        a = cell + vec2(1.0);
        b = cell + vec2(0.0, 1.0);
        c = cell + vec2(1.0, 0.0);
        weight = vec3(part.x + part.y - 1.0, 1.0 - part.x, 1.0 - part.y);
    }
    weight = pow(max(weight, vec3(0.0)), vec3(8.0));
    weight /= dot(weight, vec3(1.0));
    // 显式导数避免随机偏移边界触发错误mipmap而出现细线。
    vec2 dx = dFdx(uv);
    vec2 dy = dFdy(uv);
    vec3 color = textureGrad(grass_texture, uv + source_offset(a), dx, dy).rgb * weight.x;
    color += textureGrad(grass_texture, uv + source_offset(b), dx, dy).rgb * weight.y;
    color += textureGrad(grass_texture, uv + source_offset(c), dx, dy).rgb * weight.z;
    COLOR = vec4(color, 1.0);
}
