#include "res://src/gameplay/art/map_water_coverage.gdshaderinc"
uniform vec4 visual_rect;
uniform bool has_water = false;
uniform sampler2D water_control : filter_linear, repeat_disable;
uniform vec2 world_size;
uniform bool extend_boundary = false;
uniform sampler2D coast_field : filter_linear, repeat_disable;
uniform vec4 field_rect;
uniform float north_coast_x;
uniform bool has_mountain = false;
uniform sampler2D mountain_art : source_color, filter_linear, repeat_disable;
uniform vec4 mountain_rect;

float receiver_at(vec2 point) {
	vec2 scene_uv = (point - visual_rect.xy) / visual_rect.zw;
	if (any(lessThan(scene_uv, vec2(0.0))) || any(greaterThan(scene_uv, vec2(1.0)))) {
		return 0.0;
	}
	float land = 1.0;
	if (has_water) {
		float coverage;
		if (extend_boundary && (point.y < 0.0 || point.x > world_size.x)) {
			vec4 field = texture(coast_field, (point - field_rect.xy) / field_rect.zw);
			coverage = extended_water_coverage(field, point, world_size, north_coast_x);
		} else {
			coverage = texture(water_control, point / world_size).r;
		}
		land = 1.0 - coverage;
	}
	if (has_mountain) {
		vec2 uv = (point - mountain_rect.xy) / mountain_rect.zw;
		if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
			vec4 rock_art = texture(mountain_art, uv);
			// 草坡与平台完整接影，蓝岩的墙面减弱投影，沿原画像素软过渡。
			float rock = (rock_art.b - rock_art.g) / max(rock_art.b, 0.08);
			float terrain = 1.0 - 0.85 * smoothstep(0.05, 0.30, rock);
			land = mix(land, terrain, rock_art.a);
		}
	}
	return land;
}

