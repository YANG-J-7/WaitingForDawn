class_name GridPathfinder
extends RefCounted

const CELL_SIZE: float = 36.0
const MAX_CACHED_PATHS := 256

var model: RefCounted
var _astar := AStar2D.new()
var _synced_revision: int = -1
var _path_cache: Dictionary = {}
var _point_navigation: Dictionary = {}
var _spawn_cache: Dictionary = {}
var _spawn_revision: int = -1


func _init(grid_model: RefCounted) -> void:
	model = grid_model


func find_path(
	start_world: Vector2,
	target_world: Vector2,
	stop_radius: float = 0.0
) -> PackedVector2Array:
	_sync_if_needed()
	var start_cell: Vector2i = model.world_to_cell(start_world)
	# 同一权威格/目标/停距共享格中心路径；占用版本变化立即作废。
	var key := "%s/%s/%.4f" % [start_cell,target_world,stop_radius]
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
	var candidates: Array[Vector2i] = _target_candidates(target_world, stop_radius)
	var best_ids: Array[Vector2i] = []
	var best_cost: float = INF
	var best_approach: float = INF
	for target_cell in candidates:
		var ids: Array[Vector2i] = []
		for id in _astar.get_id_path(_id(start_cell), _id(target_cell)):
			ids.append(Vector2i(id % model.grid_size.x, id / model.grid_size.x))
		if ids.is_empty() and start_cell != target_cell:
			continue
		# 正交、斜行与地形权重的实际代价不同，不能按路径点数量选路。
		# 单位只走到交互外围，不把没有实际行走的“外围到目标中心”加入成本。
		var cost := 0.0
		for index in range(1,ids.size()):
			var distance: float = model.cell_center(ids[index-1]).distance_to(model.cell_center(ids[index]))
			cost += distance * maxf(1.0,float(model.cell_data(ids[index]).movement_cost))
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
		points.append(model.cell_center(best_ids[index]))
	if points.is_empty():
		points.append(model.cell_center(best_ids.back()))
	if _path_cache.size() >= MAX_CACHED_PATHS:
		_path_cache.erase(_path_cache.keys()[0])
	_path_cache[key] = points.duplicate()
	return points


func current_revision() -> int:
	return int(model.revision)


func _sync_if_needed() -> void:
	if _synced_revision == int(model.revision):
		return
	_path_cache.clear()
	var changed := {}
	for y in range(model.grid_size.y):
		for x in range(model.grid_size.x):
			var cell := Vector2i(x, y)
			var id := _id(cell)
			if model.is_solid(cell):
				if _astar.has_point(id):
					_astar.remove_point(id)
					_point_navigation.erase(id)
					changed[cell] = true
				continue
			var data: Dictionary = model.cell_data(cell)
			var weight := maxf(1.0, float(data.movement_cost))
			var navigation_hash: int = hash(model.navigation_data(cell))
			if not _astar.has_point(id):
				_astar.add_point(id,model.cell_center(cell),weight)
				changed[cell] = true
			elif _point_navigation.get(id) != navigation_hash:
				changed[cell] = true
			_astar.set_point_weight_scale(id,weight)
			_point_navigation[id] = navigation_hash
	# 占用改变只重连受影响格及邻域，斜角边也随正交阻挡更新。
	# 不在每次建造/树林恢复后重建整张地图的全部连接。
	var affected := {}
	for cell: Vector2i in changed:
		for dy in range(-1,2):
			for dx in range(-1,2):
				var nearby := cell+Vector2i(dx,dy)
				if model.is_inside(nearby): affected[nearby] = true
	for cell: Vector2i in affected:
		if not _astar.has_point(_id(cell)): continue
		for offset in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP,Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
			var next: Vector2i = cell + offset
			if not model.is_inside(next) or not _astar.has_point(_id(next)): continue
			var connected := _astar.are_points_connected(_id(cell),_id(next))
			if model.can_step(cell,next):
				if not connected: _astar.connect_points(_id(cell),_id(next))
			elif connected:
				_astar.disconnect_points(_id(cell),_id(next))
	_synced_revision = int(model.revision)


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
