extends Node

const MAIN_SCENE: PackedScene = preload("res://src/main/main.tscn")
const GUARD_SCENE: PackedScene = preload("res://src/gameplay/defenses/barracks_guard.tscn")
const ENEMY_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy.tscn")
const GUARD_DEFINITION: GuardDefinition = preload("res://src/data/defenses/barracks_guard.tres")
const WOLF: EnemyDefinition = preload("res://src/data/enemies/wolf.tres")

var failure_count: int = 0


func _ready() -> void:
	_test_guard_damage_and_late_intercept()
	await _test_barracks_battle_flow()
	get_tree().quit(failure_count)


func _test_guard_damage_and_late_intercept() -> void:
	var guard: BarracksGuard = GUARD_SCENE.instantiate() as BarracksGuard
	var enemy: EnemyActor = ENEMY_SCENE.instantiate() as EnemyActor
	add_child(guard)
	add_child(enemy)
	guard.position = Vector2(480.0, 313.0)
	guard.configure(GUARD_DEFINITION, 0)
	enemy.configure(WOLF, Vector2(520.0, 313.0), Vector2(782.0, 313.0))
	_expect_equal(guard.maximum_health(), 90, "guard uses ninety maximum health")
	_expect_equal(guard.armor(), 5, "guard uses five armor")
	_expect_equal(guard.perform_attack(enemy), 8, "guard deals eight neutral damage to wolf")
	_expect_equal(enemy.current_health, 47, "wolf health reflects guard attack")
	_expect_equal(guard.apply_enemy_attack(8, &"wolf"), 7, "wolf deals seven damage through guard armor")
	_expect_equal(guard.current_health, 83, "guard health reflects wolf attack")
	_expect_true(not enemy.set_guard(guard), "enemy past guard line cannot be pulled backward")
	_expect_equal(enemy.attack_target_kind, &"city", "late guard leaves passed enemy targeting city")
	enemy.position = Vector2(400.0, 313.0)
	_expect_true(enemy.set_guard(guard), "enemy before guard line can be intercepted")
	guard.apply_enemy_attack(200, &"wolf")
	_expect_true(not guard.is_active(), "lethal enemy attack defeats guard")
	_expect_equal(enemy.attack_target_kind, &"city", "enemy resumes city target after guard defeat")
	enemy.queue_free()
	guard.queue_free()

	var second_guard: BarracksGuard = GUARD_SCENE.instantiate() as BarracksGuard
	var second_enemy: EnemyActor = ENEMY_SCENE.instantiate() as EnemyActor
	add_child(second_guard)
	add_child(second_enemy)
	second_guard.configure(GUARD_DEFINITION, 1)
	second_enemy.configure(WOLF, Vector2(400.0, 313.0), Vector2(782.0, 313.0))
	_expect_true(second_guard.engage_enemy(second_enemy), "available guard engages living enemy")
	second_enemy.apply_damage(WOLF.maximum_health)
	_expect_true(second_guard.is_available(), "guard releases defeated enemy for reassignment")
	second_enemy.queue_free()
	second_guard.queue_free()


func _test_barracks_battle_flow() -> void:
	Engine.time_scale = 20.0
	var main: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame

	var inventory := main.get_node("RunCardInventory") as RunCardInventory
	var economy := main.get_node("WaveEconomy") as WaveEconomy
	var controller := main.get_node("WaveController") as WaveController
	var barracks := main.get_node("Barracks") as Barracks
	var arrow_tower := main.get_node("ArrowTower") as ArrowTower
	var settlement_builder := main.get_node("SettlementBuilder") as SettlementBuilder
	var start_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/StartButton") as Button
	var card_grid := main.get_node("HUD/DaySetupPanel/Margin/Content/CardGrid") as GridContainer
	var ready_button := main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/ReadyButton") as Button
	var barracks_slot := main.get_node("HUD/BarracksSlotButton") as CardDropSlot
	var defense_slot := main.get_node("HUD/DefenseSlotButton") as CardDropSlot
	var barrier_slot := main.get_node("HUD/BarrierSlotButton") as CardDropSlot
	var settlement_slot := main.get_node("HUD/SettlementSlot0") as CardDropSlot
	var hand_slots := main.get_node("HUD/HandBar/Margin/Content/HandSlots") as HBoxContainer
	var map_surface := main.get_node("HUD/MapDropSurface") as MapDropSurface

	start_button.pressed.emit()
	for card_index in [0, 3, 4, 5]:
		(card_grid.get_child(card_index) as Button).pressed.emit()
	_expect_true(not barracks_slot.visible, "barracks slot stays hidden during card selection")
	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_true(not barracks_slot.visible and map_surface.visible, "battle uses free map placement instead of barracks slot")
	var barracks_hand := hand_slots.get_node("HandCard_5") as HandCardSlot
	var arrow_hand := hand_slots.get_node("HandCard_3") as HandCardSlot
	var barracks_payload: Variant = barracks_hand.drag_payload()
	var arrow_payload: Variant = arrow_hand.drag_payload()
	_expect_true(map_surface.accepts_card_data(barracks_payload), "map accepts barracks card")
	_expect_true(not defense_slot.accepts_card_data(barracks_payload), "tower slot rejects barracks card")
	_expect_true(not barrier_slot.accepts_card_data(barracks_payload), "barrier slot rejects barracks card")
	_expect_true(not settlement_slot.accepts_card_data(barracks_payload), "settlement slot rejects barracks card")

	var inventory_before: int = inventory.card_count()
	RunEconomy.try_pay({&"wood": 100})
	map_surface.drop_card_data(barracks_payload, Vector2(620.0, 360.0))
	_expect_true(not barracks.is_built(), "insufficient resources do not create barracks")
	_expect_equal(inventory.card_count(), inventory_before, "failed barracks build preserves hand card")
	_expect_true(main.get_node("HUD/BuildFailurePanel").visible, "failed barracks build shows shortage popup")
	RunEconomy.add_resource(&"wood", 100)

	map_surface.drop_card_data(barracks_payload, Vector2(620.0, 360.0))
	await get_tree().process_frame
	_expect_true(barracks.is_built(), "barracks becomes active after drop")
	_expect_equal(RunEconomy.amount(&"wood"), 45, "barracks construction spends fifty five wood")
	_expect_equal(RunEconomy.amount(&"stone"), 80, "barracks construction spends twenty stone")
	_expect_equal(RunEconomy.amount(&"iron"), 90, "barracks construction spends ten iron")
	_expect_equal(inventory.card_count(), inventory_before - 1, "successful barracks drop consumes hand card")
	_expect_equal(economy.job_capacity(&"barracks"), 2, "barracks contributes two job slots")
	_expect_equal(economy.assigned_workers_for(&"barracks"), 2, "auto assignment staffs both barracks jobs")
	_expect_equal(barracks.active_guards().size(), 2, "two assigned workers spawn two guards")
	_expect_equal(barracks.active_guards().size(), 2, "barracks visual roster reflects active guard count")
	# 守卫近战用固定路径的高生命测试敌人，避免随机路线和箭塔抢先击杀。
	controller.spawning = false
	main.get_node("FarmerManager").set_process(false)
	var test_enemy: EnemyActor = controller.enemies[0]
	var test_guard: BarracksGuard = barracks.active_guards()[0]
	test_enemy.current_health = 1000
	test_enemy.global_position = test_guard.global_position + (test_guard.global_position - controller.city_target_position).normalized() * 65.0
	test_enemy._resume_to_city()
	controller._assign_defensive_targets()
	await get_tree().process_frame

	var observed_guard_target: bool = false
	var observed_mutual_damage: bool = false
	var never_overblocked: bool = true
	var frame_budget: int = 700
	while not observed_mutual_damage and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1
		var guard_target_count: int = 0
		for enemy in controller.enemies:
			if is_instance_valid(enemy) and enemy.attack_target_kind == &"guard":
				guard_target_count += 1
				observed_guard_target = true
		never_overblocked = never_overblocked and guard_target_count <= 2
		for guard in barracks.active_guards():
			if guard.total_damage > 0 and guard.current_health < guard.maximum_health():
				observed_mutual_damage = true
	_expect_true(observed_guard_target, "wolves stop to target barracks guards")
	_expect_true(never_overblocked, "two guards never block more than two wolves at once")
	_expect_true(observed_mutual_damage, "guard and wolf exchange observable melee damage")
	var guards_before_loss: Array[BarracksGuard] = barracks.active_guards()
	_expect_equal(guards_before_loss.size(), 2, "both guard slots were deployed for current wave")
	if guards_before_loss.is_empty():
		main.queue_free()
		return
	guards_before_loss[0].apply_enemy_attack(999, &"wolf")
	await get_tree().process_frame
	_expect_equal(barracks.active_guards().size(), 1, "defeated guard leaves one active guard")
	economy.refresh_jobs(settlement_builder, arrow_tower, barracks)
	await get_tree().process_frame
	_expect_equal(barracks.active_guards().size(), 1, "job refresh does not respawn casualty mid wave")
	map_surface.drop_card_data(arrow_payload, Vector2(650.0, 180.0))
	preload("res://tests/helpers/shop_wave_fixture.gd").clear_wave(controller)

	frame_budget = 1200
	while RunState.phase == RunState.Phase.WAVE_COMBAT and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1
	_expect_equal(RunState.phase, RunState.Phase.WAVE_RESULT, "受控敌人清场后进入波间阶段")
	_expect_equal(barracks.active_guards().size(), 0, "wave result removes temporary guards")
	var current_gold: int = RunEconomy.amount(&"gold")
	if current_gold < 100:
		RunEconomy.add_resource(&"gold", 100 - current_gold)
	(card_grid.get_child(0) as Button).pressed.emit()
	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "next wave starts after paid purchase")
	_expect_equal(barracks.active_guards().size(), 2, "next wave respawns guards from assignments")
	for guard in barracks.active_guards():
		_expect_equal(guard.current_health, 90, "respawned guard returns at full health")

	var reset_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/ResetButton") as Button
	reset_button.pressed.emit()
	await get_tree().process_frame
	_expect_true(not barracks.is_built(), "reset clears barracks entity")
	_expect_equal(barracks.active_guards().size(), 0, "reset clears all guards")
	_expect_true(&"barracks" not in economy.job_order, "reset removes barracks job")
	_expect_true(not barracks_slot.visible, "reset hides barracks slot")

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
