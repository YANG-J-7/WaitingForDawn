class_name GridPathFollower
extends RefCounted

var pathfinder: RefCounted
var path := PackedVector2Array()
var path_index: int = 0
var target_position: Vector2 = Vector2.INF
var stop_radius: float = 0.0
var path_revision: int = -1
var arrived: bool = false


func set_pathfinder(value: RefCounted) -> void:
	pathfinder = value
	invalidate()


func invalidate() -> void:
	path.clear()
	path_index = 0
	target_position = Vector2.INF
	path_revision = -1
	arrived = false


func advance(
	current_position: Vector2,
	next_target: Vector2,
	next_stop_radius: float,
	speed: float,
	delta: float
) -> Dictionary:
	if pathfinder == null or speed <= 0.0 or delta <= 0.0:
		return {"position": current_position, "arrived": false, "has_path": false}
	var target_changed := (
		target_position == Vector2.INF
		or target_position.distance_to(next_target) >= 18.0
		or not is_equal_approx(stop_radius, next_stop_radius)
	)
	if target_changed or path_revision != pathfinder.current_revision():
		target_position = next_target
		stop_radius = next_stop_radius
		path = pathfinder.find_path(current_position, next_target, next_stop_radius)
		path_index = 0
		path_revision = pathfinder.current_revision()
		arrived = false
	if path.is_empty():
		return {"position": current_position, "arrived": false, "has_path": false}
	var result_position := current_position
	var remaining := speed * delta
	while path_index < path.size() and remaining > 0.0:
		var waypoint: Vector2 = path[path_index]
		# 包括最后一段在内逐格检查；动态封路后绝不滑向非通行草台。
		var from_cell: Vector2i = pathfinder.model.world_to_cell(result_position)
		var to_cell: Vector2i = pathfinder.model.world_to_cell(waypoint)
		if from_cell != to_cell and not pathfinder.model.can_step(from_cell,to_cell):
			invalidate()
			return {"position": result_position, "arrived": false, "has_path": false}
		var distance := result_position.distance_to(waypoint)
		if distance <= remaining:
			result_position = waypoint
			remaining -= distance
			path_index += 1
		else:
			result_position = result_position.move_toward(waypoint, remaining)
			remaining = 0.0
	arrived = path_index >= path.size()
	return {"position": result_position, "arrived": arrived, "has_path": true}
