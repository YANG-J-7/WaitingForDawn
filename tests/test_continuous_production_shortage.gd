extends Node

const MAIN_SCENE: PackedScene = preload("res://src/main/main.tscn")

var failure_count: int = 0


func _ready() -> void:
	_run_test()


func _run_test() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame

	var draft: OpeningDraft = main.get_node("OpeningDraft") as OpeningDraft
	var builder: SettlementBuilder = main.get_node("SettlementBuilder") as SettlementBuilder
	var wave_economy: WaveEconomy = main.get_node("WaveEconomy") as WaveEconomy
	var start_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/StartButton") as Button
	var card_grid := main.get_node("HUD/DaySetupPanel/Margin/Content/CardGrid") as GridContainer
	var defense_slot := main.get_node("HUD/DefenseSlotButton") as Button
	var shortage_panel := main.get_node("HUD/BuildFailurePanel") as PanelContainer
	var shortage_detail := main.get_node("HUD/BuildFailurePanel/Margin/Content/Detail") as Label
	var shortage_close := main.get_node("HUD/BuildFailurePanel/Margin/Content/CloseButton") as Button
	var wood_label := main.get_node("HUD/ResourcesBar/Margin/Values/WoodValue") as Label
	var settlement_slots: Array[Button] = [
		main.get_node("HUD/SettlementSlot0") as Button,
		main.get_node("HUD/SettlementSlot1") as Button,
		main.get_node("HUD/SettlementSlot2") as Button,
	]

	start_button.pressed.emit()
	wave_economy.set_process(false)
	for card_index in [0, 1, 2, 3]:
		(card_grid.get_child(card_index) as Button).pressed.emit()

	settlement_slots[0].pressed.emit()
	(card_grid.get_child(1) as Button).pressed.emit()
	settlement_slots[1].pressed.emit()
	(card_grid.get_child(0) as Button).pressed.emit()
	settlement_slots[2].pressed.emit()
	_expect_equal(builder.building_count(), 3, "three resource buildings are constructed during day setup")
	_expect_equal(wave_economy.assigned_population, 6, "new buildings receive workers immediately")
	_expect_equal(draft.offered_cards[0].production_per_second, 2.0, "lumber rate is data driven")
	_expect_equal(draft.offered_cards[1].production_per_second, 2.0, "farm rate is data driven")
	_expect_equal(draft.offered_cards[2].production_per_second, 1.0, "gold mine rate is data driven")

	var produced: Dictionary = wave_economy.advance_production(1.0)
	_expect_equal(int(produced.get(&"wood", 0)), 2, "full lumber camp produces two wood per second")
	_expect_equal(int(produced.get(&"food", 0)), 2, "full farm produces two food per second")
	_expect_equal(int(produced.get(&"gold", 0)), 1, "full gold mine produces one gold per second")
	_expect_resource(&"wood", 27, "wood enters balance before wave starts")
	_expect_resource(&"food", 34, "food enters balance before wave starts")
	_expect_resource(&"gold", 21, "gold enters balance before wave starts")
	_expect_true("27" in wood_label.text, "resource bar updates immediately")

	_expect_true(wave_economy.adjust_workers(&"gold_mine", -1), "one gold worker can be removed")
	_expect_equal(int(wave_economy.advance_production(1.0).get(&"gold", 0)), 0, "half gold rate retains first fractional unit")
	_expect_equal(int(wave_economy.advance_production(1.0).get(&"gold", 0)), 1, "half gold rate pays after two seconds")

	var wood_before_settlement: int = RunEconomy.amount(&"wood")
	var gold_before_settlement: int = RunEconomy.amount(&"gold")
	var food_before_settlement: int = RunEconomy.amount(&"food")
	_expect_true(wave_economy.settle_wave(1, builder), "wave settlement still runs")
	_expect_resource(&"wood", wood_before_settlement, "settlement does not add wood production")
	_expect_resource(&"gold", gold_before_settlement, "settlement does not add gold production")
	_expect_resource(&"food", food_before_settlement - RunEconomy.current_population, "settlement only consumes population food")
	_expect_true("持续生产" in wave_economy.last_summary, "settlement summary explains continuous production")

	defense_slot.pressed.emit()
	_expect_true(shortage_panel.visible, "insufficient building resources open popup")
	_expect_true("箭塔" in shortage_detail.text, "popup identifies requested building")
	_expect_true("木材" in shortage_detail.text, "popup names missing resource")
	_expect_true("还缺" in shortage_detail.text, "popup shows missing amount")
	_expect_true(not draft.is_card_locked(3), "failed building keeps card")
	_expect_true(not (main.get_node("ArrowTower") as ArrowTower).visible, "failed building keeps defense slot empty")
	shortage_close.pressed.emit()
	_expect_true(not shortage_panel.visible, "popup can be dismissed")

	var reset_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/ResetButton") as Button
	reset_button.pressed.emit()
	await get_tree().process_frame
	_expect_true(wave_economy.production_progress.is_empty(), "reset clears fractional production progress")
	_expect_true(not shortage_panel.visible, "reset closes shortage popup")

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
