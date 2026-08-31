class_name RunCardInventory
extends Node

signal inventory_changed(card_count: int)

const MAX_CARDS: int = 12

var cards_by_instance: Dictionary = {}
var card_order: Array[int] = []
var next_instance_id: int = 0


func add_card(
	card: OpeningCardDefinition,
	source_wave: int,
	source_offer_index: int = -1,
	preferred_instance_id: int = -1
) -> int:
	if card == null or card_order.size() >= MAX_CARDS:
		return -1
	var instance_id: int = preferred_instance_id
	if instance_id < 0 or cards_by_instance.has(instance_id):
		instance_id = next_instance_id
	while cards_by_instance.has(instance_id):
		instance_id += 1
	next_instance_id = maxi(next_instance_id, instance_id + 1)
	cards_by_instance[instance_id] = {
		"instance_id": instance_id,
		"card": card,
		"source_wave": source_wave,
		"source_offer_index": source_offer_index,
	}
	card_order.append(instance_id)
	inventory_changed.emit(card_order.size())
	return instance_id


func consume(instance_id: int) -> bool:
	if not cards_by_instance.has(instance_id):
		return false
	cards_by_instance.erase(instance_id)
	card_order.erase(instance_id)
	inventory_changed.emit(card_order.size())
	return true


func has_card(instance_id: int) -> bool:
	return cards_by_instance.has(instance_id)


func card_for(instance_id: int) -> OpeningCardDefinition:
	var entry: Dictionary = entry_for(instance_id)
	return entry.get("card") as OpeningCardDefinition


func entry_for(instance_id: int) -> Dictionary:
	if not cards_by_instance.has(instance_id):
		return {}
	return (cards_by_instance[instance_id] as Dictionary).duplicate()


func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance_id in card_order:
		result.append(entry_for(instance_id))
	return result


func card_count() -> int:
	return card_order.size()


func remaining_capacity() -> int:
	return MAX_CARDS - card_order.size()


func first_instance_for_card(card_id: StringName) -> int:
	for instance_id in card_order:
		var card: OpeningCardDefinition = card_for(instance_id)
		if card != null and card.card_id == card_id:
			return instance_id
	return -1


func reset() -> void:
	cards_by_instance.clear()
	card_order.clear()
	next_instance_id = 0
	inventory_changed.emit(0)
