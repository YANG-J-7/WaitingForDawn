extends Node2D
## 3D 样区的规则仍使用第一关的 2D 世界坐标与现有玩法实体。

const Graybox = preload("res://prototypes/moonlake_3d_graybox/moonlake_3d_graybox.gd")
const Layout = preload("res://src/gameplay/buildings/map_layout.gd")
const LOWER_STOP := Vector2i(151, 43)
const UPPER_STOP := Vector2i(161, 33)

signal building_placed(card: OpeningCardDefinition, center: Vector2)
signal route_status_changed(message: String)

var terrain: Graybox
var grid: GridMapModel
var builder := SettlementBuilder.new()
var walls := WallManager.new()
var farmer := FarmerAgent.new()
var route_leg := 0
var last_error := ""


func configure(sample: Graybox) -> void:
	terrain = sample
	hide()
	var level := LevelMapRuntime.create_default()
	grid = GridMapModel.new(level.grid_size)
	TerrainMapData.apply_to(grid, level)
	var outside: Array[Vector2i] = []
	for y in range(grid.grid_size.y):
		for x in range(grid.grid_size.x):
			var cell := Vector2i(x, y)
			if not terrain.CROP.has_point(cell):
				outside.append(cell)
	grid.set_terrain_cells(outside, &"boundary", false, false, INF)
	builder.set_grid_map_model(grid)
	add_child(builder)
	walls.build_bounds = level.bounds
	add_child(walls)
	add_child(farmer)
	farmer.configure(0, grid.cell_center(LOWER_STOP))
	farmer.set_pathfinder(GridPathfinder.new(grid))
	farmer.global_position = grid.cell_center(LOWER_STOP)
	farmer.delivery_completed.connect(_on_delivery)


func placement(card: OpeningCardDefinition, point: Vector2) -> Dictionary:
	var footprint := Layout.footprint_for_card(card.card_id)
	var center := grid.snap_footprint_center(point, footprint)
	var cells := grid.footprint_cells(center, footprint)
	var reason := footprint_reason(center, footprint)
	if not card.required_resource_site.is_empty():
		reason = "%s需要对应的资源点" % card.display_name
	elif reason.is_empty() and not grid.cell_data(grid.world_to_cell(point)).get("buildable", false):
		reason = "鼠标指向的地表不可建"
	if reason.is_empty():
		var radius := Layout.WALL_RADIUS if card.card_id == &"wall" else card.footprint_radius
		if not Layout.is_buildable(center, radius):
			reason = "建筑完整占地必须位于可建地表"
		elif card.category == "resource" and not grid.has_work_access(center, footprint):
			reason = "岗位建筑需要可到达的山路入口"
		elif _overlaps_entity(center, radius):
			reason = "占地与单位或已有建筑重叠"
		elif not RunEconomy.can_pay(card.build_costs):
			reason = "建造材料不足"
	return {"center": center, "footprint": footprint, "cells": cells, "reason": reason}


func footprint_reason(center: Vector2, footprint: Vector2i) -> String:
	var cells := grid.footprint_cells(center, footprint)
	var ground := terrain.height_at(cells.front())
	for cell: Vector2i in cells:
		if not terrain.CROP.has_point(cell):
			return "完整占地必须位于样区内"
		if not is_equal_approx(ground, terrain.height_at(cell)):
			return "占地跨越高差"
	if not grid.can_place(center, footprint):
		return "占地包含水域、崖壁、石梯或已被占用"
	return ""


func _overlaps_entity(center: Vector2, radius: float) -> bool:
	if center.distance_to(farmer.global_position) < radius + farmer.attackable_radius():
		return true
	for building in builder.placed_buildings():
		if center.distance_to(building.global_position) < radius + building.attackable_radius():
			return true
	for wall in walls.active_walls():
		if center.distance_to(wall.global_position) < radius + Layout.WALL_RADIUS:
			return true
	return false


func build(card: OpeningCardDefinition, point: Vector2) -> bool:
	var plan := placement(card, point)
	last_error = plan.reason
	if not last_error.is_empty():
		return false
	var center: Vector2 = plan.center
	if card.card_id == &"wall":
		if not _build_wall(card, center, plan.footprint):
			return false
	else:
		var obstacles: Array[Dictionary] = [
			{"position": farmer.global_position, "radius": farmer.attackable_radius()},
		]
		for wall in walls.active_walls():
			obstacles.append({"position": wall.global_position, "radius": Layout.WALL_RADIUS})
		var building := builder.place_card_at(card, center, obstacles)
		if building == null:
			last_error = builder.last_error
			return false
		if card.card_id == &"farm":
			building.assign_workers(1)
			farmer.assign_job(&"farm", building, card.production_resource, maxi(1, roundi(card.production_per_second)))
	building_placed.emit(card, center)
	return true


func _build_wall(card: OpeningCardDefinition, center: Vector2, footprint: Vector2i) -> bool:
	var occupant := StringName("sample_wall_%s" % center)
	if not grid.occupy(occupant, center, footprint):
		last_error = "城墙落点已被占用"
		return false
	if not RunEconomy.try_pay(card.build_costs):
		grid.release(occupant)
		last_error = "建造材料不足"
		return false
	if walls.place_wall(card, center) == null:
		grid.release(occupant)
		for resource_id: StringName in card.build_costs:
			RunEconomy.add_resource(resource_id, card.build_costs[resource_id])
		last_error = walls.last_error
		return false
	return true


func start_round_trip() -> void:
	route_leg = 1
	farmer.path_follower.invalidate()
	route_status_changed.emit("农民沿 S6 前往山台")


func advance(delta: float) -> void:
	if route_leg == 0:
		if farmer.workplace != null:
			farmer.advance(delta)
		return
	var target := grid.cell_center(UPPER_STOP if route_leg == 1 else LOWER_STOP)
	var movement: Dictionary = farmer.path_follower.advance(farmer.global_position, target, 0.0, farmer.move_speed, delta)
	farmer.global_position = movement.position
	if not movement.has_path:
		_finish_round_trip("路径被占用，农民停在合法格")
	elif movement.arrived and route_leg == 1:
		route_leg = 2
		route_status_changed.emit("到达山台，沿 S6 返回平地")
	elif movement.arrived:
		_finish_round_trip("农民完成 S6 双向往返")


func _finish_round_trip(message: String) -> void:
	route_leg = 0
	farmer.path_follower.invalidate()
	route_status_changed.emit(message)


func _on_delivery(resource: StringName, amount: int) -> void:
	RunEconomy.add_resource(resource, amount)
	route_status_changed.emit("农民从农场运回 %d 食物" % amount)
