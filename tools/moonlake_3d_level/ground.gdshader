shader_type spatial;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_weights : filter_linear, repeat_disable;
uniform sampler2D coast_distance : filter_linear, repeat_disable;
uniform float coast_range;
uniform vec2 grid_size;
uniform vec2 town_center;
uniform bool exterior = false;
uniform bool scenic_terrace = false;

varying vec3 world_position;
varying vec3 world_normal;
varying float rock_face;
varying vec2 cliff_profile;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	rock_face = exterior ? 0.0 : COLOR.r;
	cliff_profile = UV;
}

float hash_cell(vec2 cell) {
	vec3 seed = fract(vec3(cell.xyx) * 0.1031);
	seed += dot(seed, seed.yzx + 33.33);
	return fract((seed.x + seed.y) * seed.z);
}

float grain(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash_cell(cell), hash_cell(cell + vec2(1, 0)), t.x),
		mix(hash_cell(cell + vec2(0, 1)), hash_cell(cell + vec2(1, 1)), t.x), t.y);
}

void fragment() {
	vec2 point = world_position.xz;
	float outside = length(point - clamp(point, vec2(0.0), grid_size));
	if (exterior) {
		vec2 ripple_shift = vec2(sin(point.y * 2.55), cos(point.x * 1.86 + point.y * 0.52)) * 0.13;
		float waterline = (texture(coast_distance, (point + ripple_shift) / grid_size).r - 0.5) * coast_range;
		if (outside <= 0.0 || waterline >= 0.29) {
			discard;
		}
	}
	vec2 drift = vec2(sin(point.y * 0.92 + sin(point.x * 1.3)), cos(point.x * 0.82 - point.y * 1.9));
	vec3 weights = texture(surface_weights, (point + drift * 0.24) / grid_size).rgb;
	if (scenic_terrace) {
		weights = vec3(0.0);
	}
	float broad = grain(point * 0.15) * 2.0 - 1.0;
	float patch = grain(point * 0.46 + vec2(31.3, -10.7));
	vec3 blades = texture(grass_texture, (point + drift * 0.19) / vec2(12.0, 9.0)).rgb;
	vec3 scrub = texture(grass_texture, point.yx / vec2(13.0, 9.75) + vec2(0.24, 0.51)).rgb;
	blades = mix(blades, scrub, smoothstep(0.14, 0.83, patch) * 0.60);
	float grass_detail = dot(blades, vec3(0.30, 0.54, 0.16));
	vec3 grass = mix(vec3(0.105, 0.18, 0.205), vec3(0.18, 0.265, 0.205), broad * 0.5 + 0.5);
	grass *= clamp(0.13 + grass_detail * 2.60, 0.45, 1.49);
	grass = mix(grass, vec3(0.24, 0.263, 0.19) * (0.35 + grass_detail * 1.59), smoothstep(0.46, 0.84, patch) * 0.56);

	vec3 soil_sample = texture(soil_texture, point * 0.245).rgb;
	float pebbles = dot(soil_sample, vec3(0.29, 0.52, 0.19));
	vec3 soil = vec3(0.38, 0.343, 0.277) * (0.71 + 1.03 * pebbles + 0.12 * broad);
	vec3 shore = mix(soil * 1.04, vec3(0.22, 0.30, 0.32), 0.46);
	float coast = smoothstep(0.19, 0.86, weights.b);
	float trail = smoothstep(0.19, 0.83, weights.g);
	float courtyard = 1.0 - smoothstep(1.25, 3.7, length((point - town_center) * vec2(0.90, 1.18)) + broad * 0.57);
	vec3 turf = mix(mix(grass, shore, coast), soil, max(trail, courtyard * 0.90));

	vec3 normal = normalize(world_normal);
	float up = smoothstep(0.27, 0.92, normal.y);
	vec2 stratum = vec2(point.x + point.y * 0.62, world_position.y * 1.35 + point.y * 0.13);
	vec2 rock_uv = mix(stratum * 0.20, point * 0.19, up) + vec2(broad, patch) * 0.22;
	vec3 shale = texture(rock_texture, rock_uv).rgb;
	vec3 rock = mix(shale * vec3(0.80, 0.85, 0.91), vec3(0.34, 0.40, 0.47), 0.54);
	float beds = sin(stratum.y * 5.2 + sin(stratum.x * 0.77) * 1.35);
	rock *= 0.77 + up * 0.22 + 0.09 * beds + 0.09 * broad;
	rock = mix(rock, grass * 1.08, smoothstep(0.45, 0.84, patch) * up * 0.52);
	float tread = smoothstep(0.42, 0.87, weights.r) * smoothstep(0.42, 0.87, weights.g);
	rock = mix(rock, vec3(0.50, 0.475, 0.41) * (0.82 + 0.53 * pebbles), tread * 0.75);
	float relief = 0.62 + 0.32 * smoothstep(0.0, 0.48, cliff_profile.x)
		+ 0.22 * smoothstep(0.58, 0.96, cliff_profile.x);
	rock *= mix(1.0, relief, cliff_profile.y);
	float exposed = max(smoothstep(0.22, 0.80, weights.r), step(0.01, rock_face));
	ALBEDO = mix(turf, rock, exposed) * mix(1.0, 0.82 + 0.18 * rock_face, step(0.01, rock_face));
	if (exterior) {
		float mist = smoothstep(0.0, 17.0, outside);
		ALBEDO = mix(ALBEDO, vec3(0.012, 0.022, 0.035), mist);
	}
	ROUGHNESS = mix(0.94, 0.75, exposed);
	SPECULAR = 0.23;
}
