class_name GridPathfinder
extends RefCounted

const CELL_SIZE: float = 36.0
const MAX_CACHED_PATHS := 256
const WEST := 1
const NORTH := 2
const WEST_AND_NORTH := WEST | NORTH
const NEIGHBORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var model: RefCounted
var _astar := AStar2D.new()
var _synced_revision: int = -1
var _path_cache: Dictionary = {}
var _target_cache: Dictionary = {}
var _dirty_cells: Dictionary[Vector2i, bool] = {}
var _weights := PackedFloat64Array()
var _diagonal_distance := Vector2(CELL_SIZE, CELL_SIZE).length()
var _spawn_cache: Dictionary = {}
var _spawn_revision: int = -1
var _siege_pathfinder: RefCounted
var _siege_key: String = ""


func _init(grid_model: RefCounted) -> void:
	model = grid_model
	model.navigation_cells_changed.connect(_on_navigation_cells_changed)


func find_path(
	start_world: Vector2,
	target_world: Vector2,
	stop_radius: float = 0.0
) -> PackedVector2Array:
	_sync_if_needed()
	var start_cell: Vector2i = model.world_to_cell(start_world)
	# 同一权威格/目标/停距共享格中心路径；占用版本变化立即作废。
	var key := [start_cell, target_world, stop_radius]
	if _path_cache.has(key):
		return _path_cache[key].duplicate()
	if model.is_solid(start_cell):
		# 地图内的岩壁/离路草台不能用“最近开放格”直线穿越接入。
		# 只有地图外出生兼容入口允许归入边界；正式出生会先选择合法脚点。
		if model.is_inside(start_cell):
			return PackedVector2Array()
		start_cell = _nearest_open_cell(start_cell)
	if not model.is_inside(start_cell) or model.is_solid(start_cell):
		return PackedVector2Array()
	var target_key := [target_world, stop_radius]
	if not _target_cache.has(target_key):
		if _target_cache.size() >= MAX_CACHED_PATHS:
			_target_cache.erase(_target_cache.keys()[0])
		_target_cache[target_key] = _target_candidates(target_world, stop_radius)
	var candidates: Array[Vector2i] = _target_cache[target_key]
	var best_ids := PackedInt64Array()
	var best_cost: float = INF
	var best_approach: float = INF
	var start_id := _id(start_cell)
	var width: int = model.grid_size.x
	var narrow_grid := width <= 2
	for target_cell in candidates:
		var offset := (target_cell - start_cell).abs()
		var diagonals := mini(offset.x, offset.y)
		# 权重至少为 1。忽略阻挡后的最短八方向距离只能比实际代价低。
		var lower_bound := float(absi(offset.x - offset.y)) * CELL_SIZE + float(diagonals) * _diagonal_distance
		if lower_bound > best_cost and not is_equal_approx(lower_bound, best_cost):
			continue
		var ids := _astar.get_id_path(start_id, _id(target_cell))
		if ids.is_empty() and start_cell != target_cell:
			continue
		# 正交、斜行与地形权重的实际代价不同，不能按路径点数量选路。
		# 单位只走到交互外围，不把没有实际行走的“外围到目标中心”加入成本。
		var cost := 0.0
		for index in range(1, ids.size()):
			var from_id := ids[index - 1]
			var to_id := ids[index]
			var step := absi(to_id - from_id)
			var horizontal := step == 1 and (not narrow_grid or to_id / width == from_id / width)
			var straight := step == width or horizontal
			var distance := CELL_SIZE if straight else _diagonal_distance
			cost += distance * _weights[ids[index]]
		var approach: float = model.cell_center(target_cell).distance_to(target_world)
		if cost < best_cost or (is_equal_approx(cost,best_cost) and approach < best_approach):
			best_cost = cost
			best_approach = approach
			best_ids = ids
	if best_ids.is_empty():
		if start_cell in candidates:
			return PackedVector2Array([model.cell_center(start_cell)])
		return PackedVector2Array()
	var points := PackedVector2Array()
	# 相邻边已验证两个正交方向，格内起步可直接走向下一格中心。
	# 追逐目标更新时不折返当前格中心，避免双方反复后退而无法接近。
	var first_index: int = 1 if best_ids.size() > 1 else 0
	for index in range(first_index, best_ids.size()):
		points.append(_astar.get_point_position(best_ids[index]))
	if _path_cache.size() >= MAX_CACHED_PATHS:
		_path_cache.erase(_path_cache.keys()[0])
	_path_cache[key] = points.duplicate()
	return points


func current_revision() -> int:
	return int(model.revision)

func prepare_graph() -> void:
	_sync_if_needed()


func find_siege_route(start: Vector2, target: Vector2, radius: float, blockers: Array[Vector2]) -> PackedVector2Array:
	if blockers.is_empty(): return PackedVector2Array()
	var key := "%d/%s" % [model.revision, blockers]
	if key != _siege_key:
		_siege_pathfinder = GridPathfinder.new(model.copy_without_occupants_at(blockers))
		_siege_key = key
	# 仅忽略登记的可摧毁占用，地形、岩壁、石梯跨层及其他占用保持。
	return _siege_pathfinder.find_path(start, target, radius)


func _sync_if_needed() -> void:
	if _synced_revision == int(model.revision):
		return
	_path_cache.clear()
	_target_cache.clear()
	if _synced_revision < 0:
		_build_graph()
	else:
		_refresh_dirty_cells()
	_synced_revision = int(model.revision)


func _on_navigation_cells_changed(cells: Array[Vector2i]) -> void:
	if _synced_revision >= 0:
		for cell in cells:
			if model.is_inside(cell):
				_dirty_cells[cell] = true


func _build_graph() -> void:
	var size: Vector2i = model.grid_size
	_weights = model.navigation_weights()
	if _weights.is_empty():
		return
	_astar.reserve_space(_weights.size())
	var special := PackedByteArray()
	special.resize(_weights.size())
	for cell: Vector2i in model.navigation_overrides():
		if model.is_inside(cell):
			special[_id(cell)] = 1
	var orthogonal := PackedByteArray()
	orthogonal.resize(_weights.size())
	for y in range(size.y):
		for x in range(size.x):
			var id := y * size.x + x
			var weight := _weights[id]
			if weight == 0.0:
				continue
			var cell := Vector2i(x, y)
			_astar.add_point(id, model.cell_center(cell), weight)
			var west := id - 1
			var north := id - size.x
			if x > 0 and _weights[west] > 0.0 and (
				(special[id] == 0 and special[west] == 0) or model.can_step(cell, cell + Vector2i.LEFT)
			):
				_astar.connect_points(west, id)
				orthogonal[id] |= WEST
			if y > 0 and _weights[north] > 0.0 and (
				(special[id] == 0 and special[north] == 0) or model.can_step(cell, cell + Vector2i.UP)
			):
				_astar.connect_points(north, id)
				orthogonal[id] |= NORTH
			# 每个方格的四条正交边都通过时，两条对角线才允许连接。
			if orthogonal[id] == WEST_AND_NORTH and orthogonal[west] & NORTH and orthogonal[north] & WEST:
				_astar.connect_points(north - 1, id)
				_astar.connect_points(north, west)


func _refresh_dirty_cells() -> void:
	for cell in _dirty_cells:
		var id := _id(cell)
		if model.is_solid(cell):
			_weights[id] = 0.0
			if _astar.has_point(id):
				_astar.remove_point(id)
			continue
		var weight := maxf(1.0, float(model.cell_data(cell).movement_cost))
		_weights[id] = weight
		if _astar.has_point(id):
			_astar.set_point_weight_scale(id, weight)
		else:
			_astar.add_point(id, model.cell_center(cell), weight)
	# 占用改变只重连受影响格及邻域，斜角边也随正交阻挡更新。
	var affected := {}
	for cell in _dirty_cells:
		for dy in range(-1,2):
			for dx in range(-1,2):
				var nearby := cell+Vector2i(dx,dy)
				if model.is_inside(nearby): affected[nearby] = true
	for cell: Vector2i in affected:
		if not _astar.has_point(_id(cell)): continue
		for offset: Vector2i in NEIGHBORS:
			var next: Vector2i = cell + offset
			if not model.is_inside(next) or not _astar.has_point(_id(next)): continue
			var connected := _astar.are_points_connected(_id(cell),_id(next))
			if model.can_step(cell,next):
				if not connected: _astar.connect_points(_id(cell),_id(next))
			elif connected:
				_astar.disconnect_points(_id(cell),_id(next))
	_dirty_cells.clear()


func _id(cell: Vector2i) -> int:
	return cell.y * model.grid_size.x + cell.x


func spawn_position(preferred: Vector2, anchor: Vector2 = Vector2.INF, radius: float = 96.0) -> Vector2:
	# 出生直接落合法格，不把一条穿岩直线作为初始寻路。
	# 空闲农民每帧也查询待命脚点；地形和占用不变时复用结果。
	if _spawn_revision != int(model.revision):
		_spawn_cache.clear()
		_spawn_revision = int(model.revision)
	var key := "%s/%s/%.4f" % [preferred,anchor,radius]
	if _spawn_cache.has(key):
		return _spawn_cache[key]
	var result := _find_spawn_position(preferred,anchor,radius)
	if _spawn_cache.size() >= MAX_CACHED_PATHS:
		_spawn_cache.erase(_spawn_cache.keys()[0])
	_spawn_cache[key] = result
	return result


func _find_spawn_position(preferred: Vector2, anchor: Vector2, radius: float) -> Vector2:
	if anchor == Vector2.INF:
		var cell := _nearest_open_cell(model.world_to_cell(preferred))
		return model.cell_center(cell) if model.is_inside(cell) else Vector2.INF
	var candidates := _target_candidates(anchor,radius)
	var best := Vector2.INF
	var distance := INF
	for cell in candidates:
		var point: Vector2 = model.cell_center(cell)
		if point.distance_squared_to(preferred) < distance:
			best = point
			distance = point.distance_squared_to(preferred)
	return best


func _target_candidates(target_world: Vector2, stop_radius: float) -> Array[Vector2i]:
	var target_cell: Vector2i = model.world_to_cell(target_world)
	var search_radius: int = maxi(0, ceili(stop_radius / CELL_SIZE) + 1)
	if stop_radius <= 0.0:
		if model.is_inside(target_cell) and not model.is_solid(target_cell):
			return [target_cell]
		return []
	var candidates: Array[Vector2i] = []
	var effective_radius: float = maxf(stop_radius, CELL_SIZE * 0.75)
	for y in range(target_cell.y - search_radius, target_cell.y + search_radius + 1):
		for x in range(target_cell.x - search_radius, target_cell.x + search_radius + 1):
			var cell := Vector2i(x, y)
			if not model.is_inside(cell) or model.is_solid(cell):
				continue
			if model.cell_center(cell).distance_to(target_world) <= effective_radius and model.interaction_clear(model.cell_center(cell),target_world):
				candidates.append(cell)
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
