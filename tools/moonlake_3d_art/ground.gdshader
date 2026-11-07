shader_type spatial;

varying vec3 world_position;
varying vec3 world_normal;
varying vec3 ground_tint;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	ground_tint = COLOR.rgb;
}

float hash21(vec2 cell) {
	vec3 mixed = fract(vec3(cell.xyx) * 0.1031);
	mixed += dot(mixed, mixed.yzx + 33.33);
	return fract((mixed.x + mixed.y) * mixed.z);
}

float grain(vec2 point) {
	vec2 cell = floor(point);
	vec2 weight = fract(point);
	weight = weight * weight * (3.0 - 2.0 * weight);
	return mix(mix(hash21(cell), hash21(cell + vec2(1, 0)), weight.x),
		mix(hash21(cell + vec2(0, 1)), hash21(cell + vec2(1)), weight.x), weight.y);
}

void fragment() {
	vec2 ground = world_position.xz;
	float broad = grain(ground * 0.53);
	float detail = grain(ground * 4.2);
	float fine = grain(ground * 19.0) - 0.5;
	float facing_up = smoothstep(0.28, 0.9, world_normal.y);
	float grass = step(0.03, ground_tint.g - ground_tint.b) * step(ground_tint.r, ground_tint.g);
	float stone = max(1.0 - facing_up, step(ground_tint.g + 0.008, ground_tint.b));

	vec3 plant = mix(vec3(0.20, 0.34, 0.30), vec3(0.35, 0.49, 0.36), broad);
	plant += (detail - 0.5) * vec3(0.11, 0.13, 0.06) + fine * 0.045;
	vec3 soil = ground_tint * (0.72 + 0.22 * broad + 0.19 * detail + 0.075 * fine);
	vec2 cliff_uv = vec2(ground.x + ground.y * 0.63, world_position.y * 1.55 + ground.y * 0.14);
	float fracture = grain(cliff_uv * vec2(2.6, 7.0));
	float layers = grain(cliff_uv * vec2(0.65, 4.1));
	vec3 rock = mix(vec3(0.25, 0.30, 0.37), vec3(0.43, 0.49, 0.54),
		clamp(0.2 + 0.5 * layers + 0.35 * fracture, 0.0, 1.0));
	rock *= 0.86 + 0.14 * facing_up;
	ALBEDO = mix(mix(soil, plant, grass), rock, stone);
	ROUGHNESS = 0.91;
	SPECULAR = 0.22;
}
