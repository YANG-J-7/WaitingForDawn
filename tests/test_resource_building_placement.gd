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
	var tower: ArrowTower = main.get_node("ArrowTower") as ArrowTower
	var start_button: Button = main.get_node("HUD/BottomPanel/Margin/Content/Buttons/StartButton") as Button
	var card_grid: GridContainer = main.get_node("HUD/DaySetupPanel/Margin/Content/CardGrid") as GridContainer
	var defense_slot: Button = main.get_node("HUD/DefenseSlotButton") as Button
	var settlement_slots: Array[Button] = [
		main.get_node("HUD/SettlementSlot0") as Button,
		main.get_node("HUD/SettlementSlot1") as Button,
		main.get_node("HUD/SettlementSlot2") as Button,
	]

	start_button.pressed.emit()
	await get_tree().process_frame
	_expect_resource(&"wood", 140, "initial wood")
	_expect_resource(&"food", 32, "initial food")
	_expect_resource(&"stone", 60, "initial stone")
	_expect_resource(&"iron", 30, "initial iron")
	_expect_resource(&"gold", 20, "initial gold")
	_expect_equal(RunEconomy.current_population, 6, "initial population")
	_expect_equal(RunEconomy.population_capacity, 8, "initial population capacity")
	_expect_true((main.get_node("HUD/ResourcesBar/Margin/Values/WoodValue") as Label).text.contains("140"), "resource bar shows wood")

	for card_index in [0, 1, 2, 3]:
		(card_grid.get_child(card_index) as Button).pressed.emit()
	_expect_resource(&"wood", 140, "free card selection does not spend wood")
	_expect_resource(&"stone", 60, "free card selection does not spend stone")

	settlement_slots[0].pressed.emit()
	_expect_equal(builder.building_count(), 1, "gold mine occupies first settlement slot")
	_expect_resource(&"wood", 90, "gold mine spends wood")
	_expect_resource(&"iron", 20, "gold mine spends iron")
	_expect_true(draft.is_card_locked(2), "built gold mine card locks")

	var gold_card: OpeningCardDefinition = draft.offered_cards[2]
	_expect_true(not builder.place_card(gold_card, 1), "used card cannot build twice")
	_expect_resource(&"wood", 90, "duplicate card failure keeps wood")

	(card_grid.get_child(1) as Button).pressed.emit()
	settlement_slots[0].pressed.emit()
	_expect_equal(builder.building_count(), 1, "occupied slot rejects another building")
	_expect_resource(&"wood", 90, "occupied slot failure keeps wood")
	settlement_slots[1].pressed.emit()
	_expect_equal(builder.building_count(), 2, "farm occupies second settlement slot")
	_expect_resource(&"wood", 60, "farm spends wood")
	_expect_resource(&"stone", 50, "farm spends stone")

	(card_grid.get_child(0) as Button).pressed.emit()
	settlement_slots[2].pressed.emit()
	_expect_equal(builder.building_count(), 3, "lumber camp occupies third settlement slot")
	_expect_resource(&"wood", 25, "lumber camp spends wood")

	defense_slot.pressed.emit()
	_expect_true(not tower.enabled and not tower.visible, "unaffordable arrow tower is not placed")
	_expect_resource(&"wood", 25, "failed arrow tower payment keeps wood")
	_expect_resource(&"stone", 50, "failed arrow tower payment keeps stone")

	var reset_button: Button = main.get_node("HUD/BottomPanel/Margin/Content/Buttons/ResetButton") as Button
	reset_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(RunState.phase, RunState.Phase.BOOT, "reset returns to boot")
	_expect_equal(builder.building_count(), 0, "reset clears settlement buildings")
	_expect_resource(&"wood", 0, "reset clears wood")
	_expect_resource(&"gold", 0, "reset clears gold")
	_expect_true(not tower.enabled and not tower.visible, "reset removes arrow tower")

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
