shader_type spatial;

uniform sampler2D wet_cells : filter_nearest, repeat_disable;
uniform vec2 grid_size;
uniform float motion_time = 0.0;
uniform float detail_strength = 1.0;
varying vec2 lake_position;

void vertex() {
	lake_position = VERTEX.xz;
}

float wet(vec2 cell) {
	// 裁切边缘延续湖面，避免把样区边界画成岸线。
	vec2 uv = (clamp(cell, vec2(0), grid_size - vec2(1)) + vec2(0.5)) / grid_size;
	return texture(wet_cells, uv).r;
}

void fragment() {
	vec2 cell = floor(lake_position);
	vec2 local = fract(lake_position);
	float shore_distance = min(
		min(local.x + wet(cell - vec2(1, 0)), 1.0 - local.x + wet(cell + vec2(1, 0))),
		min(local.y + wet(cell - vec2(0, 1)), 1.0 - local.y + wet(cell + vec2(0, 1)))
	);
	float shore = 1.0 - smoothstep(0.05, 0.85, shore_distance);
	float wave_a = sin(dot(lake_position, vec2(4.2, 8.2)) - motion_time * 1.65);
	float wave_b = sin(dot(lake_position, vec2(-7.8, 3.6)) + motion_time * 0.86);
	float wave_c = sin(dot(lake_position, vec2(1.4, 4.5)) + motion_time * 0.72);
	float pixel_span = max(length(dFdx(lake_position)), length(dFdy(lake_position)));
	float wave_detail = (1.0 - smoothstep(0.055, 0.145, pixel_span)) * detail_strength;
	float ribbon = sin(dot(lake_position, vec2(1.3, 7.4)) + 0.72 * wave_b - motion_time * 1.25);
	float crest = smoothstep(0.86, 0.99, ribbon) * smoothstep(-0.52, 0.74, wave_c) * wave_detail;
	float foam = (1.0 - smoothstep(0.025, 0.09, abs(shore_distance - 0.09 - 0.033 * wave_c)));
	foam *= smoothstep(-0.2, 0.9, wave_b);
	vec3 water = mix(vec3(0.078, 0.225, 0.33), vec3(0.19, 0.40, 0.43), shore * 0.83);
	water += crest * vec3(0.039, 0.061, 0.072);
	water = mix(water, vec3(0.45, 0.62, 0.64), foam * 0.44);
	ALBEDO = water;
	NORMAL = normalize(mat3(VIEW_MATRIX) * vec3(wave_a * 0.038 * wave_detail, 1.0, wave_b * 0.042 * wave_detail));
	ROUGHNESS = mix(0.40 - 0.11 * wave_detail, 0.46, shore);
	SPECULAR = 0.52;
}
