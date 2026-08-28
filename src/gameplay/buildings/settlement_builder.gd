class_name SettlementBuilder
extends Node2D

signal building_placed(slot_index: int, card_id: StringName)
signal buildings_reset

const RESOURCE_BUILDING_SCENE: PackedScene = preload(
	"res://src/gameplay/buildings/resource_building.tscn"
)

@export var slot_positions: Array[Vector2] = [
	Vector2(248.0, 188.0),
	Vector2(366.0, 188.0),
	Vector2(484.0, 188.0),
]

var buildings_by_slot: Dictionary = {}
var consumed_card_ids: Array[StringName] = []
var placement_order: Array[ResourceBuilding] = []
var last_error: String = ""


func place_card(card: OpeningCardDefinition, slot_index: int) -> bool:
	last_error = ""
	if card == null or card.category != "resource":
		last_error = "该卡不能放入聚落格。"
		return false
	if slot_index < 0 or slot_index >= slot_positions.size():
		last_error = "聚落格不存在。"
		return false
	if buildings_by_slot.has(slot_index):
		last_error = "这个聚落格已经有建筑。"
		return false
	if card.card_id in consumed_card_ids:
		last_error = "这张建筑卡已经使用。"
		return false
	if not RunEconomy.try_pay(card.build_costs):
		last_error = "建造资源不足。"
		return false

	var building := RESOURCE_BUILDING_SCENE.instantiate() as ResourceBuilding
	add_child(building)
	building.position = slot_positions[slot_index]
	building.configure(card)
	buildings_by_slot[slot_index] = building
	consumed_card_ids.append(card.card_id)
	placement_order.append(building)
	building_placed.emit(slot_index, card.card_id)
	return true


func reset_buildings() -> void:
	for building: Variant in buildings_by_slot.values():
		if is_instance_valid(building):
			(building as Node).queue_free()
	buildings_by_slot.clear()
	consumed_card_ids.clear()
	placement_order.clear()
	last_error = ""
	buildings_reset.emit()


func building_count() -> int:
	return buildings_by_slot.size()


func placed_buildings() -> Array[ResourceBuilding]:
	return placement_order.duplicate()
