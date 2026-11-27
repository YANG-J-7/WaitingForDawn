shader_type canvas_item;
render_mode unshaded;
#include "res://src/gameplay/art/map_shadow_receiver.gdshaderinc"
uniform vec4 shade : source_color;
uniform int edge_count;
uniform vec4 edges[128];
uniform float dawn_weight;
varying vec2 map_point;
varying vec2 local_point;

void vertex() {
	local_point = VERTEX;
	map_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}void fragment() {
	float ground = receiver_at(map_point);
	if (ground <= 0.0) {
		discard;
	}
	float projection = 10000.0;
	float footprint = 10000.0;
	float solid = -10000.0;
	for (int i = 0; i < 128; i++) {
		if (i >= edge_count) {
			break;
		}
		vec4 edge = edges[i];
		solid = max(solid, dot(edge.xy, local_point) + edge.z);
		if (edge.w > 1.5) {
			footprint = min(footprint, solid);
			solid = -10000.0;
		} else if (edge.w > 0.5) {
			projection = min(projection, solid);
			solid = -10000.0;
		}
	}
	float distance_from_wall = smoothstep(4.0, 155.0, footprint);
	float penumbra = mix(2.3, 14.0, distance_from_wall);
	float cast_alpha = (1.0 - smoothstep(-penumbra * 0.57, penumbra, projection)) * shade.a;
	cast_alpha *= mix(1.0, 0.55, distance_from_wall);
	float contact_alpha = (1.0 - smoothstep(-4.0, 6.8, footprint)) * mix(0.25, 0.21, dawn_weight);
	COLOR = vec4(shade.rgb, max(contact_alpha, cast_alpha) * ground);
}
