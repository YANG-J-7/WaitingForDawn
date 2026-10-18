extends Node
## 在真实地图及资源占用上验证道路、山地落点与农民完整往返。
const MAIN = preload("res://src/main/main.tscn")
const LAYOUT = preload("res://src/gameplay/buildings/map_layout.gd")
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
var failures := 0
var delivered := 0

func _ready() -> void:
	var main := MAIN.instantiate()
	add_child(main)
	main._on_start_pressed()
	main.opening_draft.active = false
	main.wave_controller.set_process(false)
	main.farmer_manager.set_process(false)
	var grid: RefCounted = main.grid_map_model
	var finder: RefCounted = main.grid_pathfinder
	var start: Vector2 = LAYOUT.CITY_POSITION + Vector2(108, 0)
	RunState.start_current_wave()
	RunEconomy.add_resource(&"wood",1000)
	RunEconomy.add_resource(&"stone",1000)
	for site_id in [&"iron_02", &"stone_01", &"stone_02", &"iron_01"]:
		var center: Vector2 = grid.resource_site_center(site_id)
		check(grid.can_place(center, Vector2i(2,2), site_id), "%s保留专属资源建筑落点" % site_id)
		grid.occupy(site_id, center, Vector2i(2,2))
		var outward: PackedVector2Array = finder.find_path(start, center, 60)
		check(not outward.is_empty() and outward[-1].distance_to(center) <= 60, "%s主城到矿场入口可达" % site_id)
		if outward.is_empty():
			continue
		var homeward: PackedVector2Array = finder.find_path(outward[-1], LAYOUT.CITY_POSITION, 96)
		check(not homeward.is_empty(), "%s矿场回城可达" % site_id)
		check(_legal_path(grid, start, outward) and _legal_path(grid, outward[-1], homeward), "%s往返避开水、岩壁和斜角夹缝" % site_id)
		var workplace := Node2D.new()
		workplace.position = center
		add_child(workplace)
		var farmer := FarmerAgent.new()
		add_child(farmer)
		farmer.configure(0, LAYOUT.CITY_POSITION)
		farmer.position = start
		farmer.set_pathfinder(finder)
		farmer.assign_job(site_id, workplace, &"iron" if String(site_id).begins_with("iron") else &"stone", 2)
		delivered = 0
		farmer.delivery_completed.connect(func(_id: StringName, amount: int): delivered += amount)
		var stayed_open := true
		for step in range(4000):
			farmer.advance(0.05)
			stayed_open = stayed_open and not grid.is_solid(grid.world_to_cell(farmer.position))
			if delivered > 0:
				print("METRIC: %s往返耗时=%.2fs 路径点=%d/%d" % [site_id, (step+1)*0.05, outward.size(), homeward.size()])
				break
		check(delivered == 2 and farmer.position.distance_to(LAYOUT.CITY_POSITION) <= 96, "%s真实农民完成采集并交付回城" % site_id)
		check(stayed_open, "%s农民全过程未穿越阻挡" % site_id)
		farmer.queue_free()
		workplace.queue_free()
	for point in [Vector2(2052,108), Vector2(2484,72), Vector2(2592,540), Vector2(3600,540)]:
		print("METRIC: 山地草台 %s 格=%s" % [point, grid.cell_data(grid.world_to_cell(point))])
		check(grid.can_place(point, Vector2i(2,2)), "山区草台可建双格建筑：%s" % point)
		if not grid.is_walkable(grid.world_to_cell(point)):
			check(finder.find_path(start, point).is_empty(), "山区离路草台禁止单位直接走入：%s" % point)
	_check_road_network(grid, start)
	_check_height_gates()
	_check_northwest_cliff(grid,finder)
	# 前景台地边缘同样是石壁，不能把高台到谷底之间的落差当成路肩。
	for source in [Vector2(1005,95),Vector2(1005,130),Vector2(1020,110),Vector2(1025,98)]:
		var point: Vector2 = Definition.source_to_world(source)
		var cell: Vector2i = grid.world_to_cell(point)
		check(grid.cell_data(cell).terrain_type == &"cliff" and grid.is_solid(cell) and not grid.cell_data(cell).buildable, "红圈岩壁明确禁行禁建：%s" % source)
		check(finder.find_path(start,point).is_empty(), "红圈岩壁不能作为寻路终点：%s" % source)
	_check_mountain_units(main,grid,finder)
	for terrain_type in [&"cliff", &"water", &"ramp"]:
		var cells: Array[Vector2i] = grid.cells_of_type(terrain_type)
		check(not cells.is_empty(), "地图存在%s地形" % terrain_type)
		var policy_ok := true
		for cell in cells:
			var data: Dictionary = grid.cell_data(cell)
			policy_ok = policy_ok and not data.buildable and data.walkable == (terrain_type == &"ramp")
		check(policy_ok, "%s全部格遵循行走/禁建规则" % terrain_type)
	var roads: Array[Vector2i] = grid.cells_of_type(&"road")
	var road_ok := not roads.is_empty()
	for cell in roads:
		var data: Dictionary = grid.cell_data(cell)
		road_ok = road_ok and data.walkable and data.buildable and is_equal_approx(data.movement_cost, 1.0)
	check(road_ok, "草地道路可行走、可建造且不增加移动速度")
	check(main.get_node("MountainRoadLayer").get_index() > main.terrain_grid_layer.get_index() and main.get_node("MountainRoadLayer").get_index() < main.get_node("ResourceSites").get_index(), "可见道路位于草地上方、资源与单位下方")
	_test_building_flow(main, grid)
	main._on_reset_pressed()
	check(grid.can_place(Vector2(2052,108), Vector2i(2,2)), "重置释放草台建筑占用")
	check(not finder.find_path(start, grid.resource_site_center(&"iron_01"), 60).is_empty(), "重置后山区资源道路仍可达")
	main.queue_free()
	RunState.reset_to_boot()
	get_tree().quit(failures)

func _test_building_flow(main: Node, grid: RefCounted) -> void:
	var card = preload("res://src/data/cards/farm.tres")
	for point in [Vector2(2052,108), Vector2(2592,540), Vector2(3600,540)]:
		var card_id: int = main.run_card_inventory.add_card(card, 1)
		check(main.placement_preview(card, point).valid, "草台拖牌显示合法预览：%s" % point)
		check(main._try_place_map_building_card(card_id, point), "草台实际建造成功：%s" % point)
		check(not grid.can_place(point, Vector2i(2,2)), "草台建筑写入真实占用：%s" % point)
	var remote := Vector2(2484,72)
	var remote_id: int = main.run_card_inventory.add_card(card, 1)
	var before: int = RunEconomy.amount(&"wood")
	check(not main.placement_preview(card, remote).valid and not main._try_place_map_building_card(remote_id,remote), "离路山区岗位建筑拒绝预览及实际投放")
	check(main.run_card_inventory.has_card(remote_id) and RunEconomy.amount(&"wood")==before, "缺少山路入口时保卡保材料")
	var house = preload("res://src/data/cards/house.tres")
	var house_id: int = main.run_card_inventory.add_card(house,1)
	check(main._try_place_map_building_card(house_id,remote), "无需岗位的民屋仍可建在离路草台")
	var rock: Vector2i = grid.cells_of_type(&"cliff")[0]
	var point: Vector2 = grid.cell_center(rock)
	var card_id: int = main.run_card_inventory.add_card(card, 1)
	var hand_count: int = main.run_card_inventory.card_count()
	var wood: int = RunEconomy.amount(&"wood")
	var stone: int = RunEconomy.amount(&"stone")
	check(not main.placement_preview(card, point).valid, "岩壁拖牌显示非法预览")
	check(not main._try_place_map_building_card(card_id, point), "岩壁拒绝实际建造")
	check(main.run_card_inventory.card_count() == hand_count and RunEconomy.amount(&"wood") == wood and RunEconomy.amount(&"stone") == stone, "岩壁建造失败保留手牌和材料")

func _check_road_network(grid: RefCounted, start: Vector2) -> void:
	var visited := {}
	var pending: Array[Vector2i] = [grid.world_to_cell(start)]
	visited[pending[0]] = true
	var index := 0
	while index < pending.size():
		var cell := pending[index]
		index += 1
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if not visited.has(next) and grid.can_step(cell,next):
				visited[next] = true
				pending.append(next)
	var isolated: Array[Vector2i] = []
	for entry in Definition.navigation_data().cells:
		var cell := Vector2i(entry.cell[0],entry.cell[1])
		if not grid.is_solid(cell) and not visited.has(cell): isolated.append(cell)
	print("METRIC: 资源占用后断开山路格=%s" % [isolated])
	check(isolated.is_empty(), "资源占用后全部开放山路及八处石梯与主城连通")
	var mountain_ok := true
	for cell in grid.cells_of_type(&"mountain_grass"):
		mountain_ok = mountain_ok and not grid.is_walkable(cell) and grid.cell_data(cell).buildable
	check(mountain_ok, "离路山地草台全部禁行且保持地形可建")

func _check_height_gates() -> void:
	var grid = preload("res://src/gameplay/grid/grid_map_model.gd").new()
	grid.set_terrain_rect(Definition.BOUNDS,&"cliff",false,false,INF)
	var cells: Array[Vector2i] = [Vector2i(4,4),Vector2i(5,4),Vector2i(6,4),Vector2i(7,4)]
	grid.set_terrain_cells(cells,&"road",true,true,1)
	grid.set_navigation_cell(cells[0],0)
	grid.set_navigation_cell(cells[1],-1,0,[0])
	grid.set_navigation_cell(cells[2],-1,0,[1])
	grid.set_navigation_cell(cells[3],1)
	var finder = preload("res://src/gameplay/grid/grid_pathfinder.gd").new(grid)
	var a: Vector2 = grid.cell_center(cells[0])
	var b: Vector2 = grid.cell_center(cells[3])
	check(not finder.find_path(a,b).is_empty() and not finder.find_path(b,a).is_empty(), "不同高度通过同一石梯双向连接")
	var follower = preload("res://src/gameplay/grid/grid_path_follower.gd").new()
	follower.set_pathfinder(finder)
	var movement: Dictionary = follower.advance(a,b,0,80,.05)
	var stopped_at: Vector2 = movement.position
	var blocked: Array[Vector2i] = [cells[2]]
	grid.set_terrain_cells(blocked,&"cliff",false,false,INF)
	check(finder.find_path(a,b).is_empty() and finder.find_path(b,a).is_empty(), "封闭石梯后双向缓存路径立即失效")
	movement = follower.advance(stopped_at,b,0,80,2)
	check(not movement.has_path and movement.position == stopped_at, "移动中的单位遇到封闭石梯会停步，不越过岩壁")
	grid.set_terrain_cells(blocked,&"ramp",true,false,1)
	var reopened: PackedVector2Array = finder.find_path(a,b)
	check(not reopened.is_empty() and _legal_path(grid,a,reopened), "石梯恢复后重新连接跨层路线")
	for step in range(50):
		movement = follower.advance(stopped_at,b,0,80,.05)
		stopped_at = movement.position
		if movement.arrived: break
	check(movement.arrived and stopped_at == b, "封路解除后原单位自动重新寻路并到达")
	check(not grid.can_step(cells[0],cells[2]) and not grid.can_step(cells[1],cells[3]), "单位不能从石梯中段跳进异层道路")
	grid.set_navigation_cell(cells[2],-1,1,[1])
	check(finder.find_path(a,b).is_empty(), "不同编号石梯即使相邻也不能拼接跨层")
	grid.set_navigation_cell(cells[1],0)
	grid.set_navigation_cell(cells[2],1)
	check(finder.find_path(a,b).is_empty(), "两层山路即使直接相邻也不能翻越高度差")
	check(finder.find_path(grid.cell_center(Vector2i(4,3)),b).is_empty(), "错误落在岩壁的单位不会瞬移接入道路")

func _check_mountain_units(main: Node,grid: RefCounted,finder: RefCounted) -> void:
	var entry: PackedVector2Array = finder.find_path(LAYOUT.CITY_POSITION+Vector2(108,0),grid.resource_site_center(&"iron_01"),60)
	if entry.is_empty():
		check(false,"山区单位移动夹具有真实入口")
		return
	var start: Vector2 = entry[-1]
	var enemy := preload("res://src/gameplay/enemies/enemy.tscn").instantiate() as EnemyActor
	main.add_child(enemy)
	enemy.configure(preload("res://src/data/enemies/wolf.tres"),start,LAYOUT.CITY_POSITION)
	enemy.set_pathfinder(finder)
	enemy.set_physics_process(false)
	var legal := true
	var stairs := false
	var last: Vector2i = grid.world_to_cell(start)
	for step in range(6000):
		enemy._physics_process(.05)
		var cell: Vector2i = grid.world_to_cell(enemy.position)
		legal = legal and not grid.is_solid(cell) and (cell==last or grid.can_step(last,cell))
		stairs = stairs or grid.cell_data(cell).terrain_type == &"ramp"
		last = cell
		if enemy.has_reached_target: break
	check(enemy.has_reached_target and legal and stairs,"真实野狼从山区沿山路、石梯下山到主城，逐帧无翻岩跨层")
	enemy.position = LAYOUT.CITY_POSITION+Vector2(108,0)
	enemy.active = true
	var guard := preload("res://src/gameplay/defenses/barracks_guard.tscn").instantiate() as BarracksGuard
	main.add_child(guard)
	guard.configure(preload("res://src/data/defenses/barracks_guard.tres"),0)
	guard.position = start
	guard.set_process(false)
	guard.set_pathfinder(finder)
	guard.engage_enemy(enemy)
	legal = true
	stairs = false
	last = grid.world_to_cell(start)
	for step in range(6000):
		guard._process(.05)
		var cell: Vector2i = grid.world_to_cell(guard.position)
		legal = legal and not grid.is_solid(cell) and (cell==last or grid.can_step(last,cell))
		stairs = stairs or grid.cell_data(cell).terrain_type == &"ramp"
		last = cell
		if guard.position.distance_to(enemy.position)<=guard.definition.attack_range_pixels: break
	check(guard.position.distance_to(enemy.position)<=guard.definition.attack_range_pixels and legal and stairs,"真实守卫从山区沿山路、石梯接近目标，逐帧无翻岩跨层")
	guard.free()
	enemy.free()

func _check_northwest_cliff(grid: RefCounted,finder: RefCounted) -> void:
	# 2026-10-17新截图：石梯西侧竖直岩壁不能当成通行路肩。
	for source in [Vector2(980,74),Vector2(1000,74),Vector2(1020,74),Vector2(1040,80)]:
		var cell: Vector2i = grid.world_to_cell(Definition.source_to_world(source))
		var point: Vector2 = grid.cell_center(cell)
		check(grid.cell_data(cell).terrain_type == &"cliff" and grid.is_solid(cell) and not grid.can_place(point,Vector2i.ONE), "新增红框石壁禁止通行和建造：%s" % source)
		check(finder.find_path(LAYOUT.CITY_POSITION+Vector2(108,0),point).is_empty(), "新增红框石壁不能成为路径终点：%s" % source)
	var a: Vector2 = grid.cell_center(grid.world_to_cell(Definition.source_to_world(Vector2(930,70))))
	var b: Vector2 = grid.cell_center(grid.world_to_cell(Definition.source_to_world(Vector2(1086,62))))
	var route: PackedVector2Array = finder.find_path(a,b)
	var uses_stair := false
	var uses_west_descent := false
	for point in route:
		uses_stair = uses_stair or grid.navigation_data(grid.world_to_cell(point)).stair == 2
		uses_west_descent = uses_west_descent or grid.navigation_data(grid.world_to_cell(point)).stair == 1
	check(not route.is_empty() and _legal_path(grid,a,route) and uses_stair and uses_west_descent, "西侧高台必须先走西侧石梯下山，再沿谷底进入北侧石梯")
	var sealed = preload("res://src/gameplay/grid/grid_map_model.gd").new()
	preload("res://src/gameplay/grid/terrain_map_data.gd").apply_to(sealed)
	var west_stairs: Array[Vector2i] = []
	for entry in Definition.navigation_data().cells:
		if int(entry.stair) == 1: west_stairs.append(Vector2i(entry.cell[0],entry.cell[1]))
	sealed.set_terrain_cells(west_stairs,&"cliff",false,false,INF)
	var sealed_finder = preload("res://src/gameplay/grid/grid_pathfinder.gd").new(sealed)
	check(sealed_finder.find_path(a,b).is_empty(), "西侧下山石梯封闭后高台无法离开，不能回退到穿石壁短路")
	var valley: Vector2 = grid.cell_center(grid.world_to_cell(Definition.source_to_world(Vector2(1080,143))))
	var approach: PackedVector2Array = finder.find_path(valley,b)
	check(not approach.is_empty() and approach.size()<25 and _legal_path(grid,valley,approach), "谷底山路连续接入北侧石梯，无需穿过前景高台")
	var follower = preload("res://src/gameplay/grid/grid_path_follower.gd").new()
	follower.set_pathfinder(finder)
	var current := a
	var legal := true
	var arrived := false
	var travel_seconds := 0.0
	var rocks: Array[PackedVector2Array] = []
	for polygon in Definition.navigation_data().hardCliffs:
		rocks.append(Definition.polygon_world(polygon))
	for step in range(10000):
		var movement: Dictionary = follower.advance(current,b,0,80,.02)
		travel_seconds += .02
		current = movement.position
		legal = legal and not grid.is_solid(grid.world_to_cell(current))
		for rock in rocks:
			legal = legal and not Geometry2D.is_point_in_polygon(current,rock)
		if movement.arrived:
			arrived = true
			break
	check(arrived and legal, "逐帧脚点沿高台石梯与谷底绕行，不进入前后两面石壁")
	print("METRIC: 西北高台经西侧下山再沿谷底到北侧石梯 路径点=%d 通行=%.2fs" % [route.size(),travel_seconds])

func _legal_path(grid: RefCounted, start: Vector2, path: PackedVector2Array) -> bool:
	var last: Vector2i = grid.world_to_cell(start)
	for point in path:
		var cell: Vector2i = grid.world_to_cell(point)
		if grid.is_solid(cell):
			return false
		if cell != last and not grid.can_step(last,cell): return false
		last = cell
	return true

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
