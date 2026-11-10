shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D tuft_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float motion_time = 0.0;
varying vec2 atlas_origin;

void vertex() {
	float variant = floor(INSTANCE_CUSTOM.r * 4.0);
	atlas_origin = vec2(mod(variant, 2.0), floor(variant / 2.0)) * 0.5;
	vec2 root = MODEL_MATRIX[3].xz;
	float phase = motion_time * 2.0 - dot(root, vec2(0.58, 0.23));
	float gust = 0.68 + 0.32 * sin(motion_time * 0.49 - dot(root, vec2(0.17, 0.065)));
	// 根部位移为零，叶尖追随跨区块传播的风。
	float height = clamp(VERTEX.y / 0.40, 0.0, 1.0);
	float bend = height * height * sin(phase) * gust;
	VERTEX.x += bend * 0.26;
	VERTEX.z += bend * 0.07;
	VERTEX.y -= abs(bend) * 0.04;
	VERTEX *= INSTANCE_CUSTOM.g;
}

void fragment() {
	vec4 blade = texture(tuft_atlas, atlas_origin + UV * 0.5);
	if (blade.a < 0.36) {
		discard;
	}
	ALBEDO = blade.rgb * vec3(0.78, 0.86, 0.74);
	ROUGHNESS = 1.0;
}
