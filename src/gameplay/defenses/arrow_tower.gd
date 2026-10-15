class_name ArrowTower
extends Node2D

signal attack_performed(target_spawn_index: int, final_damage: int, applied_damage: int, killed: bool)
signal destroyed(tower: ArrowTower)

const TILE_SIZE: float = 32.0
const DamageRules = preload("res://src/gameplay/combat/damage_calculator.gd")
const ArtVisualScript = preload("res://src/gameplay/art/art_visual.gd")
const BuildingGroundingScript = preload("res://src/gameplay/art/building_grounding.gd")

@export var definition: TowerDefinition
@export var target_provider_path: NodePath
@export var enabled: bool = true

var attack_elapsed: float = 0.0
var total_damage: int = 0
var kill_count: int = 0
var first_target_spawn_index: int = -1
var first_final_damage: int = 0
var maximum_health: int = 220
var current_health: int = 220
var armor: int = 8

@onready var target_provider: WaveController = get_node(target_provider_path) as WaveController


func _ready() -> void:
	var grounding: Node2D = BuildingGroundingScript.new() as Node2D
	add_child(grounding)
	grounding.configure(Vector2i.ONE, &"arrow_tower")
	var art := ArtVisualScript.new() as ArtVisual
	art.show_behind_parent = true
	add_child(art)
	art.configure_world("arrow_tower", Vector2(35, 64), &"lantern")
	reset_statistics()
	queue_redraw()


func _process(delta: float) -> void:
	if not enabled or definition == null or target_provider == null:
		return
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return

	attack_elapsed = minf(definition.attack_interval, attack_elapsed + delta)
	if attack_elapsed < definition.attack_interval:
		return

	var attack_range_pixels: float = definition.attack_range_tiles * TILE_SIZE
	var target: EnemyActor = target_provider.get_priority_target(global_position, attack_range_pixels)
	if target == null:
		return

	attack_elapsed = 0.0
	_attack(target)


func reset_statistics() -> void:
	attack_elapsed = definition.attack_interval if definition != null else 0.0
	total_damage = 0
	kill_count = 0
	first_target_spawn_index = -1
	first_final_damage = 0
	current_health = maximum_health


func is_attackable() -> bool:
	return visible and current_health > 0


func attackable_radius() -> float:
	return 34.0


func apply_enemy_attack(base_damage: int, _enemy_id: StringName) -> int:
	if not is_attackable() or base_damage <= 0:
		return 0
	var final_damage: int = DamageRules.physical_damage(base_damage, armor)
	var applied: int = mini(current_health, final_damage)
	current_health -= applied
	if current_health == 0:
		visible = false
		enabled = false
		destroyed.emit(self)
	queue_redraw()
	return applied


func _attack(target: EnemyActor) -> void:
	if not target.is_alive() or target.definition == null:
		return
	var counter_multiplier: float = definition.counter_multiplier_for(target.definition.enemy_id)
	var final_damage: int = DamageRules.physical_damage(
		definition.base_damage,
		target.definition.armor,
		definition.armor_penetration,
		1.0,
		1.0,
		counter_multiplier
	)
	if first_target_spawn_index < 0:
		first_target_spawn_index = target.spawn_index
		first_final_damage = final_damage
	var applied_damage: int = target.apply_damage(final_damage)
	var killed: bool = not target.is_alive()
	total_damage += applied_damage
	if killed:
		kill_count += 1
	attack_performed.emit(target.spawn_index, final_damage, applied_damage, killed)


func _draw() -> void:
	if definition != null:
		draw_arc(Vector2.ZERO, definition.attack_range_tiles * TILE_SIZE, 0.0, TAU, 64, Color(0.42, 0.7, 0.78, 0.18), 1.0)
		var health_ratio: float = float(current_health) / float(maximum_health)
		draw_rect(Rect2(-18, -38, 36, 4), Color("2b1d25"))
		draw_rect(Rect2(-18, -38, 36 * health_ratio, 4), Color("7ecf75"))
