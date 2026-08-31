class_name GuardDefinition
extends Resource

@export var defense_id: StringName = &"barracks_guard"
@export var display_name: String = "守卫"
@export_range(1, 10000, 1) var maximum_health: int = 90
@export_range(0, 1000, 1) var armor: int = 5
@export_range(1, 10000, 1) var base_damage: int = 8
@export_range(0, 1000, 1) var armor_penetration: int = 0
@export_range(0.1, 30.0, 0.05) var attack_interval: float = 0.9
@export_range(1.0, 256.0, 1.0) var attack_range_pixels: float = 46.0
@export var counter_multipliers: Dictionary = {}
@export var body_color: Color = Color("5f8f67")


func counter_multiplier_for(enemy_id: StringName) -> float:
	return float(counter_multipliers.get(enemy_id, 1.0))
