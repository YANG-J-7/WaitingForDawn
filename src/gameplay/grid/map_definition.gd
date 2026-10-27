class_name MapDefinition
extends RefCounted
## 显示、地形、资源、镜头与出生共享的地图定义入口。
const CELL_SIZE := 36.0
const GRID_SIZE := Vector2i(196, 80)
const BOUNDS := Rect2(0, 0, 7056, 2880)
const SOURCE_SIZE := Vector2(1672, 941)
const SOURCE_WORLD_SIZE := Vector2(4608, 2592)
const SOURCE_WORLD_ORIGIN := Vector2(2448, 288)
const CITY_POSITION := Vector2(4176, 1908)
const SPAWN_POINTS: Array[Vector2] = [
	Vector2(3204, 504), Vector2(5256, 324),
	Vector2(2916, 1404), Vector2(3276, 2448),
]
const DATA_PATH := "res://assets/map/dawn_wide_v3/map.json"
static var _data: Dictionary = {}
static var _visual: Dictionary = {}
static var _navigation: Dictionary = {}
static var _runtime: RefCounted

static func runtime() -> RefCounted:
	# 旧工具入口保留默认关卡；主场景持有自己的实例，不共享动态状态。
	if _runtime == null:
		_runtime = preload("res://src/gameplay/map/level_map_runtime.gd").create_default()
	return _runtime

static func navigation_data() -> Dictionary:
	return runtime().navigation

static func visual_data() -> Dictionary:
	if _visual.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/dawn_wide_v3/visual.json"))
		if parsed is Dictionary: _visual = parsed
	return _visual

static func data() -> Dictionary:
	return runtime().compiled

static func source_to_world(point: Vector2) -> Vector2:
	# 原山区不随扩边拉伸；旧图坐标与新增世界范围分别定义。
	return SOURCE_WORLD_ORIGIN + point / SOURCE_SIZE * SOURCE_WORLD_SIZE

static func world_to_source(point: Vector2) -> Vector2:
	return (point - SOURCE_WORLD_ORIGIN) / SOURCE_WORLD_SIZE * SOURCE_SIZE

static func polygon_world(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(source_to_world(Vector2(point[0], point[1])))
	return result

static func resource_sites() -> Array:
	return runtime().resource_sites()
