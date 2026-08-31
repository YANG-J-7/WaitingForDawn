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

	var builder: SettlementBuilder = main.get_node("SettlementBuilder") as SettlementBuilder
	var wave_economy: WaveEconomy = main.get_node("WaveEconomy") as WaveEconomy
	var start_button: Button = main.get_node("HUD/BottomPanel/Margin/Content/Buttons/StartButton") as Button
	var card_grid: GridContainer = main.get_node("HUD/DaySetupPanel/Margin/Content/CardGrid") as GridContainer
	var ready_button: Button = main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/ReadyButton") as Button
	var defense_slot: Button = main.get_node("HUD/DefenseSlotButton") as Button
	var settlement_slots: Array[Button] = [
		main.get_node("HUD/SettlementSlot0") as Button,
		main.get_node("HUD/SettlementSlot1") as Button,
		main.get_node("HUD/SettlementSlot2") as Button,
	]

	start_button.pressed.emit()
	(card_grid.get_child(0) as Button).pressed.emit()
	settlement_slots[0].pressed.emit()
	(card_grid.get_child(1) as Button).pressed.emit()
	settlement_slots[1].pressed.emit()
	(card_grid.get_child(3) as Button).pressed.emit()
	defense_slot.pressed.emit()
	(card_grid.get_child(4) as Button).pressed.emit()
	ready_button.pressed.emit()
	await get_tree().process_frame

	var buildings: Array[ResourceBuilding] = builder.placed_buildings()
	_expect_equal(wave_economy.arrow_tower_workers, 1, "arrow tower receives defense-priority worker")
	_expect_equal(buildings[0].assigned_workers, 2, "lumber camp receives two workers")
	_expect_equal(buildings[1].assigned_workers, 2, "farm receives two workers")
	_expect_equal(wave_economy.assigned_population, 5, "five population are assigned")
	_expect_equal(wave_economy.idle_population, 1, "one population remains idle")

	var frame_budget: int = 900
	while RunState.phase == RunState.Phase.WAVE_COMBAT and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1
	_expect_equal(RunState.phase, RunState.Phase.WAVE_RESULT, "wave one reaches result")
	_expect_true(RunEconomy.amount(&"wood") > 30, "lumber produces continuously during combat")
	_expect_true(RunEconomy.amount(&"food") > 26, "farm production offsets wave-end food consumption")
	_expect_resource(&"stone", 40, "settlement does not change stone")
	_expect_true(not RunEconomy.is_hungry, "sufficient food avoids hunger")
	_expect_true(wave_economy.last_summary.contains("持续生产"), "summary explains continuous production")
	_expect_true(not wave_economy.last_summary.contains("+10木"), "summary no longer grants wave-end lumber")
	_expect_true(wave_economy.last_summary.contains("消耗6/6食"), "summary shows food consumption")
	var status_label: Label = main.get_node("HUD/BottomPanel/Margin/Content/StatusLabel") as Label
	_expect_true(status_label.text.contains("岗位5/6"), "wave result UI shows worker summary")

	var wood_after_first_settlement: int = RunEconomy.amount(&"wood")
	var food_after_first_settlement: int = RunEconomy.amount(&"food")
	_expect_true(not wave_economy.settle_wave(1, builder), "same wave cannot settle twice")
	_expect_resource(&"wood", wood_after_first_settlement, "duplicate settlement keeps wood")
	_expect_resource(&"food", food_after_first_settlement, "duplicate settlement keeps food")

	var reset_button: Button = main.get_node("HUD/BottomPanel/Margin/Content/Buttons/ResetButton") as Button
	reset_button.pressed.emit()
	await get_tree().process_frame
	start_button.pressed.emit()
	(card_grid.get_child(2) as Button).pressed.emit()
	settlement_slots[0].pressed.emit()
	RunEconomy.current_population = 1
	wave_economy.prepare_wave(builder, main.get_node("ArrowTower") as ArrowTower)
	wave_economy.set_process(false)
	_expect_equal(builder.placed_buildings()[0].assigned_workers, 1, "single worker is assigned to gold mine")
	wave_economy.advance_production(2.0)
	_expect_resource(&"gold", 21, "half staffed gold mine accumulates one gold over two seconds")
	_expect_true(wave_economy.settle_wave(1, builder), "new run can settle wave one")
	_expect_resource(&"gold", 21, "wave settlement does not add gold")
	_expect_resource(&"food", 31, "single population consumes one food")

	RunEconomy.consume_food(31)
	_expect_resource(&"food", 0, "exact food consumption may reach zero")
	RunEconomy.consume_food(1)
	_expect_resource(&"food", 0, "food shortage never becomes negative")
	_expect_true(RunEconomy.is_hungry, "food shortage marks hunger")

	reset_button.pressed.emit()
	await get_tree().process_frame
	_expect_true(not RunEconomy.is_hungry, "reset clears hunger")
	_expect_equal(wave_economy.settled_waves.size(), 0, "reset clears settled wave records")
	_expect_equal(builder.building_count(), 0, "reset clears staffed buildings")

	Engine.time_scale = 1.0
	main.queue_free()
	get_tree().quit(failure_count)


func _expect_resource(resource_id: StringName, expected: int, label: String) -> void:
	_expect_equal(RunEconomy.amount(resource_id), expected, label)


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
