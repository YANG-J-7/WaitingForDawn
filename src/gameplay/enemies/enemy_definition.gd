class_name EnemyDefinition
extends Resource

@export var enemy_id: StringName = &"enemy"
@export var display_name: String = "敌人"
@export_range(1, 1000, 1) var threat_points: int = 1
@export_enum("normal", "tough", "elite", "boss") var reward_tier: String = "normal"
@export_range(0, 999, 1) var kill_gold: int = 2
@export_range(1, 100000, 1) var maximum_health: int = 1
@export_range(0, 1000, 1) var armor: int = 0
@export_range(0.1, 20.0, 0.05) var move_speed_tiles_per_second: float = 1.0
@export_range(1, 10000, 1) var base_damage: int = 1
@export_range(0.1, 30.0, 0.05) var attack_interval: float = 1.0
@export_range(0.0, 256.0, 1.0) var attack_range_pixels: float = 40.0
@export_range(0.0, 128.0, 1.0) var route_corridor_pixels: float = 14.0
@export_range(1.0, 3.0, 0.05) var rush_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.1) var rush_duration: float = 0.0
@export var body_color: Color = Color("b94b62")
