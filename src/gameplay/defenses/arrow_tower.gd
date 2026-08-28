class_name ArrowTower
extends Node2D

signal attack_performed(target_spawn_index: int, final_damage: int, applied_damage: int, killed: bool)

const TILE_SIZE: float = 32.0
const DamageRules = preload("res://src/gameplay/combat/damage_calculator.gd")

@export var definition: TowerDefinition
@export var target_provider_path: NodePath
@export var enabled: bool = true

var attack_elapsed: float = 0.0
var total_damage: int = 0
var kill_count: int = 0
var first_target_spawn_index: int = -1
var first_final_damage: int = 0

@onready var target_provider: WaveController = get_node(target_provider_path) as WaveController


func _ready() -> void:
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
	var color: Color = Color("5c8aa6") if definition == null else definition.body_color
	draw_rect(Rect2(-17.0, -15.0, 34.0, 30.0), color)
	draw_rect(Rect2(-6.0, -30.0, 12.0, 18.0), color.lightened(0.15))
	draw_line(Vector2(0.0, -23.0), Vector2(18.0, -23.0), Color("d8e7ed"), 3.0)
	if definition != null:
		draw_arc(Vector2.ZERO, definition.attack_range_tiles * TILE_SIZE, 0.0, TAU, 64, Color(0.42, 0.7, 0.78, 0.18), 1.0)
