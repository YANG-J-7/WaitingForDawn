class_name EnemyActor
extends Node2D

signal attack_requested(base_damage: int)
signal barrier_attack_requested(
	base_damage: int,
	enemy_id: StringName,
	target_wall: BarrierWall
)
signal guard_attack_requested(
	base_damage: int,
	enemy_id: StringName,
	target_guard: BarracksGuard
)
signal world_target_attack_requested(
	base_damage: int,
	enemy_id: StringName,
	target: Node2D
)
signal target_released(enemy: EnemyActor)
signal health_changed(current_health: int, maximum_health: int)
signal died(enemy: EnemyActor)

const TILE_SIZE: float = 32.0

var definition: EnemyDefinition
var target_position: Vector2 = Vector2.ZERO
var city_target_position: Vector2 = Vector2.ZERO
var barrier_target: BarrierWall
var guard_target: BarracksGuard
var world_target: Node2D
var attack_target_kind: StringName = &"city"
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
	city_target_position = city_position
	target_position = city_target_position
	barrier_target = null
	guard_target = null
	world_target = null
	attack_target_kind = &"city"
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


func set_barrier(wall: BarrierWall) -> bool:
	if wall == null or not is_instance_valid(wall) or not wall.is_blocking():
		return false
	if attack_target_kind == &"guard" and _has_valid_guard_target():
		return false
	var parent_2d := get_parent() as Node2D
	var local_barrier_position: Vector2 = (
		parent_2d.to_local(wall.global_position)
		if parent_2d != null
		else wall.global_position
	)
	if not _is_forward_target(local_barrier_position):
		return false
	barrier_target = wall
	target_position = local_barrier_position
	attack_target_kind = &"barrier"
	has_reached_target = false
	attack_elapsed = 0.0
	if not wall.destroyed.is_connected(_on_barrier_destroyed):
		wall.destroyed.connect(_on_barrier_destroyed)
	return true


func set_guard(guard: BarracksGuard) -> bool:
	if guard == null or not is_instance_valid(guard) or not guard.is_available():
		return false
	var parent_2d := get_parent() as Node2D
	var local_guard_position: Vector2 = (
		parent_2d.to_local(guard.global_position)
		if parent_2d != null
		else guard.global_position
	)
	if not _is_forward_target(local_guard_position):
		return false
	if not guard.engage_enemy(self):
		return false
	guard_target = guard
	target_position = local_guard_position
	attack_target_kind = &"guard"
	has_reached_target = false
	attack_elapsed = 0.0
	if not guard.defeated.is_connected(_on_guard_defeated):
		guard.defeated.connect(_on_guard_defeated)
	return true


func set_world_target(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or not _target_is_attackable(target):
		return false
	if attack_target_kind == &"guard" and _has_valid_guard_target():
		return false
	var parent_2d := get_parent() as Node2D
	var local_target_position: Vector2 = parent_2d.to_local(target.global_position) if parent_2d != null else target.global_position
	if not _is_forward_target(local_target_position):
		return false
	barrier_target = null
	guard_target = null
	world_target = target
	target_position = local_target_position
	attack_target_kind = &"world"
	has_reached_target = false
	attack_elapsed = 0.0
	return true


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

	if (attack_target_kind == &"world" and not _has_valid_world_target()) or (attack_target_kind == &"guard" and not _has_valid_guard_target()) or (attack_target_kind == &"barrier" and (not is_instance_valid(barrier_target) or not barrier_target.is_blocking())):
		_resume_to_city()
	if attack_target_kind == &"world" and _has_valid_world_target():
		var parent_2d := get_parent() as Node2D
		target_position = parent_2d.to_local(world_target.global_position) if parent_2d != null else world_target.global_position
		if not is_on_route(world_target):
			_resume_to_city()
	if position.distance_to(target_position) > _contact_range():
		has_reached_target = false
	if has_reached_target:
		_process_attack(delta)
		return

	age_seconds += delta
	var speed_multiplier: float = 1.0
	if age_seconds <= definition.rush_duration:
		speed_multiplier = definition.rush_multiplier
	var speed_pixels: float = definition.move_speed_tiles_per_second * TILE_SIZE * speed_multiplier
	position = position.move_toward(target_position, speed_pixels * delta)

	if position.distance_to(target_position) <= _contact_range():
		has_reached_target = true
		attack_elapsed = 0.0


func _process_attack(delta: float) -> void:
	if attack_target_kind == &"guard" and not _has_valid_guard_target():
		_resume_to_city()
		return
	if attack_target_kind == &"barrier" and (
		barrier_target == null
		or not is_instance_valid(barrier_target)
		or not barrier_target.is_blocking()
	):
		_resume_to_city()
		return
	if attack_target_kind == &"world" and not _has_valid_world_target():
		_resume_to_city()
		return
	attack_elapsed += delta
	while attack_elapsed >= definition.attack_interval:
		attack_elapsed -= definition.attack_interval
		if attack_target_kind == &"guard":
			guard_attack_requested.emit(definition.base_damage, definition.enemy_id, guard_target)
			if attack_target_kind != &"guard":
				return
		elif attack_target_kind == &"barrier":
			barrier_attack_requested.emit(
				definition.base_damage,
				definition.enemy_id,
				barrier_target
			)
			if attack_target_kind != &"barrier":
				return
		elif attack_target_kind == &"world":
			world_target_attack_requested.emit(
				definition.base_damage,
				definition.enemy_id,
				world_target
			)
			if not _has_valid_world_target():
				_resume_to_city()
				return
		else:
			attack_requested.emit(definition.base_damage)
		if RunState.phase != RunState.Phase.WAVE_COMBAT:
			return


func _on_barrier_destroyed(wall: BarrierWall) -> void:
	if attack_target_kind == &"barrier" and wall == barrier_target:
		_resume_to_city()


func _on_guard_defeated(guard: BarracksGuard) -> void:
	if attack_target_kind == &"guard" and guard == guard_target:
		_resume_to_city()


func _has_valid_guard_target() -> bool:
	return (
		guard_target != null
		and is_instance_valid(guard_target)
		and guard_target.is_active()
	)


func _has_valid_world_target() -> bool:
	return world_target != null and is_instance_valid(world_target) and _target_is_attackable(world_target)


func _target_is_attackable(target: Node2D) -> bool:
	return target.has_method("is_attackable") and bool(target.call("is_attackable"))


func _resume_to_city() -> void:
	if is_instance_valid(guard_target) and guard_target.engaged_enemy == self:
		guard_target.release_enemy()
	barrier_target = null
	guard_target = null
	world_target = null
	target_position = city_target_position
	attack_target_kind = &"city"
	has_reached_target = false
	attack_elapsed = 0.0
	target_released.emit(self)


func _contact_range() -> float:
	if attack_target_kind == &"world" and _has_valid_world_target():
		return definition.attack_range_pixels + float(world_target.call("attackable_radius"))
	if attack_target_kind == &"barrier":
		return definition.attack_range_pixels + 28.0
	return definition.attack_range_pixels


func is_on_route(candidate: Node2D) -> bool:
	var route: Vector2 = city_target_position - position
	if route.length() <= 0.001:
		return false
	var relative: Vector2 = candidate.global_position - global_position
	var forward_distance: float = relative.dot(route.normalized())
	var radius: float = float(candidate.call("attackable_radius"))
	return forward_distance >= 0.0 and forward_distance < route.length() and absf(relative.cross(route.normalized())) <= radius + 14.0


func _is_forward_target(candidate_position: Vector2) -> bool:
	var route: Vector2 = city_target_position - position
	var route_length: float = route.length()
	if route_length <= 0.001:
		return false
	var forward_distance: float = (candidate_position - position).dot(route / route_length)
	return forward_distance >= -16.0 and forward_distance < route_length


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
