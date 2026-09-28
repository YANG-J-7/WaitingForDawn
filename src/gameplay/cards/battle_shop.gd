class_name BattleShop
extends Node

signal offers_changed
signal purchase_changed(purchased_indices: Array[int], inventory_count: int)
signal shop_refreshed(refresh_count: int, next_refresh_cost: int)

@export var card_pool: Array[OpeningCardDefinition] = []

var active: bool = false
var initialized_stage: int = 0
var offered_cards: Array[OpeningCardDefinition] = []
var purchased_indices: Array[int] = []
var refresh_count: int = 0
var last_error: String = ""


func open_for_stage(stage_index: int) -> bool:
	if not begin_stage(stage_index):
		return false
	active = true
	offers_changed.emit()
	return true


func open_for_wave(wave_index: int) -> bool:
	# 兼容旧测试入口；新版主流程按10分钟威胁阶段刷新商店。
	return open_for_stage(wave_index)


func begin_stage(stage_index: int) -> bool:
	if card_pool.size() < 6 or stage_index <= 0:
		return false
	if initialized_stage != stage_index or offered_cards.is_empty():
		initialized_stage = stage_index
		offered_cards.assign(card_pool)
		purchased_indices.clear()
		refresh_count = 0
		last_error = ""
		_shuffle_offers()
		offered_cards.resize(6)
	return true


func close() -> void:
	active = false


func purchase_card(card_index: int, inventory: RunCardInventory) -> bool:
	last_error = ""
	if not active:
		last_error = "战斗商店尚未打开。"
		return false
	if card_index < 0 or card_index >= offered_cards.size():
		last_error = "这张商店牌不存在。"
		return false
	if card_index in purchased_indices:
		last_error = "这张牌已经售罄。"
		return false
	if inventory == null or inventory.card_count() >= RunCardInventory.MAX_CARDS:
		last_error = "普通卡库存已满（18/18），请先打出或合成。"
		return false
	var card: OpeningCardDefinition = offered_cards[card_index]
	if not RunEconomy.try_pay({&"gold": card.shop_price}):
		last_error = "金币不足：购买%s需要%d金币。" % [card.display_name, card.shop_price]
		return false
	var instance_id: int = inventory.add_card(card, initialized_stage, card_index)
	if instance_id < 0:
		RunEconomy.add_resource(&"gold", card.shop_price)
		last_error = "普通卡库存已满，购买款已返还。"
		return false
	purchased_indices.append(card_index)
	purchase_changed.emit(purchased_indices.duplicate(), inventory.card_count())
	offers_changed.emit()
	return true


func current_refresh_cost() -> int:
	return mini(2 + refresh_count, 6)


func refresh() -> bool:
	last_error = ""
	if not active:
		last_error = "战斗商店尚未打开。"
		return false
	var cost: int = current_refresh_cost()
	if not RunEconomy.try_pay({&"gold": cost}):
		last_error = "金币不足：刷新需要%d金币。" % cost
		return false
	_rotate_open_offers()
	purchased_indices.clear()
	refresh_count += 1
	offers_changed.emit()
	shop_refreshed.emit(refresh_count, current_refresh_cost())
	return true


func reset() -> void:
	active = false
	initialized_stage = 0
	offered_cards.clear()
	purchased_indices.clear()
	refresh_count = 0
	last_error = ""
	offers_changed.emit()


func _shuffle_offers() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = absi(hash("%s:battle-shop:%d" % [RunState.run_id, initialized_stage]))
	for index in range(offered_cards.size() - 1, 0, -1):
		var swap_index: int = random.randi_range(0, index)
		var held: OpeningCardDefinition = offered_cards[index]
		offered_cards[index] = offered_cards[swap_index]
		offered_cards[swap_index] = held


func _rotate_open_offers() -> void:
	preload("res://src/gameplay/cards/shop_offer_refresh.gd").redraw(
		card_pool, offered_cards, [],
		absi(hash("%s:battle-shop:%d:refresh:%d" % [RunState.run_id, initialized_stage, refresh_count]))
	)
