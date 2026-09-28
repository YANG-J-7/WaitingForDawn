class_name ResourceSite
extends Node2D

const ArtVisualScript = preload("res://src/gameplay/art/art_visual.gd")

@export var site_type: StringName = &"forest"
@export var display_name: String = "资源点"
@export var radius: float = 32.0
@export var site_color: Color = Color("4f7650")

var occupied_building: ResourceBuilding
var highlighted: bool = false
var art_visual: ArtVisual
var hide_visual_when_occupied: bool = false


func _ready() -> void:
	art_visual = ArtVisualScript.new() as ArtVisual
	art_visual.show_behind_parent = true
	add_child(art_visual)
	match site_type:
		&"forest":
			art_visual.configure_path("res://assets/map/resource_sites/forest_resource.png", Vector2(218, 178), &"sway")
			hide_visual_when_occupied = true
		&"stone_deposit":
			art_visual.configure_path("res://assets/map/resource_sites/stone_deposit.png", Vector2(130, 82))
		&"iron_deposit":
			art_visual.configure_path("res://assets/map/resource_sites/iron_deposit.png", Vector2(130, 82))
		&"gold_vein":
			art_visual.configure("mine_entrance", Vector2(52, 42), &"lantern")
		_:
			art_visual.configure("terrain_grass", Vector2(65, 40))


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
	if hide_visual_when_occupied:
		art_visual.visible = false
	queue_redraw()
	return true


func release(building: ResourceBuilding) -> void:
	if occupied_building == building:
		occupied_building = null
		art_visual.visible = true
		queue_redraw()


func reset() -> void:
	occupied_building = null
	art_visual.visible = true
	queue_redraw()


func _draw() -> void:
	if highlighted:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 40, Color("ffe083"), 4.0)
		draw_circle(Vector2.ZERO, radius, Color(site_color, 0.24))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, site_color, 2.0)
	if site_type == &"farmland":
		for row in range(-2, 3):
			draw_line(Vector2(-30, row * 9), Vector2(30, row * 9), Color("b8994b"), 3.0)
	if highlighted:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-38, radius + 16),
			display_name if not is_occupied() else "%s·占用" % display_name,
			HORIZONTAL_ALIGNMENT_CENTER,
			76.0,
			13,
			Color("e8e2ca")
		)
