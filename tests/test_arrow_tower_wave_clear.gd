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
	var status_label: Label = main.get_node("HUD/BottomPanel/Margin/Content/StatusLabel") as Label
	var start_button: Button = main.get_node("HUD/BottomPanel/Margin/Content/Buttons/StartButton") as Button
	var card_grid: GridContainer = main.get_node("HUD/DaySetupPanel/Margin/Content/CardGrid") as GridContainer
	var ready_button: Button = main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/ReadyButton") as Button
	var slot_button: Button = main.get_node("HUD/DefenseSlotButton") as Button

	start_button.pressed.emit()
	for card_index in [0, 1, 3, 4]:
		(card_grid.get_child(card_index) as Button).pressed.emit()
	slot_button.pressed.emit()
	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "opening draft enters wave combat")
	_expect_true(start_button.disabled, "start button stays disabled during combat")
	_expect_true(controller.spawning or controller.spawned_count > 0, "opening draft starts enemy spawning")

	var frame_budget: int = 900
	while RunState.phase == RunState.Phase.WAVE_COMBAT and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1

	_expect_equal(tower.first_target_spawn_index, 0, "tower targets enemy nearest city first")
	_expect_equal(tower.first_final_damage, 16, "tower deals counter damage")
	_expect_equal(tower.kill_count, 4, "tower kills all wolves")
	_expect_equal(tower.total_damage, 220, "tower applies exact total health damage")
	_expect_equal(controller.spawned_count, 4, "all enemies were spawned")
	_expect_equal(controller.enemies.size(), 0, "no living enemies remain")
	_expect_equal(RunState.phase, RunState.Phase.WAVE_RESULT, "run enters wave result")
	_expect_equal(RunState.current_wave, 2, "wave advances to two")
	_expect_true(RunState.city_health > 0, "city survives wave one")
	_expect_true(status_label.text.contains("第1波已清空"), "ui reports wave clear")

	var reset_button: Button = main.get_node("HUD/BottomPanel/Margin/Content/Buttons/ResetButton") as Button
	reset_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(RunState.phase, RunState.Phase.BOOT, "reset returns to boot")
	_expect_equal(RunState.city_health, RunState.DEFAULT_CITY_HEALTH, "reset restores city health")
	_expect_equal(tower.total_damage, 0, "reset clears tower damage")
	_expect_equal(tower.kill_count, 0, "reset clears tower kills")

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
