shader_type spatial;

uniform sampler2D coast_distance : filter_linear, repeat_disable;
uniform sampler2D water_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 grid_size;
uniform float coast_range;
uniform float motion_time = 0.0;
uniform float detail_strength = 1.0;

varying vec2 lake_position;
varying float exterior;

void vertex() {
	lake_position = VERTEX.xz;
	exterior = 1.0 - COLOR.r;
}

void fragment() {
	vec2 p = lake_position;
	float outside = length(p - clamp(p, vec2(0.0), grid_size));
	if (exterior > 0.5 && outside <= 0.0) {
		discard;
	}
	vec2 ripple_shift = vec2(sin(p.y * 2.55), cos(p.x * 1.86 + p.y * 0.52)) * 0.13;
	float coast = (texture(coast_distance, (p + ripple_shift) / grid_size).r - 0.5) * coast_range;
	// 水面向逻辑水域内收，露出的窄带仍按水域处理。
	float edge = coast - 0.29;
	if (edge < 0.0) {
		discard;
	}
	float shallow = 1.0 - smoothstep(0.0, 4.4, edge);
	float time = motion_time;
	vec3 ripples = texture(water_texture, p * 0.096 + vec2(time * 0.007, time * -0.004)).rgb;
	vec3 cross_wave = texture(water_texture, p.yx * 0.064 + vec2(time * -0.005, time * 0.008)).rgb;
	float texture_wave = dot(mix(ripples, cross_wave, 0.37), vec3(0.25, 0.51, 0.24));
	float swell = sin(p.x * 0.43 + p.y * 1.22 + sin(p.y * 0.49 - p.x * 0.22) * 2.1 - time * 0.73);
	float lapping = sin(p.x * 1.2 - p.y * 1.5 + time * 0.91);
	float foam = (1.0 - smoothstep(0.025, 0.16, abs(edge - 0.18 - lapping * 0.075)))
		* smoothstep(-0.61, 0.69, swell);
	vec3 water = mix(vec3(0.048, 0.14, 0.235), vec3(0.12, 0.34, 0.36), shallow);
	water += (texture_wave - 0.40) * vec3(0.15, 0.25, 0.30);
	water += smoothstep(0.64, 1.0, swell) * vec3(0.013, 0.028, 0.038) * detail_strength;
	ALBEDO = mix(water, vec3(0.36, 0.53, 0.54), foam * 0.54);
	if (exterior > 0.5) {
		ALBEDO = mix(ALBEDO, vec3(0.012, 0.022, 0.035), smoothstep(1.0, 39.0, outside));
	}
	NORMAL = normalize(mat3(VIEW_MATRIX) * vec3(swell * 0.035 * detail_strength, 1.0, lapping * 0.027 * detail_strength));
	ROUGHNESS = mix(0.54, 0.73, shallow);
	SPECULAR = 0.34;
}
