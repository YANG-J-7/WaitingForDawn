class_name RunCardInventory
extends Node

signal inventory_changed(card_count: int)

const MAX_CARDS: int = 18
const MAX_STAR: int = 3

var cards_by_instance: Dictionary = {}
var card_order: Array[int] = []
var next_instance_id: int = 0


func add_card(
	card: OpeningCardDefinition,
	source_wave: int,
	source_offer_index: int = -1,
	preferred_instance_id: int = -1,
	star: int = 1
) -> int:
	if card == null or card_order.size() >= MAX_CARDS or star < 1 or star > MAX_STAR:
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
		"star": star,
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


func count_matching(card_id: StringName, star: int) -> int:
	var count: int = 0
	for instance_id in card_order:
		var entry: Dictionary = cards_by_instance[instance_id]
		var card: OpeningCardDefinition = entry.get("card") as OpeningCardDefinition
		if card != null and card.card_id == card_id and int(entry.get("star", 1)) == star:
			count += 1
	return count


func matching_instances(card_id: StringName, star: int) -> Array[int]:
	var result: Array[int] = []
	for instance_id in card_order:
		var entry: Dictionary = cards_by_instance[instance_id]
		var card: OpeningCardDefinition = entry.get("card") as OpeningCardDefinition
		if card != null and card.card_id == card_id and int(entry.get("star", 1)) == star:
			result.append(instance_id)
	return result


func fuse_first_matching(card_id: StringName, star: int) -> int:
	var matching: Array[int] = matching_instances(card_id, star)
	if matching.size() < 3:
		return -1
	matching.resize(3)
	return fuse(matching)


func fuse(instance_ids: Array[int]) -> int:
	if instance_ids.size() != 3:
		return -1
	var unique_ids: Dictionary = {}
	var card: OpeningCardDefinition
	var star: int = -1
	var source_wave: int = 0
	for instance_id in instance_ids:
		if unique_ids.has(instance_id) or not cards_by_instance.has(instance_id):
			return -1
		unique_ids[instance_id] = true
		var entry: Dictionary = cards_by_instance[instance_id]
		var entry_card: OpeningCardDefinition = entry.get("card") as OpeningCardDefinition
		var entry_star: int = int(entry.get("star", 1))
		if entry_card == null or entry_star >= MAX_STAR:
			return -1
		if card == null:
			card = entry_card
			star = entry_star
		elif entry_card.card_id != card.card_id or entry_star != star:
			return -1
		source_wave = maxi(source_wave, int(entry.get("source_wave", 0)))
	for instance_id in instance_ids:
		cards_by_instance.erase(instance_id)
		card_order.erase(instance_id)
	var result_id: int = next_instance_id
	next_instance_id += 1
	cards_by_instance[result_id] = {
		"instance_id": result_id,
		"card": card,
		"source_wave": source_wave,
		"source_offer_index": -1,
		"star": star + 1,
	}
	card_order.append(result_id)
	inventory_changed.emit(card_order.size())
	return result_id


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
