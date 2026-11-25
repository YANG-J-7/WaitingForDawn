// 视觉外延使用与湖水共用的岸线场，防止北侧草地被开放岸线误判为湖。
float extended_water_coverage(vec4 field, vec2 point, vec2 world_size, float north_coast_x) {
	float distance = (field.b * 65280.0 + field.a * 255.0) / 65535.0 * 1024.0 - 512.0;
	if (point.y < 0.0) {
		distance = abs(distance) * sign(point.x - north_coast_x);
	}
	return point.x > world_size.x ? 1.0 : smoothstep(-70.0, -35.0, distance);
}
