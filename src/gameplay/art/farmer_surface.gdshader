shader_type canvas_item;

uniform bool key_enabled = false;
uniform float frame_column;
uniform bool mirror;
uniform vec2 key_direction;
uniform vec3 key_color;
uniform float key_strength;
uniform float dawn_weight;

void fragment() {
	vec4 body = COLOR;
	if (key_enabled) {
		vec2 p = vec2(UV.x * 4.0 - frame_column, fract(UV.y * 2.0));
		float side = clamp((p.x - 0.5) * 4.0, -1.0, 1.0) * (mirror ? -1.0 : 1.0);
		float top_band = (p.y - 0.29) * 7.0;
		float up = 0.22 + 0.42 * exp(-top_band * top_band);
		float face_light = clamp(0.25 + side * key_direction.x * 0.69 - up * key_direction.y, 0.0, 1.0);
		vec3 floor_color = mix(vec3(0.61, 0.66, 0.76), vec3(0.72, 0.72, 0.74), dawn_weight);
		body.rgb *= floor_color + key_color * (face_light * key_strength * 0.89);
	}
	COLOR = body;
}
