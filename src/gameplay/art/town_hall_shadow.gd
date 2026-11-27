extends Polygon2D
## 将建筑体块从地图主光投到固定墙基，合并为一道地表软影。

const SHADER = preload("res://src/gameplay/art/town_hall_shadow.gdshader")
const EDGE_LIMIT := 128

var _surface := ShaderMaterial.new()
var _footprint_edges := PackedVector4Array()
var _footprint_bounds := Rect2()
var _solids: Array[PackedVector3Array] = []
var _height := 0.0
var _slope: Vector3
var _last_light := {}


func configure(appearance: TownHallAppearance, units_per_pixel: float) -> void:
	name = "WatchHallShadow"
	_surface.shader = SHADER
	material = _surface
	hide()
	_slope = appearance.shadow_slope
	for footprint in appearance.footprints:
		var ground := PackedVector2Array()
		for point in footprint:
			var local_point := (point - appearance.origin) * units_per_pixel
			ground.append(local_point)
			_footprint_bounds = _footprint_bounds.expand(local_point)
		_append_edges(_footprint_edges, Geometry2D.convex_hull(ground), 2.0)
	for solid in appearance.solids:
		var local_solid := PackedVector3Array()
		for point in solid:
			var ground := (Vector2(point.x, point.y) - appearance.origin) * units_per_pixel
			local_solid.append(Vector3(ground.x, ground.y, point.z * units_per_pixel))
			_height = maxf(_height, point.z * units_per_pixel)
		_solids.append(local_solid)


func update_light(sample: Dictionary) -> void:
	visible = not sample.is_empty()
	if sample.is_empty():
		_last_light.clear()
		return
	var position_from_root: Vector2 = sample.position - global_position
	var dawn: float = sample.dawn_weight
	var energy: float = sample.energy
	var lighting_state := {"offset": position_from_root, "dawn": dawn, "energy": energy}
	if lighting_state == _last_light:
		return
	_last_light = lighting_state
	var distance := position_from_root.length()
	var key := position_from_root.normalized()
	var slope := lerpf(_slope.x + _slope.y * absf(key.x), _slope.z, dawn)
	# 光源从北缘掠过时限制虚拟高度的下界，确保靠近地图边缘仍有有限投影。
	var light_height := maxf(distance / slope, _height + maxf(96.0, distance * 0.38))
	var edges := _footprint_edges.duplicate()
	var bounds := _footprint_bounds
	for solid in _solids:
		var points := PackedVector2Array()
		for point in solid:
			var foot := Vector2(point.x, point.y)
			var ground := foot + (foot - position_from_root) * point.z / (light_height - point.z)
			points.append(ground)
			bounds = bounds.expand(ground)
		_append_edges(edges, Geometry2D.convex_hull(points), 1.0)
	assert(edges.size() <= EDGE_LIMIT, "主城投影几何超出着色器容量")
	var edge_count := edges.size()
	edges.resize(EDGE_LIMIT)
	bounds = bounds.grow(20.0)
	polygon = PackedVector2Array([
		bounds.position, Vector2(bounds.end.x, bounds.position.y),
		bounds.end, Vector2(bounds.position.x, bounds.end.y),
	])
	_surface.set_shader_parameter("edge_count", edge_count)
	_surface.set_shader_parameter("edges", edges)
	_surface.set_shader_parameter("dawn_weight", dawn)
	var opacity := lerpf(0.53, 0.35, dawn) * smoothstep(0.0, 0.20, energy)
	_surface.set_shader_parameter("shade", Color(0.028, 0.048, 0.074, opacity))


func _append_edges(edges: PackedVector4Array, hull: PackedVector2Array, end_kind: float) -> void:
	var count := hull.size() - 1
	var center := Vector2.ZERO
	for index in count:
		center += hull[index] / float(count)
	for index in count:
		var a := hull[index]
		var tangent := (hull[index + 1] - a).normalized()
		var normal := Vector2(tangent.y, -tangent.x)
		if normal.dot(center - a) > 0.0:
			normal = -normal
		edges.append(Vector4(normal.x, normal.y, -normal.dot(a), end_kind if index == count - 1 else 0.0))
