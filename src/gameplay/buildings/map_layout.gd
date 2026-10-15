extends RefCounted

const TerrainMapData = preload("res://src/gameplay/grid/terrain_map_data.gd")

const Definition = preload("res://src/gameplay/grid/map_definition.gd")
const BOUNDS := Definition.BOUNDS
const CITY_POSITION := Definition.CITY_POSITION
# 保守覆盖湖面内部；岸线附近仍以实际地图视觉为准，避免误伤半岛资源点。
const SPAWN_POINTS: Array[Vector2] = Definition.SPAWN_POINTS
const CITY_RADIUS: float = 48.0
const TOWER_RADIUS: float = 24.0
const BARRACKS_RADIUS: float = 30.0
const WALL_RADIUS: float = 20.0
const BUILDING_RADIUS: float = 24.0

const GRID_CELL_SIZE: float = Definition.CELL_SIZE
const GRID_SIZE := Definition.GRID_SIZE
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
