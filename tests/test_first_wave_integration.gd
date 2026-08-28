extends Node

const MAIN_SCENE: PackedScene = preload("res://src/main/main.tscn")

var failure_count: int = 0


func _ready() -> void:
	_run_test()


func _run_test() -> void:
	Engine.time_scale = 20.0
	var main: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame

	var controller: WaveController = main.get_node("WaveController") as WaveController
	var tower: ArrowTower = main.get_node("ArrowTower") as ArrowTower
	tower.enabled = false
	_expect_equal(controller.wave_definition.total_threat(), 20, "wave threat budget")

	RunState.begin_new_run()
	RunState.start_current_wave()
	_expect_true(controller.start_first_wave(), "wave starts with valid data")

	var frame_budget: int = 600
	while RunState.phase != RunState.Phase.RUN_LOST and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1

	_expect_equal(controller.spawned_count, 4, "four wolves spawned")
	_expect_equal(RunState.city_health, 0, "city health reaches zero")
	_expect_equal(RunState.phase, RunState.Phase.RUN_LOST, "run enters lost phase")

	var positions_before: Array[Vector2] = []
	for enemy in controller.enemies:
		positions_before.append(enemy.position)
	for _frame in range(5):
		await get_tree().process_frame
	for index in range(controller.enemies.size()):
		_expect_true(
			controller.enemies[index].position.is_equal_approx(positions_before[index]),
			"enemy stops after loss %d" % index
		)

	var failure_button: Button = main.get_node("HUD/FailurePanel/Margin/Content/FailureResetButton") as Button
	failure_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(RunState.phase, RunState.Phase.BOOT, "reset returns to boot")
	_expect_equal(controller.enemies.size(), 0, "reset clears enemies")

	Engine.time_scale = 1.0
	main.queue_free()
	get_tree().quit(failure_count)


func _expect_equal(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	failure_count += 1
	push_error("FAIL: %s expected=%d actual=%d" % [label, expected, actual])


func _expect_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failure_count += 1
	push_error("FAIL: %s" % label)
