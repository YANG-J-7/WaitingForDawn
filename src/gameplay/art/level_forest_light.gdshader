shader_type canvas_item;

uniform vec2 key_position;
uniform vec3 key_color;
uniform float key_energy;
uniform float key_radius;
uniform float moon_weight;
instance uniform vec2 crown_center;
instance uniform vec2 crown_radius;
varying vec2 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 surface = clamp((world_point - crown_center) / crown_radius, vec2(-1.2), vec2(1.2));
	vec2 to_light = key_position - crown_center;
	vec2 direction = normalize(to_light + vec2(0.0, -60.0));
	float facing = smoothstep(-0.42, 0.88, dot(surface, direction));
	float spill = 1.0 - smoothstep(0.18, 1.0, length(to_light) / key_radius);
	float exposure = clamp(key_energy * spill * 2.45, 0.0, 1.0);
	float crown = 1.0 - smoothstep(0.71, 0.97, UV.y);
	float gain = mix(0.65, 0.73, crown) + facing * exposure * mix(0.10, 0.23, crown);
	vec3 tint = mix(vec3(0.87, 0.99, 1.01), mix(vec3(1.0), key_color, 0.34), facing * exposure);
	float warm_light = smoothstep(0.15, 0.48, key_color.r - key_color.b);
	float sunlit_leaves = warm_light * facing * exposure * crown;
	gain += sunlit_leaves * 0.22;
	tint *= mix(vec3(1.0), vec3(1.19, 1.06, 0.86), sunlit_leaves);
	float leaf_detail = smoothstep(0.05, 0.46, dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722)));
	gain *= mix(1.0, mix(0.67, 0.82, facing * exposure), moon_weight);
	COLOR.rgb *= gain * tint;
	COLOR.rgb += vec3(0.22, 0.125, 0.025) * sunlit_leaves * mix(0.45, 1.0, leaf_detail);
	float blades = pow(0.5 + 0.5 * sin(world_point.x * 0.63 + sin(world_point.x * 0.27)), 2.0);
	COLOR.a *= 1.0 - smoothstep(0.942, 0.992, UV.y) * mix(0.54, 0.95, blades);
}
