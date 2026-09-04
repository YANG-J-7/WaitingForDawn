class_name BarrierWall
extends Node2D

signal health_changed(current_health: int, maximum_health: int)
signal destroyed(wall: BarrierWall)

const DamageRules = preload("res://src/gameplay/combat/damage_calculator.gd")

@export var maximum_health: int = 400
@export var armor: int = 20

var current_health: int = 0
var active: bool = false
var card_definition: OpeningCardDefinition


func build(card: OpeningCardDefinition) -> bool:
	if card == null or card.card_id != &"wall" or is_blocking():
		return false
	card_definition = card
	current_health = maximum_health
	active = true
	visible = true
	health_changed.emit(current_health, maximum_health)
	queue_redraw()
	return true


func reset() -> void:
	card_definition = null
	current_health = 0
	active = false
	visible = false
	health_changed.emit(current_health, maximum_health)
	queue_redraw()


func is_blocking() -> bool:
	return active and current_health > 0


func is_attackable() -> bool:
	return is_blocking()


func attackable_radius() -> float:
	return 28.0


func blocks_route(route_y: float, tolerance: float = 40.0) -> bool:
	return is_blocking() and absf(global_position.y - route_y) <= tolerance


func blocks_segment(origin: Vector2, destination: Vector2, tolerance: float = 40.0) -> bool:
	if not is_blocking():
		return false
	var route: Vector2 = destination - origin
	var route_length: float = route.length()
	if route_length <= 0.001:
		return false
	var direction: Vector2 = route / route_length
	var relative: Vector2 = global_position - origin
	var forward_distance: float = relative.dot(direction)
	if forward_distance < 0.0 or forward_distance > route_length:
		return false
	var perpendicular_distance: float = absf(relative.cross(direction))
	return perpendicular_distance <= tolerance


func apply_enemy_attack(base_damage: int, enemy_id: StringName) -> int:
	if not is_blocking() or base_damage <= 0:
		return 0
	var counter_multiplier: float = 0.8 if enemy_id == &"wolf" else 1.0
	var final_damage: int = DamageRules.physical_damage(
		base_damage,
		armor,
		0,
		1.0,
		1.0,
		counter_multiplier
	)
	var health_before: int = current_health
	current_health = maxi(0, current_health - final_damage)
	var applied_damage: int = health_before - current_health
	health_changed.emit(current_health, maximum_health)
	queue_redraw()
	if current_health == 0:
		active = false
		visible = false
		destroyed.emit(self)
	return applied_damage


func _draw() -> void:
	if not visible:
		return
	var stone_color := Color("75808d")
	var mortar_color := Color("323a46")
	draw_rect(Rect2(-16.0, -38.0, 32.0, 76.0), mortar_color)
	for row in range(4):
		var y: float = -36.0 + row * 18.0
		var offset: float = -13.0 if row % 2 == 0 else -5.0
		for column in range(2):
			draw_rect(Rect2(offset + column * 18.0, y, 16.0, 15.0), stone_color)
	var health_ratio: float = float(current_health) / float(maximum_health)
	draw_rect(Rect2(-19.0, -48.0, 38.0, 5.0), Color("2b1d25"))
	draw_rect(Rect2(-19.0, -48.0, 38.0 * health_ratio, 5.0), Color("7ecf75"))
