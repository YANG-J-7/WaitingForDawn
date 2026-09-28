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
	var setup_panel := main.get_node("HUD/DaySetupPanel") as PanelContainer
	var selection_label := main.get_node("HUD/DaySetupPanel/Margin/Content/Header/SelectionLabel") as Label
	var hand_bar := main.get_node("HUD/HandBar") as PanelContainer
	var hand_slots := main.get_node("HUD/HandBar/Margin/Content/HandScroll/HandSlots") as HBoxContainer
	var defense_slot := main.get_node("HUD/DefenseSlotButton") as Button
	var build_failure_panel := main.get_node("HUD/BuildFailurePanel") as PanelContainer

	start_button.pressed.emit()
	for card_index in [0, 3, 4, 5]:
		(card_grid.get_child(card_index) as Button).pressed.emit()
	defense_slot.pressed.emit()
	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(inventory.card_count(), 3, "three unused opening cards enter persistent inventory")
	build_failure_panel.visible = true

	preload("res://tests/helpers/shop_wave_fixture.gd").clear_wave(controller)
	var frame_budget: int = 900
	while 1 not in wave_economy.settled_waves and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1

	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "wave one clear continues combat")
	_expect_equal(RunState.current_wave, 2, "continuous defense prepares wave two")
	_expect_true(not shop.active, "battle shop stays closed until requested")
	main._on_battle_shop_button_pressed()
	_expect_true(shop.active, "paid battle shop opens during wave two")
	_expect_true(setup_panel.visible, "battle shop panel is visible")
	_expect_true(not build_failure_panel.visible, "opening battle shop closes stale build failure popup")
	_expect_equal(card_grid.get_child_count(), 6, "wave two shop displays six offers")
	_expect_true("金币" in selection_label.text, "shop reports current gold")
	_expect_true(controller.spawning, "opening shop does not pause enemy spawning")
	_expect_true(hand_bar.visible, "battle hand stays visible below shop drawer")
	_expect_true(main.map_drop_surface.visible, "battle map stays interactive outside shop drawer")

	var current_gold: int = RunEconomy.amount(&"gold")
	if current_gold < 100:
		RunEconomy.add_resource(&"gold", 100 - current_gold)
	var gold_before: int = RunEconomy.amount(&"gold")
	var wood_before: int = RunEconomy.amount(&"wood")
	var purchased_price: int = shop.offered_cards[0].shop_price
	(card_grid.get_child(0) as Button).pressed.emit()
	_expect_equal(shop.purchased_indices.size(), 1, "wave two can purchase one card")
	_expect_equal(RunEconomy.amount(&"gold"), gold_before - purchased_price, "purchase spends displayed gold")
	_expect_equal(RunEconomy.amount(&"wood"), wood_before, "purchase spends no build resources")
	_expect_true(not ready_button.disabled, "paid shop permits ready after purchase")

	_expect_true(wave_economy.adjust_workers(&"arrow_tower", -1), "battle shop allows removing a worker")
	_expect_true(wave_economy.adjust_workers(&"arrow_tower", 1), "battle shop allows restoring a worker")
	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "closing shop keeps wave two running")
	_expect_true(not shop.active and not setup_panel.visible, "wave two combat closes shop")
	_expect_true(hand_bar.visible, "wave two combat restores bottom hand")
	_expect_equal(inventory.card_count(), 4, "purchased card merges with three retained cards")
	_expect_equal(hand_slots.get_child_count(), 4, "hand bar renders merged persistent inventory")
	_expect_true(not wave_economy.assignments_locked, "wave two combat keeps workers editable")
	_expect_equal(controller.active_wave_index, 2, "controller uses wave two definition")
	_expect_equal(controller.active_enemy_count, 5, "wave two has five wolves")

	preload("res://tests/helpers/shop_wave_fixture.gd").clear_wave(controller)
	frame_budget = 1100
	while 2 not in wave_economy.settled_waves and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1
	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "wave two can be cleared and continued")
	_expect_equal(RunState.current_wave, 3, "wave two clear advances to wave three")
	_expect_true(2 in wave_economy.settled_waves, "wave two settlement runs once")
	_expect_true(controller.spawning, "wave three auto starts")

	var reset_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/ResetButton") as Button
	reset_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(inventory.card_count(), 0, "reset clears persistent inventory")
	_expect_true(not shop.active and shop.purchased_indices.is_empty(), "reset clears battle shop")

	Engine.time_scale = 1.0
	main.queue_free()
	get_tree().quit(failure_count)


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
