class_name BuildingGrounding
extends Node2D

const CELL_SIZE: float = 36.0

var footprint: Vector2i = Vector2i.ONE
var footprint_size: Vector2 = Vector2.ONE * CELL_SIZE
var shadow_size: Vector2 = Vector2(28, 6)
var surface_kind: StringName = &"default"


func _ready() -> void:
	show_behind_parent = true
	z_index = -2
	queue_redraw()


func configure(value: Vector2i, kind: StringName = &"default") -> void:
	footprint = Vector2i(maxi(1, value.x), maxi(1, value.y))
	footprint_size = Vector2(footprint) * CELL_SIZE
	shadow_size = Vector2(maxf(24.0, footprint_size.x * 0.72), clampf(footprint_size.y * 0.12, 4.0, 8.0))
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
	_draw_ellipse(Vector2(0, half.y * 0.56), shadow_size, Color(0.015, 0.025, 0.035, 0.72))


func _draw_ellipse(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * size.x * 0.5, sin(angle) * size.y * 0.5))
	draw_colored_polygon(points, color)
