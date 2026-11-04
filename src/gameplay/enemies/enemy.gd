class_name EnemyActor
extends Node2D

const ArtVisualScript = preload("res://src/gameplay/art/art_visual.gd")
const GridPathFollowerScript = preload("res://src/gameplay/grid/grid_path_follower.gd")

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

const TILE_SIZE: float = 36.0

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
var reward_transaction_id: StringName = &""
var path_follower: RefCounted = GridPathFollowerScript.new()
var city_route := PackedVector2Array()
var blocked_city_route := PackedVector2Array()
var _city_route_cell := Vector2i(-1, -1)
var _city_route_revision: int = -1
var _city_route_target := Vector2.INF
var _route_blockers: Array[Vector2] = []


func set_pathfinder(value: RefCounted) -> void:
	path_follower.set_pathfinder(value)
	_city_route_revision = -1
	_route_blockers.clear()
	if definition != null:
		prepare_city_route()
		if attack_target_kind == &"city":
			path_follower.prepare(global_position, _city_global_position(), 96.0)


func _ready() -> void:
	add_to_group(&"map_units")
	var art := ArtVisualScript.new() as ArtVisual
	art.show_behind_parent = true
	add_child(art)
	art.configure_world("wolf", Vector2(23, 17), &"wolf")


func configure(
	enemy_definition: EnemyDefinition,
	spawn_position: Vector2,
	city_position: Vector2,
	entity_spawn_index: int = -1,
	transaction_id: StringName = &""
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
	reward_transaction_id = transaction_id
	current_health = definition.maximum_health
	active = true
	has_reached_target = false
	age_seconds = 0.0
	attack_elapsed = 0.0
	path_follower.invalidate()
	_city_route_revision = -1
	_route_blockers.clear()
	if path_follower.pathfinder != null:
		prepare_city_route()
		path_follower.prepare(global_position, _city_global_position(), 96.0)
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
	if not _accepts_route_target(wall, local_barrier_position):
		return false
	barrier_target = wall
	target_position = local_barrier_position
	attack_target_kind = &"barrier"
	has_reached_target = false
	attack_elapsed = 0.0
	path_follower.invalidate()
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
	if not _accepts_route_target(guard, local_guard_position):
		return false
	if not guard.engage_enemy(self):
		return false
	guard_target = guard
	target_position = local_guard_position
	attack_target_kind = &"guard"
	has_reached_target = false
	attack_elapsed = 0.0
	path_follower.invalidate()
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
	if not _accepts_route_target(target, local_target_position):
		return false
	barrier_target = null
	guard_target = null
	world_target = target
	target_position = local_target_position
	attack_target_kind = &"world"
	has_reached_target = false
	attack_elapsed = 0.0
	path_follower.invalidate()
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
	if attack_target_kind == &"guard" and _has_valid_guard_target():
		# 守卫沿格中心接近敌人后，目标脚点必须随之更新，避免继续走向旧位置。
		var guard_parent := get_parent() as Node2D
		target_position = guard_parent.to_local(guard_target.global_position) if guard_parent != null else guard_target.global_position
	if path_follower.pathfinder != null:
		var parent_for_target := get_parent() as Node2D
		var current_target_global := parent_for_target.to_global(target_position) if parent_for_target != null else target_position
		if (
			path_follower.target_position == Vector2.INF
			or path_follower.target_position.distance_to(current_target_global) >= 18.0
			or not path_follower.arrived
		):
			has_reached_target = false
	elif position.distance_to(target_position) > _contact_range():
		has_reached_target = false
	if has_reached_target:
		_process_attack(delta)
		return

	age_seconds += delta
	var speed_multiplier: float = 1.0
	if age_seconds <= definition.rush_duration:
		speed_multiplier = definition.rush_multiplier
	var speed_pixels: float = definition.move_speed_tiles_per_second * TILE_SIZE * speed_multiplier
	if path_follower.pathfinder != null:
		var parent_2d := get_parent() as Node2D
		var target_global := parent_2d.to_global(target_position) if parent_2d != null else target_position
		var movement: Dictionary = path_follower.advance(
			global_position, target_global, _path_stop_radius(), speed_pixels, delta
		)
		global_position = movement.position
		has_reached_target = bool(movement.arrived)
	else:
		position = position.move_toward(target_position, speed_pixels * delta)

	if has_reached_target or (path_follower.pathfinder == null and position.distance_to(target_position) <= _contact_range()):
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
	if path_follower.pathfinder != null and attack_target_kind != &"city":
		var target_global := _attack_target_global_position()
		if global_position.distance_to(target_global) > _contact_range() or not path_follower.pathfinder.model.interaction_clear(global_position, target_global):
			has_reached_target = false
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
	path_follower.invalidate()
	target_released.emit(self)


func _path_stop_radius() -> float:
	if attack_target_kind == &"city":
		return 96.0
	return _contact_range()


func _contact_range() -> float:
	if attack_target_kind == &"world" and _has_valid_world_target():
		return definition.attack_range_pixels + float(world_target.call("attackable_radius"))
	if attack_target_kind == &"barrier":
		return definition.attack_range_pixels + 28.0
	return definition.attack_range_pixels


func is_on_route(candidate: Node2D) -> bool:
	if path_follower.pathfinder != null:
		prepare_city_route()
		var points := city_route if not city_route.is_empty() else blocked_city_route
		if points.is_empty():
			return false
		var radius := float(candidate.call("attackable_radius")) if candidate.has_method("attackable_radius") else 24.0
		var origin := global_position
		for endpoint in points:
			var segment := endpoint - origin
			if segment.length_squared() > .001:
				var projection := (candidate.global_position-origin).dot(segment)/segment.length_squared()
				if (origin != global_position or projection >= 0.0) and (endpoint != points[-1] or projection <= 1.0):
					var closest := origin + segment*clampf(projection,0.0,1.0)
					if closest.distance_to(candidate.global_position) <= radius+definition.route_corridor_pixels and path_follower.pathfinder.model.interaction_clear(closest,candidate.global_position):
						return true
			origin = endpoint
		return false
	var route: Vector2 = city_target_position - position
	if route.length() <= 0.001:
		return false
	var relative: Vector2 = candidate.global_position - global_position
	var forward_distance: float = relative.dot(route.normalized())
	var radius: float = float(candidate.call("attackable_radius"))
	return forward_distance >= 0.0 and forward_distance < route.length() and absf(relative.cross(route.normalized())) <= radius + 14.0


func _city_global_position() -> Vector2:
	var parent_2d := get_parent() as Node2D
	return parent_2d.to_global(city_target_position) if parent_2d != null else city_target_position


func prepare_city_route() -> void:
	var finder: RefCounted = path_follower.pathfinder
	if finder == null:
		return
	var cell: Vector2i = finder.model.world_to_cell(global_position)
	var city := _city_global_position()
	if _city_route_cell == cell and _city_route_revision == finder.current_revision() and _city_route_target == city:
		return
	_city_route_cell = cell
	_city_route_revision = finder.current_revision()
	_city_route_target = city
	blocked_city_route.clear()
	# 正在进城时复用实际剩余路径，避免每经过一格重新搜索主城各入口。
	if attack_target_kind == &"city" and path_follower.path_revision == _city_route_revision and path_follower.target_position == city:
		city_route = path_follower.path.slice(path_follower.path_index)
	else:
		city_route = finder.find_path(global_position, city, 96.0)
	if city_route.is_empty():
		blocked_city_route = finder.find_siege_route(global_position, city, 96.0, _route_blockers)


func set_route_blockers(positions: Array[Vector2]) -> void:
	if _route_blockers == positions: return
	_route_blockers = positions.duplicate()
	_city_route_revision = -1
	prepare_city_route()


func _accepts_route_target(candidate: Node2D, local_position: Vector2) -> bool:
	return is_on_route(candidate) if path_follower.pathfinder != null else _is_forward_target(local_position)


func attack_approach(candidate: Node2D) -> PackedVector2Array:
	var radius := float(candidate.call("attackable_radius")) if candidate.has_method("attackable_radius") else 0.0
	if candidate is BarracksGuard:
		radius = 0.0
	return path_follower.pathfinder.find_path(global_position, candidate.global_position, definition.attack_range_pixels+radius)


func _attack_target_global_position() -> Vector2:
	if attack_target_kind == &"world" and is_instance_valid(world_target): return world_target.global_position
	if attack_target_kind == &"guard" and is_instance_valid(guard_target): return guard_target.global_position
	if attack_target_kind == &"barrier" and is_instance_valid(barrier_target): return barrier_target.global_position
	return _city_global_position()


func _is_forward_target(candidate_position: Vector2) -> bool:
	var route: Vector2 = city_target_position - position
	var route_length: float = route.length()
	if route_length <= 0.001:
		return false
	var forward_distance: float = (candidate_position - position).dot(route / route_length)
	return forward_distance >= -16.0 and forward_distance < route_length


func _draw() -> void:
	if definition != null and current_health > 0:
		var health_ratio: float = float(current_health) / float(definition.maximum_health)
		var head_y: float = -preload("res://src/gameplay/art/world_art_scale.gd").height_for("wolf",17.0)-7.0
		draw_rect(Rect2(-14.0, head_y, 28.0, 3.0), Color("3c1f2a"))
		draw_rect(Rect2(-14.0, head_y, 28.0 * health_ratio, 3.0), Color("7ecf75"))
