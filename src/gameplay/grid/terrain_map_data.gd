class_name TerrainMapData
extends RefCounted
## 权威格由人工地形标注离线生成，图层显隐不影响地形判定。
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
const SHORE_MOVEMENT_COST: float = 1.2

static func apply_to(grid: RefCounted) -> void:
	var groups: Dictionary = Definition.data().get("cells", {})
	for terrain_type in [&"cliff", &"water", &"forest", &"road", &"ramp"]:
		var cells: Array[Vector2i] = []
		for cell in groups.get(String(terrain_type), []):
			cells.append(Vector2i(cell[0], cell[1]))
		var walkable: bool = terrain_type in [&"road", &"ramp"]
		grid.set_terrain_cells(cells, terrain_type, walkable, terrain_type == &"road", 1.0 if walkable else INF)
	_apply_mountain_navigation(grid)
	var shores: Array[Vector2i] = []
	var seen := {}
	for water_cell in grid.cells_of_type(&"water"):
		for offset in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]:
			var next: Vector2i = water_cell + offset
			if grid.is_inside(next) and grid.is_walkable(next) and not seen.has(next) and grid.cell_data(next).terrain_type in [&"grass", &"road"]:
				seen[next] = true
				shores.append(next)
	grid.set_terrain_cells(shores, &"shore", true, false, SHORE_MOVEMENT_COST)

static func _apply_mountain_navigation(grid: RefCounted) -> void:
	var data := Definition.navigation_data()
	# 清除旧的宽泛山路/石阶开放；高清图校核后的标注才是当前通行权威。
	for point in data.get("mountainCells", []):
		var cell := Vector2i(point[0],point[1])
		var single: Array[Vector2i] = [cell]
		var kind: StringName = grid.cell_data(cell).terrain_type
		if kind in [&"grass", &"road", &"ramp", &"cliff"]:
			grid.set_terrain_cells(single, &"mountain_grass", false, true, INF)
	for point in data.get("cliffCells", []):
		var cell := Vector2i(point[0],point[1])
		var single: Array[Vector2i] = [cell]
		if grid.cell_data(cell).terrain_type not in [&"water", &"forest"]:
			grid.set_terrain_cells(single, &"cliff", false, false, INF)
	for entry in data.get("cells", []):
		var cell := Vector2i(entry.cell[0],entry.cell[1])
		var single: Array[Vector2i] = [cell]
		if grid.cell_data(cell).terrain_type in [&"water", &"forest"]:
			continue
		grid.set_terrain_cells(single, StringName(entry.kind), true, entry.kind == "road", 1.0)
		grid.set_navigation_cell(cell, int(entry.level), int(entry.stair), entry.ends)

static func is_water_world_point(point: Vector2) -> bool:
	for points in Definition.data().get("islands", []):
		if Geometry2D.is_point_in_polygon(point, Definition.polygon_world(points)):
			return false
	for points in Definition.data().get("water", []):
		if Geometry2D.is_point_in_polygon(point, Definition.polygon_world(points)):
			return true
	return false

static func first_cell_of_type(grid: RefCounted, terrain_type: StringName) -> Vector2i:
	var cells: Array[Vector2i] = grid.cells_of_type(terrain_type)
	return cells[0] if not cells.is_empty() else Vector2i(-1, -1)
