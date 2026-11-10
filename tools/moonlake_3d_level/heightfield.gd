extends RefCounted
## 只从关卡编译数据和权威格推导表现高度。

const LEVEL_HEIGHT := 5.6
const S6_HEIGHT_RATIOS := [0.0, 0.5, 0.5, 0.5, 0.8125, 1.0]
const WATER_HEIGHT := -0.36
const BASE_HEIGHT := -0.9
const RAY_EPS := 0.00001
const COLORS := {
	"grass": Color("#739371"), "mountain_grass": Color("#648777"),
	"forest": Color("#49685b"), "boundary": Color("#465967"),
	"water": Color("#31687d"), "shore": Color("#8d8261"),
	"road": Color("#988668"), "ramp": Color("#c5a47d"),
	"cliff": Color("#626d79"), "resource": Color("#739371"),
}

var size := Vector2i.ZERO
var cell_size := 36.0
var kinds := PackedStringArray()
var heights := PackedFloat32Array()
var stair_paths: Dictionary[int, PackedVector2Array] = {}


func configure(runtime: LevelMapRuntime, grid: GridMapModel) -> void:
	size = runtime.grid_size
	cell_size = float(runtime.definition.cell_size)
	kinds.resize(size.x * size.y)
	heights.resize(kinds.size())
	for y in range(size.y):
		for x in range(size.x):
			var cell := Vector2i(x, y)
			var key := index(cell)
			kinds[key] = str(grid.cell_data(cell).terrain_type)
			if kinds[key] == "water":
				heights[key] = WATER_HEIGHT
	for module in runtime.modules:
		if module.role != "mountain":
			continue
		for path: Dictionary in module.payload.paths:
			if path.kind != "stair":
				continue
			var points := PackedVector2Array()
			for pair: Array in path.points:
				points.append((Vector2(pair[0], pair[1]) + Vector2(module.origin)) / cell_size)
			stair_paths[int(path.id.get_slice("_", 1))] = points

	var levels: Dictionary[int, Vector2] = {}
	for entry: Dictionary in runtime.navigation.stairs:
		levels[int(entry.id)] = Vector2(entry.fromLevel, entry.toLevel)
	var seeds: Array[Vector2i] = []
	for entry: Dictionary in runtime.navigation.cells:
		var cell := Vector2i(entry.cell[0], entry.cell[1])
		var key := index(cell)
		if kinds[key] not in ["road", "ramp"]:
			continue
		if entry.stair >= 0:
			var stair_id := int(entry.stair)
			heights[key] = _stair_height(stair_id, Vector2(cell) + Vector2(0.5, 0.5), levels[stair_id])
		else:
			heights[key] = LEVEL_HEIGHT * float(entry.level)
			seeds.append(cell)
	_spread_plateaus(seeds)
	for entry: Dictionary in runtime.resource_sites():
		var center := grid.resource_site_center(StringName(entry.id))
		var cells := grid.footprint_cells(center, Vector2i(2, 2))
		var elevation := height(grid.world_to_cell(center))
		for cell in cells:
			heights[index(cell)] = elevation


func index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x


func inside(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, size).has_point(cell)


func height(cell: Vector2i) -> float:
	return heights[index(cell)] if inside(cell) else BASE_HEIGHT


func kind(cell: Vector2i) -> String:
	return kinds[index(cell)]


func surface_position(world: Vector2) -> Vector3:
	var local := world / cell_size
	return Vector3(local.x, maxf(BASE_HEIGHT, height(Vector2i(floori(local.x), floori(local.y)))), local.y)


func camera_height(world: Vector2) -> float:
	# 镜头平滑跨过格边，拾取和单位脚点仍使用精确的地形高度。
	var sample := (world / cell_size - Vector2.ONE * 0.5).clamp(Vector2.ZERO, Vector2(size - Vector2i.ONE))
	var first := Vector2i(sample.floor())
	var last := (first + Vector2i.ONE).min(size - Vector2i.ONE)
	var fraction := sample - Vector2(first)
	var near := lerpf(height(first), height(Vector2i(last.x, first.y)), fraction.x)
	var far := lerpf(height(Vector2i(first.x, last.y)), height(last), fraction.x)
	return lerpf(near, far, fraction.y)


func pick_ray(origin: Vector3, direction: Vector3) -> Dictionary:
	if direction.y >= -RAY_EPS:
		return {}
	var start := Vector2(origin.x, origin.z)
	var ray := Vector2(direction.x, direction.z)
	var step := Vector2i(signf(ray.x), signf(ray.y))
	var entry := 0.0
	var limit := INF
	# 先裁到关卡范围，再按射线与格边交点的顺序走格。
	for axis in range(2):
		if absf(ray[axis]) <= RAY_EPS:
			if start[axis] < 0.0 or start[axis] >= size[axis]:
				return {}
			step[axis] = 0
			continue
		var first := -start[axis] / ray[axis]
		var last := (size[axis] - start[axis]) / ray[axis]
		entry = maxf(entry, minf(first, last))
		limit = minf(limit, maxf(first, last))
	if limit <= entry:
		return {}
	# Vector2 的浮点舍入会把边界入射点算回地图外，先向内采样再夹到合法索引。
	var at_entry := start + ray * minf(entry + 0.0002, (entry + limit) * 0.5)
	var cell := Vector2i(floori(at_entry.x), floori(at_entry.y)).clamp(Vector2i.ZERO, size - Vector2i.ONE)
	var previous_height := BASE_HEIGHT
	while inside(cell) and entry < limit:
		var cross_x := _next_crossing(start.x, ray.x, cell.x, step.x)
		var cross_z := _next_crossing(start.y, ray.y, cell.y, step.y)
		var exit := minf(limit, minf(cross_x, cross_z))
		var altitude := height(cell)
		var entry_y := origin.y + direction.y * entry
		if entry_y < altitude - RAY_EPS and entry_y >= previous_height - RAY_EPS:
			return _ray_hit(start + ray * entry, cell, false)
		var top := (altitude - origin.y) / direction.y
		if top >= entry - RAY_EPS and top <= exit + RAY_EPS:
			return _ray_hit(start + ray * top, cell, true)
		# 同时经过角点时跨到对角格，避免拾取只有一个角接触的格。
		if cross_x <= exit + RAY_EPS:
			cell.x += step.x
		if cross_z <= exit + RAY_EPS:
			cell.y += step.y
		entry = exit
		previous_height = altitude
	return {}


func _next_crossing(origin: float, direction: float, cell: int, step: int) -> float:
	if step == 0:
		return INF
	return (cell + int(step > 0) - origin) / direction


func _ray_hit(point: Vector2, cell: Vector2i, top: bool) -> Dictionary:
	var inset := Vector2.ONE * RAY_EPS
	var inside_cell := point.clamp(Vector2(cell) + inset, Vector2(cell + Vector2i.ONE) - inset)
	return {"world": inside_cell * cell_size, "cell": cell, "top": top}


func _spread_plateaus(seeds: Array[Vector2i]) -> void:
	var propagated := PackedFloat32Array()
	propagated.resize(heights.size())
	propagated.fill(-1.0)
	for cell in seeds:
		propagated[index(cell)] = height(cell)
	var next := 0
	while next < seeds.size():
		var cell := seeds[next]
		next += 1
		var elevation := propagated[index(cell)]
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor: Vector2i = cell + offset
			if not inside(neighbor):
				continue
			var key := index(neighbor)
			if propagated[key] >= 0.0 or kinds[key] not in ["mountain_grass", "cliff", "resource"]:
				continue
			propagated[key] = elevation
			seeds.append(neighbor)
			heights[key] = elevation
	for key in range(kinds.size()):
		if kinds[key] == "cliff":
			heights[key] = maxf(0.74, heights[key] * 0.82 + 0.57) + float(key % 3) * 0.16


func _stair_height(id: int, point: Vector2, levels: Vector2) -> float:
	var path: PackedVector2Array = stair_paths[id]
	var length := 0.0
	for i in range(path.size() - 1):
		length += path[i].distance_to(path[i + 1])
	var nearest_distance := INF
	var closest_height := levels.x * LEVEL_HEIGHT
	var walked := 0.0
	for i in range(path.size() - 1):
		var a := path[i]
		var b := path[i + 1]
		var nearest := Geometry2D.get_closest_point_to_segment(point, a, b)
		var distance := nearest.distance_squared_to(point)
		var segment_length := a.distance_to(b)
		if distance < nearest_distance:
			nearest_distance = distance
			var offset := a.distance_to(nearest)
			if id == 6:
				closest_height = lerpf(S6_HEIGHT_RATIOS[i], S6_HEIGHT_RATIOS[i + 1], offset / segment_length) * LEVEL_HEIGHT
			else:
				closest_height = lerpf(levels.x, levels.y, (walked + offset) / length) * LEVEL_HEIGHT
		walked += segment_length
	return snappedf(closest_height, 0.4)
