class_name HandCardSlot
extends Button

var card_index: int = -1
var card_definition: OpeningCardDefinition
var interaction_enabled: bool = false


func configure(index: int, definition: OpeningCardDefinition) -> void:
	card_index = index
	card_definition = definition
	name = "HandCard_%d" % card_index
	custom_minimum_size = Vector2(118.0, 40.0)
	text = "%s\n拖到地图" % card_definition.display_name
	tooltip_text = card_definition.description


func set_interaction_enabled(is_enabled: bool) -> void:
	interaction_enabled = is_enabled


func drag_payload() -> Variant:
	if not interaction_enabled or card_definition == null:
		return null
	return {
		"card_index": card_index,
		"card_id": card_definition.card_id,
		"category": card_definition.category,
		"display_name": card_definition.display_name,
	}


func _get_drag_data(_at_position: Vector2) -> Variant:
	var payload: Variant = drag_payload()
	if payload == null:
		return null
	var preview := PanelContainer.new()
	var label := Label.new()
	label.custom_minimum_size = Vector2(180.0, 54.0)
	label.text = "%s\n松手建造" % card_definition.display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.add_child(label)
	set_drag_preview(preview)
	return payload
