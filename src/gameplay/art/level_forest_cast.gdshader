shader_type canvas_item;
render_mode unshaded;
#include "res://src/gameplay/art/map_shadow_receiver.gdshaderinc"
uniform vec4 shade : source_color = vec4(0.023, 0.059, 0.091, 0.21);

uniform vec2 key_position;
uniform float dawn_weight;
uniform float ground_depth;
instance uniform vec3 cast_shape;
instance uniform float cast_opacity = 1.0;
instance uniform float cast_root_y = 1.0;
varying vec2 map_point;

void vertex() {
	vec2 root = MODEL_MATRIX[3].xy;
	vec2 away = root - key_position;
	// 月光保留斜俯视的投影纵深，晨光逐渐使用实际地面方向。
	away.y = mix(max(away.y, ground_depth), away.y, dawn_weight);
	vec2 direction = length(away) > 0.001 ? normalize(away) : vec2(0.0, 1.0);
	vec2 across = vec2(direction.y, -direction.x * 0.60);
	float reach = cast_shape.x * mix(1.02, 0.68, dawn_weight);
	// 树脚所在纹理行对应地面原点，根尖仍可延伸到原点另一侧。
	float along = 1.0 - step(0.0, VERTEX.y) / cast_root_y;
	float across_offset = mix(cast_shape.y, cast_shape.z, step(0.0, VERTEX.x));
	VERTEX = direction * reach * along + across * across_offset;
	map_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
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
