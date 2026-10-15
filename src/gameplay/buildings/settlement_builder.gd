class_name SettlementBuilder
extends Node2D

signal building_placed(slot_index: int, card_id: StringName)
signal building_placed_at(building: ResourceBuilding, card_id: StringName)
signal building_destroyed(building: ResourceBuilding, card_id: StringName)
signal buildings_reset

const RESOURCE_BUILDING_SCENE: PackedScene = preload(
	"res://src/gameplay/buildings/resource_building.tscn"
)
const MapLayout = preload("res://src/gameplay/buildings/map_layout.gd")

@export var slot_positions: Array[Vector2] = [
	Vector2(1180.0, 1030.0),
	Vector2(1380.0, 1240.0),
	Vector2(1580.0, 1030.0),
]

var buildings_by_slot: Dictionary = {}
var consumed_card_ids: Array[StringName] = []
var placement_order: Array[ResourceBuilding] = []
var last_error: String = ""
var resource_sites: Array[ResourceSite] = []
var grid_map_model: RefCounted
@export var build_bounds: Rect2 = Rect2(64.0, 126.0, 832.0, 288.0)


func set_resource_sites(sites: Array[ResourceSite]) -> void:
	resource_sites = sites.duplicate()


func set_grid_map_model(model: RefCounted) -> void:
	grid_map_model = model


func place_card(card: OpeningCardDefinition, slot_index: int) -> bool:
	last_error = ""
	if card == null or card.category != "resource":
		last_error = "该卡不能放入聚落格。"
		return false
	if slot_index < 0 or slot_index >= slot_positions.size():
		last_error = "聚落格不存在。"
		return false
	if buildings_by_slot.has(slot_index):
		last_error = "这个聚落格已经有建筑。"
		return false
	# 旧固定格接口以类型代表开局唯一卡；地图入口按库存实例消费。
	if card.card_id in consumed_card_ids:
		last_error = "这张开局建筑卡已经使用。"
		return false
	if not RunEconomy.try_pay(card.build_costs):
		last_error = "建造资源不足。"
		return false

	var building := RESOURCE_BUILDING_SCENE.instantiate() as ResourceBuilding
	add_child(building)
	var footprint: Vector2i = MapLayout.footprint_for_card(card.card_id)
	var claimed_site: ResourceSite = null
	if not card.required_resource_site.is_empty():
		for site in resource_sites:
			if site.accepts(card):
				claimed_site = site
				break
		if claimed_site == null:
			_refund(card.build_costs)
			building.queue_free()
			last_error = "%s需要空闲的对应资源点。" % card.display_name
			return false
	var final_position: Vector2 = claimed_site.position if claimed_site != null else slot_positions[slot_index]
	if grid_map_model != null:
		final_position = grid_map_model.snap_footprint_center(final_position, footprint)
	var site_id := StringName(claimed_site.name) if claimed_site != null else &""
	if grid_map_model != null and not grid_map_model.can_place(final_position, footprint, site_id):
		_refund(card.build_costs)
		building.queue_free()
		last_error = "目标网格包含水域、岩壁、石质坡道、资源点或已占用地块。"
		return false
	building.position = final_position
	building.configure(card, claimed_site)
	if claimed_site != null and not claimed_site.claim(building):
		_refund(card.build_costs)
		building.queue_free()
		last_error = "该资源点已被占用。"
		return false
	if grid_map_model != null and not grid_map_model.occupy(
		_occupant_id(building), final_position, footprint, site_id
	):
		if claimed_site != null:
			claimed_site.release(building)
		_refund(card.build_costs)
		building.queue_free()
		last_error = "目标网格已被占用。"
		return false
	building.destroyed.connect(_on_building_destroyed)
	buildings_by_slot[slot_index] = building
	consumed_card_ids.append(card.card_id)
	placement_order.append(building)
	building_placed.emit(slot_index, card.card_id)
	return true


func place_card_at(
	card: OpeningCardDefinition,
	map_position: Vector2,
	obstacles: Array[Dictionary] = []
) -> ResourceBuilding:
	last_error = ""
	if card == null or card.category not in ["resource", "population"]:
		last_error = "该卡不能作为地图建筑放置。"
		return null
	var footprint: Vector2i = MapLayout.footprint_for_card(card.card_id)
	var final_position: Vector2 = (
		grid_map_model.snap_footprint_center(map_position, footprint)
		if grid_map_model != null
		else map_position
	)
	var claimed_site: ResourceSite = null
	if card.category == "resource" and not card.required_resource_site.is_empty():
		claimed_site = _matching_site(card, map_position)
		if claimed_site == null:
			last_error = "%s必须建在对应的%s资源点上。" % [card.display_name, _site_label(card.required_resource_site)]
			return null
		final_position = claimed_site.global_position
	var site_id := StringName(claimed_site.name) if claimed_site != null else &""
	if grid_map_model != null and not grid_map_model.can_place(final_position, footprint, site_id):
		last_error = "目标网格包含水域、岩壁、石质坡道、资源点或已占用地块。"
		return null
	if not MapLayout.is_buildable(final_position, card.footprint_radius):
		last_error = "建筑的完整占地必须位于地图可建造区域内。"
		return null
	if card.category == "resource" and grid_map_model != null and not grid_map_model.has_work_access(final_position,footprint):
		last_error = "山区岗位建筑需要靠近山路，留出人员可到达的入口。"
		return null
	if not _is_clear(final_position, card.footprint_radius, obstacles):
		last_error = "这里已有建筑或单位，不能放置%s。" % card.display_name
		return null
	if not RunEconomy.try_pay(card.build_costs):
		last_error = "建造资源不足。"
		return null
	var building := RESOURCE_BUILDING_SCENE.instantiate() as ResourceBuilding
	add_child(building)
	building.global_position = final_position
	building.configure(card, claimed_site)
	building.destroyed.connect(_on_building_destroyed)
	if claimed_site != null and not claimed_site.claim(building):
		_refund(card.build_costs)
		building.queue_free()
		last_error = "该资源点已被占用。"
		return null
	if grid_map_model != null and not grid_map_model.occupy(
		_occupant_id(building), final_position, footprint, site_id
	):
		if claimed_site != null:
			claimed_site.release(building)
		_refund(card.build_costs)
		building.queue_free()
		last_error = "目标网格已被占用。"
		return null
	placement_order.append(building)
	building_placed_at.emit(building, card.card_id)
	return building


func reset_buildings() -> void:
	for building: Variant in buildings_by_slot.values():
		if is_instance_valid(building):
			if grid_map_model != null:
				grid_map_model.release(_occupant_id(building as Node))
			(building as ResourceBuilding).remove_from_run()
			(building as Node).queue_free()
	for building in placement_order:
		if is_instance_valid(building) and building not in buildings_by_slot.values():
			if grid_map_model != null:
				grid_map_model.release(_occupant_id(building))
			building.remove_from_run()
			building.queue_free()
	buildings_by_slot.clear()
	consumed_card_ids.clear()
	placement_order.clear()
	last_error = ""
	buildings_reset.emit()


func building_count() -> int:
	return placement_order.size()


func placed_buildings() -> Array[ResourceBuilding]:
	return placement_order.duplicate()


func _matching_site(card: OpeningCardDefinition, map_position: Vector2) -> ResourceSite:
	var best_site: ResourceSite = null
	var best_distance: float = INF
	for site in resource_sites:
		if not is_instance_valid(site) or not site.accepts(card):
			continue
		var distance: float = site.global_position.distance_to(map_position)
		if distance <= site.radius and distance < best_distance:
			best_site = site
			best_distance = distance
	return best_site


func _is_clear(position_to_test: Vector2, radius: float, obstacles: Array[Dictionary]) -> bool:
	for building in placement_order:
		if not is_instance_valid(building) or building.definition == null:
			continue
		if building.global_position.distance_to(position_to_test) < radius + building.definition.footprint_radius:
			return false
	for obstacle in obstacles:
		var obstacle_position: Vector2 = obstacle.get("position", Vector2.ZERO)
		var obstacle_radius: float = float(obstacle.get("radius", 0.0))
		if obstacle_position.distance_to(position_to_test) < radius + obstacle_radius:
			return false
	return true


func _site_label(site_type: StringName) -> String:
	return str({
		&"forest": "树林",
		&"farmland": "农田",
		&"gold_vein": "金矿脉",
		&"stone_deposit": "石矿脉",
		&"iron_deposit": "铁矿脉",
	}.get(site_type, "资源"))


func _refund(costs: Dictionary) -> void:
	for resource_id: Variant in costs:
		RunEconomy.add_resource(StringName(resource_id), int(costs[resource_id]))


func _on_building_destroyed(building: ResourceBuilding) -> void:
	if grid_map_model != null:
		grid_map_model.release(_occupant_id(building))
	placement_order.erase(building)
	var removed_slots: Array = []
	for slot_index: Variant in buildings_by_slot:
		if buildings_by_slot[slot_index] == building:
			removed_slots.append(slot_index)
	for slot_index in removed_slots:
		buildings_by_slot.erase(slot_index)
	var card_id: StringName = building.definition.card_id if building.definition != null else &""
	building_destroyed.emit(building, card_id)
	building.queue_free()


func _occupant_id(building: Node) -> StringName:
	return StringName("building_%d" % building.get_instance_id())
