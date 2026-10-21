extends Node

const GridMapModelScript = preload("res://src/gameplay/grid/grid_map_model.gd")

var failures: int = 0


func _ready() -> void:
	var grid = GridMapModelScript.new()
	check(grid.grid_size == Vector2i(196, 80), "7056×2880地图建立196×80逻辑网格")
	check(grid.world_to_cell(Vector2(0, 0)) == Vector2i(0, 0), "地图原点转换到首格")
	check(grid.world_to_cell(Vector2(1380, 1030)) == Vector2i(38, 28), "世界坐标转换到预期格")
	check(grid.cell_center(Vector2i(38, 28)).is_equal_approx(Vector2(1386, 1026)), "格坐标转换到36像素格中心")
	check(grid.snap_footprint_center(Vector2(700, 270), Vector2i.ONE).is_equal_approx(Vector2(702, 270)), "单格建筑吸附到格中心")
	check(grid.snap_footprint_center(Vector2(760, 1080), Vector2i(2, 2)).is_equal_approx(Vector2(756, 1080)), "双格建筑吸附到占地区域中心")

	grid.set_terrain_rect(Rect2(2200, 1050, 680, 570), &"water", false, false, INF)
	check(not grid.can_place(Vector2(2400, 1350), Vector2i.ONE), "湖水格拒绝建筑")
	check(grid.can_place(Vector2(800, 1000), Vector2i(2, 2)), "草地允许双格建筑")

	var center := grid.snap_footprint_center(Vector2(800, 1000), Vector2i(2, 2))
	check(grid.occupy(&"building_a", center, Vector2i(2, 2)), "合法建筑写入四格静态占用")
	check(not grid.can_place(center, Vector2i.ONE), "静态占用格拒绝重叠建筑")
	check(grid.occupied_cells_for(&"building_a").size() == 4, "2×2建筑记录四个占用格")
	grid.release(&"building_a")
	check(grid.can_place(center, Vector2i(2, 2)), "建筑释放后格位恢复可建造")

	grid.register_resource_site(&"forest_01", &"forest", Vector2(900, 360), Vector2i(2, 2))
	var site_center: Vector2 = grid.resource_site_center(&"forest_01")
	check(not grid.can_place(site_center, Vector2i(2, 2)), "普通建筑不能占用资源格")
	check(grid.can_place(site_center, Vector2i(2, 2), &"forest_01"), "对应资源建筑可以占用完整资源格")
	check(not grid.can_place(site_center, Vector2i.ONE, &"forest_01"), "资源建筑占地必须与资源点一致")

	get_tree().quit(failures)


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
