shader_type canvas_item;
render_mode unshaded;

// 新截图参考生成的静态草地；直接读取原稿色彩，不叠动态草叶或强制染色。
uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 detail_world_size = vec2(216.0, 216.0);
varying vec2 map_position;

void vertex() {
    map_position = VERTEX;
}

vec2 offset_for(vec2 cell) {
    return fract(sin(vec2(dot(cell, vec2(127.1, 311.7)),
        dot(cell, vec2(269.5, 183.3)))) * 43758.5453);
}

void fragment() {
    vec2 uv = map_position / detail_world_size;
    vec2 dx = dFdx(uv);
    vec2 dy = dFdy(uv);
    vec2 grid = vec2(uv.x - uv.y * 0.57735027, uv.y * 1.15470054);
    vec2 cell = floor(grid);
    vec2 f = fract(grid);
    vec2 a; vec2 b; vec2 c; vec3 w;
    if (f.x + f.y < 1.0) {
        a = cell; b = cell + vec2(1.0, 0.0); c = cell + vec2(0.0, 1.0);
        w = vec3(1.0 - f.x - f.y, f.x, f.y);
    } else {
        a = cell + vec2(1.0); b = cell + vec2(0.0, 1.0); c = cell + vec2(1.0, 0.0);
        w = vec3(f.x + f.y - 1.0, 1.0 - f.x, 1.0 - f.y);
    }
    w = w * w * w;
    w /= w.x + w.y + w.z;
    vec3 grass = textureGrad(grass_texture, uv + offset_for(a), dx, dy).rgb * w.x
        + textureGrad(grass_texture, uv + offset_for(b), dx, dy).rgb * w.y
        + textureGrad(grass_texture, uv + offset_for(c), dx, dy).rgb * w.z;
    COLOR = vec4(grass, 1.0);
}
