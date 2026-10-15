class_name MountainRoadData
extends RefCounted
## 固定路网同时供绘制和坡道开放查询；不依赖显示节点或运行时图片采样。
const DATA_PATH := "res://design/levels/mountain-resource-routes.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("山区路网数据无法读取")
	return _data

static func routes() -> Array:
	return data().get("routes", [])

static func points_for(route: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in route.get("points", []):
		points.append(Vector2(point[0], point[1]))
	return points

static func contains_point(point: Vector2) -> bool:
	var radius: float = float(data().get("road_width",72)) / 2.0
	for route in routes():
		var points := points_for(route)
		for index in range(points.size() - 1):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,points[index],points[index+1])) <= radius:
				return true
	return false

static func apply_to(grid: RefCounted) -> void:
	var roads: Array[Vector2i] = []
	var ramps: Array[Vector2i] = []
	for y in range(grid.grid_size.y):
		for x in range(grid.grid_size.x):
			var cell := Vector2i(x,y)
			var terrain: Dictionary = grid.cell_data(cell)
			if terrain.terrain_type == &"water" or not contains_point(grid.cell_center(cell)):
				continue
			if terrain.terrain_type in [&"cliff", &"shore"]:
				ramps.append(cell)
			else:
				roads.append(cell)
	grid.set_terrain_cells(roads,&"road",true,true,1.0)
	grid.set_terrain_cells(ramps,&"ramp",true,false,1.0,1)
