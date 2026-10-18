extends Node

const GridMapModelScript = preload("res://src/gameplay/grid/grid_map_model.gd")
const GridPathfinderScript = preload("res://src/gameplay/grid/grid_pathfinder.gd")

var failures: int = 0


func _ready() -> void:
	var model = GridMapModelScript.new()
	var pathfinder = GridPathfinderScript.new(model)
	model.set_terrain_rect(Rect2(360, 0, 36, 360), &"water", false, false, INF)
	var path: PackedVector2Array = pathfinder.find_path(Vector2(90, 90), Vector2(630, 90))
	check(path.size() > 0, "网格寻路可绕过有限湖水阻挡")
	var all_walkable := true
	var went_around := false
	for point in path:
		all_walkable = all_walkable and bool(model.cell_data(model.world_to_cell(point)).walkable)
		went_around = went_around or point.y > 360.0
	check(all_walkable, "路径只经过可行走地形")
	check(went_around, "路径从水域末端绕行")

	var blocker_center := model.snap_footprint_center(Vector2(234, 378), Vector2i.ONE)
	check(model.occupy(&"wall", blocker_center, Vector2i.ONE), "测试城墙写入静态占用")
	var blocked_path: PackedVector2Array = pathfinder.find_path(Vector2(90, 378), Vector2(450, 378))
	check(blocked_path.size() > 0 and blocker_center not in blocked_path, "路径重建后绕开新增城墙")
	model.release(&"wall")
	var reopened_path: PackedVector2Array = pathfinder.find_path(Vector2(90, 378), Vector2(450, 378))
	check(blocker_center in reopened_path, "城墙释放后路径恢复穿过原格")

	var building_center := model.snap_footprint_center(Vector2(720, 540), Vector2i(2, 2))
	check(model.occupy(&"building", building_center, Vector2i(2, 2)), "测试建筑占用2×2格")
	var approach: PackedVector2Array = pathfinder.find_path(Vector2(450, 540), building_center, 60.0)
	check(approach.size() > 0, "可寻路到被占用建筑的外围交互格")
	check(approach[-1].distance_to(building_center) <= 60.0, "路径终点位于建筑交互距离内")
	check(not model.is_solid(model.world_to_cell(approach[-1])), "建筑外围终点保持可行走")

	_test_corner_rule()
	_test_spawn_occupancy()
	get_tree().quit(failures)


func _test_corner_rule() -> void:
	var model = GridMapModelScript.new()
	var origin := model.cell_center(Vector2i(4, 4))
	model.occupy(&"right", model.cell_center(Vector2i(5, 4)), Vector2i.ONE)
	model.occupy(&"down", model.cell_center(Vector2i(4, 5)), Vector2i.ONE)
	var pathfinder = GridPathfinderScript.new(model)
	var path: PackedVector2Array = pathfinder.find_path(origin, model.cell_center(Vector2i(5, 5)))
	check(path.size() == 0 or path[0] != model.cell_center(Vector2i(5, 5)), "两个正交障碍夹角禁止对角穿越")


func _test_spawn_occupancy() -> void:
	var model = GridMapModelScript.new()
	var finder = GridPathfinderScript.new(model)
	var preferred: Vector2 = model.cell_center(Vector2i(8,8))
	var anchor := preferred + Vector2(72,0)
	check(finder.spawn_position(preferred,anchor,216) == preferred, "空闲待命点优先采用合法预定脚点")
	check(model.occupy(&"new_wall",preferred,Vector2i.ONE), "待命脚点可以被新建筑占用")
	var alternate: Vector2 = finder.spawn_position(preferred,anchor,216)
	check(alternate != preferred and not model.is_solid(model.world_to_cell(alternate)), "建筑占用变化立即清除脚点缓存并选择新落点")
	model.release(&"new_wall")
	check(finder.spawn_position(preferred,anchor,216) == preferred, "建筑释放后脚点缓存恢复原合法落点")


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
