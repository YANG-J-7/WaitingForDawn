class_name MapDefinition
extends RefCounted
## 显示、地形、资源、镜头与出生共享的地图定义入口。
const CELL_SIZE := 36.0
const GRID_SIZE := Vector2i(128, 72)
const BOUNDS := Rect2(0, 0, 4608, 2592)
const SOURCE_SIZE := Vector2(1672, 941)
const CITY_POSITION := Vector2(1728, 1620)
const SPAWN_POINTS: Array[Vector2] = [
	Vector2(756, 216), Vector2(2808, 36),
	Vector2(468, 1116), Vector2(828, 2160),
]
const DATA_PATH := "res://assets/map/dawn_large_v1/map.json"
static var _data: Dictionary = {}
static var _visual: Dictionary = {}
static var _navigation: Dictionary = {}

static func navigation_data() -> Dictionary:
	if _navigation.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/dawn_large_v1/mountain-navigation.json"))
		if parsed is Dictionary:
			_navigation = parsed
		else:
			push_error("山区通行标注无法读取")
	return _navigation

static func visual_data() -> Dictionary:
	if _visual.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/dawn_large_hd_v2/visual.json"))
		if parsed is Dictionary: _visual = parsed
	return _visual

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("大地图定义无法读取")
	return _data

static func source_to_world(point: Vector2) -> Vector2:
	return point / SOURCE_SIZE * BOUNDS.size

static func polygon_world(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(source_to_world(Vector2(point[0], point[1])))
	return result

static func resource_sites() -> Array:
	var sites: Array = data().get("resourceSites", []).duplicate(true)
	for site in sites:
		for entry in visual_data().get("forests", []):
			if site.id == entry.id: site.sprite = entry.path
	return sites
