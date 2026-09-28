class_name BarracksGuard
extends Node2D

signal defeated(guard: BarracksGuard)
signal target_released(guard: BarracksGuard)

const DamageRules = preload("res://src/gameplay/combat/damage_calculator.gd")
const ArtVisualScript = preload("res://src/gameplay/art/art_visual.gd")
const GridPathFollowerScript = preload("res://src/gameplay/grid/grid_path_follower.gd")

var definition: GuardDefinition
var guard_index: int = -1
var current_health: int = 0
var active: bool = false
var engaged_enemy: EnemyActor
var attack_elapsed: float = 0.0
var total_damage: int = 0
var kill_count: int = 0
var move_speed: float = 72.0
var path_follower: RefCounted = GridPathFollowerScript.new()


func set_pathfinder(value: RefCounted) -> void:
	path_follower.set_pathfinder(value)


func _ready() -> void:
	var art := ArtVisualScript.new() as ArtVisual
	art.show_behind_parent = true
	add_child(art)
	art.configure("guard", Vector2(18, 25), &"walk")


func configure(guard_definition: GuardDefinition, entity_index: int) -> void:
	definition = guard_definition
	guard_index = entity_index
	current_health = definition.maximum_health
	active = true
	engaged_enemy = null
	attack_elapsed = definition.attack_interval
	total_damage = 0
	kill_count = 0
	visible = true
	path_follower.invalidate()
	queue_redraw()


func maximum_health() -> int:
	return definition.maximum_health if definition != null else 0


func armor() -> int:
	return definition.armor if definition != null else 0


func is_active() -> bool:
	return active and current_health > 0


func is_available() -> bool:
	return is_active() and (engaged_enemy == null or not is_instance_valid(engaged_enemy))


func is_attackable() -> bool:
	return is_active()


func attackable_radius() -> float:
	return 18.0


func engage_enemy(enemy: EnemyActor) -> bool:
	if not is_available() or enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return false
	engaged_enemy = enemy
	path_follower.invalidate()
	attack_elapsed = definition.attack_interval
	if not enemy.died.is_connected(_on_engaged_enemy_died):
		enemy.died.connect(_on_engaged_enemy_died)
	return true


func release_enemy() -> void:
	if engaged_enemy != null and is_instance_valid(engaged_enemy):
		if engaged_enemy.died.is_connected(_on_engaged_enemy_died):
			engaged_enemy.died.disconnect(_on_engaged_enemy_died)
	engaged_enemy = null
	path_follower.invalidate()
	target_released.emit(self)


func perform_attack(enemy: EnemyActor) -> int:
	if not is_active() or definition == null:
		return 0
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive() or enemy.definition == null:
		return 0
	var final_damage: int = DamageRules.physical_damage(
		definition.base_damage,
		enemy.definition.armor,
		definition.armor_penetration,
		1.0,
		1.0,
		definition.counter_multiplier_for(enemy.definition.enemy_id)
	)
	var applied_damage: int = enemy.apply_damage(final_damage)
	total_damage += applied_damage
	if not enemy.is_alive():
		kill_count += 1
	return applied_damage


func apply_enemy_attack(base_damage: int, _enemy_id: StringName) -> int:
	if not is_active() or base_damage <= 0:
		return 0
	var final_damage: int = DamageRules.physical_damage(base_damage, definition.armor)
	var health_before: int = current_health
	current_health = maxi(0, current_health - final_damage)
	var applied_damage: int = health_before - current_health
	queue_redraw()
	if current_health == 0:
		active = false
		defeated.emit(self)
	return applied_damage


func dismiss() -> void:
	if not active:
		return
	active = false
	current_health = 0
	defeated.emit(self)


func _process(delta: float) -> void:
	if not is_active() or definition == null:
		return
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return
	if engaged_enemy == null or not is_instance_valid(engaged_enemy) or not engaged_enemy.is_alive():
		if engaged_enemy != null:
			release_enemy()
		return
	if global_position.distance_to(engaged_enemy.global_position) > definition.attack_range_pixels:
		if path_follower.pathfinder != null:
			var movement: Dictionary = path_follower.advance(
				global_position,
				engaged_enemy.global_position,
				definition.attack_range_pixels,
				move_speed,
				delta
			)
			global_position = movement.position
		if global_position.distance_to(engaged_enemy.global_position) > definition.attack_range_pixels:
			return
	attack_elapsed = minf(definition.attack_interval, attack_elapsed + delta)
	if attack_elapsed < definition.attack_interval:
		return
	attack_elapsed = 0.0
	perform_attack(engaged_enemy)


func _on_engaged_enemy_died(_enemy: EnemyActor) -> void:
	engaged_enemy = null
	path_follower.invalidate()
	target_released.emit(self)


func _draw() -> void:
	if definition != null and current_health > 0:
		var health_ratio: float = float(current_health) / float(definition.maximum_health)
		draw_rect(Rect2(-13.0, -25.0, 26.0, 3.0), Color("2b1d25"))
		draw_rect(Rect2(-13.0, -25.0, 26.0 * health_ratio, 3.0), Color("7ecf75"))
