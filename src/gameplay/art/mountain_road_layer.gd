class_name MountainRoadLayer
extends Node2D
## 复用已有生成的石土纹理，路带与坡道开放共用同一份设计坐标。
const ROAD_DATA = preload("res://src/gameplay/grid/mountain_road_data.gd")
const ROAD_TEXTURE: Texture2D = preload("res://assets/art_candidates/night_set_v1/terrain_road.png")
const TILE_WORLD_SIZE := 144.0
const ROAD_TINT := Color(0.92, 0.92, 0.87, 0.94)
var grid_model: RefCounted

func configure(grid: RefCounted) -> void:
	grid_model = grid
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	queue_redraw()

func _draw() -> void:
	var radius: float = float(ROAD_DATA.data().get("road_width", 72)) / 2.0
	for route in ROAD_DATA.routes():
		var points: PackedVector2Array = ROAD_DATA.points_for(route)
		for index in range(points.size() - 1):
			var a := points[index]
			var b := points[index + 1]
			var side := (b - a).normalized().orthogonal()
			# 中央保留完整材质，两侧顶点透明度渐变融入草地。
			for band in [[-radius, -radius * 0.68, 0.0, 1.0], [-radius * 0.68, radius * 0.68, 1.0, 1.0], [radius * 0.68, radius, 1.0, 0.0]]:
				_paint(PackedVector2Array([a + side * band[0], b + side * band[0], b + side * band[1], a + side * band[1]]), PackedFloat32Array([band[2], band[2], band[3], band[3]]))
		for point in points:
			_paint_join(point, radius)
	# 岩壁坡道上叠加横向踏面明暗，清楚标出可通过的缺口。
	if grid_model != null:
		var marked := {}
		for cell in grid_model.cells_of_type(&"ramp"):
			var center: Vector2 = grid_model.cell_center(cell)
			var closest := center
			var side := Vector2.RIGHT
			var distance := INF
			for route in ROAD_DATA.routes():
				var points: PackedVector2Array = ROAD_DATA.points_for(route)
				for index in range(points.size() - 1):
					var point := Geometry2D.get_closest_point_to_segment(center, points[index], points[index+1])
					if point.distance_squared_to(center) < distance:
						distance = point.distance_squared_to(center)
						closest = point
						side = (points[index+1] - points[index]).normalized().orthogonal()
			var key := Vector2i(closest / 6.0)
			if marked.has(key):
				continue
			marked[key] = true
			# 踏面垂直于路向，严格留在路幅内部，不在两侧草地上留下浮线。
			var half_step := side * radius * 0.52
			draw_line(closest - half_step, closest + half_step, Color(0.09, 0.13, 0.16, 0.7), 2.0, true)
			draw_line(closest - half_step + Vector2(0, 1), closest + half_step + Vector2(0, 1), Color(0.55, 0.57, 0.53, 0.5), 1.0, true)

func _paint_join(center: Vector2, radius: float) -> void:
	var inner := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		var next := TAU * float(index + 1) / 20.0
		var a := Vector2.from_angle(angle)
		var b := Vector2.from_angle(next)
		inner.append(center + a * radius * 0.68)
		_paint(PackedVector2Array([center + a * radius * 0.68, center + b * radius * 0.68, center + b * radius, center + a * radius]), PackedFloat32Array([1, 1, 0, 0]))
	_paint(inner, PackedFloat32Array([1.0]))

func _paint(points: PackedVector2Array, alphas: PackedFloat32Array) -> void:
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for index in range(points.size()):
		var color := ROAD_TINT
		color.a *= alphas[0] if alphas.size() == 1 else alphas[index]
		colors.append(color)
		uvs.append(points[index] / TILE_WORLD_SIZE)
	draw_polygon(points, colors, uvs, ROAD_TEXTURE)
