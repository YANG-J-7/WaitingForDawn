extends Node

const MAIN_SCENE: PackedScene = preload("res://src/main/main.tscn")

var failure_count: int = 0


func _ready() -> void:
	await _test_free_wall_and_battle_shop()
	get_tree().quit(failure_count)


func _test_free_wall_and_battle_shop() -> void:
	Engine.time_scale = 20.0
	var main: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame

	var inventory := main.get_node("RunCardInventory") as RunCardInventory
	var controller := main.get_node("WaveController") as WaveController
	var wall_manager := main.get_node("WallManager") as WallManager
	var battle_shop := main.get_node("BattleShop") as BattleShop
	var map_surface := main.get_node("HUD/MapDropSurface") as MapDropSurface
	var barrier_slot := main.get_node("HUD/BarrierSlotButton") as CardDropSlot
	var shop_button := main.get_node("HUD/BattleShopButton") as Button
	var build_failure_panel := main.get_node("HUD/BuildFailurePanel") as PanelContainer
	var start_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/StartButton") as Button
	var card_grid := main.get_node("HUD/DaySetupPanel/Margin/Content/CardGrid") as GridContainer
	var ready_button := main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/ReadyButton") as Button
	var refresh_button := main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/RefreshButton") as Button
	var hand_slots := main.get_node("HUD/HandBar/Margin/Content/HandScroll/HandSlots") as HBoxContainer

	start_button.pressed.emit()
	for card_index in [0, 3, 4, 5]:
		(card_grid.get_child(card_index) as Button).pressed.emit()
	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_true(map_surface.visible, "battle reveals map wall drop surface")
	_expect_true(not barrier_slot.visible, "fixed barrier slot stays hidden")
	_expect_true(shop_button.visible, "battle reveals battle shop button")

	var wall_hand := hand_slots.get_node("HandCard_4") as HandCardSlot
	var wall_payload: Variant = wall_hand.drag_payload()
	_expect_true(map_surface.accepts_card_data(wall_payload), "map surface accepts wall card")
	var inventory_before: int = inventory.card_count()
	map_surface.drop_card_data(wall_payload, controller.city_target_position)
	_expect_equal(wall_manager.active_walls().size(), 0, "city center rejects wall placement")
	_expect_equal(inventory.card_count(), inventory_before, "invalid wall placement preserves card")
	_expect_equal(RunEconomy.amount(&"wood"), 100, "invalid wall placement preserves materials")

	var frame_budget: int = 180
	while controller.enemies.is_empty() and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1
	var tracked_enemy: EnemyActor = controller.enemies[0]
	Engine.time_scale = 1.0
	# 本例只验商店与拖墙，固定一条进攻线；外围随机性另有专测。
	controller.spawning = false
	tracked_enemy.position = Vector2(100, 1030)
	tracked_enemy._resume_to_city()
	var off_route_position := Vector2(700, 850)
	battle_shop.card_pool.resize(6)
	# 重建本阶段报价，确保缩小后的六张夹具池全部出现，避免依赖run_id随机遗漏城墙。
	battle_shop.reset()
	map_surface.drop_card_data(wall_payload, off_route_position)
	_expect_equal(wall_manager.active_walls().size(), 1, "legal off route point creates first wall")
	var off_route_wall: BarrierWall = wall_manager.active_walls()[0]
	_expect_true(not off_route_wall.blocks_segment(tracked_enemy.global_position, controller.city_target_position), "off route wall does not block tracked path")
	_expect_equal(RunEconomy.amount(&"wood"), 80, "first free wall spends twenty wood")
	_expect_equal(RunEconomy.amount(&"stone"), 85, "first free wall spends fifteen stone")
	_expect_equal(inventory.card_count(), inventory_before - 1, "first free wall consumes card")

	var distance_before_shop: float = tracked_enemy.global_position.distance_to(controller.city_target_position)
	build_failure_panel.visible = true
	shop_button.pressed.emit()
	await get_tree().process_frame
	_expect_true(not build_failure_panel.visible, "opening battle shop closes stale build failure popup")
	_expect_true(battle_shop.active, "battle shop opens during combat")
	_expect_true(main.get_node("HUD/DaySetupPanel").visible, "battle shop uses six card panel")
	_expect_true(map_surface.visible and main.get_node("HUD/HandBar").visible, "shop drawer keeps map and hand visible")
	_expect_equal(card_grid.columns, 2, "shop drawer arranges six offers in two columns")
	_expect_true(main.shop_close_button.visible, "shop drawer exposes a dedicated close button")
	for _frame in range(8):
		await get_tree().physics_frame
	_expect_true(tracked_enemy.global_position.distance_to(controller.city_target_position) < distance_before_shop, "enemy keeps moving while shop is open")

	var wall_offer_index: int = -1
	for card_index in range(battle_shop.offered_cards.size()):
		if battle_shop.offered_cards[card_index].card_id == &"wall":
			wall_offer_index = card_index
			break
	_expect_true(wall_offer_index >= 0, "battle shop contains wall offer")
	RunEconomy.add_resource(&"gold", 50)
	var gold_before_purchase: int = RunEconomy.amount(&"gold")
	(card_grid.get_child(wall_offer_index) as Button).pressed.emit()
	_expect_equal(
		RunEconomy.amount(&"gold"),
		gold_before_purchase - battle_shop.offered_cards[wall_offer_index].shop_price,
		"battle purchase spends exact card price"
	)
	_expect_equal(inventory.card_count(), inventory_before, "battle purchase immediately adds wall card")
	_expect_true(wall_offer_index in battle_shop.purchased_indices, "purchased battle offer becomes sold out")

	var purchased_wall: OpeningCardDefinition = battle_shop.offered_cards[wall_offer_index]
	var gold_before_refresh: int = RunEconomy.amount(&"gold")
	refresh_button.pressed.emit()
	_expect_equal(RunEconomy.amount(&"gold"), gold_before_refresh - 2, "first battle refresh costs two gold")
	_expect_equal(battle_shop.current_refresh_cost(), 3, "next battle refresh rises to three gold")
	_expect_true(battle_shop.purchased_indices.is_empty(), "refresh restores purchased offer slot")
	_expect_true(refresh_button.text.contains("下次 4金"), "refresh row shows current and next refresh costs")

	main.shop_close_button.pressed.emit()
	await get_tree().process_frame
	_expect_true(not battle_shop.active, "close button returns to battle")
	_expect_true(main.get_node("HUD/HandBar").visible, "closing shop restores battle hand")
	shop_button.pressed.emit()
	await get_tree().process_frame
	_expect_true(battle_shop.active, "same wave battle shop can reopen")
	_expect_equal(battle_shop.current_refresh_cost(), 3, "reopening does not reset refresh price")
	_expect_true(battle_shop.purchased_indices.is_empty(), "reopening keeps refreshed slots available")
	main.shop_close_button.pressed.emit()
	await get_tree().process_frame
	var purchased_wall_id: int = inventory.first_instance_for_card(&"wall")
	_expect_true(purchased_wall_id >= 0, "purchased wall is available in inventory")
	var purchased_wall_hand := hand_slots.get_node("HandCard_%d" % purchased_wall_id) as HandCardSlot
	var purchased_wall_payload: Variant = purchased_wall_hand.drag_payload()
	map_surface.drop_card_data(purchased_wall_payload, tracked_enemy.global_position)
	_expect_equal(wall_manager.active_walls().size(), 1, "enemy occupied point rejects wall placement")
	_expect_true(inventory.has_card(purchased_wall_id), "enemy overlap rejection preserves wall card")
	map_surface.drop_card_data(purchased_wall_payload, off_route_position)
	_expect_equal(wall_manager.active_walls().size(), 1, "overlapping wall placement is rejected")
	_expect_true(inventory.has_card(purchased_wall_id), "overlap rejection preserves purchased wall card")

	var route_wall_position := Vector2(900, 1030)
	map_surface.drop_card_data(purchased_wall_payload, route_wall_position)
	_expect_equal(wall_manager.active_walls().size(), 2, "second wall can be placed at another free point (%s)" % (main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/SetupHintLabel") as Label).text)
	var route_wall: BarrierWall = wall_manager.active_walls()[1]
	_expect_true(route_wall.blocks_segment(tracked_enemy.global_position, controller.city_target_position), "route wall participates in blocking")
	Engine.time_scale = 20.0
	frame_budget = 700
	var observed_route_target: bool = false
	while route_wall.current_health == 400 and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1
		for enemy in controller.enemies:
			if is_instance_valid(enemy) and enemy.barrier_target == route_wall:
				observed_route_target = true
	_expect_true(observed_route_target, "wolves choose the valid route wall")
	_expect_true(route_wall.current_health < 400, "wolves damage route wall")
	_expect_equal(off_route_wall.current_health, 400, "off route wall remains untouched")

	var reset_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/ResetButton") as Button
	reset_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(wall_manager.active_walls().size(), 0, "reset clears all free placed walls")
	_expect_true(not map_surface.visible, "reset hides map drop surface")
	_expect_true(not shop_button.visible, "reset hides battle shop button")
	_expect_true(not battle_shop.active, "reset closes battle shop")

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
