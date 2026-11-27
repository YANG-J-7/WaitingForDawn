shader_type canvas_item;
render_mode unshaded;

uniform sampler2D flag_cloth : source_color, filter_linear, repeat_disable;
uniform vec4 flag_rect;
uniform vec2 fire_left_position;
uniform vec2 fire_right_position;
uniform vec2 key_direction;
uniform vec3 key_color;
uniform float key_strength;
uniform float dawn_weight;
uniform float animation_time;
uniform bool lighting_enabled = true;
uniform bool hearth_lit = true;

float flame_at(vec2 point, vec2 root) {
	vec2 delta = (point - root - vec2(0.0, -34.0)) / vec2(200.0, 200.0);
	return 1.0 - smoothstep(0.08, 1.0, length(delta));
}

void fragment() {
	vec4 body = texture(TEXTURE, UV);
	vec2 p = UV;
	vec2 point = p / TEXTURE_PIXEL_SIZE;
	vec2 flag = point - flag_rect.xy;
	flag.y -= (flag.x / flag_rect.z - 0.5) * 7.5;
	flag.x -= smoothstep(0.12, 1.0, flag.y / flag_rect.w) * sin(animation_time * 4.0) * 7.0;
	vec2 flag_uv = flag / flag_rect.zw;
	if (all(greaterThanEqual(flag_uv, vec2(0.0))) && all(lessThanEqual(flag_uv, vec2(1.0)))) {
		vec4 cloth = texture(flag_cloth, flag_uv);
		body.rgb = mix(body.rgb, cloth.rgb, cloth.a);
	}

	vec3 surface = body.rgb;
	if (lighting_enabled) {
		// 屋脊、两面檐口、山墙和右侧墙的方向依据一级守夜厅原图定位。
		float eave = 0.567 - max(0.0, p.x - 0.641) * 0.34;
		float roof = 1.0 - smoothstep(eave - 0.020, eave + 0.015, p.y);
		float near_slope = smoothstep(-0.014, 0.020, p.x - (0.34 + (p.y - 0.19) * 0.79));
		float side = smoothstep(0.625, 0.659, p.x);
		float roof_normal = mix(-0.86, 0.64, near_slope);
		float wall_normal = mix(-0.86, 1.0, side);
		float face = mix(wall_normal, roof_normal, roof);
		float orient = clamp(key_direction.x * face * 1.2, -1.0, 1.0);
		float exposure = clamp(key_strength * (1.40 + 0.70 * dawn_weight), 0.0, 1.0);
		float direct = max(exposure, dawn_weight * 0.61) * clamp(0.32 + orient * 0.72, 0.0, 1.0);
		float dark = exposure * max(0.0, -orient);

		// 衰减背光侧原画中的冷色高光，使月光换向时屋檐能清楚换边。
		float cool = smoothstep(0.055, 0.25, body.b - body.r) * smoothstep(0.33, 0.66, body.b);
		vec3 neutral = mix(body.rgb, vec3(dot(body.rgb, vec3(0.28, 0.49, 0.23))), cool * dark * 0.56);
		neutral = mix(neutral, vec3(neutral.r * 1.06, neutral.g * 0.92, neutral.b * 0.75), dawn_weight * cool * 0.67);
		vec3 ambient = mix(vec3(0.68, 0.74, 0.87), vec3(0.79, 0.80, 0.85), dawn_weight);
		surface = neutral * ambient * (1.0 - dark * 0.34 - cool * dark * 0.23);
		vec3 tinted_key = mix(key_color * vec3(0.78, 0.94, 1.0), vec3(1.0, 0.71, 0.44), dawn_weight);
		float highlight = smoothstep(0.18, 0.72, max(body.r, body.b));
		surface += (body.rgb * mix(0.77, 0.98, dawn_weight) + vec3(0.09 + 0.09 * dawn_weight) * highlight) * tinted_key * direct;
		// 右檐的暖边随晨光起来，红瓦的暗纹和木梁分缝仍可辨。
		float right_eave = roof * near_slope * smoothstep(eave - 0.066, eave - 0.012, p.y);
		surface += tinted_key * right_eave * direct * (0.025 + 0.11 * dawn_weight);
		// 原画左檐绘有蓝白高光。沿斜檐定位，按西侧直射光逐渐恢复亮边。
		vec2 eave_start = vec2(10.0, 509.0);
		vec2 eave_axis = vec2(325.0, 203.0) - eave_start;
		float along_eave = clamp(dot(point - eave_start, eave_axis) / dot(eave_axis, eave_axis), 0.0, 1.0);
		float eave_distance = length(point - eave_start - eave_axis * along_eave);
		float left_tiles = 1.0 - smoothstep(18.0, 37.0, eave_distance);
		float left_cap = 1.0 - smoothstep(0.78, 1.13, length((point - vec2(345.0, 172.0)) / vec2(51.0, 44.0)));
		float west_light = smoothstep(0.02, 0.85, -key_direction.x)
			* smoothstep(0.02, 0.35, exposure) * (1.0 - dawn_weight);
		float tile_value = dot(body.rgb, vec3(0.27, 0.55, 0.18));
		vec3 brick_in_shade = mix(vec3(0.076, 0.070, 0.099), vec3(0.318, 0.228, 0.269), pow(tile_value, 1.18));
		brick_in_shade *= mix(vec3(0.91, 0.96, 1.08), vec3(1.05, 1.02, 0.99), dawn_weight);
		vec3 cap_in_shade = mix(vec3(0.055, 0.069, 0.100), vec3(0.305, 0.326, 0.382), tile_value);
		float fade_baked = 1.0 - west_light * 0.89;
		surface = mix(surface, brick_in_shade, left_tiles * fade_baked);
		surface = mix(surface, cap_in_shade, left_cap * (1.0 - left_tiles) * fade_baked * 0.73);
		if (hearth_lit) {
			float window = smoothstep(0.68, 0.93, body.r) * smoothstep(0.38, 0.68, body.g);
			window *= (1.0 - smoothstep(0.16, 0.38, body.b));
			window *= smoothstep(0.55, 0.59, p.y) * (1.0 - smoothstep(0.74, 0.77, p.y));
			float shimmer = 0.99 + sin(animation_time * 2.1 + p.x * 8.0) * 0.035;
			surface = mix(surface, body.rgb * shimmer, window * mix(1.0, 0.78, dawn_weight));
			float glow = flame_at(point, fire_left_position) * (0.89 + 0.11 * sin(animation_time * 10.3));
			glow += flame_at(point, fire_right_position) * (0.86 + 0.14 * sin(animation_time * 8.2 + 2.1));
			surface += (body.rgb * vec3(0.57, 0.30, 0.11) + vec3(0.070, 0.024, 0.004))
				* glow * mix(1.0, 0.41, dawn_weight);
		}
	}
	COLOR = vec4(surface, body.a);
}
