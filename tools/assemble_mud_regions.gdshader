shader_type canvas_item;
render_mode unshaded;

// 六块内部共用连续母图；只在整个区域外围接回已存在的草地。
uniform sampler2D existing_grass : filter_linear, repeat_enable;
uniform sampler2D mud_region : filter_linear, repeat_disable;
uniform vec2 grid_size = vec2(3.0, 2.0);
uniform float tile_size = 1024.0;
uniform bool plain_grass = false;

void fragment() {
    vec2 local_uv = (fract(UV * grid_size) * tile_size - vec2(0.5)) / (tile_size - 1.0);
    // 原生裁切的草地保持叶片尺度；只在本草地采样的边缘做周期过渡。
    vec2 grass_inside = min(local_uv, vec2(1.0) - local_uv);
    vec2 w = smoothstep(vec2(0.025), vec2(0.15), grass_inside);
    vec3 a = texture(existing_grass, local_uv).rgb;
    vec3 b = texture(existing_grass, local_uv + vec2(0.5, 0.0)).rgb;
    vec3 c = texture(existing_grass, local_uv + vec2(0.0, 0.5)).rgb;
    vec3 d = texture(existing_grass, local_uv + vec2(0.5)).rgb;
    vec3 grass = mix(mix(d, c, w.x), mix(b, a, w.x), w.y);
    vec2 pixels = UV * grid_size * tile_size - vec2(0.5);
    vec2 distance_to_edge = min(pixels, grid_size * tile_size - vec2(1.0) - pixels) / tile_size;
    float weight = plain_grass ? 0.0 : smoothstep(0.04, 0.22, min(distance_to_edge.x, distance_to_edge.y));
    COLOR = vec4(mix(grass, texture(mud_region, UV).rgb, weight), 1.0);
}
