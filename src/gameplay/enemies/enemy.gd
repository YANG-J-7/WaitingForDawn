class_name EnemyActor
extends Node2D

signal attack_requested(base_damage: int)
signal health_changed(current_health: int, maximum_health: int)
signal died(enemy: EnemyActor)

const TILE_SIZE: float = 32.0

var definition: EnemyDefinition
var target_position: Vector2 = Vector2.ZERO
var active: bool = false
var has_reached_target: bool = false
var age_seconds: float = 0.0
var attack_elapsed: float = 0.0
var current_health: int = 0
var spawn_index: int = -1


func configure(
	enemy_definition: EnemyDefinition,
	spawn_position: Vector2,
	city_position: Vector2,
	entity_spawn_index: int = -1
) -> void:
	definition = enemy_definition
	position = spawn_position
	target_position = city_position
	spawn_index = entity_spawn_index
	current_health = definition.maximum_health
	active = true
	has_reached_target = false
	age_seconds = 0.0
	attack_elapsed = 0.0
	health_changed.emit(current_health, definition.maximum_health)
	queue_redraw()


func stop() -> void:
	active = false


func is_alive() -> bool:
	return active and current_health > 0


func apply_damage(amount: int) -> int:
	if not is_alive() or amount <= 0:
		return 0
	var health_before: int = current_health
	current_health = maxi(0, current_health - amount)
	var applied_damage: int = health_before - current_health
	health_changed.emit(current_health, definition.maximum_health)
	queue_redraw()
	if current_health == 0:
		active = false
		died.emit(self)
		queue_free()
	return applied_damage


func _physics_process(delta: float) -> void:
	if not active or definition == null:
		return
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return

	if has_reached_target:
		_process_attack(delta)
		return

	age_seconds += delta
	var speed_multiplier: float = 1.0
	if age_seconds <= definition.rush_duration:
		speed_multiplier = definition.rush_multiplier
	var speed_pixels: float = definition.move_speed_tiles_per_second * TILE_SIZE * speed_multiplier
	position = position.move_toward(target_position, speed_pixels * delta)

	if position.distance_to(target_position) <= definition.attack_range_pixels:
		has_reached_target = true
		attack_elapsed = 0.0


func _process_attack(delta: float) -> void:
	attack_elapsed += delta
	while attack_elapsed >= definition.attack_interval:
		attack_elapsed -= definition.attack_interval
		attack_requested.emit(definition.base_damage)
		if RunState.phase != RunState.Phase.WAVE_COMBAT:
			return


func _draw() -> void:
	var color: Color = Color("b94b62") if definition == null else definition.body_color
	draw_rect(Rect2(-14.0, -11.0, 28.0, 22.0), color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11.0, -11.0),
		Vector2(-6.0, -19.0),
		Vector2(-2.0, -11.0),
	]), color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2.0, -11.0),
		Vector2(7.0, -19.0),
		Vector2(11.0, -11.0),
	]), color)
	draw_circle(Vector2(7.0, -3.0), 2.0, Color("f6e3a6"))
	if definition != null and current_health > 0:
		var health_ratio: float = float(current_health) / float(definition.maximum_health)
		draw_rect(Rect2(-14.0, -25.0, 28.0, 3.0), Color("3c1f2a"))
		draw_rect(Rect2(-14.0, -25.0, 28.0 * health_ratio, 3.0), Color("7ecf75"))
