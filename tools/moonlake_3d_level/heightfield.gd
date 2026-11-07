extends RefCounted
## 只从关卡编译数据和权威格推导表现高度。

const LEVEL_HEIGHT := 3.2
const WATER_HEIGHT := -0.36
const BASE_HEIGHT := -0.9
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
				const S6_HEIGHTS := [0.0, 1.6, 1.6, 1.6, 2.6, LEVEL_HEIGHT]
				closest_height = lerpf(S6_HEIGHTS[i], S6_HEIGHTS[i + 1], offset / segment_length)
			else:
				closest_height = lerpf(levels.x, levels.y, (walked + offset) / length) * LEVEL_HEIGHT
		walked += segment_length
	return snappedf(closest_height, 0.4)
