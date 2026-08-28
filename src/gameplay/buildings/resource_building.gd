class_name ResourceBuilding
extends Node2D

var definition: OpeningCardDefinition
var assigned_workers: int = 0


func configure(card_definition: OpeningCardDefinition) -> void:
	definition = card_definition
	queue_redraw()


func assign_workers(worker_count: int) -> void:
	if definition == null:
		assigned_workers = 0
	else:
		assigned_workers = clampi(worker_count, 0, definition.worker_slots)
	queue_redraw()


func _draw() -> void:
	var body_color := Color("6b8f5e") if definition == null else definition.building_color
	draw_rect(Rect2(-34.0, -24.0, 68.0, 48.0), body_color)
	draw_polygon(PackedVector2Array([
		Vector2(-39.0, -24.0),
		Vector2(0.0, -43.0),
		Vector2(39.0, -24.0),
	]), PackedColorArray([body_color.lightened(0.18)]))
	if definition != null:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-30.0, 5.0),
			definition.display_name,
			HORIZONTAL_ALIGNMENT_CENTER,
			60.0,
			14,
			Color.WHITE
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-30.0, 20.0),
			"岗位 %d/%d" % [assigned_workers, definition.worker_slots],
			HORIZONTAL_ALIGNMENT_CENTER,
			60.0,
			11,
			Color("e8ddb5")
		)
