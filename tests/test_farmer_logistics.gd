extends Node

const MAIN_SCENE: PackedScene = preload("res://src/main/main.tscn")
const STONE_MINE: OpeningCardDefinition = preload("res://src/data/cards/stone_mine.tres")
const HOUSE: OpeningCardDefinition = preload("res://src/data/cards/house.tres")

var failure_count: int = 0


func _ready() -> void:
	await _run_test()
	get_tree().quit(failure_count)


func _run_test() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame

	var start_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/StartButton") as Button
	var train_button := main.get_node("HUD/TrainFarmerButton") as Button
	var manager := main.get_node("FarmerManager") as FarmerManager
	var builder := main.get_node("SettlementBuilder") as SettlementBuilder
	var wave_economy := main.get_node("WaveEconomy") as WaveEconomy
	var stone_site := main.get_node("ResourceSites/StoneDeposit") as ResourceSite

	start_button.pressed.emit()
	manager.set_process(false)
	wave_economy.set_process(false)
	_expect_equal(RunEconomy.current_population, 5, "run starts with five farmers")
	_expect_equal(RunEconomy.population_capacity, 5, "run starts with five population capacity")
	_expect_equal(manager.active_farmers().size(), 5, "five farmer entities spawn around city")
	_expect_true(train_button.visible, "active run shows city farmer production button")

	for resource_id in RunEconomy.RESOURCE_IDS:
		RunEconomy.add_resource(resource_id, 500)
	var stone_building: ResourceBuilding = builder.place_card_at(STONE_MINE, stone_site.global_position)
	_expect_true(stone_building != null, "stone mine is available for farmer assignment")
	wave_economy.refresh_jobs(builder, main.get_node("ArrowTower") as ArrowTower, main.get_node("Barracks") as Barracks)
	_expect_equal(wave_economy.assigned_workers_for(&"stone_mine"), 2, "two farmers are assigned to stone mine")

	var stone_before: int = RunEconomy.amount(&"stone")
	_expect_true(wave_economy.advance_production(100.0).is_empty(), "building no longer deposits resources directly")
	manager.advance(2.0)
	_expect_equal(RunEconomy.amount(&"stone"), stone_before, "outbound farmers do not add resources")
	manager.advance(2.5)
	manager.advance(1.1)
	_expect_equal(RunEconomy.amount(&"stone"), stone_before, "gathered cargo is not credited before return")
	manager.advance(4.0)
	_expect_true(RunEconomy.amount(&"stone") > stone_before, "cargo credits only after farmers reach city")

	var house: ResourceBuilding = builder.place_card_at(HOUSE, Vector2(600.0, 160.0))
	_expect_true(house != null, "house builds on free ground")
	_expect_equal(RunEconomy.population_capacity, 7, "house raises capacity by two")
	var gold_before: int = RunEconomy.amount(&"gold")
	train_button.pressed.emit()
	_expect_equal(RunEconomy.amount(&"gold"), gold_before - 10, "city spends ten gold to train farmer")
	_expect_equal(RunEconomy.current_population, 6, "trained farmer occupies one population")
	_expect_equal(manager.active_farmers().size(), 6, "trained farmer appears as map entity")

	RunEconomy.current_population = RunEconomy.population_capacity
	var gold_at_capacity: int = RunEconomy.amount(&"gold")
	train_button.pressed.emit()
	_expect_equal(RunEconomy.amount(&"gold"), gold_at_capacity, "full population rejects training without spending gold")

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
