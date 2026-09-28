extends Node

const MAIN_SCENE: PackedScene = preload("res://src/main/main.tscn")

var failure_count: int = 0


func _ready() -> void:
	_run_test()


func _run_test() -> void:
	Engine.time_scale = 20.0
	var main: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame

	var inventory: RunCardInventory = main.get_node("RunCardInventory") as RunCardInventory
	var shop: BattleShop = main.get_node("BattleShop") as BattleShop
	var controller: WaveController = main.get_node("WaveController") as WaveController
	var wave_economy: WaveEconomy = main.get_node("WaveEconomy") as WaveEconomy
	var start_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/StartButton") as Button
	var card_grid := main.get_node("HUD/DaySetupPanel/Margin/Content/CardGrid") as GridContainer
	var ready_button := main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/ReadyButton") as Button
	var refresh_button := main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/RefreshButton") as Button
	var hand_bar := main.get_node("HUD/HandBar") as PanelContainer
	var hand_slots := main.get_node("HUD/HandBar/Margin/Content/HandScroll/HandSlots") as HBoxContainer
	var defense_slot := main.get_node("HUD/DefenseSlotButton") as Button
	var setup_hint := main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/SetupHintLabel") as Label

	start_button.pressed.emit()
	for card_index in [0, 3, 4, 5]:
		(card_grid.get_child(card_index) as Button).pressed.emit()
	defense_slot.pressed.emit()
	ready_button.pressed.emit()
	await get_tree().process_frame
	main._on_battle_shop_button_pressed()
	_expect_true(shop.active, "continuous battle shop opens during combat")
	_expect_equal(shop.initialized_stage, 1, "shop is configured for first threat stage")
	_expect_equal(shop.refresh_count, 0, "new stage starts with zero refreshes")
	_expect_equal(shop.current_refresh_cost(), 2, "first threat stage refresh starts at two")
	_expect_true("2" in refresh_button.text, "refresh button shows current cost")
	_expect_true(controller.spawning, "enemy spawning continues while shop is open")

	_set_gold(100)
	var inventory_before_purchase: int = inventory.card_count()
	(card_grid.get_child(0) as Button).pressed.emit()
	var inventory_before_refresh: int = inventory.card_count()
	var gold_after_purchase: int = RunEconomy.amount(&"gold")
	_expect_equal(inventory_before_refresh, inventory_before_purchase + 1, "battle shop purchase immediately enters inventory")
	var expected_costs: Array[int] = [2, 3, 4, 5, 6]
	for refresh_index in range(expected_costs.size()):
		var previous_offers: Array[StringName] = _offer_ids(shop)
		var gold_before: int = RunEconomy.amount(&"gold")
		refresh_button.pressed.emit()
		_expect_equal(
			RunEconomy.amount(&"gold"),
			gold_before - expected_costs[refresh_index],
			"refresh %d spends expected gold" % (refresh_index + 1)
		)
		_expect_equal(shop.refresh_count, refresh_index + 1, "successful refresh advances count")
		_expect_true(shop.purchased_indices.is_empty(), "refresh restores purchased slots")
		_expect_equal(inventory.card_count(), inventory_before_refresh, "refresh keeps persistent inventory")
		_expect_true(_all_unselected_changed(previous_offers, shop), "refresh replaces every shop slot")

	_expect_equal(RunEconomy.amount(&"gold"), gold_after_purchase - 20, "five refreshes spend exactly twenty gold")
	_expect_equal(shop.current_refresh_cost(), 6, "sixth refresh remains capped at six")
	RunEconomy.try_pay({&"gold": RunEconomy.amount(&"gold")})
	var offers_before_failure: Array[StringName] = _offer_ids(shop)
	var purchased_before_failure: Array[int] = shop.purchased_indices.duplicate()
	refresh_button.pressed.emit()
	_expect_equal(shop.refresh_count, 5, "failed refresh keeps count")
	_expect_equal(shop.current_refresh_cost(), 6, "failed refresh keeps next cost")
	_expect_equal(_offer_ids(shop), offers_before_failure, "failed refresh keeps offers")
	_expect_equal(shop.purchased_indices, purchased_before_failure, "failed refresh keeps sold-out slots")
	_expect_true("金币不足" in setup_hint.text, "failed refresh explains insufficient gold")

	var inventory_before_stage_change: int = inventory.card_count()
	RunState.advance_campaign_time(600.0)
	_expect_equal(RunState.threat_stage, 2, "ten minutes advances threat stage")
	_expect_equal(shop.initialized_stage, 2, "stage change replenishes battle shop")
	_expect_equal(shop.refresh_count, 0, "stage change resets refresh count")
	_expect_equal(shop.current_refresh_cost(), 2, "new stage refresh returns to two")
	_expect_true(shop.purchased_indices.is_empty(), "new stage clears sold-out slots")
	_expect_equal(inventory.card_count(), inventory_before_stage_change, "stage change preserves inventory")
	var inventory_before_ready: int = inventory.card_count()
	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "closing shop keeps combat running")
	_expect_equal(inventory.card_count(), inventory_before_ready, "closing shop grants no free cards")
	_expect_true(hand_bar.visible, "closing shop restores battle hand")
	_expect_equal(hand_slots.get_child_count(), inventory.card_count(), "hand renders full persistent inventory")

	preload("res://tests/helpers/shop_wave_fixture.gd").clear_wave(controller)
	while 1 not in wave_economy.settled_waves:
		await get_tree().process_frame
	_expect_equal(RunState.current_wave, 2, "wave clear advances continuous threat")
	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "next threat auto starts")
	_expect_equal(controller.active_wave_index, 2, "controller uses second threat template")

	var reset_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/ResetButton") as Button
	reset_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(shop.refresh_count, 0, "reset clears refresh count")
	_expect_true(not shop.active, "reset closes shop")

	Engine.time_scale = 1.0
	main.queue_free()
	get_tree().quit(failure_count)


func _wait_for_result(frame_budget: int) -> void:
	preload("res://tests/helpers/shop_wave_fixture.gd").clear_wave(get_tree().root.get_node("Main/WaveController") as WaveController)
	while RunState.phase == RunState.Phase.WAVE_COMBAT and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1


func _set_gold(target: int) -> void:
	var current: int = RunEconomy.amount(&"gold")
	if current < target:
		RunEconomy.add_resource(&"gold", target - current)
	elif current > target:
		RunEconomy.try_pay({&"gold": current - target})


func _offer_ids(shop: BattleShop) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card in shop.offered_cards:
		ids.append(card.card_id)
	return ids


func _all_unselected_changed(previous: Array[StringName], shop: BattleShop) -> bool:
	for card_index in range(shop.offered_cards.size()):
		if card_index in shop.purchased_indices:
			continue
		if previous[card_index] == shop.offered_cards[card_index].card_id:
			return false
	return true


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
