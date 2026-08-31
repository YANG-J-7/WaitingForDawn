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
	var setup_panel := main.get_node("HUD/DaySetupPanel") as PanelContainer
	var selection_label := main.get_node("HUD/DaySetupPanel/Margin/Content/Header/SelectionLabel") as Label
	var hand_bar := main.get_node("HUD/HandBar") as PanelContainer
	var hand_slots := main.get_node("HUD/HandBar/Margin/Content/HandSlots") as HBoxContainer
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

	var frame_budget: int = 900
	while RunState.phase == RunState.Phase.WAVE_COMBAT and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1

	_expect_equal(RunState.phase, RunState.Phase.WAVE_RESULT, "wave one reaches result")
	_expect_equal(RunState.current_wave, 2, "result prepares wave two")
	_expect_true(shop.active, "wave two free shop is active")
	_expect_true(setup_panel.visible, "wave two shop panel is visible")
	_expect_true(not build_failure_panel.visible, "opening interwave shop closes stale build failure popup")
	_expect_equal(card_grid.get_child_count(), 6, "wave two shop displays six offers")
	_expect_true("2" in selection_label.text, "shop reports two free choices")
	_expect_true(not controller.spawning and controller.enemies.is_empty(), "shop does not auto spawn enemies")
	_expect_true(not hand_bar.visible, "battle hand stays hidden in shop")

	var gold_before: int = RunEconomy.amount(&"gold")
	var wood_before: int = RunEconomy.amount(&"wood")
	(card_grid.get_child(0) as Button).pressed.emit()
	(card_grid.get_child(1) as Button).pressed.emit()
	_expect_equal(shop.selected_indices.size(), 2, "two free cards can be selected")
	(card_grid.get_child(2) as Button).pressed.emit()
	_expect_equal(shop.selected_indices.size(), 2, "third free card is rejected")
	_expect_equal(RunEconomy.amount(&"gold"), gold_before, "free selection spends no gold")
	_expect_equal(RunEconomy.amount(&"wood"), wood_before, "free selection spends no build resources")
	_expect_true(not ready_button.disabled, "two selections enable wave two ready button")

	_expect_true(wave_economy.adjust_workers(&"arrow_tower", -1), "interwave shop allows worker adjustment")
	_expect_true(wave_economy.adjust_workers(&"arrow_tower", 1), "interwave shop allows worker restoration")
	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "ready starts wave two")
	_expect_true(not shop.active and not setup_panel.visible, "wave two combat closes shop")
	_expect_true(hand_bar.visible, "wave two combat restores bottom hand")
	_expect_equal(inventory.card_count(), 5, "two new cards merge with three retained cards")
	_expect_equal(hand_slots.get_child_count(), 5, "hand bar renders merged persistent inventory")
	_expect_true(wave_economy.assignments_locked, "wave two combat locks workers")
	_expect_equal(controller.active_wave_index, 2, "controller uses wave two definition")
	_expect_equal(controller.active_enemy_count, 5, "wave two has five wolves")

	frame_budget = 1100
	while RunState.phase == RunState.Phase.WAVE_COMBAT and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1
	_expect_equal(RunState.phase, RunState.Phase.WAVE_RESULT, "wave two can be cleared")
	_expect_equal(RunState.current_wave, 3, "wave two clear advances to wave three result")
	_expect_true(2 in wave_economy.settled_waves, "wave two settlement runs once")
	_expect_true(not controller.spawning, "wave three does not auto start")

	var reset_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/ResetButton") as Button
	reset_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(inventory.card_count(), 0, "reset clears persistent inventory")
	_expect_true(not shop.active and shop.selected_indices.is_empty(), "reset clears interwave shop")

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
