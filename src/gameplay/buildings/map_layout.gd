extends RefCounted

const TerrainMapData = preload("res://src/gameplay/grid/terrain_map_data.gd")

const BOUNDS := Rect2(0, 0, 2880, 1620)
const CITY_POSITION := Vector2(1368, 1044)
# 保守覆盖湖面内部；岸线附近仍以实际地图视觉为准，避免误伤半岛资源点。
const WATER_ZONES: Array[Rect2] = [
	Rect2(2200, 1050, 680, 570),
	Rect2(1750, 1280, 1130, 340),
	Rect2(1250, 1510, 1630, 110),
]
const SPAWN_POINTS: Array[Vector2] = [
	Vector2(420, 0),
	Vector2(2380, 0),
	Vector2(0, 720),
	Vector2(620, 1620),
]
const CITY_RADIUS: float = 48.0
const TOWER_RADIUS: float = 24.0
const BARRACKS_RADIUS: float = 30.0
const WALL_RADIUS: float = 20.0
const BUILDING_RADIUS: float = 24.0

const GRID_CELL_SIZE: float = 36.0
const GRID_SIZE := Vector2i(80, 45)
const CITY_FOOTPRINT := Vector2i(4, 4)


static func footprint_for_card(card_id: StringName) -> Vector2i:
	match card_id:
		&"arrow_tower", &"wall":
			return Vector2i.ONE
		&"barracks", &"farm", &"house", &"lumber_camp", &"stone_mine", &"iron_mine", &"gold_mine":
			return Vector2i(2, 2)
		_:
			return Vector2i.ONE

static func is_buildable(point: Vector2, radius: float = 0.0) -> bool:
	if not BOUNDS.grow(-radius).has_point(point):
		return false
	for sample in [
		point,
		point + Vector2(radius, 0), point + Vector2(-radius, 0),
		point + Vector2(0, radius), point + Vector2(0, -radius),
	]:
		if TerrainMapData.is_water_world_point(sample):
			return false
	return true
