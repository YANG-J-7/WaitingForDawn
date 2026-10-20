extends Node
## 用必须先远离主城的弯路验证索敌，避免直线判断掩盖山路问题。
const Grid = preload("res://src/gameplay/grid/grid_map_model.gd")
const Finder = preload("res://src/gameplay/grid/grid_pathfinder.gd")
const WOLF = preload("res://src/data/enemies/wolf.tres")
const GUARD = preload("res://src/data/defenses/barracks_guard.tres")
var failures := 0

func _ready() -> void:
	RunState.reset_to_boot()
	RunState.begin_new_run()
	RunState.start_current_wave()
	_test_bent_route()
	_test_spawn_plan()
	_test_blocking_wall()
	_test_nearest_access()
	await _test_real_spawns()
	RunState.reset_to_boot()
	get_tree().quit(failures)

func _fixture() -> WaveController:
	var grid = Grid.new()
	grid.set_terrain_rect(Grid.MAP_BOUNDS,&"cliff",false,false,INF)
	var cells: Array[Vector2i] = []
	for x in range(2,7): cells.append(Vector2i(x,2))
	for y in range(2,11):
		cells.append(Vector2i(2,y))
		cells.append(Vector2i(17,y))
	for x in range(2,18): cells.append(Vector2i(x,10))
	grid.set_terrain_cells(cells,&"road",true,true,1)
	var controller := WaveController.new()
	add_child(controller)
	controller.set_process(false)
	controller.city_target_position=Vector2(630,90)
	controller.set_pathfinder(Finder.new(grid))
	return controller

func _enemy(controller: WaveController) -> EnemyActor:
	var enemy := EnemyActor.new()
	controller.add_child(enemy)
	enemy.configure(WOLF,Vector2(234,90),controller.city_target_position)
	enemy.set_pathfinder(controller.pathfinder)
	enemy.set_physics_process(false)
	enemy.world_target_attack_requested.connect(controller._on_enemy_world_target_attack_requested)
	controller.enemies.append(enemy)
	return enemy

func _farmer(controller: WaveController,point: Vector2) -> FarmerAgent:
	var farmer := FarmerAgent.new()
	controller.add_child(farmer)
	farmer.configure(0,controller.city_target_position)
	farmer.global_position=point
	return farmer

func _test_bent_route() -> void:
	var controller := _fixture()
	var enemy := _enemy(controller)
	var near := _farmer(controller,Vector2(90,126))
	var far := _farmer(controller,Vector2(90,270))
	var false_straight := _farmer(controller,Vector2(342,90))
	controller.set_world_targets([false_straight,far,near])
	check(enemy.world_target==near,"必须先远离主城的真实弯路优先最近农民，不受数组与直线影响")
	var legal := true
	for step in range(100):
		controller._assign_defensive_targets()
		enemy._physics_process(.05)
		legal=legal and not controller.pathfinder.model.is_solid(controller.pathfinder.model.world_to_cell(enemy.global_position))
		if near.current_health<near.maximum_health: break
	check(near.current_health<near.maximum_health,"野狼沿合法弯路实际走到并攻击最近农民")
	check(legal and false_straight.current_health==false_straight.maximum_health,"不穿岩壁，也不攻击原直线上的不可达目标")
	near.apply_enemy_attack(999,&"wolf")
	enemy._physics_process(.01)
	controller._assign_defensive_targets()
	check(enemy.world_target==far,"最近目标死亡后接力攻击后续路线目标")
	far.global_position=Vector2(342,90)
	controller._assign_defensive_targets()
	check(enemy.attack_target_kind==&"city","移动目标离开真实路线后恢复进城")
	var guard := BarracksGuard.new()
	controller.add_child(guard)
	guard.configure(GUARD,0)
	guard.global_position=Vector2(90,234)
	guard.set_pathfinder(controller.pathfinder)
	guard.set_process(false)
	controller.set_world_targets([guard])
	check(enemy.guard_target==guard,"弯曲进城路线上的守卫可拦截野狼")
	guard.dismiss()
	controller.set_world_targets([])
	check(enemy.attack_target_kind==&"city","守卫失效后释放交战并恢复进城")
	controller.queue_free()

func _test_spawn_plan() -> void:
	var controller := _fixture()
	controller.wave_definition=preload("res://src/data/waves/wave_01.tres")
	controller.spawn_points=[Vector2(234,90)]
	controller.start_first_wave()
	controller._spawn_enemy()
	controller.spawning=false
	var enemy: EnemyActor=controller.enemies[0]
	enemy.set_physics_process(false)
	var path: PackedVector2Array=enemy.path_follower.path
	check(not path.is_empty(),"野狼出生即确定主城路线，无需等首次移动")
	var expected: PackedVector2Array=controller.pathfinder.find_path(enemy.global_position,controller.city_target_position,96)
	check(path==expected,"出生默认路线与最短合法主城入口路线一致")
	controller.queue_free()

func _test_blocking_wall() -> void:
	var controller := _fixture()
	var enemy := _enemy(controller)
	var wall := BarrierWall.new()
	controller.add_child(wall)
	wall.global_position=Vector2(90,234)
	wall.build(preload("res://src/data/cards/wall.tres"))
	var grid: RefCounted=controller.pathfinder.model
	check(grid.occupy(&"test_wall",wall.global_position,Vector2i.ONE),"封路夹具写入真实静态占用")
	var far := _farmer(controller,Vector2(90,306))
	controller.world_targets=[far]
	controller.set_barrier_walls([wall])
	enemy.barrier_attack_requested.connect(controller._on_enemy_barrier_attack_requested)
	check(enemy.barrier_target==wall and enemy.city_route.is_empty(),"主城路被完全封死时选择真实通路上的可达封路墙")
	var legal := true
	for step in range(160):
		controller._assign_defensive_targets()
		enemy._physics_process(.05)
		legal=legal and not grid.is_solid(grid.world_to_cell(enemy.global_position))
		if wall.current_health<wall.maximum_health: break
	check(legal and wall.current_health<wall.maximum_health,"封路后沿可达攻击入口破墙，不走穿忽略占用的参考线")
	check(far.current_health==far.maximum_health,"墙后的农民不能隔墙受到近战伤害")
	wall.apply_enemy_attack(9999,&"wolf")
	grid.release(&"test_wall")
	controller.set_barrier_walls([])
	check(enemy.world_target==far and not enemy.city_route.is_empty(),"破墙释放占用后恢复进城路径并接力最近目标")
	controller.set_world_targets([])
	# 无可攻击物的地形封闭不能被破障参考网格忽略。
	var closed: Array[Vector2i] = [Vector2i(2,8)]
	grid.set_terrain_cells(closed,&"cliff",false,false,INF)
	controller._assign_defensive_targets()
	var before := enemy.global_position
	for step in range(5): enemy._physics_process(.1)
	check(enemy.global_position==before,"地形完全断路时停止，不能把岩壁当可破坏建筑穿过")
	controller.queue_free()

func _test_nearest_access() -> void:
	var controller := WaveController.new()
	add_child(controller)
	controller.set_process(false)
	controller.city_target_position=Vector2(738,198)
	var grid = Grid.new()
	controller.set_pathfinder(Finder.new(grid))
	var enemy := EnemyActor.new()
	controller.add_child(enemy)
	enemy.configure(WOLF,Vector2(90,198),controller.city_target_position)
	enemy.set_pathfinder(controller.pathfinder)
	enemy.set_physics_process(false)
	controller.enemies=[enemy]
	var near := _farmer(controller,Vector2(234,198))
	var far := _farmer(controller,Vector2(378,198))
	var behind := _farmer(controller,Vector2(54,198))
	var off_route := _farmer(controller,Vector2(126,306))
	controller.set_world_targets([far,behind,off_route,near])
	check(enemy.world_target==near,"多目标按可达攻击距离选最近，不追身后及路线外单位")
	enemy.path_follower.prepare(enemy.global_position,near.global_position,50)
	enemy.attack_elapsed=.45
	var unchanged: int = enemy.path_follower.path_revision
	for step in range(20): controller._assign_defensive_targets()
	check(enemy.world_target==near and enemy.path_follower.path_revision==unchanged and enemy.attack_elapsed==.45,"目标未变化时连续扫描不重置战斗路径或攻击计时")
	near.apply_enemy_attack(999,&"wolf")
	controller._assign_defensive_targets()
	check(enemy.world_target==far,"最近者失效后选择下一可达目标")
	var newcomer := _farmer(controller,Vector2(198,198))
	controller.set_world_targets([far,newcomer])
	check(enemy.world_target==newcomer,"途中出现更近可攻击单位时切换到最近者")
	controller.set_world_targets([far])
	far.global_position=Vector2(234,198)
	enemy.world_target_attack_requested.connect(controller._on_enemy_world_target_attack_requested)
	for step in range(100):
		controller._assign_defensive_targets()
		enemy._physics_process(.05)
		if far.current_health<far.maximum_health: break
	var contact_start := enemy.global_position
	far.global_position.x+=17
	var health_before := far.current_health
	for step in range(100):
		controller._assign_defensive_targets()
		enemy._physics_process(.05)
		if far.current_health<health_before: break
	check(enemy.global_position!=contact_start and far.current_health<health_before,"移动目标只挪17像素脱离近战后重新接近，不在旧终点停死或隔空攻击")
	controller.queue_free()
	var bent := _fixture()
	var wolf := _enemy(bent)
	var near_on_path := _farmer(bent,Vector2(90,378))
	var near_in_air := _farmer(bent,Vector2(270,378))
	bent.set_world_targets([near_in_air,near_on_path])
	check(wolf.world_target==near_on_path and wolf.global_position.distance_to(near_on_path.global_position)>wolf.global_position.distance_to(near_in_air.global_position),"最近按实际路程判定，即使另一目标直线更近也不绕远追逐")
	bent.queue_free()

func _test_real_spawns() -> void:
	RunState.reset_to_boot()
	var main := preload("res://src/main/main.tscn").instantiate()
	add_child(main)
	main._on_start_pressed()
	main.opening_draft.active=false
	main.farmer_manager.set_process(false)
	var controller: WaveController=main.wave_controller
	controller.set_process(false)
	controller.set_world_targets([])
	RunState.start_current_wave()
	controller.start_first_wave()
	var oracle := preload("res://tests/test_junction_routes.gd").new()
	for index in range(4):
		controller._spawn_enemy()
		var enemy: EnemyActor=controller.enemies[-1]
		enemy.set_physics_process(false)
		var path: PackedVector2Array=enemy.path_follower.path
		var grid: RefCounted=main.grid_map_model
		check(not path.is_empty() and oracle._legal(grid,enemy.global_position,path),"真实地图出生即规划合法主城路，遵守岩壁与石梯：%d" % index)
		var optimum: float=oracle._best_distance(grid,oracle._distances(grid,grid.world_to_cell(enemy.global_position)),controller.city_target_position,96)
		var cost: float=oracle._cost(grid,enemy.global_position,path)
		check(absf(cost-optimum)<.01,"真实地图出生路线与独立Dijkstra最短代价一致：%d" % index)
		print("METRIC: 出生%d 最短进城代价=%.2f 路径点=%d" % [index,cost,path.size()])
		var stayed_legal := true
		for step in range(2000):
			enemy._physics_process(.1)
			stayed_legal=stayed_legal and not grid.is_solid(grid.world_to_cell(enemy.global_position))
			if enemy.has_reached_target: break
		check(stayed_legal and enemy.has_reached_target,"真实野狼按出生路径抵达主城外围：%d" % index)
		# 不让前一只在受控步进中持续攻击主城。
		enemy.stop()
	oracle.free()
	main.queue_free()
	await get_tree().process_frame

func check(value: bool,label: String) -> void:
	if value: print("PASS: "+label)
	else:
		failures+=1
		push_error("FAIL: "+label)
