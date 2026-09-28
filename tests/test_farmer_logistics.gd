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
	var stone_site := main.get_node("ResourceSites/stone_01") as ResourceSite

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
	manager.advance(12.0)
	_expect_equal(RunEconomy.amount(&"stone"), stone_before, "outbound farmers do not add resources")
	manager.advance(2.5)
	manager.advance(1.1)
	_expect_equal(RunEconomy.amount(&"stone"), stone_before, "gathered cargo is not credited before return")
	manager.advance(12.0)
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

	for won in [false, true]:
		RunState.begin_new_run()
		RunState.start_current_wave()
		var farmer: FarmerAgent = manager.active_farmers()[0]
		farmer.state = FarmerAgent.WorkState.TO_CITY
		farmer.global_position = manager.city_position + Vector2(100, 0)
		farmer.carried_resource = &"stone"
		farmer.carried_amount = 2
		if won:
			RunState.advance_campaign_time(RunState.CAMPAIGN_DURATION_SECONDS)
			await get_tree().process_frame
		else:
			RunState.damage_city(RunState.city_health)
		var label := "胜利" if won else "失败"
		var position_before := farmer.global_position
		var balance_before := RunEconomy.balances.duplicate(true)
		manager.advance(100.0)
		_expect_equal(farmer.global_position, position_before, label + "后运输农民停止移动")
		_expect_equal(RunEconomy.balances, balance_before, label + "后携货不再入账")
		farmer.delivery_completed.emit(&"stone", 2)
		_expect_equal(RunEconomy.balances, balance_before, label + "后迟到的交付信号不入账")
		farmer.state = FarmerAgent.WorkState.GATHERING
		farmer.gather_elapsed = 0.0
		farmer.advance(100.0)
		_expect_equal(farmer.gather_elapsed, 0.0, label + "后停止采集")
	# 新局重建实体后，应恢复完整运输周期。
	main._on_reset_pressed()
	start_button.pressed.emit()
	manager.set_process(false)
	var fresh_building: ResourceBuilding = builder.place_card_at(STONE_MINE, stone_site.global_position)
	wave_economy.refresh_jobs(builder, main.arrow_tower, main.barracks)
	var fresh_balance: int = RunEconomy.amount(&"stone")
	manager.advance(100.0)
	manager.advance(2.0)
	manager.advance(100.0)
	_expect_true(fresh_building != null and RunEconomy.amount(&"stone") > fresh_balance, "重新开局后恢复运输交付")

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
