shader_type canvas_item;
render_mode unshaded;
varying vec4 shadow_tint;

void vertex() {
	// fragment中的COLOR已乘过源图alpha；独立传递顶点色，避免透明边被重复衰减。
	shadow_tint = COLOR;
}

void fragment() {
	// 仅模糊轮廓透明度，不把精灵本身的色彩带进地面投影。
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 8.0;
	float alpha = texture(TEXTURE, UV).a * 0.40;
	alpha += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a * 0.15;
	alpha += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a * 0.15;
	alpha += texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a * 0.15;
	alpha += texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a * 0.15;
	COLOR = vec4(shadow_tint.rgb, shadow_tint.a * alpha);
}
