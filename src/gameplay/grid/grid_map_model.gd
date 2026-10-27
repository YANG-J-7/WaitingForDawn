class_name GridMapModel
extends RefCounted

const Definition = preload("res://src/gameplay/grid/map_definition.gd")
const CELL_SIZE: float = Definition.CELL_SIZE
const GRID_SIZE := Definition.GRID_SIZE
const MAP_BOUNDS := Rect2(Vector2.ZERO, Vector2(GRID_SIZE) * CELL_SIZE)
const BASE_NAVIGATION := {"level": 0, "stair": -1, "ends": []}

var grid_size: Vector2i = GRID_SIZE
var _cells: Array[Dictionary] = []
var _static_occupants: Dictionary = {}
var _occupant_cells: Dictionary = {}
var _resource_sites: Dictionary = {}
var revision: int = 0
var _navigation: Dictionary = {}


func set_navigation_cell(cell: Vector2i, level: int, stair: int = -1, ends: Array = []) -> void:
	var levels: Array[int] = []
	for end in ends:
		levels.append(int(end))
	_navigation[cell] = {"level": level, "stair": stair, "ends": levels}
	revision += 1


func navigation_data(cell: Vector2i) -> Dictionary:
	return _navigation.get(cell, BASE_NAVIGATION)


func can_step(from: Vector2i, to: Vector2i) -> bool:
	if is_solid(from) or is_solid(to) or absi(from.x-to.x)>1 or absi(from.y-to.y)>1:
		return false
	if from.x != to.x and from.y != to.y:
		# 斜行的两个正交分解也须合法，不能切过岩角或跨越平台入口。
		return can_step(from, Vector2i(from.x,to.y)) and can_step(Vector2i(from.x,to.y),to) and can_step(from,Vector2i(to.x,from.y)) and can_step(Vector2i(to.x,from.y),to)
	var a := navigation_data(from)
	var b := navigation_data(to)
	if a.stair >= 0 and b.stair >= 0:
		return a.stair == b.stair
	if a.stair >= 0:
		return b.level in a.ends
	if b.stair >= 0:
		return a.level in b.ends
	return a.level == b.level


func _init(size: Vector2i = GRID_SIZE) -> void:
	grid_size = size
	_cells.resize(grid_size.x * grid_size.y)
	for index in range(_cells.size()):
		_cells[index] = _make_cell(&"grass", true, true, 1.0)


func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / CELL_SIZE), floori(world_position.y / CELL_SIZE))


func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func snap_footprint_center(world_position: Vector2, footprint: Vector2i) -> Vector2:
	var safe_size := Vector2i(maxi(1, footprint.x), maxi(1, footprint.y))
	var half_size := Vector2(safe_size) * 0.5
	var top_left := Vector2i(
		roundi(world_position.x / CELL_SIZE - half_size.x),
		roundi(world_position.y / CELL_SIZE - half_size.y)
	)
	return (Vector2(top_left) + half_size) * CELL_SIZE


func footprint_cells(world_center: Vector2, footprint: Vector2i) -> Array[Vector2i]:
	var safe_size := Vector2i(maxi(1, footprint.x), maxi(1, footprint.y))
	var snapped_center := snap_footprint_center(world_center, safe_size)
	var top_left := Vector2i(
		roundi(snapped_center.x / CELL_SIZE - float(safe_size.x) * 0.5),
		roundi(snapped_center.y / CELL_SIZE - float(safe_size.y) * 0.5)
	)
	var result: Array[Vector2i] = []
	for y in range(safe_size.y):
		for x in range(safe_size.x):
			result.append(top_left + Vector2i(x, y))
	return result


func cell_data(cell: Vector2i) -> Dictionary:
	if not is_inside(cell):
		return {}
	return _cells[_index(cell)].duplicate()


func is_walkable(cell: Vector2i) -> bool:
	return is_inside(cell) and bool(_cells[_index(cell)].walkable)


func is_solid(cell: Vector2i) -> bool:
	return not is_walkable(cell) or _static_occupants.has(cell)


func interaction_clear(from: Vector2, target: Vector2) -> bool:
	# 停距允许站在建筑外围，但不能隔着岩壁、水域或树林完成交互。
	var steps := maxi(1,ceili(from.distance_to(target)/(CELL_SIZE*0.25)))
	for index in range(steps+1):
		var cell := world_to_cell(from.lerp(target,float(index)/steps))
		if not is_inside(cell) or cell_data(cell).terrain_type in [&"cliff",&"water",&"forest",&"boundary"]:
			return false
	return true


func has_work_access(center: Vector2, footprint: Vector2i, radius: float = 60.0) -> bool:
	var occupied := footprint_cells(center,footprint)
	var mountain := false
	for cell in occupied:
		mountain = mountain or cell_data(cell).get("terrain_type") == &"mountain_grass" or _navigation.has(cell)
	if not mountain:
		return true
	var origin := world_to_cell(center)
	var reach := ceili(radius/CELL_SIZE)+1
	for y in range(origin.y-reach,origin.y+reach+1):
		for x in range(origin.x-reach,origin.x+reach+1):
			var cell := Vector2i(x,y)
			var point := cell_center(cell)
			if cell not in occupied and not is_solid(cell) and point.distance_to(center)<=radius and interaction_clear(point,center):
				return true
	return false


func set_terrain_rect(
	world_rect: Rect2,
	terrain_type: StringName,
	walkable: bool,
	buildable: bool,
	movement_cost: float
) -> void:
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := Vector2i(x, y)
			if world_rect.has_point(cell_center(cell)):
				_cells[_index(cell)] = _make_cell(terrain_type, walkable, buildable, movement_cost)
	revision += 1


func set_terrain_cells(
	cells: Array[Vector2i],
	terrain_type: StringName,
	walkable: bool,
	buildable: bool,
	movement_cost: float,
	elevation: int = 0
) -> void:
	var changed := false
	for cell in cells:
		if not is_inside(cell):
			continue
		var data := _make_cell(terrain_type, walkable, buildable, movement_cost)
		data.elevation = elevation
		_cells[_index(cell)] = data
		changed = true
	if changed:
		revision += 1


func cells_of_type(terrain_type: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := Vector2i(x, y)
			if StringName(_cells[_index(cell)].terrain_type) == terrain_type:
				result.append(cell)
	return result


func register_resource_site(
	site_id: StringName,
	site_type: StringName,
	world_position: Vector2,
	footprint: Vector2i = Vector2i(2, 2)
) -> void:
	var center := snap_footprint_center(world_position, footprint)
	var cells := footprint_cells(center, footprint)
	_resource_sites[site_id] = {
		"site_type": site_type,
		"center": center,
		"footprint": footprint,
		"cells": cells,
	}
	for cell in cells:
		if not is_inside(cell):
			continue
		var data := _cells[_index(cell)].duplicate()
		data.terrain_type = &"resource"
		data.walkable = false
		data.buildable = false
		data.movement_cost = INF
		data.resource_site_id = site_id
		_cells[_index(cell)] = data
	revision += 1


func resource_site_center(site_id: StringName) -> Vector2:
	if not _resource_sites.has(site_id):
		return Vector2.INF
	return _resource_sites[site_id].center


func resource_site_type(site_id: StringName) -> StringName:
	if not _resource_sites.has(site_id):
		return &""
	return _resource_sites[site_id].site_type


func can_place(
	world_center: Vector2,
	footprint: Vector2i,
	resource_site_id: StringName = &""
) -> bool:
	var cells := footprint_cells(world_center, footprint)
	if cells.is_empty():
		return false
	if not resource_site_id.is_empty():
		if not _resource_sites.has(resource_site_id):
			return false
		var site: Dictionary = _resource_sites[resource_site_id]
		if Vector2i(site.footprint) != footprint or site.cells != cells:
			return false
	for cell in cells:
		if not is_inside(cell) or _static_occupants.has(cell):
			return false
		var data: Dictionary = _cells[_index(cell)]
		if resource_site_id.is_empty():
			if not bool(data.buildable):
				return false
		elif StringName(data.resource_site_id) != resource_site_id:
			return false
	return true


func occupy(
	occupant_id: StringName,
	world_center: Vector2,
	footprint: Vector2i,
	resource_site_id: StringName = &""
) -> bool:
	if occupant_id.is_empty() or not can_place(world_center, footprint, resource_site_id):
		return false
	release(occupant_id)
	var cells := footprint_cells(world_center, footprint)
	_occupant_cells[occupant_id] = cells
	for cell in cells:
		_static_occupants[cell] = occupant_id
	revision += 1
	return true


func release(occupant_id: StringName) -> void:
	if not _occupant_cells.has(occupant_id):
		return
	for cell: Vector2i in _occupant_cells[occupant_id]:
		if _static_occupants.get(cell, &"") == occupant_id:
			_static_occupants.erase(cell)
	_occupant_cells.erase(occupant_id)
	revision += 1


func clear_occupancy() -> void:
	_static_occupants.clear()
	_occupant_cells.clear()
	revision += 1


func copy_without_occupants_at(positions: Array[Vector2]) -> RefCounted:
	# 只供封路时判断破障方向；实际移动始终读取原网格。
	var result := GridMapModel.new()
	result.grid_size = grid_size
	result._cells = _cells.duplicate(true)
	result._navigation = _navigation.duplicate(true)
	result._resource_sites = _resource_sites.duplicate(true)
	result._static_occupants = _static_occupants.duplicate()
	result._occupant_cells = _occupant_cells.duplicate(true)
	for point in positions:
		var occupant: StringName = _static_occupants.get(world_to_cell(point), &"")
		if not occupant.is_empty(): result.release(occupant)
	result.revision = revision
	return result


func occupied_cells_for(occupant_id: StringName) -> Array[Vector2i]:
	if not _occupant_cells.has(occupant_id):
		return []
	var result: Array[Vector2i] = []
	result.assign(_occupant_cells[occupant_id])
	return result


func _index(cell: Vector2i) -> int:
	return cell.y * grid_size.x + cell.x


func _make_cell(
	terrain_type: StringName,
	walkable: bool,
	buildable: bool,
	movement_cost: float
) -> Dictionary:
	return {
		"terrain_type": terrain_type,
		"walkable": walkable,
		"buildable": buildable,
		"movement_cost": movement_cost,
		"elevation": 0,
		"resource_site_id": &"",
	}
