shader_type canvas_item;

// 受光遮罩的红通道表示岩壁，绿通道表示水域，其余为普通地面。
uniform sampler2D surface_mask : filter_linear, repeat_disable;
uniform vec3 surface_response = vec3(1.0, 0.72, 0.38);
uniform vec2 uv_axis_x;
uniform vec2 uv_axis_y;
uniform vec2 uv_origin;
varying vec2 surface_uv;
varying vec2 surface_weights;

void vertex() {
	vec2 world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	surface_uv = uv_origin + uv_axis_x * world_point.x + uv_axis_y * world_point.y;
}

void fragment() {
	surface_weights = texture(surface_mask, surface_uv).rg;
}

void light() {
	float land_response = mix(surface_response.x, surface_response.y, surface_weights.r);
	float response = mix(land_response, surface_response.z, surface_weights.g);
	// 保留原图颜色和灯光衰减，只改变不同地表接收的局部光强度。
	LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY * response, LIGHT_COLOR.a);
}
