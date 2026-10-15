class_name ResourceBuilding
extends Node2D

const ArtVisualScript = preload("res://src/gameplay/art/art_visual.gd")
const BuildingGroundingScript = preload("res://src/gameplay/art/building_grounding.gd")

signal destroyed(building: ResourceBuilding)

var definition: OpeningCardDefinition
var assigned_workers: int = 0
var resource_site: ResourceSite
var capacity_bonus_applied: bool = false
var current_health: int = 0
var art_visual: ArtVisual
var grounding: Node2D


func _ready() -> void:
	grounding = BuildingGroundingScript.new() as Node2D
	add_child(grounding)
	art_visual = ArtVisualScript.new() as ArtVisual
	art_visual.show_behind_parent = true
	add_child(art_visual)


func configure(card_definition: OpeningCardDefinition, site: ResourceSite = null) -> void:
	definition = card_definition
	resource_site = site
	current_health = definition.maximum_health if definition != null else 0
	var art_name: String = str({
		&"lumber_camp": "lumberyard",
		&"farm": "farm",
		&"stone_mine": "quarry",
		&"iron_mine": "mine_entrance",
		&"gold_mine": "mine_entrance",
		&"house": "house",
	}.get(definition.card_id, "house")) if definition != null else "house"
	grounding.configure(Vector2i(2, 2), definition.card_id if definition != null else &"default")
	art_visual.configure_world(art_name, Vector2(65, 56), &"lantern")
	if definition != null and definition.population_capacity_bonus > 0:
		capacity_bonus_applied = RunEconomy.change_population_capacity(
			definition.population_capacity_bonus
		)
	queue_redraw()


func is_attackable() -> bool:
	return visible and definition != null and current_health > 0


func attackable_radius() -> float:
	return definition.footprint_radius if definition != null else 34.0


func apply_enemy_attack(base_damage: int, _enemy_id: StringName) -> int:
	if not is_attackable() or base_damage <= 0:
		return 0
	var final_damage: int = maxi(1, floori(float(base_damage) * 100.0 / (100.0 + float(definition.armor))))
	var applied: int = mini(current_health, final_damage)
	current_health -= applied
	queue_redraw()
	if current_health == 0:
		remove_from_run()
		visible = false
		destroyed.emit(self)
	return applied


func remove_from_run() -> void:
	if resource_site != null and is_instance_valid(resource_site):
		resource_site.release(self)
	var removed_bonus: int = definition.population_capacity_bonus if capacity_bonus_applied and definition != null else 0
	capacity_bonus_applied = false
	if removed_bonus > 0:
		RunEconomy.change_population_capacity(-removed_bonus)


func assign_workers(worker_count: int) -> void:
	if definition == null:
		assigned_workers = 0
	else:
		assigned_workers = clampi(worker_count, 0, definition.worker_slots)
	queue_redraw()


func _draw() -> void:
	if definition != null:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-30.0, 5.0),
			definition.display_name,
			HORIZONTAL_ALIGNMENT_CENTER,
			60.0,
			14,
			Color.WHITE
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-30.0, 20.0),
			"岗位 %d/%d" % [assigned_workers, definition.worker_slots],
			HORIZONTAL_ALIGNMENT_CENTER,
			60.0,
			11,
			Color("e8ddb5")
		)
		var health_ratio: float = float(current_health) / float(definition.maximum_health)
		draw_rect(Rect2(-34, -52, 68, 4), Color("2b1d25"))
		draw_rect(Rect2(-34, -52, 68 * health_ratio, 4), Color("7ecf75"))
