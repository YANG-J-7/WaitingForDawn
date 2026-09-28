class_name GridMapModel
extends RefCounted

const CELL_SIZE: float = 36.0
const GRID_SIZE := Vector2i(80, 45)
const MAP_BOUNDS := Rect2(Vector2.ZERO, Vector2(GRID_SIZE) * CELL_SIZE)

var grid_size: Vector2i = GRID_SIZE
var _cells: Array[Dictionary] = []
var _static_occupants: Dictionary = {}
var _occupant_cells: Dictionary = {}
var _resource_sites: Dictionary = {}
var revision: int = 0


func _init() -> void:
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
