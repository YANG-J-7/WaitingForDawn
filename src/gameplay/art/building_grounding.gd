class_name BuildingGrounding
extends Node2D

const CELL_SIZE: float = 36.0

var footprint: Vector2i = Vector2i.ONE
var footprint_size: Vector2 = Vector2.ONE * CELL_SIZE
var surface_kind: StringName = &"default"


func _ready() -> void:
	show_behind_parent = true
	z_index = -2
	queue_redraw()


func configure(value: Vector2i, kind: StringName = &"default") -> void:
	footprint = Vector2i(maxi(1, value.x), maxi(1, value.y))
	footprint_size = Vector2(footprint) * CELL_SIZE
	surface_kind = kind
	queue_redraw()


func _draw() -> void:
	var half := footprint_size * 0.5 - Vector2(3, 3)
	var foundation_color := Color(0.14, 0.21, 0.22, 0.55)
	match surface_kind:
		&"farm": foundation_color = Color(0.34, 0.26, 0.15, 0.72)
		&"lumber_camp": foundation_color = Color(0.28, 0.22, 0.16, 0.68)
		&"stone_mine", &"iron_mine", &"gold_mine": foundation_color = Color(0.30, 0.34, 0.38, 0.72)
		&"wall": foundation_color = Color(0.23, 0.25, 0.27, 0.70)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half.x, -half.y * 0.42), Vector2(-half.x * 0.72, -half.y * 0.72),
		Vector2(half.x * 0.72, -half.y * 0.72), Vector2(half.x, -half.y * 0.42),
		Vector2(half.x, half.y * 0.42), Vector2(half.x * 0.72, half.y * 0.72),
		Vector2(-half.x * 0.72, half.y * 0.72), Vector2(-half.x, half.y * 0.42),
	]), foundation_color)
