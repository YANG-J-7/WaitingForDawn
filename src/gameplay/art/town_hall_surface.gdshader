shader_type canvas_item;
render_mode unshaded;

uniform sampler2D face_mask : filter_linear, repeat_disable;
uniform sampler2D hearth_mask : filter_linear, repeat_disable;
uniform vec2 key_direction;
uniform vec3 key_color;
uniform float key_energy;
uniform float dawn_weight;
uniform float animation_time;
uniform bool lighting_enabled = true;
uniform bool hearth_lit = true;

void fragment() {
	vec4 body = texture(TEXTURE, UV);
	vec3 surface = body.rgb;
	if (lighting_enabled) {
		vec3 faces = texture(face_mask, UV).rgb;
		vec3 hearth = texture(hearth_mask, UV).rgb;
		float value = dot(body.rgb, vec3(0.2126, 0.7152, 0.0722));
		// 红通道记录瓦面朝向，绿蓝通道分别标出东西檐和瓦脊的亮边。
		float orient = clamp((faces.r * 2.0 - 1.0) * key_direction.x * 1.21, -1.0, 1.0);
		vec3 terracotta = vec3(0.15, 0.092, 0.123) + value * vec3(0.28, 0.18, 0.20);
		vec3 base = mix(body.rgb, terracotta, hearth.r);
		float energy = smoothstep(0.0, 0.47, key_energy) * 0.84 + 0.16 * dawn_weight;
		float direct = energy * max(0.22 + 0.64 * orient, 0.0);
		float back = smoothstep(0.04, 0.80, -orient);
		vec3 ambient = mix(vec3(0.77, 0.80, 0.89), vec3(0.83, 0.84, 0.87), dawn_weight);
		vec3 tint = mix(key_color * vec3(0.85, 0.95, 1.0), vec3(1.0, 0.70, 0.41), dawn_weight);
		surface = base * ambient * (1.0 - 0.26 * back * energy);
		surface += (base * 0.69 + vec3(0.074)) * tint * direct;
		float west = smoothstep(0.03, 0.83, -key_direction.x);
		float east = smoothstep(0.03, 0.83, key_direction.x);
		float detail = 0.34 + 0.66 * smoothstep(0.06, 0.57, value);
		surface += (faces.g * west + faces.b * east) * energy * detail * tint * (0.38 + 0.03 * dawn_weight);
		if (hearth_lit) {
			float phase = UV.x * 23.0 + UV.y * 17.0;
			float flicker = 0.85 + 0.10 * sin(animation_time * 7.6 + phase)
				+ 0.05 * sin(animation_time * 11.7 - phase);
			float glow = hearth.b * flicker;
			surface += glow * base * vec3(0.16, 0.10, 0.026) * (1.0 - dawn_weight * 0.39);
			surface = surface * (1.0 - hearth.g * 0.88)
				+ body.rgb * hearth.g * (0.84 + 0.17 * glow - dawn_weight * 0.06);
		}
	}
	COLOR = vec4(surface, body.a);
}
