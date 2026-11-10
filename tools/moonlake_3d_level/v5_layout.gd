extends RefCounted
## V5 灰盒的景观坐标，水平单位为一格。后山两级台面都在可玩区以北。

const LOWER_RIDGE := [
	Vector2(73.0, -4.2), Vector2(79.0, -2.7), Vector2(90.0, -1.5),
	Vector2(98.0, -2.0), Vector2(104.0, -3.5), Vector2(111.0, -3.2),
	Vector2(117.0, -1.6), Vector2(126.0, -1.0), Vector2(131.0, -1.8),
	Vector2(137.0, -3.4), Vector2(145.0, -3.0), Vector2(150.0, -1.4),
	Vector2(159.0, -0.7), Vector2(169.0, -0.9), Vector2(174.0, -2.4),
	Vector2(184.0, -2.6), Vector2(192.0, -3.6), Vector2(195.0, -5.7),
	Vector2(190.0, -8.4), Vector2(178.0, -10.8), Vector2(164.0, -12.0),
	Vector2(145.0, -11.7), Vector2(132.0, -11.0), Vector2(119.0, -10.3),
	Vector2(100.0, -9.4), Vector2(85.0, -7.6),
]
const UPPER_RIDGE := [
	Vector2(93.0, -6.8), Vector2(101.0, -6.3), Vector2(108.0, -4.9),
	Vector2(117.0, -4.2), Vector2(126.0, -4.8), Vector2(133.0, -6.0),
	Vector2(140.0, -6.1), Vector2(147.0, -4.7), Vector2(157.0, -3.0),
	Vector2(167.0, -3.3), Vector2(174.0, -4.1), Vector2(179.0, -5.4),
	Vector2(187.0, -6.4),
	Vector2(180.0, -8.8), Vector2(166.0, -10.1), Vector2(151.0, -10.4),
	Vector2(136.0, -9.5), Vector2(122.0, -8.3), Vector2(107.0, -7.8),
]
const LOWER_HEIGHT := 4.4
const UPPER_HEIGHT := 8.2
# 使用固定镜头在地平面上的等效投影筛掉覆盖下空位的树冠。
const LOWER_OPENING := Rect2(0.0, 55.0, 23.0, 9.0)
const HEIGHT_TO_SCREEN_DEPTH := 72.0 / 80.0


static func clears_tree(root: Vector2, width: float, height: float) -> bool:
	var footprint := Rect2(root - Vector2(width * 0.5, height * HEIGHT_TO_SCREEN_DEPTH),
		Vector2(width, height * HEIGHT_TO_SCREEN_DEPTH))
	return LOWER_OPENING.intersects(footprint)


static func add_ridge(parent: Node3D, ground_material: ShaderMaterial) -> void:
	var material := ground_material.duplicate() as ShaderMaterial
	material.set_shader_parameter("scenic_terrace", true)
	_add_terrace(parent, "LowerTerrace", PackedVector2Array(LOWER_RIDGE), 0.0, LOWER_HEIGHT, material)
	_add_terrace(parent, "UpperTerrace", PackedVector2Array(UPPER_RIDGE), LOWER_HEIGHT, UPPER_HEIGHT, material)


static func ridge_height(point: Vector2, lower: PackedVector2Array, upper: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(point, upper):
		return UPPER_HEIGHT
	return LOWER_HEIGHT if Geometry2D.is_point_in_polygon(point, lower) else 0.0


static func _add_terrace(parent: Node3D, node_name: String, contour: PackedVector2Array,
		bottom: float, top: float, material: ShaderMaterial) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var indices := Geometry2D.triangulate_polygon(contour)
	for index in range(0, indices.size(), 3):
		var a := contour[indices[index]]
		var b := contour[indices[index + 1]]
		var c := contour[indices[index + 2]]
		if (b - a).cross(c - a) < 0.0:
			var swap := b
			b = c
			c = swap
		for point: Vector2 in [a, b, c]:
			surface.set_color(Color.BLACK)
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2.ZERO)
			surface.add_vertex(Vector3(point.x, top, point.y))
	for index in range(contour.size()):
		var a := contour[index]
		var b := contour[(index + 1) % contour.size()]
		var edge := b - a
		var outward := Vector2(-edge.y, edge.x).normalized()
		var tint := Color.WHITE.darkened(float(index % 4) * 0.045)
		for corner: Vector3 in [
			Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(b.x, bottom, b.y),
			Vector3(a.x, top, a.y), Vector3(b.x, bottom, b.y), Vector3(a.x, bottom, a.y),
		]:
			surface.set_color(tint)
			surface.set_normal(Vector3(outward.x, 0.0, outward.y))
			surface.set_uv(Vector2((corner.y - bottom) / (top - bottom), 1.0))
			surface.add_vertex(corner)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = surface.commit()
	parent.add_child(instance)
