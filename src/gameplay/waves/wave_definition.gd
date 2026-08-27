class_name WaveDefinition
extends Resource

@export_range(1, 10, 1) var wave_index: int = 1
@export var enemy_definition: EnemyDefinition
@export_range(1, 100, 1) var enemy_count: int = 1
@export_range(0.1, 10.0, 0.1) var spawn_interval: float = 1.0


func total_threat() -> int:
	if enemy_definition == null:
		return 0
	return enemy_definition.threat_points * enemy_count
