class_name TowerDefinition
extends Resource

@export var defense_id: StringName = &"tower"
@export var display_name: String = "防御塔"
@export_range(1, 10000, 1) var base_damage: int = 1
@export_range(0, 1000, 1) var armor_penetration: int = 0
@export_range(0.1, 30.0, 0.05) var attack_interval: float = 1.0
@export_range(0.5, 20.0, 0.5) var attack_range_tiles: float = 1.0
@export var counter_multipliers: Dictionary = {}
@export var body_color: Color = Color("5c8aa6")


func counter_multiplier_for(enemy_id: StringName) -> float:
	return float(counter_multipliers.get(enemy_id, 1.0))
