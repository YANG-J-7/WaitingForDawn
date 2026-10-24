shader_type canvas_item;
uniform float animation_time = 0.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// 仅影响暖色高亮窗芯，屋顶、木梁和石墙不随灯光整体闪动。
	float warm = smoothstep(0.70, 0.90, source.r) * smoothstep(0.42, 0.64, source.g);
	warm *= 1.0 - smoothstep(0.36, 0.64, source.b);
	float pulse = sin(animation_time * 1.7 + UV.x * 17.0 + UV.y * 9.0);
	source.rgb *= 1.0 + 0.035 * warm * pulse;
	// 生成稿在纯色底上较亮，统一压回当前冷蓝夜景的材质亮度。
	source.rgb *= vec3(0.84, 0.90, 0.98);
	// 墙脚承接地面的冷暗环境色，暖窗保留亮度；不整体压暗屋顶。
	float ground_blend = smoothstep(0.73, 1.0, UV.y) * (1.0 - warm);
	source.rgb *= mix(vec3(1.0), vec3(0.72, 0.81, 0.85), ground_blend);
	COLOR = source;
}
