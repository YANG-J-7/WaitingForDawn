class_name MapDropSurface
extends Control

signal card_dropped(card_index: int, map_position: Vector2)

@export var accepted_card_ids: PackedStringArray = PackedStringArray([
	"wall",
	"arrow_tower",
	"barracks",
	"lumber_camp",
	"farm",
	"gold_mine",
	"stone_mine",
	"house",
])
var interaction_enabled: bool = true
var screen_to_world: Callable


func accepts_card_data(data: Variant) -> bool:
	if not visible or not interaction_enabled or not data is Dictionary:
		return false
	var payload := data as Dictionary
	if not payload.has("card_index") or not payload.has("card_id"):
		return false
	return str(payload["card_id"]) in accepted_card_ids


func drop_card_data(data: Variant, map_position: Vector2) -> bool:
	if not accepts_card_data(data):
		return false
	var payload := data as Dictionary
	card_dropped.emit(
		int(payload.get("card_instance_id", payload["card_index"])),
		map_position
	)
	return true


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return accepts_card_data(data)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var screen_position := global_position + at_position
	var map_position: Vector2 = screen_to_world.call(screen_position) if screen_to_world.is_valid() else screen_position
	drop_card_data(data, map_position)
