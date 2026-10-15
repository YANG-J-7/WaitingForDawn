class_name HandCardSlot
extends Button

const ArtVisualScript = preload("res://src/gameplay/art/art_visual.gd")
const ART_ROOT := "res://assets/art_candidates/night_set_v1/"
static var illustration_cache: Dictionary = {}

signal fusion_requested(card_id: StringName, star: int)

var card_index: int = -1
var card_instance_id: int = -1
var card_definition: OpeningCardDefinition
var interaction_enabled: bool = false
var card_star: int = 1
var matching_count: int = 1
var illustration: TextureRect
var title_label: Label
var cost_label: Label
var hint_label: Label
var reference_face: Control


func _ready() -> void:
	_create_card_visuals()


func _create_card_visuals() -> void:
	if illustration != null:
		return
	illustration = TextureRect.new()
	illustration.position = Vector2(22, 21)
	illustration.size = Vector2(94, 45)
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	illustration.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(illustration)
	title_label = _make_label(Vector2(7, 4), Vector2(124, 18), 12)
	cost_label = _make_label(Vector2(7, 65), Vector2(124, 13), 10)
	hint_label = _make_label(Vector2(7, 78), Vector2(124, 12), 9)


func _make_label(at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("24180d"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


static func _illustration_for(card_id: StringName) -> Texture2D:
	var art_name: String = str({
		&"lumber_camp": "lumberyard",
		&"farm": "farm",
		&"stone_mine": "quarry",
		&"gold_mine": "mine_entrance",
		&"iron_mine": "mine_entrance",
		&"arrow_tower": "arrow_tower",
		&"wall": "palisade_wall",
		&"barracks": "barracks",
		&"house": "house",
	}.get(card_id, "house"))
	if illustration_cache.has(art_name):
		return illustration_cache[art_name] as Texture2D
	var source: Texture2D = load(ART_ROOT + art_name + ".png") as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	var used: Rect2i = ArtVisualScript._visible_region(source.get_image())
	atlas.region = Rect2(Vector2(used.position), Vector2(used.size))
	illustration_cache[art_name] = atlas
	return atlas


func configure(instance_id: int, definition: OpeningCardDefinition, star: int = 1, same_count: int = 1) -> void:
	_create_card_visuals()
	card_index = instance_id
	card_instance_id = instance_id
	card_definition = definition
	card_star = star
	matching_count = same_count
	name = "HandCard_%d" % card_instance_id
	custom_minimum_size = Vector2(138.0, 96.0)
	var fusion_text := "同星 %d/3" % matching_count
	if matching_count >= 3:
		fusion_text = "同星 ×%d｜可合成%d次" % [matching_count, floori(float(matching_count) / 3.0)]
	text = "%s  %s\n%s｜%s\n建造 %s%s" % [
		card_definition.display_name,
		"★".repeat(card_star),
		card_definition.category_label(),
		fusion_text,
		card_definition.build_cost_text,
		"｜右键合成" if matching_count >= 3 and card_star < RunCardInventory.MAX_STAR else "｜拖动部署",
	]
	tooltip_text = "%s\n建造：%s\n拖动部署；%s" % [
		card_definition.description, card_definition.build_cost_text,
		"已达最高星级" if card_star >= RunCardInventory.MAX_STAR else "3张同名同星手牌可右键合成",
	]
	illustration.texture = _illustration_for(card_definition.card_id)
	title_label.text = "%s  %s" % [card_definition.display_name, "★".repeat(card_star)]
	cost_label.text = "建造 %s" % card_definition.build_cost_text
	hint_label.text = "同星 %d/3｜%s" % [matching_count, "右键合成" if matching_count >= 3 and card_star < RunCardInventory.MAX_STAR else "拖动部署"]
	add_theme_font_size_override("font_size", 13)
	add_theme_color_override("font_color", Color.TRANSPARENT)
	add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	add_theme_stylebox_override("normal", _card_style(Color("f1d8a8"), Color("8e6a31"), 2))
	add_theme_stylebox_override("hover", _card_style(Color("ffe8b8"), Color("e4a846"), 3))
	add_theme_stylebox_override("pressed", _card_style(Color("d9bd83"), Color("ffd27a"), 3))
	for child in [illustration,title_label,cost_label,hint_label]:
		child.hide()
	if reference_face == null:
		reference_face = preload("res://src/gameplay/art/hud_card_face.gd").new()
		add_child(reference_face)
	reference_face.definition = card_definition
	reference_face.illustration = illustration.texture
	reference_face.star = card_star
	reference_face.count = matching_count
	reference_face.highlighted = matching_count >= 3 and card_star < RunCardInventory.MAX_STAR
	reference_face.update_icons()
	for style_name in ["normal","hover","pressed","focus"]:
		add_theme_stylebox_override(style_name,StyleBoxEmpty.new())
	add_theme_font_size_override("font_size",1)



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
