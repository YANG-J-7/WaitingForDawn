shader_type canvas_item;

uniform sampler2D arrival_mask : filter_linear, repeat_disable;
uniform float dawn_progress = 0.0;

void fragment() {
	// 红通道控制见光先后，绿通道压低崖壁背光面的响应。
	if (dawn_progress > 0.0) {
		vec2 arrival = texture(arrival_mask, UV).rg;
		float light = smoothstep(arrival.r, arrival.r + 0.17, dawn_progress) * arrival.g;
		light *= mix(1.0, 0.63, smoothstep(0.68, 1.0, dawn_progress));
		COLOR.rgb += light * (COLOR.rgb * vec3(0.47, 0.24, 0.03) + vec3(0.11, 0.048, 0.0));
	}
}
