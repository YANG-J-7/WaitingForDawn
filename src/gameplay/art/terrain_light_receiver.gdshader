shader_type canvas_item;

// 受光遮罩的红通道表示岩壁，绿通道表示水域，其余为普通地面。
uniform sampler2D surface_mask : filter_linear, repeat_disable;
uniform vec3 surface_response = vec3(1.0, 0.72, 0.38);
uniform vec2 uv_axis_x;
uniform vec2 uv_axis_y;
uniform vec2 uv_origin;
uniform vec2 surface_world_size = vec2(1.0);
uniform vec2 shadow_light_uv;
uniform float terrain_shadow_opacity = 0.0;
uniform float terrain_shadow_reach = 96.0;
varying vec2 surface_uv;
varying vec2 surface_weights;

void vertex() {
	vec2 world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	surface_uv = uv_origin + uv_axis_x * world_point.x + uv_axis_y * world_point.y;
}

void fragment() {
	surface_weights = texture(surface_mask, surface_uv).rg;
	if (terrain_shadow_opacity > 0.0 && surface_weights.r < 0.85) {
		// 只取朝向光源的一侧，岩壁的背光暗部随光源转移。
		vec2 to_light = (shadow_light_uv-surface_uv)*surface_world_size;
		to_light.y = min(to_light.y,-surface_world_size.y*0.18);
		vec2 step_uv = normalize(to_light)*terrain_shadow_reach/surface_world_size;
		float near_rock = texture(surface_mask,surface_uv+step_uv*0.25).r;
		float middle_rock = texture(surface_mask,surface_uv+step_uv*0.55).r;
		float far_rock = texture(surface_mask,surface_uv+step_uv).r;
		float blocker = max(near_rock,max(middle_rock*0.72,far_rock*0.42));
		float receiver = (1.0-smoothstep(0.15,0.85,surface_weights.r))*mix(1.0,0.35,surface_weights.g);
		COLOR.rgb *= 1.0-terrain_shadow_opacity*receiver*smoothstep(0.15,0.85,blocker);
	}
}

void light() {
	float land_response = mix(surface_response.x, surface_response.y, surface_weights.r);
	float response = mix(land_response, surface_response.z, surface_weights.g);
	// 保留原图颜色和灯光衰减，只改变不同地表接收的局部光强度。
	LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY * response, LIGHT_COLOR.a);
}
