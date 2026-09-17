extends Node

const CARDS: Array[OpeningCardDefinition] = [
	preload("res://src/data/cards/lumber_camp.tres"),
	preload("res://src/data/cards/farm.tres"),
	preload("res://src/data/cards/stone_mine.tres"),
	preload("res://src/data/cards/arrow_tower_card.tres"),
	preload("res://src/data/cards/wall.tres"),
	preload("res://src/data/cards/barracks.tres"),
]

var failures: int = 0


func _ready() -> void:
	_test_initial_state_and_opening_gate()
	_test_kill_gold_ledger()
	_test_shop_refresh_and_capacity()
	_test_manual_fusion_and_reset()
	get_tree().quit(failures)


func _test_initial_state_and_opening_gate() -> void:
	RunEconomy.begin_run()
	for resource_id in [&"wood", &"food", &"stone", &"iron"]:
		check(RunEconomy.amount(resource_id) == 100, "%s初始为100" % resource_id)
	check(RunEconomy.amount(&"gold") == 0, "金币初始为0")
	check(RunEconomy.current_population == 5 and RunEconomy.population_capacity == 5, "人口初始为5/5")
	var draft := OpeningDraft.new()
	draft.offered_cards.assign(CARDS)
	add_child(draft)
	draft.begin()
	for index in [0, 1, 2, 4]:
		draft.toggle_card(index)
	check(not draft.can_finish(), "四张无伤害牌不能确认")
	var selection_before: Array[int] = draft.selected_indices.duplicate()
	check(not draft.finish(), "伤害牌门槛拒绝确认")
	check(draft.selected_indices == selection_before and draft.active, "拒绝确认保持免费选择")
	draft.toggle_card(4)
	draft.toggle_card(3)
	check(draft.can_finish() and draft.finish(), "包含箭塔的四张牌可以确认")
	draft.queue_free()


func _test_kill_gold_ledger() -> void:
	RunEconomy.begin_run()
	var ledger := KillGoldLedger.new()
	check(ledger.award(&"normal-1", 2), "普通敌人首次死亡奖励2金币")
	check(ledger.award(&"tough-1", 4), "强敌首次死亡奖励4金币")
	check(ledger.award(&"elite-1", 8), "精英首次死亡奖励8金币")
	check(ledger.award(&"boss-1", 20), "首领首次死亡奖励20金币")
	check(RunEconomy.amount(&"gold") == 34, "四档奖励合计正确")
	check(not ledger.award(&"normal-1", 2), "重复死亡事务不重复发奖")
	check(not ledger.award(&"cleanup-1", 20, false), "清理敌人不发金币")
	check(RunEconomy.amount(&"gold") == 34 and ledger.claimed_count() == 4, "拒绝发奖不污染余额与账本")
	ledger.reset()
	check(ledger.claimed_count() == 0, "新局重置清空奖励事务")
	check(ledger.award(&"normal-1", 2), "新局可以使用新的同名事务标识")


func _test_shop_refresh_and_capacity() -> void:
	RunEconomy.begin_run()
	RunEconomy.add_resource(&"gold", 100)
	var shop := BattleShop.new()
	var inventory := RunCardInventory.new()
	shop.card_pool.assign(CARDS)
	add_child(shop)
	add_child(inventory)
	check(shop.open_for_wave(1), "六格商店可以打开")
	check(shop.offered_cards.size() == 6, "商店固定六个1星槽位")
	var expected_costs: Array[int] = [2, 3, 4, 5, 6, 6]
	for expected in expected_costs:
		var before: int = RunEconomy.amount(&"gold")
		check(shop.current_refresh_cost() == expected, "刷新费用为%d" % expected)
		check(shop.refresh(), "支付%d金币刷新成功" % expected)
		check(RunEconomy.amount(&"gold") == before - expected, "刷新精确扣除%d金币" % expected)
	check(shop.current_refresh_cost() == 6, "刷新费用封顶6金币")
	check(shop.open_for_wave(2), "新威胁阶段补满商店")
	check(shop.refresh_count == 0 and shop.current_refresh_cost() == 2, "新威胁阶段重置刷新费用")
	for index in range(RunCardInventory.MAX_CARDS):
		inventory.add_card(CARDS[0], 1)
	var gold_before: int = RunEconomy.amount(&"gold")
	check(not shop.purchase_card(0, inventory), "18张满手牌拒绝购买")
	check(RunEconomy.amount(&"gold") == gold_before and inventory.card_count() == 18, "满手购买原子失败")
	shop.queue_free()
	inventory.queue_free()


func _test_manual_fusion_and_reset() -> void:
	var inventory := RunCardInventory.new()
	add_child(inventory)
	var ids: Array[int] = []
	for index in range(3):
		ids.append(inventory.add_card(CARDS[3], 1))
	var result_id: int = inventory.fuse(ids)
	var result: Dictionary = inventory.entry_for(result_id)
	check(result_id >= 0 and inventory.card_count() == 1, "三张同卡精确合成一张")
	check(int(result.get("star", 0)) == 2, "三张1星合成一张2星")
	var mixed_ids: Array[int] = [result_id]
	mixed_ids.append(inventory.add_card(CARDS[3], 1))
	mixed_ids.append(inventory.add_card(CARDS[4], 2, -1, -1, 2))
	var before_entries: Array[Dictionary] = inventory.entries()
	check(inventory.fuse(mixed_ids) < 0, "不同名或不同星不能合成")
	check(inventory.entries() == before_entries, "非法合成不吞卡")
	inventory.reset()
	var two_star_ids: Array[int] = []
	for index in range(3):
		two_star_ids.append(inventory.add_card(CARDS[3], 1, -1, -1, 2))
	var three_star_id: int = inventory.fuse(two_star_ids)
	check(int(inventory.entry_for(three_star_id).get("star", 0)) == 3, "三张2星合成一张3星")
	var three_star_ids: Array[int] = [three_star_id]
	three_star_ids.append(inventory.add_card(CARDS[3], 1, -1, -1, 3))
	three_star_ids.append(inventory.add_card(CARDS[3], 1, -1, -1, 3))
	check(inventory.fuse(three_star_ids) < 0 and inventory.card_count() == 3, "3星达到原型上限且失败不消费")
	inventory.reset()
	check(inventory.card_count() == 0 and inventory.next_instance_id == 0, "新局清空手牌、星级和实例序号")
	inventory.queue_free()


func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
		return
	failures += 1
	push_error("FAIL: " + label)
