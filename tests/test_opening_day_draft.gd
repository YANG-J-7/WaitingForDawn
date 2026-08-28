extends Node

const MAIN_SCENE: PackedScene = preload("res://src/main/main.tscn")

var failure_count: int = 0


func _ready() -> void:
	_run_test()


func _run_test() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame

	var draft: OpeningDraft = main.get_node("OpeningDraft") as OpeningDraft
	var controller: WaveController = main.get_node("WaveController") as WaveController
	var tower: ArrowTower = main.get_node("ArrowTower") as ArrowTower
	var start_button: Button = main.get_node("HUD/BottomPanel/Margin/Content/Buttons/StartButton") as Button
	var setup_panel: PanelContainer = main.get_node("HUD/DaySetupPanel") as PanelContainer
	var card_grid: GridContainer = main.get_node("HUD/DaySetupPanel/Margin/Content/CardGrid") as GridContainer
	var ready_button: Button = main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/ReadyButton") as Button
	var pause_button: Button = main.get_node_or_null(
		"HUD/DaySetupPanel/Margin/Content/Header/PauseTimerButton"
	) as Button
	var slot_button: Button = main.get_node("HUD/DefenseSlotButton") as Button

	start_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(RunState.phase, RunState.Phase.DAY_SETUP, "start enters day setup")
	_expect_true(setup_panel.visible, "day setup panel is visible")
	_expect_equal(card_grid.get_child_count(), 6, "six opening cards are shown")
	_expect_equal(draft.category_count("resource"), 3, "three resource cards")
	_expect_equal(draft.category_count("defense"), 3, "three defense cards")
	_expect_true(draft.seconds_remaining <= 20.0 and draft.seconds_remaining > 19.0, "countdown starts at twenty")
	_expect_true(not controller.spawning, "enemies wait during setup")
	_expect_true(ready_button.disabled, "ready is disabled before four picks")
	_expect_true(pause_button != null, "setup exposes a visible countdown pause button")
	if pause_button != null:
		pause_button.pressed.emit()
		var manual_pause_time: float = draft.seconds_remaining
		await get_tree().create_timer(0.05).timeout
		_expect_true(
			is_equal_approx(draft.seconds_remaining, manual_pause_time),
			"manual setup pause freezes only the draft countdown"
		)
		pause_button.pressed.emit()
		_expect_true(not draft.countdown_paused, "pause button resumes setup countdown")

	var time_before_pause: float = draft.seconds_remaining
	get_tree().paused = true
	await get_tree().create_timer(0.05, true).timeout
	get_tree().paused = false
	_expect_true(is_equal_approx(draft.seconds_remaining, time_before_pause), "pause freezes countdown")

	slot_button.pressed.emit()
	_expect_true(not tower.enabled, "arrow tower cannot be placed before selection")
	for card_index in [0, 1, 3, 4]:
		(card_grid.get_child(card_index) as Button).pressed.emit()
	_expect_equal(draft.selected_indices.size(), 4, "four cards can be selected")
	_expect_true(not ready_button.disabled, "ready enables after four picks")
	(card_grid.get_child(5) as Button).pressed.emit()
	_expect_equal(draft.selected_indices.size(), 4, "fifth card is rejected")

	slot_button.pressed.emit()
	_expect_true(tower.visible and tower.enabled, "selected arrow tower is placed")
	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "ready starts wave one")
	_expect_true(not setup_panel.visible, "setup panel locks after ready")
	_expect_true(controller.spawning or controller.spawned_count > 0, "wave spawning begins")

	var reset_button: Button = main.get_node("HUD/BottomPanel/Margin/Content/Buttons/ResetButton") as Button
	reset_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(RunState.phase, RunState.Phase.BOOT, "reset returns to boot")
	_expect_equal(draft.selected_indices.size(), 0, "reset clears selection")
	_expect_true(not tower.visible and not tower.enabled, "reset removes placed arrow tower")

	draft.duration_seconds = 0.05
	start_button.pressed.emit()
	var frame_budget: int = 30
	while RunState.phase == RunState.Phase.DAY_SETUP and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1
	_expect_equal(draft.selected_indices.size(), 4, "timeout auto fills four cards")
	_expect_true(_selected_has_category(draft, "resource"), "auto fill keeps a resource card")
	_expect_true(_selected_has_category(draft, "defense"), "auto fill keeps a defense card")
	_expect_equal(RunState.phase, RunState.Phase.WAVE_COMBAT, "timeout starts wave one")

	main.queue_free()
	get_tree().quit(failure_count)


func _selected_has_category(draft: OpeningDraft, category: String) -> bool:
	for card_index in draft.selected_indices:
		if draft.offered_cards[card_index].category == category:
			return true
	return false


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	failure_count += 1
	push_error("FAIL: %s expected=%s actual=%s" % [label, expected, actual])


func _expect_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failure_count += 1
	push_error("FAIL: %s" % label)
