class_name WaveDefinition
extends Resource

@export_range(1, 10, 1) var wave_index: int = 1
@export var enemy_definition: EnemyDefinition
# 未乘后期倍率的基础编成数量；实际数量由 spawn_count() 计算。
@export_range(1, 100, 1) var enemy_count: int = 1
@export_range(0.1, 10.0, 0.1) var spawn_interval: float = 1.0


func total_threat() -> int:
	if enemy_definition == null:
		return 0
	return enemy_definition.threat_points * spawn_count()


func is_valid() -> bool:
	return (
		wave_index >= 1 and wave_index <= 10
		and enemy_definition != null and enemy_definition.threat_points > 0
		and enemy_count > 0 and spawn_interval > 0.0
	)


func strength_multiplier() -> float:
	return pow(1.1, maxi(0, wave_index - 5))


func threat_budget() -> int:
	if not is_valid():
		return 0
	return roundi(enemy_definition.threat_points * enemy_count * strength_multiplier())


func spawn_count() -> int:
	if not is_valid():
		return 0
	# 当前只有野狼：预算先四舍五入，再取最接近预算的整数只数。
	# 单怪属性不缩放；编成实际威胁与整数预算最多相差半只怪。
	return maxi(1, roundi(float(threat_budget()) / enemy_definition.threat_points))
