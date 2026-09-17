extends Node2D

var main: Node
var dragged_card: OpeningCardDefinition

func _draw() -> void:
	if dragged_card == null or main == null:
		return
	for footprint in main.building_footprints():
		var center: Vector2 = footprint.position
		var radius: float = footprint.radius
		draw_circle(center, radius, Color(1.0, 0.66, 0.25, 0.18))
		draw_arc(center, radius, 0, TAU, 48, Color("ffc46b"), 1.5)
	var preview: Dictionary = main.placement_preview(dragged_card, get_global_mouse_position())
	var color := Color("73e8ad") if preview.valid else Color("ff7777")
	draw_circle(preview.position, preview.radius, Color(color, 0.15))
	draw_arc(preview.position, preview.radius, 0, TAU, 48, color, 2.0)
