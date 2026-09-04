class_name ResourceBuilding
extends Node2D

signal destroyed(building: ResourceBuilding)

var definition: OpeningCardDefinition
var assigned_workers: int = 0
var resource_site: ResourceSite
var capacity_bonus_applied: bool = false
var current_health: int = 0


func configure(card_definition: OpeningCardDefinition, site: ResourceSite = null) -> void:
	definition = card_definition
	resource_site = site
	current_health = definition.maximum_health if definition != null else 0
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
	if capacity_bonus_applied and definition != null:
		RunEconomy.change_population_capacity(-definition.population_capacity_bonus)
	capacity_bonus_applied = false


func assign_workers(worker_count: int) -> void:
	if definition == null:
		assigned_workers = 0
	else:
		assigned_workers = clampi(worker_count, 0, definition.worker_slots)
	queue_redraw()


func _draw() -> void:
	var body_color := Color("6b8f5e") if definition == null else definition.building_color
	draw_rect(Rect2(-34.0, -24.0, 68.0, 48.0), body_color)
	draw_polygon(PackedVector2Array([
		Vector2(-39.0, -24.0),
		Vector2(0.0, -43.0),
		Vector2(39.0, -24.0),
	]), PackedColorArray([body_color.lightened(0.18)]))
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
