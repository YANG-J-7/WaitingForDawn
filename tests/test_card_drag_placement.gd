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
	var start_button := main.get_node("HUD/BottomPanel/Margin/Content/Buttons/StartButton") as Button
	var ready_button := main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/ReadyButton") as Button
	var card_grid := main.get_node("HUD/DaySetupPanel/Margin/Content/CardGrid") as GridContainer
	var hand_bar := main.get_node("HUD/HandBar") as PanelContainer
	var hand_scroll := main.get_node("HUD/HandBar/Margin/Content/HandScroll") as ScrollContainer
	var hand_slots := main.get_node("HUD/HandBar/Margin/Content/HandScroll/HandSlots") as HBoxContainer
	var map_surface := main.get_node("HUD/MapDropSurface") as MapDropSurface
	var resource_sites := main.get_node("ResourceSites")
	var settlement_slots: Array[CardDropSlot] = [
		main.get_node("HUD/SettlementSlot0") as CardDropSlot,
		main.get_node("HUD/SettlementSlot1") as CardDropSlot,
		main.get_node("HUD/SettlementSlot2") as CardDropSlot,
	]
	var defense_slot := main.get_node("HUD/DefenseSlotButton") as CardDropSlot

	start_button.pressed.emit()
	_expect_true(not hand_bar.visible, "hand bar stays hidden before card selection finishes")
	_expect_equal(hand_slots.get_child_count(), 0, "hidden hand has no cards")
	_expect_true(not settlement_slots[0].visible and not defense_slot.visible, "map deployment targets stay hidden during selection")
	_expect_true(not card_grid.get_child(0) is HandCardSlot, "shop offer itself is not draggable hand card")

	(card_grid.get_child(0) as Button).pressed.emit()
	_expect_true(not hand_bar.visible, "one selected card does not show hand bar")
	(card_grid.get_child(3) as Button).pressed.emit()
	_expect_true(not hand_bar.visible, "two selected cards do not show hand bar")
	(card_grid.get_child(1) as Button).pressed.emit()
	_expect_true(not hand_bar.visible, "three selected cards do not show hand bar")
	(card_grid.get_child(2) as Button).pressed.emit()
	_expect_true(not hand_bar.visible, "completed selection still keeps hand bar hidden")
	_expect_equal(hand_slots.get_child_count(), 0, "completed selection does not create hand before battle")
	_expect_true("已选择" in (card_grid.get_child(0) as Button).text, "shop offer reports selected state")

	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "ready starts battle before hand appears")
	_expect_true(hand_bar.visible, "battle start reveals bottom hand bar")
	_expect_equal(hand_slots.get_child_count(), 4, "battle hand contains four selected cards")
	_expect_true(hand_slots.size.x <= hand_scroll.size.x or hand_scroll.get_h_scroll_bar() != null, "hand cards use a horizontal scroll viewport instead of overlapping")
	_expect_true(map_surface.visible, "battle exposes unified map deployment surface")
	_expect_true(not settlement_slots[0].visible and not defense_slot.visible, "legacy fixed deployment targets stay hidden")
	_expect_true(hand_bar.position.y >= 400.0, "hand bar is anchored at the bottom of the battle view")
	var lumber_hand := hand_slots.get_node("HandCard_0") as HandCardSlot
	_expect_true(lumber_hand.custom_minimum_size.y >= 80.0, "battle hand uses tall readable card slots")
	var lumber_data: Variant = lumber_hand.drag_payload()
	_expect_true(lumber_data is Dictionary, "hand card exposes drag payload")
	_expect_true(map_surface.accepts_card_data(lumber_data), "resource hand card accepts map target")
	map_surface.drop_card_data(lumber_data, (resource_sites.get_node("forest_02") as Node2D).global_position)
	_expect_equal(builder.building_count(), 1, "resource hand drop constructs building")
	_expect_equal(RunEconomy.amount(&"wood"), 80, "resource hand drop uses atomic cost")
	_expect_true(draft.is_card_locked(0), "successful resource drop locks selected card")
	_expect_equal(hand_slots.get_child_count(), 3, "successful construction consumes one hand card")

	var arrow_hand := hand_slots.get_node("HandCard_3") as HandCardSlot
	var arrow_data: Variant = arrow_hand.drag_payload()
	_expect_true(map_surface.accepts_card_data(arrow_data), "arrow hand card accepts free map target")
	map_surface.drop_card_data(arrow_data, Vector2(900, 1008))
	_expect_true(tower.visible and tower.enabled, "arrow hand drop constructs tower")
	_expect_equal(RunEconomy.amount(&"wood"), 35, "arrow hand drop spends wood")
	_expect_equal(RunEconomy.amount(&"stone"), 90, "arrow hand drop spends stone")
	_expect_equal(hand_slots.get_child_count(), 2, "tower construction consumes one hand card")

	var farm_hand := hand_slots.get_node("HandCard_1") as HandCardSlot
	var farm_data: Variant = farm_hand.drag_payload()
	var wood_before_occupied: int = RunEconomy.amount(&"wood")
	map_surface.drop_card_data(farm_data, Vector2(4200, 2200))
	_expect_equal(hand_slots.get_child_count(), 2, "rejected target keeps all remaining hand cards")
	_expect_equal(RunEconomy.amount(&"wood"), wood_before_occupied, "rejected target keeps resources")
	map_surface.drop_card_data(farm_data, Vector2(760, 1080))
	_expect_equal(builder.building_count(), 2, "second legal hand drop constructs farm")
	_expect_equal(hand_slots.get_child_count(), 1, "farm leaves hand only after success")

	var stone_hand := hand_slots.get_node("HandCard_2") as HandCardSlot
	var stone_data: Variant = stone_hand.drag_payload()
	var wood_before_unaffordable: int = RunEconomy.amount(&"wood")
	var iron_before_unaffordable: int = RunEconomy.amount(&"iron")
	map_surface.drop_card_data(stone_data, (resource_sites.get_node("stone_01") as Node2D).global_position)
	_expect_true(not draft.is_card_locked(2), "unaffordable drop does not consume selected card")
	_expect_equal(hand_slots.get_child_count(), 1, "unaffordable card remains in hand bar")
	_expect_equal(RunEconomy.amount(&"wood"), wood_before_unaffordable, "unaffordable drop keeps wood")
	_expect_equal(RunEconomy.amount(&"iron"), iron_before_unaffordable, "unaffordable drop keeps iron")
	_expect_true("拖动部署" in stone_hand.text, "hand slot explains drag action")

	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "card deployment stays inside battle phase")
	_expect_true(hand_bar.visible, "battle keeps hand bar visible")
	_expect_true(stone_hand.drag_payload() is Dictionary, "battle allows remaining hand card dragging")
	for _index in range(RunCardInventory.MAX_CARDS - main.run_card_inventory.card_count()):
		main.run_card_inventory.add_card(preload("res://src/data/cards/farm.tres"), 2)
	main._populate_battle_hand()
	await get_tree().process_frame
	_expect_equal(hand_slots.get_child_count(), RunCardInventory.MAX_CARDS, "full inventory renders every hand card")
	_expect_true(hand_slots.size.x > hand_scroll.size.x, "overflowing hand extends inside the horizontal scroll viewport")
	_expect_true(hand_scroll.get_h_scroll_bar().max_value > hand_scroll.get_h_scroll_bar().page, "overflowing hand exposes horizontal scrolling")

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
