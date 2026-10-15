extends Node

const GridMapModelScript = preload("res://src/gameplay/grid/grid_map_model.gd")
const GridPathfinderScript = preload("res://src/gameplay/grid/grid_pathfinder.gd")
const ENEMY_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy.tscn")
const GUARD_SCENE: PackedScene = preload("res://src/gameplay/defenses/barracks_guard.tscn")
const WOLF: EnemyDefinition = preload("res://src/data/enemies/wolf.tres")
const GUARD: GuardDefinition = preload("res://src/data/defenses/barracks_guard.tres")
const MAIN_SCENE: PackedScene = preload("res://src/main/main.tscn")
const MapLayout = preload("res://src/gameplay/buildings/map_layout.gd")

var failures: int = 0


func _ready() -> void:
	RunState.reset_to_boot()
	RunState.begin_new_run()
	RunState.start_current_wave()
	_test_enemy_route()
	_test_farmer_route()
	_test_guard_route()
	RunState.reset_to_boot()
	await _test_main_spawn_routes()
	get_tree().quit(failures)


func _navigation_fixture() -> Array:
	var model = GridMapModelScript.new()
	model.set_terrain_rect(Rect2(360, 0, 36, 360), &"water", false, false, INF)
	return [model, GridPathfinderScript.new(model)]


func _test_enemy_route() -> void:
	var fixture := _navigation_fixture()
	var model = fixture[0]
	var pathfinder = fixture[1]
	var enemy := ENEMY_SCENE.instantiate() as EnemyActor
	add_child(enemy)
	enemy.configure(WOLF, Vector2(90, 90), Vector2(630, 90))
	enemy.set_pathfinder(pathfinder)
	enemy.set_physics_process(false)
	var maximum_y := enemy.global_position.y
	var stayed_walkable := true
	for _step in range(600):
		enemy._physics_process(0.05)
		maximum_y = maxf(maximum_y, enemy.global_position.y)
		stayed_walkable = stayed_walkable and not model.is_solid(model.world_to_cell(enemy.global_position))
		if enemy.has_reached_target:
			break
	check(enemy.has_reached_target, "敌人沿网格路径到达主城外围")
	check(maximum_y > 360.0, "敌人绕过湖水阻挡")
	check(stayed_walkable, "敌人移动过程不进入固体格")
	enemy.queue_free()


func _test_farmer_route() -> void:
	var fixture := _navigation_fixture()
	var model = fixture[0]
	var pathfinder = fixture[1]
	var workplace := Node2D.new()
	workplace.position = Vector2(630, 90)
	add_child(workplace)
	var farmer := FarmerAgent.new()
	add_child(farmer)
	farmer.configure(0, Vector2(90, 90))
	farmer.global_position = Vector2(90, 90)
	farmer.set_pathfinder(pathfinder)
	farmer.assign_job(&"farm", workplace, &"food", 2)
	var maximum_y := farmer.global_position.y
	var stayed_walkable := true
	for _step in range(600):
		farmer.advance(0.05)
		maximum_y = maxf(maximum_y, farmer.global_position.y)
		stayed_walkable = stayed_walkable and not model.is_solid(model.world_to_cell(farmer.global_position))
		if farmer.state == FarmerAgent.WorkState.GATHERING:
			break
	check(farmer.state == FarmerAgent.WorkState.GATHERING, "农民沿网格路径到达工作建筑外围")
	check(maximum_y > 360.0, "农民绕过湖水阻挡")
	check(stayed_walkable, "农民移动过程不进入固体格")
	farmer.queue_free()
	workplace.queue_free()


func _test_guard_route() -> void:
	var fixture := _navigation_fixture()
	var model = fixture[0]
	var pathfinder = fixture[1]
	var enemy := ENEMY_SCENE.instantiate() as EnemyActor
	add_child(enemy)
	enemy.configure(WOLF, Vector2(630, 90), Vector2(700, 90))
	enemy.set_physics_process(false)
	var guard := GUARD_SCENE.instantiate() as BarracksGuard
	add_child(guard)
	guard.global_position = Vector2(90, 90)
	guard.configure(GUARD, 0)
	guard.set_pathfinder(pathfinder)
	check(guard.engage_enemy(enemy), "守卫接受存活敌人作为目标")
	var maximum_y := guard.global_position.y
	var stayed_walkable := true
	for _step in range(600):
		guard._process(0.05)
		maximum_y = maxf(maximum_y, guard.global_position.y)
		stayed_walkable = stayed_walkable and not model.is_solid(model.world_to_cell(guard.global_position))
		if guard.global_position.distance_to(enemy.global_position) <= GUARD.attack_range_pixels:
			break
	check(guard.global_position.distance_to(enemy.global_position) <= GUARD.attack_range_pixels, "守卫沿网格路径进入近战范围")
	check(maximum_y > 360.0, "守卫绕过湖水阻挡")
	check(stayed_walkable, "守卫移动过程不进入固体格")
	guard.queue_free()
	enemy.queue_free()


func _test_main_spawn_routes() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	for spawn_position in MapLayout.SPAWN_POINTS:
		spawn_position = main.grid_pathfinder.spawn_position(spawn_position)
		var path: PackedVector2Array = main.grid_pathfinder.find_path(
			spawn_position, MapLayout.CITY_POSITION, 96.0
		)
		check(path.size() > 0, "实际地图出生点存在到主城外围的网格路径：%s" % spawn_position)
		var all_walkable := true
		for point in path:
			all_walkable = all_walkable and not main.grid_map_model.is_solid(
				main.grid_map_model.world_to_cell(point)
			)
		check(all_walkable, "实际地图出生路径不穿湖泊、资源点或建筑：%s" % spawn_position)
	main.queue_free()


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
