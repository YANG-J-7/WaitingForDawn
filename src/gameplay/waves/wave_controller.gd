class_name WaveController
extends Node2D

signal enemy_count_changed(active_count: int, total_spawned: int)
signal wave_cleared(wave_index: int)

const ENEMY_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy.tscn")
const DamageRules = preload("res://src/gameplay/combat/damage_calculator.gd")

@export var wave_definition: WaveDefinition
@export var spawn_position: Vector2 = Vector2(96.0, 313.0)
@export var city_target_position: Vector2 = Vector2(782.0, 313.0)

var spawning: bool = false
var spawned_count: int = 0
var spawn_elapsed: float = 0.0
var enemies: Array[EnemyActor] = []


func _ready() -> void:
	RunState.phase_changed.connect(_on_phase_changed)


func _process(delta: float) -> void:
	if not spawning or wave_definition == null:
		return
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return

	spawn_elapsed += delta
	while spawned_count < wave_definition.enemy_count and spawn_elapsed >= wave_definition.spawn_interval:
		spawn_elapsed -= wave_definition.spawn_interval
		_spawn_enemy()

	if spawned_count >= wave_definition.enemy_count:
		spawning = false


func start_first_wave() -> bool:
	if wave_definition == null or wave_definition.enemy_definition == null:
		return false
	reset_wave()
	spawning = true
	spawned_count = 0
	spawn_elapsed = wave_definition.spawn_interval
	return true


func reset_wave() -> void:
	spawning = false
	spawned_count = 0
	spawn_elapsed = 0.0
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	enemy_count_changed.emit(0, 0)


func stop_wave() -> void:
	spawning = false
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.stop()


func get_priority_target(origin: Vector2, attack_range_pixels: float) -> EnemyActor:
	var best_target: EnemyActor = null
	var best_city_distance: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if origin.distance_to(enemy.global_position) > attack_range_pixels:
			continue
		var city_distance: float = enemy.global_position.distance_to(city_target_position)
		if city_distance < best_city_distance:
			best_target = enemy
			best_city_distance = city_distance
		elif is_equal_approx(city_distance, best_city_distance) and best_target != null:
			if enemy.spawn_index < best_target.spawn_index:
				best_target = enemy
	return best_target


func _spawn_enemy() -> void:
	var enemy: EnemyActor = ENEMY_SCENE.instantiate() as EnemyActor
	add_child(enemy)
	enemy.configure(wave_definition.enemy_definition, spawn_position, city_target_position, spawned_count)
	enemy.attack_requested.connect(_on_enemy_attack_requested)
	enemy.died.connect(_on_enemy_died)
	enemies.append(enemy)
	spawned_count += 1
	enemy_count_changed.emit(enemies.size(), spawned_count)


func _on_enemy_attack_requested(base_damage: int) -> void:
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return
	var final_damage: int = DamageRules.physical_damage(base_damage, RunState.city_armor)
	RunState.damage_city(final_damage)


func _on_enemy_died(enemy: EnemyActor) -> void:
	enemies.erase(enemy)
	enemy_count_changed.emit(enemies.size(), spawned_count)
	if spawned_count < wave_definition.enemy_count or not enemies.is_empty():
		return
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return
	spawning = false
	wave_cleared.emit(wave_definition.wave_index)
	RunState.complete_current_wave()


func _on_phase_changed(phase: int) -> void:
	if phase == RunState.Phase.RUN_LOST or phase == RunState.Phase.RUN_WON:
		stop_wave()
