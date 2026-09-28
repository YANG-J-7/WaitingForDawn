class_name WaveController
extends Node2D

signal enemy_count_changed(active_count: int, total_spawned: int)
signal wave_cleared(wave_index: int)

const ENEMY_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy.tscn")
const DamageRules = preload("res://src/gameplay/combat/damage_calculator.gd")

@export var wave_definition: WaveDefinition
@export var wave_definitions: Array[WaveDefinition] = []
@export var playable_bounds: Rect2 = Rect2(64.0, 126.0, 832.0, 288.0)
@export var city_target_position: Vector2 = Vector2(480.0, 270.0)
@export var spawn_points: Array[Vector2] = []

var spawning: bool = false
var spawned_count: int = 0
var spawn_elapsed: float = 0.0
var enemies: Array[EnemyActor] = []
var active_wave_definition: WaveDefinition
var active_wave_index: int = 0
var active_run_wave_index: int = 0
var active_enemy_count: int = 0
var barrier_walls: Array[BarrierWall] = []
var additional_barracks: Array[Barracks] = []
var barracks: Barracks
var spawn_history: Array[Vector2] = []
var spawn_random := RandomNumberGenerator.new()
var spawn_side_order: Array[int] = []
var world_targets: Array[Node2D] = []
var target_scan_elapsed: float = 0.0
var clear_pending: bool = false
var wave_generation: int = 0
var kill_gold_ledger := KillGoldLedger.new()
var pathfinder: RefCounted


func _ready() -> void:
	RunState.phase_changed.connect(_on_phase_changed)


func _process(delta: float) -> void:
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return
	if spawning and active_wave_definition != null:
		spawn_elapsed += delta
		while spawned_count < active_enemy_count and spawn_elapsed >= active_wave_definition.spawn_interval:
			spawn_elapsed -= active_wave_definition.spawn_interval
			_spawn_enemy()
		if spawned_count >= active_enemy_count:
			spawning = false
	target_scan_elapsed += delta
	if target_scan_elapsed >= 0.1:
		target_scan_elapsed = 0.0
		_assign_defensive_targets()


func start_first_wave() -> bool:
	return start_wave(1)


func start_wave(wave_index: int, run_wave_index: int = -1) -> bool:
	var definition: WaveDefinition = _definition_for_wave(wave_index)
	if definition == null or not definition.is_valid():
		return false
	reset_wave()
	active_wave_definition = definition
	active_wave_index = wave_index
	active_run_wave_index = wave_index if run_wave_index <= 0 else run_wave_index
	active_enemy_count = definition.spawn_count()
	spawning = true
	spawned_count = 0
	spawn_elapsed = definition.spawn_interval
	spawn_history.clear()
	spawn_random.seed = absi(hash("%s:wave:%d:perimeter" % [RunState.run_id, active_run_wave_index]))
	_refill_spawn_sides()
	return true


func reset_wave() -> void:
	wave_generation += 1
	clear_pending = false
	spawning = false
	spawned_count = 0
	spawn_elapsed = 0.0
	active_wave_definition = null
	active_wave_index = 0
	active_run_wave_index = 0
	active_enemy_count = 0
	spawn_history.clear()
	spawn_side_order.clear()
	target_scan_elapsed = 0.0
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	enemy_count_changed.emit(0, 0)
	kill_gold_ledger.reset()


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


func set_world_targets(targets: Array[Node2D]) -> void:
	world_targets = targets.duplicate()
	_assign_defensive_targets()


func set_pathfinder(value: RefCounted) -> void:
	pathfinder = value
	for enemy in enemies:
		enemy.set_pathfinder(pathfinder)


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
	var current_spawn_position: Vector2 = _next_spawn_position()
	spawn_history.append(current_spawn_position)
	enemy.configure(
		active_wave_definition.enemy_definition,
		current_spawn_position,
		city_target_position,
		spawned_count,
		StringName("%s:%d:%d:%d" % [RunState.run_id, wave_generation, active_run_wave_index, spawned_count])
	)
	enemy.set_pathfinder(pathfinder)
	enemy.attack_requested.connect(_on_enemy_attack_requested)
	enemy.barrier_attack_requested.connect(_on_enemy_barrier_attack_requested)
	enemy.guard_attack_requested.connect(_on_enemy_guard_attack_requested)
	enemy.world_target_attack_requested.connect(_on_enemy_world_target_attack_requested)
	enemy.target_released.connect(_on_enemy_target_released)
	enemy.died.connect(_on_enemy_died)
	enemies.append(enemy)
	spawned_count += 1
	_assign_defensive_targets()
	enemy_count_changed.emit(enemies.size(), spawned_count)


func _next_spawn_position() -> Vector2:
	if spawn_side_order.is_empty():
		_refill_spawn_sides()
	var side: int = spawn_side_order.pop_front()
	if not spawn_points.is_empty():
		return spawn_points[side % spawn_points.size()]
	var margin: float = 28.0
	match side:
		0:
			return Vector2(spawn_random.randf_range(playable_bounds.position.x + margin, playable_bounds.end.x - margin), playable_bounds.position.y)
		1:
			return Vector2(playable_bounds.end.x, spawn_random.randf_range(playable_bounds.position.y + margin, playable_bounds.end.y - margin))
		2:
			return Vector2(spawn_random.randf_range(playable_bounds.position.x + margin, playable_bounds.end.x - margin), playable_bounds.end.y)
		_:
			return Vector2(playable_bounds.position.x, spawn_random.randf_range(playable_bounds.position.y + margin, playable_bounds.end.y - margin))


func _refill_spawn_sides() -> void:
	spawn_side_order.clear()
	var count: int = spawn_points.size() if not spawn_points.is_empty() else 4
	for index in range(count):
		spawn_side_order.append(index)
	for index in range(spawn_side_order.size() - 1, 0, -1):
		var swap_index: int = spawn_random.randi_range(0, index)
		var value: int = spawn_side_order[index]
		spawn_side_order[index] = spawn_side_order[swap_index]
		spawn_side_order[swap_index] = value


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


func _on_enemy_world_target_attack_requested(
	base_damage: int,
	enemy_id: StringName,
	target: Node2D
) -> void:
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return
	if target == null or not is_instance_valid(target) or not target.has_method("apply_enemy_attack"):
		return
	target.call("apply_enemy_attack", base_damage, enemy_id)


func _on_enemy_target_released(_enemy: EnemyActor) -> void:
	_assign_defensive_targets.call_deferred()


func _on_enemy_died(enemy: EnemyActor) -> void:
	if enemy not in enemies:
		return
	if enemy.definition != null:
		kill_gold_ledger.award(enemy.reward_transaction_id, enemy.definition.kill_gold, true)
	enemies.erase(enemy)
	enemy_count_changed.emit(enemies.size(), spawned_count)
	_assign_defensive_targets.call_deferred()
	if spawned_count < active_enemy_count or not enemies.is_empty():
		return
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return
	if clear_pending:
		return
	spawning = false
	clear_pending = true
	# 等同帧攻击处理完毕，主城摧毁优先；代号隔离重置前的迟到回调。
	_finish_clear.call_deferred(wave_generation)


func _finish_clear(generation: int) -> void:
	if generation != wave_generation or not clear_pending:
		return
	clear_pending = false
	if RunState.phase != RunState.Phase.WAVE_COMBAT or RunState.city_health <= 0:
		return
	if RunState.current_wave != active_run_wave_index or not enemies.is_empty():
		return
	wave_cleared.emit(active_run_wave_index)
	RunState.complete_current_wave()


func _on_guard_roster_changed(_active_count: int, _assigned_workers: int) -> void:
	_assign_defensive_targets.call_deferred()


func _assign_defensive_targets() -> void:
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var target: Node2D = _nearest_forward_world_target(enemy)
		if target != null and (target == enemy.world_target or target == enemy.barrier_target or target == enemy.guard_target):
			continue
		if enemy.attack_target_kind != &"city":
			enemy._resume_to_city()
		if target is BarracksGuard:
			enemy.set_guard(target as BarracksGuard)
		elif target is BarrierWall:
			enemy.set_barrier(target as BarrierWall)
		elif target != null:
			enemy.set_world_target(target)


func _nearest_forward_route_wall(enemy: EnemyActor) -> BarrierWall:
	var best_wall: BarrierWall = null
	var best_forward_distance: float = INF
	var route: Vector2 = city_target_position - enemy.global_position
	if route.length() <= 0.001:
		return null
	var direction: Vector2 = route.normalized()
	for wall in barrier_walls:
		if not is_instance_valid(wall) or not wall.blocks_segment(enemy.global_position, city_target_position):
			continue
		var forward_distance: float = (wall.global_position - enemy.global_position).dot(direction)
		if forward_distance < best_forward_distance:
			best_wall = wall
			best_forward_distance = forward_distance
	return best_wall


func _nearest_forward_world_target(enemy: EnemyActor) -> Node2D:
	var candidates: Array[Node2D] = world_targets.duplicate()
	var camps: Array[Barracks] = additional_barracks.duplicate()
	if is_instance_valid(barracks):
		camps.append(barracks)
	for camp in camps:
		if not is_instance_valid(camp) or not camp.is_built():
			continue
		for guard in camp.active_guards():
			if guard.is_available() or guard.engaged_enemy == enemy:
				candidates.append(guard)
	for wall in barrier_walls:
		if is_instance_valid(wall) and wall not in candidates:
			candidates.append(wall)
	var route: Vector2 = city_target_position - enemy.global_position
	var route_length: float = route.length()
	if route_length <= 0.001:
		return null
	var direction: Vector2 = route / route_length
	var best_target: Node2D = null
	var best_forward_distance: float = INF
	for candidate in candidates:
		if not is_instance_valid(candidate) or not candidate.has_method("is_attackable") or not bool(candidate.call("is_attackable")):
			continue
		var relative: Vector2 = candidate.global_position - enemy.global_position
		var forward_distance: float = relative.dot(direction)
		if forward_distance < 0.0 or forward_distance >= route_length:
			continue
		var radius: float = float(candidate.call("attackable_radius")) if candidate.has_method("attackable_radius") else 24.0
		var perpendicular_distance: float = absf(relative.cross(direction))
		if perpendicular_distance > radius + 14.0:
			continue
		if forward_distance < best_forward_distance:
			best_target = candidate
			best_forward_distance = forward_distance
	return best_target


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
