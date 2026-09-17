class_name ResourceSite
extends Node2D

@export var site_type: StringName = &"forest"
@export var display_name: String = "资源点"
@export var radius: float = 32.0
@export var site_color: Color = Color("4f7650")

var occupied_building: ResourceBuilding
var highlighted: bool = false


func set_highlighted(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	queue_redraw()


func accepts(card: OpeningCardDefinition) -> bool:
	return (
		card != null
		and card.required_resource_site == site_type
		and not is_occupied()
	)


func is_occupied() -> bool:
	return occupied_building != null and is_instance_valid(occupied_building)


func claim(building: ResourceBuilding) -> bool:
	if building == null or is_occupied():
		return false
	occupied_building = building
	queue_redraw()
	return true


func release(building: ResourceBuilding) -> void:
	if occupied_building == building:
		occupied_building = null
		queue_redraw()


func reset() -> void:
	occupied_building = null
	queue_redraw()


func _draw() -> void:
	if highlighted:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 40, Color("ffe083"), 4.0)
	draw_circle(Vector2.ZERO, radius, Color(site_color, 0.24))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, site_color, 2.0)
	if site_type == &"forest":
		for offset in [Vector2(-20, 5), Vector2(0, -12), Vector2(21, 8)]:
			draw_rect(Rect2(offset + Vector2(-3, 7), Vector2(6, 18)), Color("6b4d32"))
			draw_circle(offset, 13.0, Color("4f8b55"))
	elif site_type == &"farmland":
		for row in range(-2, 3):
			draw_line(Vector2(-30, row * 9), Vector2(30, row * 9), Color("b8994b"), 3.0)
	else:
		var ore_color := Color("d6b64d") if site_type == &"gold_vein" else Color("8b939e")
		for offset in [Vector2(-18, 8), Vector2(0, -8), Vector2(20, 10)]:
			draw_colored_polygon(PackedVector2Array([
				offset + Vector2(-11, 10),
				offset + Vector2(-5, -8),
				offset + Vector2(8, -12),
				offset + Vector2(13, 9),
			]), ore_color)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-38, radius + 16),
		display_name if not is_occupied() else "%s·占用" % display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		76.0,
		13,
		Color("e8e2ca")
	)
