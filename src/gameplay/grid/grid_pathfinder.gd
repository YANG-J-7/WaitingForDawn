class_name GridPathfinder
extends RefCounted

const CELL_SIZE: float = 36.0

var model: RefCounted
var _astar := AStarGrid2D.new()
var _synced_revision: int = -1


func _init(grid_model: RefCounted) -> void:
	model = grid_model


func find_path(
	start_world: Vector2,
	target_world: Vector2,
	stop_radius: float = 0.0
) -> PackedVector2Array:
	_sync_if_needed()
	var start_cell: Vector2i = model.world_to_cell(start_world)
	var start_was_solid: bool = bool(model.is_solid(start_cell))
	if model.is_solid(start_cell):
		start_cell = _nearest_open_cell(start_cell)
	if not model.is_inside(start_cell) or model.is_solid(start_cell):
		return PackedVector2Array()
	var candidates: Array[Vector2i] = _target_candidates(target_world, stop_radius)
	var best_ids: Array[Vector2i] = []
	var best_cost: float = INF
	for target_cell in candidates:
		var ids: Array[Vector2i] = _astar.get_id_path(start_cell, target_cell)
		if ids.is_empty() and start_cell != target_cell:
			continue
		var cost: float = float(ids.size()) * CELL_SIZE + model.cell_center(target_cell).distance_to(target_world)
		if cost < best_cost:
			best_cost = cost
			best_ids = ids
	if best_ids.is_empty():
		if start_cell in candidates:
			return PackedVector2Array([model.cell_center(start_cell)])
		return PackedVector2Array()
	var points := PackedVector2Array()
	var first_index: int = 0 if start_was_solid else 1
	for index in range(first_index, best_ids.size()):
		points.append(model.cell_center(best_ids[index]))
	if points.is_empty():
		points.append(model.cell_center(best_ids.back()))
	return points


func current_revision() -> int:
	return int(model.revision)


func _sync_if_needed() -> void:
	if _synced_revision == int(model.revision):
		return
	_astar.region = Rect2i(Vector2i.ZERO, model.grid_size)
	_astar.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	_astar.offset = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in range(model.grid_size.y):
		for x in range(model.grid_size.x):
			var cell := Vector2i(x, y)
			_astar.set_point_solid(cell, model.is_solid(cell))
			var data: Dictionary = model.cell_data(cell)
			if not data.is_empty() and is_finite(float(data.movement_cost)):
				_astar.set_point_weight_scale(cell, maxf(1.0, float(data.movement_cost)))
	_synced_revision = int(model.revision)


func _target_candidates(target_world: Vector2, stop_radius: float) -> Array[Vector2i]:
	var target_cell: Vector2i = model.world_to_cell(target_world)
	var search_radius: int = maxi(0, ceili(stop_radius / CELL_SIZE) + 1)
	if stop_radius <= 0.0 and model.is_inside(target_cell) and not model.is_solid(target_cell):
		return [target_cell]
	var candidates: Array[Vector2i] = []
	var effective_radius: float = maxf(stop_radius, CELL_SIZE * 0.75)
	for y in range(target_cell.y - search_radius, target_cell.y + search_radius + 1):
		for x in range(target_cell.x - search_radius, target_cell.x + search_radius + 1):
			var cell := Vector2i(x, y)
			if not model.is_inside(cell) or model.is_solid(cell):
				continue
			if model.cell_center(cell).distance_to(target_world) <= effective_radius:
				candidates.append(cell)
	if candidates.is_empty():
		var nearest: Vector2i = _nearest_open_cell(target_cell)
		if model.is_inside(nearest) and not model.is_solid(nearest):
			candidates.append(nearest)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i):
		return model.cell_center(a).distance_squared_to(target_world) < model.cell_center(b).distance_squared_to(target_world)
	)
	return candidates


func _nearest_open_cell(origin: Vector2i) -> Vector2i:
	for radius in range(0, maxi(model.grid_size.x, model.grid_size.y)):
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				if radius > 0 and x > origin.x - radius and x < origin.x + radius and y > origin.y - radius and y < origin.y + radius:
					continue
				var cell := Vector2i(x, y)
				if model.is_inside(cell) and not model.is_solid(cell):
					return cell
	return Vector2i(-1, -1)
