class_name WaveController
extends Node2D

signal enemy_count_changed(active_count: int, total_spawned: int)
signal wave_cleared(wave_index: int)

const ENEMY_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy.tscn")
const DamageRules = preload("res://src/gameplay/combat/damage_calculator.gd")

@export var wave_definition: WaveDefinition
@export var wave_definitions: Array[WaveDefinition] = []
@export var spawn_position: Vector2 = Vector2(96.0, 313.0)
@export var city_target_position: Vector2 = Vector2(782.0, 313.0)

var spawning: bool = false
var spawned_count: int = 0
var spawn_elapsed: float = 0.0
var enemies: Array[EnemyActor] = []
var active_wave_definition: WaveDefinition
var active_wave_index: int = 0
var active_enemy_count: int = 0
var barrier_walls: Array[BarrierWall] = []
var barracks: Barracks


func _ready() -> void:
	RunState.phase_changed.connect(_on_phase_changed)


func _process(delta: float) -> void:
	if not spawning or active_wave_definition == null:
		return
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return

	spawn_elapsed += delta
	while spawned_count < active_enemy_count and spawn_elapsed >= active_wave_definition.spawn_interval:
		spawn_elapsed -= active_wave_definition.spawn_interval
		_spawn_enemy()

	if spawned_count >= active_enemy_count:
		spawning = false


func start_first_wave() -> bool:
	return start_wave(1)


func start_wave(wave_index: int) -> bool:
	var definition: WaveDefinition = _definition_for_wave(wave_index)
	if definition == null or definition.enemy_definition == null:
		return false
	reset_wave()
	active_wave_definition = definition
	active_wave_index = wave_index
	active_enemy_count = definition.enemy_count
	spawning = true
	spawned_count = 0
	spawn_elapsed = definition.spawn_interval
	return true


func reset_wave() -> void:
	spawning = false
	spawned_count = 0
	spawn_elapsed = 0.0
	active_wave_definition = null
	active_wave_index = 0
	active_enemy_count = 0
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


func set_barrier_walls(walls: Array[BarrierWall]) -> void:
	barrier_walls = walls.duplicate()
	_assign_defensive_targets()


func set_barracks(value: Barracks) -> void:
	if barracks != null and is_instance_valid(barracks):
		if barracks.guard_roster_changed.is_connected(_on_guard_roster_changed):
			barracks.guard_roster_changed.disconnect(_on_guard_roster_changed)
	barracks = value
	if barracks != null and not barracks.guard_roster_changed.is_connected(_on_guard_roster_changed):
		barracks.guard_roster_changed.connect(_on_guard_roster_changed)
	_assign_defensive_targets()


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
	enemy.configure(
		active_wave_definition.enemy_definition,
		spawn_position,
		city_target_position,
		spawned_count
	)
	enemy.attack_requested.connect(_on_enemy_attack_requested)
	enemy.barrier_attack_requested.connect(_on_enemy_barrier_attack_requested)
	enemy.guard_attack_requested.connect(_on_enemy_guard_attack_requested)
	enemy.died.connect(_on_enemy_died)
	enemies.append(enemy)
	spawned_count += 1
	_assign_defensive_targets()
	enemy_count_changed.emit(enemies.size(), spawned_count)


func _on_enemy_attack_requested(base_damage: int) -> void:
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return
	var final_damage: int = DamageRules.physical_damage(base_damage, RunState.city_armor)
	RunState.damage_city(final_damage)


func _on_enemy_barrier_attack_requested(
	base_damage: int,
	enemy_id: StringName,
	target_wall: BarrierWall
) -> void:
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return
	if target_wall == null or not is_instance_valid(target_wall) or not target_wall.is_blocking():
		return
	target_wall.apply_enemy_attack(base_damage, enemy_id)


func _on_enemy_guard_attack_requested(
	base_damage: int,
	enemy_id: StringName,
	target_guard: BarracksGuard
) -> void:
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return
	if target_guard == null or not is_instance_valid(target_guard) or not target_guard.is_active():
		return
	target_guard.apply_enemy_attack(base_damage, enemy_id)


func _on_enemy_died(enemy: EnemyActor) -> void:
	enemies.erase(enemy)
	enemy_count_changed.emit(enemies.size(), spawned_count)
	_assign_defensive_targets.call_deferred()
	if spawned_count < active_enemy_count or not enemies.is_empty():
		return
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return
	spawning = false
	wave_cleared.emit(active_wave_index)
	RunState.complete_current_wave()


func _on_guard_roster_changed(_active_count: int, _assigned_workers: int) -> void:
	_assign_defensive_targets.call_deferred()


func _assign_defensive_targets() -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if enemy.attack_target_kind == &"guard" and enemy.guard_target != null:
			if is_instance_valid(enemy.guard_target) and enemy.guard_target.is_active():
				continue
		var guard: BarracksGuard = null
		if barracks != null and is_instance_valid(barracks) and barracks.is_built():
			guard = barracks.available_guard()
		if guard != null and enemy.set_guard(guard):
			continue
		var wall: BarrierWall = _nearest_forward_route_wall(enemy)
		if wall != null:
			enemy.set_barrier(wall)


func _nearest_forward_route_wall(enemy: EnemyActor) -> BarrierWall:
	var best_wall: BarrierWall = null
	var best_x: float = INF
	for wall in barrier_walls:
		if not is_instance_valid(wall) or not wall.blocks_route(city_target_position.y):
			continue
		if wall.global_position.x + 16.0 < enemy.global_position.x:
			continue
		if wall.global_position.x < best_x:
			best_wall = wall
			best_x = wall.global_position.x
	return best_wall


func _definition_for_wave(wave_index: int) -> WaveDefinition:
	for definition in wave_definitions:
		if definition != null and definition.wave_index == wave_index:
			return definition
	if wave_definition != null and wave_definition.wave_index == wave_index:
		return wave_definition
	return null


func _on_phase_changed(phase: int) -> void:
	if phase == RunState.Phase.RUN_LOST or phase == RunState.Phase.RUN_WON:
		stop_wave()
