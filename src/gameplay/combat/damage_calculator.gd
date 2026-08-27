class_name DamageCalculator
extends RefCounted


static func physical_damage(
	base_damage: int,
	target_armor: int,
	armor_penetration: int = 0,
	attack_multiplier: float = 1.0,
	growth_multiplier: float = 1.0,
	counter_multiplier: float = 1.0
) -> int:
	if base_damage <= 0:
		return 0

	var effective_armor: int = maxi(0, target_armor - armor_penetration)
	var scaled_damage: float = (
		float(base_damage)
		* attack_multiplier
		* growth_multiplier
		* 100.0
		/ (100.0 + float(effective_armor))
		* counter_multiplier
	)
	return maxi(1, int(floor(scaled_damage)))
