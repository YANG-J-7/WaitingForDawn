class_name WallManager
extends Node2D

signal walls_changed(active_walls: Array[BarrierWall])
signal wall_destroyed(wall: BarrierWall)

const WALL_SCENE: PackedScene = preload("res://src/gameplay/defenses/barrier_wall.tscn")
const WALL_RADIUS: float = 28.0

@export var build_bounds: Rect2 = Rect2(64.0, 126.0, 832.0, 288.0)

var walls: Array[BarrierWall] = []
var last_error: String = ""


func can_place_wall(map_position: Vector2, obstacles: Array[Dictionary] = []) -> bool:
	last_error = ""
	if not build_bounds.has_point(map_position):
		last_error = "城墙必须放在地图可建造区域内。"
		return false
	for wall in active_walls():
		if wall.global_position.distance_to(map_position) < WALL_RADIUS * 2.0:
			last_error = "这里已经有一面城墙。"
			return false
	for obstacle in obstacles:
		var obstacle_position: Vector2 = obstacle.get("position", Vector2.ZERO)
		var obstacle_radius: float = float(obstacle.get("radius", 0.0))
		if obstacle_position.distance_to(map_position) < WALL_RADIUS + obstacle_radius:
			last_error = "这里已有建筑或单位，不能放置城墙。"
			return false
	return true


func place_wall(
	card: OpeningCardDefinition,
	map_position: Vector2,
	obstacles: Array[Dictionary] = []
) -> BarrierWall:
	if card == null or card.card_id != &"wall":
		last_error = "只有城墙卡可以放到地图。"
		return null
	if not can_place_wall(map_position, obstacles):
		return null
	var wall: BarrierWall = WALL_SCENE.instantiate() as BarrierWall
	add_child(wall)
	wall.global_position = map_position
	if not wall.build(card):
		wall.queue_free()
		last_error = "城墙实体创建失败。"
		return null
	wall.destroyed.connect(_on_wall_destroyed)
	walls.append(wall)
	walls_changed.emit(active_walls())
	return wall


func active_walls() -> Array[BarrierWall]:
	var result: Array[BarrierWall] = []
	for wall in walls:
		if is_instance_valid(wall) and wall.is_blocking():
			result.append(wall)
	return result


func reset_walls() -> void:
	for wall in walls:
		if is_instance_valid(wall):
			wall.queue_free()
	walls.clear()
	last_error = ""
	var empty_walls: Array[BarrierWall] = []
	walls_changed.emit(empty_walls)


func _on_wall_destroyed(wall: BarrierWall) -> void:
	wall_destroyed.emit(wall)
	walls_changed.emit(active_walls())
