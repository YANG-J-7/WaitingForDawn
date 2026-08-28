extends SceneTree

const DamageRules = preload("res://src/gameplay/combat/damage_calculator.gd")

var failure_count: int = 0


func _init() -> void:
	_expect_equal(DamageRules.physical_damage(8, 10), 7, "wolf attacks city")
	_expect_equal(DamageRules.physical_damage(12, 0, 0, 1.0, 1.0, 1.35), 16, "arrow tower counters wolf")
	_expect_equal(DamageRules.physical_damage(34, 20, 15), 32, "ballista armor penetration")
	_expect_equal(DamageRules.physical_damage(1, 999), 1, "minimum positive damage")
	_expect_equal(DamageRules.physical_damage(0, 0), 0, "zero base damage")
	quit(failure_count)


func _expect_equal(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	failure_count += 1
	push_error("FAIL: %s expected=%d actual=%d" % [label, expected, actual])
