shader_type canvas_item;
render_mode unshaded;
#include "res://src/gameplay/art/map_water_coverage.gdshaderinc"
uniform vec4 shade : source_color = vec4(0.023, 0.059, 0.091, 0.21);

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
uniform vec2 key_position;
uniform float dawn_weight;
uniform float ground_depth;
instance uniform vec3 cast_shape;
instance uniform float cast_opacity = 1.0;
varying vec2 map_point;

void vertex() {
	vec2 root = MODEL_MATRIX[3].xy;
	vec2 away = root - key_position;
	// 月光保留斜俯视的投影纵深，晨光逐渐使用实际地面方向。
	away.y = mix(max(away.y, ground_depth), away.y, dawn_weight);
	vec2 direction = length(away) > 0.001 ? normalize(away) : vec2(0.0, 1.0);
	vec2 across = vec2(direction.y, -direction.x * 0.60);
	float reach = cast_shape.x * mix(1.02, 0.68, dawn_weight);
	float far_end = 1.0 - step(0.0, VERTEX.y);
	float across_offset = mix(cast_shape.y, cast_shape.z, step(0.0, VERTEX.x));
	VERTEX = direction * reach * far_end + across * across_offset;
	map_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

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

void fragment() {
	float ground = receiver_at(map_point);
	if (ground <= 0.0) {
		discard;
	}
	vec2 d = TEXTURE_PIXEL_SIZE * 13.0;
	float a = texture(TEXTURE, UV).a * 0.40;
	a += texture(TEXTURE, UV + vec2(d.x, 0.0)).a * 0.15;
	a += texture(TEXTURE, UV - vec2(d.x, 0.0)).a * 0.15;
	a += texture(TEXTURE, UV + vec2(0.0, d.y)).a * 0.15;
	a += texture(TEXTURE, UV - vec2(0.0, d.y)).a * 0.15;
	float falloff = mix(0.34, 1.0, smoothstep(0.02, 0.53, UV.y));
	COLOR = vec4(shade.rgb, shade.a * a * falloff * ground * cast_opacity);
}
