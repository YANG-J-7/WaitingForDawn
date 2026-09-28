class_name TerrainMapData
extends RefCounted

const SHORE_MOVEMENT_COST: float = 1.2


static func apply_to(grid: RefCounted) -> void:
	var cliff_cells: Array[Vector2i] = _cells_inside_polygons(grid, _cliff_polygons())
	grid.set_terrain_cells(cliff_cells, &"cliff", false, false, INF, 1)

	var water_cells: Array[Vector2i] = _cells_inside_polygon(grid, _water_polygon())
	var protected_land: Array[Vector2i] = _cells_inside_polygons(grid, _protected_land_polygons())
	for cell in protected_land:
		water_cells.erase(cell)
	grid.set_terrain_cells(water_cells, &"water", false, false, INF)

	var water_lookup := {}
	for cell in water_cells:
		water_lookup[cell] = true
	var shore_cells: Array[Vector2i] = []
	for water_cell in water_cells:
		for offset in [
			Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
			Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
		]:
			var neighbour: Vector2i = water_cell + offset
			if not grid.is_inside(neighbour) or water_lookup.has(neighbour):
				continue
			var data: Dictionary = grid.cell_data(neighbour)
			if StringName(data.get("terrain_type", &"")) == &"grass" and neighbour not in shore_cells:
				shore_cells.append(neighbour)
	grid.set_terrain_cells(shore_cells, &"shore", true, false, SHORE_MOVEMENT_COST)


static func is_water_world_point(point: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(point, _water_polygon()):
		return false
	for polygon in _protected_land_polygons():
		if Geometry2D.is_point_in_polygon(point, polygon):
			return false
	return true


static func first_cell_of_type(grid: RefCounted, terrain_type: StringName) -> Vector2i:
	for y in range(grid.grid_size.y):
		for x in range(grid.grid_size.x):
			var cell := Vector2i(x, y)
			if StringName(grid.cell_data(cell).get("terrain_type", &"")) == terrain_type:
				return cell
	return Vector2i(-1, -1)


static func _cells_inside_polygon(grid: RefCounted, polygon: PackedVector2Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(grid.grid_size.y):
		for x in range(grid.grid_size.x):
			var cell := Vector2i(x, y)
			if Geometry2D.is_point_in_polygon(grid.cell_center(cell), polygon):
				result.append(cell)
	return result


static func _cells_inside_polygons(grid: RefCounted, polygons: Array[PackedVector2Array]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for polygon in polygons:
		for cell in _cells_inside_polygon(grid, polygon):
			if cell not in result:
				result.append(cell)
	return result


static func _water_polygon() -> PackedVector2Array:
	# 轮廓沿当前16:9地图可见石岸内缘取样，并延伸到右、下边界。
	return PackedVector2Array([
		Vector2(1510, 1620), Vector2(1510, 1570), Vector2(1640, 1515),
		Vector2(1770, 1480), Vector2(1850, 1410), Vector2(1855, 1345),
		Vector2(1770, 1300), Vector2(1650, 1260), Vector2(1655, 1195),
		Vector2(1760, 1140), Vector2(1850, 1070), Vector2(1990, 1060),
		Vector2(2100, 1105), Vector2(2240, 1085), Vector2(2320, 1010),
		Vector2(2260, 945), Vector2(2315, 860), Vector2(2460, 835),
		Vector2(2535, 760), Vector2(2700, 720), Vector2(2880, 750),
		Vector2(2880, 1620),
	])


static func _cliff_polygons() -> Array[PackedVector2Array]:
	return [
		PackedVector2Array([
			Vector2(1010, 245), Vector2(1510, 285), Vector2(1570, 340),
			Vector2(1480, 385), Vector2(1120, 335), Vector2(980, 290),
		]),
		PackedVector2Array([
			Vector2(1870, 390), Vector2(2410, 445), Vector2(2470, 510),
			Vector2(2340, 540), Vector2(1960, 485), Vector2(1840, 435),
		]),
		PackedVector2Array([
			Vector2(2190, 570), Vector2(2720, 625), Vector2(2760, 685),
			Vector2(2630, 705), Vector2(2280, 650), Vector2(2160, 610),
		]),
	]


static func _protected_land_polygons() -> Array[PackedVector2Array]:
	# 右侧铁矿位于伸入湖面的半岛，不能被外侧湖泊主轮廓吞掉。
	return [PackedVector2Array([
		Vector2(2240, 745), Vector2(2460, 750), Vector2(2530, 825),
		Vector2(2480, 930), Vector2(2410, 1010), Vector2(2290, 1005),
		Vector2(2225, 930),
	])]
