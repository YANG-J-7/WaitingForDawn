class_name HandCardSlot
extends Button

signal fusion_requested(card_id: StringName, star: int)

var card_index: int = -1
var card_instance_id: int = -1
var card_definition: OpeningCardDefinition
var interaction_enabled: bool = false
var card_star: int = 1
var matching_count: int = 1


func configure(instance_id: int, definition: OpeningCardDefinition, star: int = 1, same_count: int = 1) -> void:
	card_index = instance_id
	card_instance_id = instance_id
	card_definition = definition
	card_star = star
	matching_count = same_count
	name = "HandCard_%d" % card_instance_id
	custom_minimum_size = Vector2(108.0, 92.0)
	text = "%s %s【%s】\n同名同星 %d/3｜建造：%s\n拖动部署%s" % [
		card_definition.display_name,
		"★".repeat(card_star),
		card_definition.category_label(),
		matching_count,
		card_definition.build_cost_text,
		"｜右键合成" if matching_count >= 3 and card_star < RunCardInventory.MAX_STAR else "",
	]
	tooltip_text = card_definition.description
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", Color("ead9ad"))
	add_theme_color_override("font_hover_color", Color("ffffff"))
	add_theme_stylebox_override("normal", _card_style(Color("1a2430"), Color("d6a94f"), 2))
	add_theme_stylebox_override("hover", _card_style(Color("223642"), Color("65c0b2"), 3))
	add_theme_stylebox_override("pressed", _card_style(Color("101820"), Color("f0c767"), 3))


func set_interaction_enabled(is_enabled: bool) -> void:
	interaction_enabled = is_enabled


func drag_payload() -> Variant:
	if not interaction_enabled or card_definition == null:
		return null
	return {
		"card_index": card_index,
		"card_instance_id": card_instance_id,
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


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if interaction_enabled and card_definition != null and matching_count >= 3 and card_star < RunCardInventory.MAX_STAR:
		fusion_requested.emit(card_definition.card_id, card_star)
		accept_event()


func _card_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style
