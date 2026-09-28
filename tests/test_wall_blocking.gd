extends Node

const MAIN_SCENE: PackedScene = preload("res://src/main/main.tscn")
const WALL_SCENE: PackedScene = preload("res://src/gameplay/defenses/barrier_wall.tscn")
const ENEMY_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy.tscn")
const WALL_CARD: OpeningCardDefinition = preload("res://src/data/cards/wall.tres")
const WOLF: EnemyDefinition = preload("res://src/data/enemies/wolf.tres")

var failure_count: int = 0


func _ready() -> void:
	_run_test()


func _run_test() -> void:
	_test_wall_damage_formula()
	_test_late_wall_does_not_pull_enemy_back()
	_test_nearest_wall_priority()
	await _test_wall_battle_flow()
	get_tree().quit(failure_count)


func _test_wall_damage_formula() -> void:
	var wall: BarrierWall = WALL_SCENE.instantiate() as BarrierWall
	add_child(wall)
	wall.build(WALL_CARD)
	_expect_equal(wall.maximum_health, 400, "wall uses four hundred maximum health")
	_expect_equal(wall.armor, 20, "wall uses twenty armor")
	var applied: int = wall.apply_enemy_attack(8, &"wolf")
	_expect_equal(applied, 5, "wolf deals five damage after armor and disadvantage")
	_expect_equal(wall.current_health, 395, "wall health reflects applied damage")
	wall.queue_free()


func _test_late_wall_does_not_pull_enemy_back() -> void:
	var wall: BarrierWall = WALL_SCENE.instantiate() as BarrierWall
	var enemy: EnemyActor = ENEMY_SCENE.instantiate() as EnemyActor
	add_child(wall)
	add_child(enemy)
	wall.position = Vector2(550.0, 313.0)
	wall.build(WALL_CARD)
	enemy.configure(WOLF, Vector2(600.0, 313.0), Vector2(782.0, 313.0))
	_expect_true(not enemy.set_barrier(wall), "enemy past barrier cannot be pulled backward")
	_expect_equal(enemy.attack_target_kind, &"city", "late wall leaves passed enemy targeting city")
	enemy.queue_free()
	wall.queue_free()


func _test_nearest_wall_priority() -> void:
	var controller := WaveController.new()
	var enemy: EnemyActor = ENEMY_SCENE.instantiate() as EnemyActor
	var near_wall: BarrierWall = WALL_SCENE.instantiate() as BarrierWall
	var far_wall: BarrierWall = WALL_SCENE.instantiate() as BarrierWall
	add_child(controller)
	controller.city_target_position = Vector2(782.0, 313.0)
	controller.add_child(enemy)
	add_child(near_wall)
	add_child(far_wall)
	near_wall.position = Vector2(300.0, 313.0)
	far_wall.position = Vector2(500.0, 313.0)
	near_wall.build(WALL_CARD)
	far_wall.build(WALL_CARD)
	enemy.configure(WOLF, Vector2(100.0, 313.0), Vector2(782.0, 313.0))
	controller.enemies.append(enemy)
	controller.set_barrier_walls([far_wall, near_wall])
	_expect_equal(enemy.barrier_target, near_wall, "enemy chooses nearest forward route wall")
	near_wall.apply_enemy_attack(999, &"wolf")
	controller.set_barrier_walls([far_wall])
	_expect_equal(enemy.barrier_target, far_wall, "enemy chooses next route wall after first breaks")
	controller.queue_free()
	near_wall.queue_free()
	far_wall.queue_free()


func _test_wall_battle_flow() -> void:
	Engine.time_scale = 20.0
	var main: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame

	var inventory: RunCardInventory = main.get_node("RunCardInventory") as RunCardInventory
	var controller: WaveController = main.get_node("WaveController") as WaveController
	var wall_manager: WallManager = main.get_node("WallManager") as WallManager
	var start_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/StartButton") as Button
	var card_grid := main.get_node("HUD/DaySetupPanel/Margin/Content/CardGrid") as GridContainer
	var ready_button := main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/ReadyButton") as Button
	var barrier_slot := main.get_node("HUD/BarrierSlotButton") as CardDropSlot
	var map_surface := main.get_node("HUD/MapDropSurface") as MapDropSurface
	var defense_slot := main.get_node("HUD/DefenseSlotButton") as CardDropSlot
	var settlement_slot := main.get_node("HUD/SettlementSlot0") as CardDropSlot
	var hand_slots := main.get_node("HUD/HandBar/Margin/Content/HandScroll/HandSlots") as HBoxContainer

	start_button.pressed.emit()
	for card_index in [0, 3, 4, 5]:
		(card_grid.get_child(card_index) as Button).pressed.emit()
	_expect_true(not barrier_slot.visible, "barrier slot stays hidden during card selection")
	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_true(not barrier_slot.visible, "battle keeps legacy barrier slot hidden")
	_expect_true(map_surface.visible, "battle reveals free wall map surface")
	var wall_hand := hand_slots.get_node("HandCard_4") as HandCardSlot
	var wall_payload: Variant = wall_hand.drag_payload()
	_expect_true(map_surface.accepts_card_data(wall_payload), "map surface accepts wall card")
	_expect_true(not defense_slot.accepts_card_data(wall_payload), "tower slot rejects wall card")
	_expect_true(not settlement_slot.accepts_card_data(wall_payload), "settlement slot rejects wall card")
	var inventory_before: int = inventory.card_count()
	var spawn_budget: int = 120
	while controller.enemies.is_empty() and spawn_budget > 0:
		await get_tree().process_frame
		spawn_budget -= 1
	# 固定被测敌人的路径，避免出生在南北边时试图在主城占地内建墙。
	controller.enemies[0].position = Vector2(100, 1030)
	controller.enemies[0]._resume_to_city()
	var route_position := Vector2(900, 1030)
	RunEconomy.try_pay({&"wood": RunEconomy.amount(&"wood")})
	map_surface.drop_card_data(wall_payload, route_position)
	_expect_equal(wall_manager.active_walls().size(), 0, "insufficient resources do not create wall")
	_expect_equal(inventory.card_count(), inventory_before, "failed wall build preserves hand card")
	_expect_true(main.get_node("HUD/BuildFailurePanel").visible, "failed wall build shows shortage popup")
	RunEconomy.add_resource(&"wood", 100)
	map_surface.drop_card_data(wall_payload, route_position)
	var wall: BarrierWall = wall_manager.active_walls()[0]
	_expect_true(wall.is_blocking(), "wall becomes active after drop")
	_expect_equal(wall.current_health, 400, "built wall starts at full health")
	_expect_equal(RunEconomy.amount(&"wood"), 80, "wall construction spends twenty wood")
	_expect_equal(RunEconomy.amount(&"stone"), 85, "wall construction spends fifteen stone")
	_expect_equal(inventory.card_count(), inventory_before - 1, "successful wall drop consumes hand card")

	var frame_budget: int = 700
	var observed_barrier_target: bool = false
	while wall.current_health == 400 and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1
		for enemy in controller.enemies:
			if is_instance_valid(enemy) and enemy.attack_target_kind == &"barrier":
				observed_barrier_target = true
	_expect_true(observed_barrier_target, "wolf targets barrier before city")
	_expect_true(wall.current_health < 400, "wolves damage wall")
	_expect_true(RunState.city_health > 0, "city remains standing when route wall starts taking damage")

	var observed_city_target: bool = false
	frame_budget = 1800
	while RunState.phase == RunState.Phase.WAVE_COMBAT and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1
		for enemy in controller.enemies:
			if is_instance_valid(enemy) and enemy.attack_target_kind == &"city":
				observed_city_target = true
	_expect_true(observed_city_target, "wolves from other directions continue toward city")
	_expect_equal(RunState.phase, RunState.Phase.RUN_LOST, "one route wall cannot protect every radial direction")
	_expect_true(wall.current_health >= 0, "失败时城墙耐久保持合法，不假定随机其他路线的存亡结果")
	_expect_true(not map_surface.visible, "loss closes map placement surface")

	var reset_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/ResetButton") as Button
	reset_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(wall_manager.active_walls().size(), 0, "reset clears wall collection")
	_expect_true(not map_surface.visible, "reset hides free wall surface")
	_expect_true(not barrier_slot.visible, "reset hides barrier slot")

	Engine.time_scale = 1.0
	main.queue_free()


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	failure_count += 1
	push_error("FAIL: %s expected=%s actual=%s" % [label, expected, actual])


func _expect_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failure_count += 1
	push_error("FAIL: %s" % label)
