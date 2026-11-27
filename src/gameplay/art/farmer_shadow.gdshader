shader_type canvas_item;
render_mode unshaded;
#include "res://src/gameplay/art/map_shadow_receiver.gdshaderinc"

uniform vec4 frame_rect;
uniform vec4 shade : source_color;
uniform vec2 left_sole;
uniform vec2 right_sole;
varying vec2 world_point;
varying vec2 shadow_point;

void vertex() {
	shadow_point = VERTEX;
	world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float sole_contact(vec2 sole) {
	vec2 d = (shadow_point - sole - vec2(0.0, 0.3)) / vec2(3.8, 2.1);
	return 1.0 - smoothstep(0.28, 1.0, length(d));
}

void fragment() {
	vec2 texel = UV / TEXTURE_PIXEL_SIZE - frame_rect.xy;
	float cast = 0.0;
	if (all(greaterThanEqual(texel, vec2(1.5))) && all(lessThan(texel, frame_rect.zw - vec2(1.5)))) {
		vec2 step_uv = TEXTURE_PIXEL_SIZE * 1.25;
		cast = texture(TEXTURE, UV).a * 0.48;
		cast += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a * 0.13;
		cast += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a * 0.13;
		cast += texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a * 0.13;
		cast += texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a * 0.13;
	}
	float contact = max(sole_contact(left_sole), sole_contact(right_sole));
	COLOR = vec4(shade.rgb, max(cast * shade.a, contact * 0.53) * receiver_at(world_point));
}
