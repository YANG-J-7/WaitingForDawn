shader_type canvas_item;

// 图集UV连续跨过六块；仅整片区域外圈退回下方共享草地。
uniform vec2 patch_grid_size = vec2(1.0);
uniform float soil_warmth : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 art = texture(TEXTURE, UV);
    if (soil_warmth > 0.0) {
        // 裸土的青色较弱，草叶偏绿，石面高光偏蓝。用软阈值保留过渡和原纹理。
        vec3 rgb = art.rgb * 255.0;
        float grass = smoothstep(22.0, 34.0, rgb.g - rgb.r);
        float stone = max(smoothstep(27.0, 43.0, rgb.b - rgb.g), smoothstep(115.0, 137.0, rgb.b));
        float ground = smoothstep(30.0, 54.0, rgb.r) * smoothstep(-8.0, 7.0, rgb.b - rgb.g);
        float soil = ground * (1.0 - grass) * (1.0 - stone);
        art.rgb += vec3(68.0, 40.0, 10.0) / 255.0 * soil * soil_warmth;
    }
    vec2 inside = min(UV, vec2(1.0) - UV) * patch_grid_size;
    float edge = smoothstep(0.035, 0.19, min(inside.x, inside.y));
    COLOR = vec4(art.rgb, art.a * edge);
}
