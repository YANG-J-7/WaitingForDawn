class_name OpeningDraft
extends Node

signal time_changed(seconds_remaining: float)
signal selection_changed(selected_indices: Array[int], free_choices_remaining: int)
signal setup_finished(selected_indices: Array[int])
signal countdown_pause_changed(is_paused: bool)

@export_range(1.0, 120.0, 1.0) var duration_seconds: float = 20.0
@export_range(1, 6, 1) var free_choice_limit: int = 4
@export var offered_cards: Array[OpeningCardDefinition] = []

var active: bool = false
var countdown_paused: bool = false
var seconds_remaining: float = 20.0
var selected_indices: Array[int] = []
var locked_indices: Array[int] = []


func _process(delta: float) -> void:
	if not active or countdown_paused:
		return
	seconds_remaining = maxf(0.0, seconds_remaining - delta)
	time_changed.emit(seconds_remaining)
	if is_zero_approx(seconds_remaining):
		finish(true)


func begin() -> void:
	selected_indices.clear()
	locked_indices.clear()
	seconds_remaining = duration_seconds
	active = true
	countdown_paused = false
	time_changed.emit(seconds_remaining)
	countdown_pause_changed.emit(countdown_paused)
	_emit_selection_changed()


func reset() -> void:
	active = false
	countdown_paused = false
	selected_indices.clear()
	locked_indices.clear()
	seconds_remaining = duration_seconds
	time_changed.emit(seconds_remaining)
	countdown_pause_changed.emit(countdown_paused)
	_emit_selection_changed()


func set_countdown_paused(is_paused: bool) -> bool:
	if not active:
		return false
	countdown_paused = is_paused
	countdown_pause_changed.emit(countdown_paused)
	return true


func toggle_card(card_index: int) -> bool:
	if not active or card_index < 0 or card_index >= offered_cards.size():
		return false
	if card_index in locked_indices:
		return false
	if card_index in selected_indices:
		selected_indices.erase(card_index)
		_emit_selection_changed()
		return true
	if selected_indices.size() >= free_choice_limit:
		return false
	selected_indices.append(card_index)
	_emit_selection_changed()
	return true


func finish(auto_fill_missing: bool = false) -> bool:
	if not active:
		return false
	if auto_fill_missing:
		_auto_fill()
	if selected_indices.size() != free_choice_limit:
		return false
	active = false
	setup_finished.emit(selected_indices.duplicate())
	return true


func is_card_selected(card_id: StringName) -> bool:
	for card_index in selected_indices:
		if offered_cards[card_index].card_id == card_id:
			return true
	return false


func lock_card(card_id: StringName) -> bool:
	for card_index in selected_indices:
		if offered_cards[card_index].card_id != card_id:
			continue
		if card_index not in locked_indices:
			locked_indices.append(card_index)
		_emit_selection_changed()
		return true
	return false


func is_card_locked(card_index: int) -> bool:
	return card_index in locked_indices


func category_count(category: String) -> int:
	var count: int = 0
	for card in offered_cards:
		if card.category == category:
			count += 1
	return count


func _auto_fill() -> void:
	if not _selection_contains_category("resource"):
		_select_lowest_price("resource")
	if not _selection_contains_category("defense"):
		_select_lowest_price("defense")
	while selected_indices.size() < free_choice_limit:
		if not _select_lowest_price(""):
			break
	_emit_selection_changed()


func _selection_contains_category(category: String) -> bool:
	for card_index in selected_indices:
		if offered_cards[card_index].category == category:
			return true
	return false


func _select_lowest_price(category_filter: String) -> bool:
	var best_index: int = -1
	var best_price: int = 1000000
	for card_index in range(offered_cards.size()):
		if card_index in selected_indices:
			continue
		var card: OpeningCardDefinition = offered_cards[card_index]
		if not category_filter.is_empty() and card.category != category_filter:
			continue
		if card.shop_price < best_price:
			best_index = card_index
			best_price = card.shop_price
	if best_index < 0:
		return false
	selected_indices.append(best_index)
	return true


func _emit_selection_changed() -> void:
	selection_changed.emit(
		selected_indices.duplicate(),
		maxi(0, free_choice_limit - selected_indices.size())
	)
