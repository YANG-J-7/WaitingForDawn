class_name InterwaveDraft
extends Node

signal selection_changed(selected_indices: Array[int], free_choices_remaining: int)
signal selection_finished(selected_cards: Array[OpeningCardDefinition])
signal shop_refreshed(refresh_count: int, next_refresh_cost: int)
signal purchase_changed(purchased_indices: Array[int], inventory_count: int)

@export_range(1, 6, 1) var free_choice_limit: int = 2
@export var card_pool: Array[OpeningCardDefinition] = []

var active: bool = false
var wave_index: int = 0
var inventory_count_at_open: int = 0
var offered_cards: Array[OpeningCardDefinition] = []
var selected_indices: Array[int] = []
var purchased_indices: Array[int] = []
var refresh_count: int = 0
var last_error: String = ""


func begin(next_wave_index: int, current_inventory_count: int) -> bool:
	if card_pool.size() < 6:
		return false
	wave_index = next_wave_index
	inventory_count_at_open = current_inventory_count
	selected_indices.clear()
	purchased_indices.clear()
	refresh_count = 0
	last_error = ""
	offered_cards.assign(card_pool)
	_shuffle_offers()
	active = true
	_emit_selection_changed()
	return true


func toggle_card(card_index: int) -> bool:
	if is_purchase_mode() or not active or card_index < 0 or card_index >= offered_cards.size():
		return false
	if card_index in selected_indices:
		selected_indices.erase(card_index)
		_emit_selection_changed()
		return true
	if selected_indices.size() >= required_free_choices():
		return false
	if inventory_count_at_open + selected_indices.size() >= RunCardInventory.MAX_CARDS:
		return false
	selected_indices.append(card_index)
	_emit_selection_changed()
	return true


func finish() -> bool:
	if not active:
		return false
	if not is_purchase_mode() and selected_indices.size() != required_free_choices():
		return false
	var selected_cards: Array[OpeningCardDefinition] = []
	for card_index in selected_indices:
		selected_cards.append(offered_cards[card_index])
	active = false
	selection_finished.emit(selected_cards)
	return true


func is_purchase_mode() -> bool:
	return wave_index >= 4


func required_free_choices() -> int:
	return 0 if is_purchase_mode() else free_choice_limit


func purchase_card(card_index: int, inventory: RunCardInventory) -> bool:
	last_error = ""
	if not active or not is_purchase_mode():
		last_error = "当前商店不是金币购买阶段。"
		return false
	if card_index < 0 or card_index >= offered_cards.size():
		last_error = "这张商店牌不存在。"
		return false
	if card_index in purchased_indices:
		last_error = "这张牌已经售罄。"
		return false
	if inventory == null or inventory.card_count() >= RunCardInventory.MAX_CARDS:
		last_error = "普通卡库存已满（12/12），请先打出或弃牌。"
		return false
	var card: OpeningCardDefinition = offered_cards[card_index]
	if not RunEconomy.can_pay({&"gold": card.shop_price}):
		last_error = "金币不足：购买%s需要%d金币。" % [card.display_name, card.shop_price]
		return false
	if not RunEconomy.try_pay({&"gold": card.shop_price}):
		last_error = "金币状态已变化，请重试。"
		return false
	var instance_id: int = inventory.add_card(card, wave_index, card_index)
	if instance_id < 0:
		RunEconomy.add_resource(&"gold", card.shop_price)
		last_error = "普通卡库存已满（12/12），购买款已返还。"
		return false
	purchased_indices.append(card_index)
	inventory_count_at_open = inventory.card_count()
	purchase_changed.emit(purchased_indices.duplicate(), inventory.card_count())
	_emit_selection_changed()
	return true


func current_refresh_cost() -> int:
	return 10 + 5 * refresh_count


func refresh() -> bool:
	if not active:
		return false
	if selected_indices.size() + purchased_indices.size() >= offered_cards.size():
		last_error = "当前商店没有可刷新的卡牌。"
		return false
	var cost: int = current_refresh_cost()
	if not RunEconomy.try_pay({&"gold": cost}):
		last_error = "金币不足：刷新需要%d金币。" % cost
		return false
	last_error = ""
	_rotate_unselected_offers()
	refresh_count += 1
	_emit_selection_changed()
	shop_refreshed.emit(refresh_count, current_refresh_cost())
	return true


func reset() -> void:
	active = false
	wave_index = 0
	inventory_count_at_open = 0
	offered_cards.clear()
	selected_indices.clear()
	purchased_indices.clear()
	refresh_count = 0
	last_error = ""
	_emit_selection_changed()


func _shuffle_offers() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = absi(hash("%s:%d" % [RunState.run_id, wave_index]))
	for index in range(offered_cards.size() - 1, 0, -1):
		var swap_index: int = random.randi_range(0, index)
		var held: OpeningCardDefinition = offered_cards[index]
		offered_cards[index] = offered_cards[swap_index]
		offered_cards[swap_index] = held


func _rotate_unselected_offers() -> void:
	var open_indices: Array[int] = []
	var previous_cards: Array[OpeningCardDefinition] = []
	for card_index in range(offered_cards.size()):
		if card_index in selected_indices or card_index in purchased_indices:
			continue
		open_indices.append(card_index)
		previous_cards.append(offered_cards[card_index])
	if open_indices.size() <= 1:
		return
	var random := RandomNumberGenerator.new()
	random.seed = absi(hash("%s:%d:refresh:%d" % [RunState.run_id, wave_index, refresh_count]))
	var shift: int = random.randi_range(1, open_indices.size() - 1)
	for position in range(open_indices.size()):
		offered_cards[open_indices[position]] = previous_cards[
			(position + shift) % previous_cards.size()
		]


func _emit_selection_changed() -> void:
	selection_changed.emit(
		selected_indices.duplicate(),
		maxi(0, required_free_choices() - selected_indices.size())
	)
