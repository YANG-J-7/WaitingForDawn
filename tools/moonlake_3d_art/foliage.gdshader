shader_type spatial;

uniform float motion_time = 0.0;
varying vec3 foliage_color;
varying vec3 branch_point;

void vertex() {
	branch_point = VERTEX;
	foliage_color = COLOR.rgb;
	vec2 root = MODEL_MATRIX[3].xz;
	float bend = clamp(VERTEX.y / 3.0, 0.0, 1.0);
	float wind = sin(motion_time * 1.8 + dot(root, vec2(0.69, 0.37)));
	VERTEX.x += 0.13 * bend * bend * wind;
	VERTEX.z += 0.06 * bend * bend * sin(motion_time * 1.37 + root.x * 0.73);
}

void fragment() {
	float needles = sin(branch_point.y * 73.0 + sin(branch_point.x * 39.0) * 1.4);
	ALBEDO = foliage_color * (1.0 + 0.045 * needles);
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
