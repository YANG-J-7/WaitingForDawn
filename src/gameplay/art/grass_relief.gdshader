shader_type canvas_item;
render_mode unshaded;

// 岩石与坡脚来自现有构图底稿；草地像素只替换地表材质。
uniform sampler2D relief_source : filter_linear, repeat_disable;
uniform sampler2D macro_source : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(2880.0, 1620.0);
uniform float detail_contrast : hint_range(0.0, 1.0) = 0.62;
uniform bool clear_left_plain_rocks = true;
uniform vec2 left_plain_cleanup_polygon[22];
uniform float plain_grass_light = 0.88;
varying vec2 ground_position;

void vertex() {
	ground_position = VERTEX;
}

float rock_mask(vec3 sample_color) {
	return smoothstep(0.0, 0.035, sample_color.b - sample_color.g);
}

bool in_left_plain(vec2 position) {
	bool inside = false;
	for (int i = 0; i < 22; i++) {
		vec2 a = left_plain_cleanup_polygon[i];
		vec2 b = left_plain_cleanup_polygon[(i + 1) % 22];
		if ((a.y > position.y) != (b.y > position.y)) {
			float crossing_x = a.x + (position.y - a.y) * (b.x - a.x) / (b.y - a.y);
			if (position.x < crossing_x) {
				inside = !inside;
			}
		}
	}
	return inside;
}

void fragment() {
	vec4 grass = texture(TEXTURE, UV);
	// 连续世界坐标取样，避免高清岩面遮罩被重新量化为2世界像素方块。
	vec2 uv = ground_position / map_size;
	vec3 base = texture(relief_source, uv).rgb;
	vec2 rim = vec2(6.0) / map_size;
	float rock = rock_mask(base);
	rock = max(rock, rock_mask(texture(relief_source, uv + vec2(rim.x, 0.0)).rgb));
	rock = max(rock, rock_mask(texture(relief_source, uv - vec2(rim.x, 0.0)).rgb));
	rock = max(rock, rock_mask(texture(relief_source, uv + vec2(0.0, rim.y)).rgb));
	rock = max(rock, rock_mask(texture(relief_source, uv - vec2(0.0, rim.y)).rgb));
	// 沿用同一草地图集，不生成新地形；只在选定平原取消装饰石头的透出。
	bool cleanup_plain = clear_left_plain_rocks && in_left_plain(ground_position);
	if (cleanup_plain) {
		rock = 0.0;
	}
	vec2 spread = vec2(40.0) / map_size;
	vec3 macro = texture(macro_source, uv).rgb;
	macro += texture(macro_source, uv + vec2(spread.x, 0.0)).rgb;
	macro += texture(macro_source, uv - vec2(spread.x, 0.0)).rgb;
	macro += texture(macro_source, uv + vec2(0.0, spread.y)).rgb;
	macro += texture(macro_source, uv - vec2(0.0, spread.y)).rgb;
	macro /= 5.0;
	float relief_light = clamp(dot(macro, vec3(0.299, 0.587, 0.114)) / 0.26, 0.68, 1.20);
	// 所有平原草地共用同一基准亮度，不再按清理区域切换调色。
	// 仅岩面近邻保留坡脚明暗；清理区域不继承已移除石堆的残影。
	float relief_nearby = rock;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		vec2 offset = vec2(cos(angle), sin(angle)) * 40.0 / map_size;
		vec2 sample_position = ground_position + offset * map_size;
		if (!clear_left_plain_rocks || !in_left_plain(sample_position)) {
			relief_nearby = max(relief_nearby, rock_mask(texture(relief_source, uv + offset).rgb) * 0.65);
		}
	}
	float light = mix(plain_grass_light, relief_light, relief_nearby);
	// 只压低材质对比，不模糊草叶边缘；优先让建筑和单位成为视觉焦点。
	vec3 soil = texture(TEXTURE, vec2(0.0001)).rgb;
	vec3 surface = mix(soil, grass.rgb, detail_contrast);
	// 岩面边缘留下过渡空间，恢复原有明暗和高度轮廓。
	COLOR = vec4(surface * light, grass.a * (1.0 - rock));
}
