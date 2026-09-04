extends Node

const MAIN_SCENE: PackedScene = preload("res://src/main/main.tscn")
const STONE_MINE: OpeningCardDefinition = preload("res://src/data/cards/stone_mine.tres")
const HOUSE: OpeningCardDefinition = preload("res://src/data/cards/house.tres")
const ARROW_TOWER: OpeningCardDefinition = preload("res://src/data/cards/arrow_tower_card.tres")
const BARRACKS: OpeningCardDefinition = preload("res://src/data/cards/barracks.tres")

var failure_count: int = 0


func _ready() -> void:
	await _run_test()
	get_tree().quit(failure_count)


func _run_test() -> void:
	Engine.time_scale = 20.0
	var main: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame

	var controller := main.get_node("WaveController") as WaveController
	var builder := main.get_node("SettlementBuilder") as SettlementBuilder
	var inventory := main.get_node("RunCardInventory") as RunCardInventory
	var map_surface := main.get_node("HUD/MapDropSurface") as MapDropSurface
	var arrow_tower := main.get_node("ArrowTower") as ArrowTower
	var barracks := main.get_node("Barracks") as Barracks
	var resource_sites := main.get_node("ResourceSites")

	_expect_vector(controller.city_target_position, Vector2(480.0, 270.0), "city target is centered")
	_expect_equal(resource_sites.get_child_count(), 4, "map provides four typed resource sites")
	_expect_true("stone_mine" in map_surface.accepted_card_ids, "map accepts stone mine card")
	_expect_true("house" in map_surface.accepted_card_ids, "map accepts house card")
	_expect_true("arrow_tower" in map_surface.accepted_card_ids, "map accepts free arrow tower")
	_expect_true("barracks" in map_surface.accepted_card_ids, "map accepts free barracks")

	RunState.begin_new_run()
	RunEconomy.begin_run()
	RunState.start_current_wave()
	map_surface.visible = true
	for resource_id in RunEconomy.RESOURCE_IDS:
		RunEconomy.add_resource(resource_id, 500)

	var stone_id: int = inventory.add_card(STONE_MINE, 1)
	var stone_site: Node2D = resource_sites.get_node("StoneDeposit") as Node2D
	var forest_site: Node2D = resource_sites.get_node("Forest") as Node2D
	map_surface.drop_card_data(_payload(stone_id, STONE_MINE), forest_site.global_position)
	_expect_equal(builder.building_count(), 0, "stone mine rejects forest site")
	_expect_true(inventory.has_card(stone_id), "wrong resource site preserves card")
	map_surface.drop_card_data(_payload(stone_id, STONE_MINE), stone_site.global_position)
	_expect_equal(builder.building_count(), 1, "stone mine builds on stone deposit")
	_expect_vector(builder.placed_buildings()[0].global_position, stone_site.global_position, "resource building snaps to site")

	var capacity_before: int = RunEconomy.population_capacity
	var house_id: int = inventory.add_card(HOUSE, 1)
	map_surface.drop_card_data(_payload(house_id, HOUSE), Vector2(600.0, 160.0))
	_expect_equal(RunEconomy.population_capacity, capacity_before + 2, "house adds two population capacity")

	var arrow_id: int = inventory.add_card(ARROW_TOWER, 1)
	map_surface.drop_card_data(_payload(arrow_id, ARROW_TOWER), Vector2(700.0, 270.0))
	_expect_true(arrow_tower.visible, "arrow tower builds on free ground")
	_expect_vector(arrow_tower.global_position, Vector2(700.0, 270.0), "arrow tower uses dropped position")

	var barracks_id: int = inventory.add_card(BARRACKS, 1)
	map_surface.drop_card_data(_payload(barracks_id, BARRACKS), Vector2(620.0, 360.0))
	_expect_true(barracks.is_built(), "barracks builds on free ground")
	_expect_vector(barracks.global_position, Vector2(620.0, 360.0), "barracks uses dropped position")

	_expect_true(controller.start_wave(1), "radial first wave starts")
	var frame_budget: int = 240
	while controller.spawn_history.size() < 4 and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1
	_expect_equal(controller.spawn_history.size(), 4, "first wave records four spawn points")
	var unique_points: Dictionary = {}
	for spawn_point in controller.spawn_history:
		_expect_true(_is_on_perimeter(spawn_point, controller.playable_bounds), "enemy spawns on map perimeter")
		unique_points[spawn_point] = true
	_expect_true(unique_points.size() >= 2, "wave uses more than one random spawn direction")

	Engine.time_scale = 1.0
	main.queue_free()


func _payload(instance_id: int, card: OpeningCardDefinition) -> Dictionary:
	return {
		"card_index": instance_id,
		"card_instance_id": instance_id,
		"card_id": card.card_id,
		"category": card.category,
	}


func _is_on_perimeter(point: Vector2, bounds: Rect2) -> bool:
	return (
		is_equal_approx(point.x, bounds.position.x)
		or is_equal_approx(point.x, bounds.end.x)
		or is_equal_approx(point.y, bounds.position.y)
		or is_equal_approx(point.y, bounds.end.y)
	)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	failure_count += 1
	push_error("FAIL: %s expected=%s actual=%s" % [label, expected, actual])


func _expect_vector(actual: Vector2, expected: Vector2, label: String) -> void:
	_expect_true(actual.is_equal_approx(expected), "%s expected=%s actual=%s" % [label, expected, actual])


func _expect_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failure_count += 1
	push_error("FAIL: %s" % label)
