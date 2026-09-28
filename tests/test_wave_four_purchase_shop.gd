extends Node

const MAIN_SCENE: PackedScene = preload("res://src/main/main.tscn")
const CARD_POOL: Array[OpeningCardDefinition] = [
	preload("res://src/data/cards/lumber_camp.tres"),
	preload("res://src/data/cards/farm.tres"),
	preload("res://src/data/cards/gold_mine.tres"),
	preload("res://src/data/cards/arrow_tower_card.tres"),
	preload("res://src/data/cards/wall.tres"),
	preload("res://src/data/cards/barracks.tres"),
]

var failure_count: int = 0


func _ready() -> void:
	_run_test()


func _run_test() -> void:
	await _test_purchase_rules()
	await _test_wave_four_integration()
	get_tree().quit(failure_count)


func _test_purchase_rules() -> void:
	var inventory := RunCardInventory.new()
	var shop := InterwaveDraft.new()
	shop.card_pool.assign(CARD_POOL)
	add_child(inventory)
	add_child(shop)
	RunEconomy.begin_run()
	RunEconomy.add_resource(&"gold", 100)
	_expect_true(shop.begin(4, inventory.card_count()), "wave four purchase shop opens")
	_expect_true(shop.is_purchase_mode(), "wave four uses purchase mode")
	_expect_equal(shop.required_free_choices(), 0, "purchase mode has no free choices")
	_expect_true(shop.finish(), "purchase mode permits zero-card finish")

	shop.begin(4, inventory.card_count())
	var starting_gold: int = RunEconomy.amount(&"gold")
	var total_price: int = 0
	for card_index in range(6):
		total_price += shop.offered_cards[card_index].shop_price
		_expect_true(shop.purchase_card(card_index, inventory), "offer %d can be purchased" % card_index)
	_expect_equal(inventory.card_count(), 6, "all six offers can enter empty inventory")
	_expect_equal(shop.purchased_indices.size(), 6, "all six offers become sold out")
	_expect_equal(RunEconomy.amount(&"gold"), starting_gold - total_price, "six purchases spend exact card prices")
	var gold_after_all: int = RunEconomy.amount(&"gold")
	_expect_true(not shop.purchase_card(0, inventory), "sold offer cannot be bought twice")
	_expect_equal(RunEconomy.amount(&"gold"), gold_after_all, "duplicate purchase spends no gold")
	_expect_true(shop.refresh(), "all-sold shop can refresh every slot")
	_expect_equal(RunEconomy.amount(&"gold"), gold_after_all - 2, "full refresh spends current refresh cost")
	_expect_true(shop.purchased_indices.is_empty(), "full refresh clears every sold-out marker")
	_expect_true(shop.purchase_card(0, inventory), "refreshed slot can be purchased again")

	inventory.reset()
	shop.begin(4, inventory.card_count())
	for index in range(RunCardInventory.MAX_CARDS):
		inventory.add_card(CARD_POOL[0], 4)
	RunEconomy.add_resource(&"gold", 100)
	var gold_before_full: int = RunEconomy.amount(&"gold")
	_expect_true(not shop.purchase_card(0, inventory), "full inventory rejects purchase")
	_expect_equal(RunEconomy.amount(&"gold"), gold_before_full, "full inventory rejection spends no gold")
	_expect_true("18" in shop.last_error, "full inventory error explains capacity")

	inventory.reset()
	shop.begin(4, inventory.card_count())
	var first_price: int = shop.offered_cards[0].shop_price
	var current_gold: int = RunEconomy.amount(&"gold")
	RunEconomy.try_pay({&"gold": current_gold - first_price})
	_expect_true(shop.purchase_card(0, inventory), "gold exactly equal to price can purchase")
	_expect_equal(RunEconomy.amount(&"gold"), 0, "exact-price purchase leaves zero gold")
	var inventory_after_exact: int = inventory.card_count()
	_expect_true(not shop.purchase_card(1, inventory), "insufficient gold rejects purchase")
	_expect_equal(inventory.card_count(), inventory_after_exact, "insufficient purchase keeps inventory")
	_expect_true("金币不足" in shop.last_error, "insufficient purchase exposes reason")

	shop.queue_free()
	inventory.queue_free()
	await get_tree().process_frame


func _test_wave_four_integration() -> void:
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
	var selection_label := main.get_node("HUD/DaySetupPanel/Margin/Content/Header/SelectionLabel") as Label
	var setup_hint := main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/SetupHintLabel") as Label
	var defense_slot := main.get_node("HUD/DefenseSlotButton") as Button

	start_button.pressed.emit()
	for card_index in [0, 3, 4, 5]:
		(card_grid.get_child(card_index) as Button).pressed.emit()
	defense_slot.pressed.emit()
	ready_button.pressed.emit()
	await get_tree().process_frame
	main._on_battle_shop_button_pressed()
	_expect_equal(RunState.current_wave, 1, "battle shop opens without waiting for wave clear")
	_expect_true(shop.active, "continuous battle shop uses purchase mode")
	_expect_true(not ready_button.disabled, "battle shop can be closed without purchase")
	_expect_true("金币" in selection_label.text, "shop header displays current gold")
	_expect_true("金币不足" in (card_grid.get_child(0) as Button).text, "zero-gold offer explains unavailable purchase")
	_expect_true("金" in (card_grid.get_child(0) as Button).text, "offer displays gold price")

	_set_gold(100)
	_expect_true("购买" in (card_grid.get_child(0) as Button).text, "affordable offer displays purchase action")
	var inventory_before_purchase: int = inventory.card_count()
	var offer_card: OpeningCardDefinition = shop.offered_cards[0]
	var offer_price: int = offer_card.shop_price
	var gold_before_purchase: int = RunEconomy.amount(&"gold")
	(card_grid.get_child(0) as Button).pressed.emit()
	_expect_equal(inventory.card_count(), inventory_before_purchase + 1, "UI purchase immediately adds inventory card")
	_expect_equal(RunEconomy.amount(&"gold"), gold_before_purchase - offer_price, "UI purchase spends displayed price")
	_expect_true(0 in shop.purchased_indices, "purchased UI slot is sold out")
	_expect_true("已售罄" in (card_grid.get_child(0) as Button).text, "purchased offer displays sold out")
	var inventory_after_purchase: int = inventory.card_count()
	refresh_button.pressed.emit()
	_expect_equal(inventory.card_count(), inventory_after_purchase, "refresh preserves purchased inventory")
	_expect_true(shop.purchased_indices.is_empty(), "refresh clears sold-out state")
	_expect_true("购买" in (card_grid.get_child(0) as Button).text, "refreshed slot is purchasable again")
	var inventory_before_repeat: int = inventory.card_count()
	(card_grid.get_child(0) as Button).pressed.emit()
	_expect_equal(inventory.card_count(), inventory_before_repeat + 1, "refreshed slot can be purchased repeatedly")

	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "closing shop keeps current wave running")
	_expect_equal(controller.active_wave_index, 1, "controller keeps current threat template")
	preload("res://tests/helpers/shop_wave_fixture.gd").clear_wave(controller)
	while 1 not in wave_economy.settled_waves:
		await get_tree().process_frame
	_expect_equal(RunState.current_wave, 2, "wave clear advances to wave two")
	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "wave two auto starts without planning pause")
	_expect_true(1 in wave_economy.settled_waves, "wave one settles once")
	_expect_true(controller.spawning, "wave two starts spawning automatically")

	var reset_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/ResetButton") as Button
	reset_button.pressed.emit()
	await get_tree().process_frame
	_expect_true(shop.purchased_indices.is_empty(), "reset clears purchased offer state")

	Engine.time_scale = 1.0
	main.queue_free()


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
