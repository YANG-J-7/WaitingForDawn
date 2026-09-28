extends Node2D

const MapLayout = preload("res://src/gameplay/buildings/map_layout.gd")

var main: Node
var dragged_card: OpeningCardDefinition

func _draw() -> void:
	if dragged_card == null or main == null:
		return
	_draw_build_grid()
	for footprint in main.building_footprints():
		var center: Vector2 = footprint.position
		var radius: float = footprint.radius
		draw_circle(center, radius, Color(1.0, 0.66, 0.25, 0.18))
		draw_arc(center, radius, 0, TAU, 48, Color("ffc46b"), 1.5)
	var preview: Dictionary = main.placement_preview(dragged_card, get_global_mouse_position())
	var color := Color("73e8ad") if preview.valid else Color("ff7777")
	var footprint_size := Vector2(preview.footprint) * MapLayout.GRID_CELL_SIZE
	var footprint_rect := Rect2(preview.position - footprint_size * 0.5, footprint_size)
	draw_rect(footprint_rect, Color(color, 0.2), true)
	draw_rect(footprint_rect, color, false, 2.0)


func _draw_build_grid() -> void:
	var grid_color := Color(0.52, 0.72, 0.74, 0.16)
	for x in range(MapLayout.GRID_SIZE.x + 1):
		var world_x := float(x) * MapLayout.GRID_CELL_SIZE
		draw_line(Vector2(world_x, 0), Vector2(world_x, MapLayout.BOUNDS.size.y), grid_color, 1.0)
	for y in range(MapLayout.GRID_SIZE.y + 1):
		var world_y := float(y) * MapLayout.GRID_CELL_SIZE
		draw_line(Vector2(0, world_y), Vector2(MapLayout.BOUNDS.size.x, world_y), grid_color, 1.0)
