class_name CardDropSlot
extends Button

signal card_dropped(card_index: int)

@export var accepted_category: String = ""
@export var accepted_card_ids: PackedStringArray = []


func accepts_card_data(data: Variant) -> bool:
	if disabled or not visible or not data is Dictionary:
		return false
	var payload := data as Dictionary
	if not payload.has("card_index") or not payload.has("category") or not payload.has("card_id"):
		return false
	if not accepted_category.is_empty() and str(payload["category"]) != accepted_category:
		return false
	if not accepted_card_ids.is_empty() and str(payload["card_id"]) not in accepted_card_ids:
		return false
	return true


func drop_card_data(data: Variant) -> bool:
	if not accepts_card_data(data):
		return false
	var payload := data as Dictionary
	card_dropped.emit(int(payload.get("card_instance_id", payload["card_index"])))
	return true


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return accepts_card_data(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	drop_card_data(data)
