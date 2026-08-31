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
	var shop: InterwaveDraft = main.get_node("InterwaveDraft") as InterwaveDraft
	var controller: WaveController = main.get_node("WaveController") as WaveController
	var wave_economy: WaveEconomy = main.get_node("WaveEconomy") as WaveEconomy
	var start_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/StartButton") as Button
	var card_grid := main.get_node("HUD/DaySetupPanel/Margin/Content/CardGrid") as GridContainer
	var ready_button := main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/ReadyButton") as Button
	var refresh_button := main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/RefreshButton") as Button
	var hand_bar := main.get_node("HUD/HandBar") as PanelContainer
	var hand_slots := main.get_node("HUD/HandBar/Margin/Content/HandSlots") as HBoxContainer
	var defense_slot := main.get_node("HUD/DefenseSlotButton") as Button
	var setup_hint := main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/SetupHintLabel") as Label

	start_button.pressed.emit()
	for card_index in [0, 3, 4, 5]:
		(card_grid.get_child(card_index) as Button).pressed.emit()
	defense_slot.pressed.emit()
	ready_button.pressed.emit()
	await _wait_for_result(900)

	_expect_equal(RunState.current_wave, 2, "wave one opens wave two shop")
	_expect_true(refresh_button.visible, "wave two shop exposes paid refresh")
	_expect_equal(shop.current_refresh_cost(), 10, "wave two first refresh starts at ten")
	(card_grid.get_child(0) as Button).pressed.emit()
	(card_grid.get_child(1) as Button).pressed.emit()
	ready_button.pressed.emit()
	await _wait_for_result(1100)

	_expect_equal(RunState.current_wave, 3, "wave two opens wave three shop")
	_expect_true(shop.active, "wave three free shop is active")
	_expect_equal(shop.wave_index, 3, "shop is configured for wave three")
	_expect_equal(shop.selected_indices.size(), 0, "new shop resets free selections")
	_expect_equal(shop.refresh_count, 0, "new shop resets refresh count")
	_expect_equal(shop.current_refresh_cost(), 10, "wave three first refresh resets to ten")
	_expect_true("10" in refresh_button.text, "refresh button shows current cost")
	_expect_true(not controller.spawning and controller.enemies.is_empty(), "wave three waits in shop")

	(card_grid.get_child(0) as Button).pressed.emit()
	var selected_card: OpeningCardDefinition = shop.offered_cards[0]
	var inventory_before_refresh: int = inventory.card_count()
	_set_gold(100)
	var expected_costs: Array[int] = [10, 15, 20, 25, 30]
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
		_expect_true(shop.offered_cards[0] == selected_card, "selected free card survives refresh")
		_expect_true(0 in shop.selected_indices, "selected index remains selected")
		_expect_equal(inventory.card_count(), inventory_before_refresh, "refresh keeps persistent inventory")
		_expect_true(_all_unselected_changed(previous_offers, shop), "refresh replaces every unselected slot")

	_expect_equal(RunEconomy.amount(&"gold"), 0, "five refreshes spend exactly one hundred gold")
	_expect_equal(shop.current_refresh_cost(), 35, "sixth refresh would cost thirty five")
	var offers_before_failure: Array[StringName] = _offer_ids(shop)
	var selected_before_failure: Array[int] = shop.selected_indices.duplicate()
	refresh_button.pressed.emit()
	_expect_equal(shop.refresh_count, 5, "failed refresh keeps count")
	_expect_equal(shop.current_refresh_cost(), 35, "failed refresh keeps next cost")
	_expect_equal(_offer_ids(shop), offers_before_failure, "failed refresh keeps offers")
	_expect_equal(shop.selected_indices, selected_before_failure, "failed refresh keeps selections")
	_expect_true("金币不足" in setup_hint.text, "failed refresh explains insufficient gold")

	(card_grid.get_child(1) as Button).pressed.emit()
	_expect_equal(shop.selected_indices.size(), 2, "wave three still grants only two free cards")
	var inventory_before_ready: int = inventory.card_count()
	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "ready starts wave three")
	_expect_equal(inventory.card_count(), inventory_before_ready + 2, "wave three cards merge into inventory")
	_expect_true(hand_bar.visible, "wave three combat shows battle hand")
	_expect_equal(hand_slots.get_child_count(), inventory.card_count(), "hand renders full persistent inventory")
	_expect_equal(controller.active_wave_index, 3, "controller uses wave three definition")
	_expect_equal(controller.active_enemy_count, 6, "wave three has six wolves")

	await _wait_for_result(1300)
	_expect_equal(RunState.current_wave, 4, "wave three clear advances to wave four")
	_expect_equal(RunState.phase, RunState.Phase.WAVE_RESULT, "wave four remains in result planning")
	_expect_true(3 in wave_economy.settled_waves, "wave three settles once")
	_expect_true(not controller.spawning, "wave four does not auto start")

	var reset_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/ResetButton") as Button
	reset_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(shop.refresh_count, 0, "reset clears refresh count")
	_expect_true(not shop.active, "reset closes shop")

	Engine.time_scale = 1.0
	main.queue_free()
	get_tree().quit(failure_count)


func _wait_for_result(frame_budget: int) -> void:
	while RunState.phase == RunState.Phase.WAVE_COMBAT and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1


func _set_gold(target: int) -> void:
	var current: int = RunEconomy.amount(&"gold")
	if current < target:
		RunEconomy.add_resource(&"gold", target - current)
	elif current > target:
		RunEconomy.try_pay({&"gold": current - target})


func _offer_ids(shop: InterwaveDraft) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card in shop.offered_cards:
		ids.append(card.card_id)
	return ids


func _all_unselected_changed(previous: Array[StringName], shop: InterwaveDraft) -> bool:
	for card_index in range(shop.offered_cards.size()):
		if card_index in shop.selected_indices:
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
