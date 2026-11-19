shader_type canvas_item;
render_mode unshaded;

// 图集UV连续跨过六块；仅整片区域外圈退回下方共享草地。
uniform vec2 patch_grid_size = vec2(1.0);

void fragment() {
    vec4 art = texture(TEXTURE, UV);
    vec2 inside = min(UV, vec2(1.0) - UV) * patch_grid_size;
    float edge = smoothstep(0.035, 0.19, min(inside.x, inside.y));
    COLOR = vec4(art.rgb, art.a * edge);
}
