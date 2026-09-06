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

	var builder: SettlementBuilder = main.get_node("SettlementBuilder") as SettlementBuilder
	var wave_economy: WaveEconomy = main.get_node("WaveEconomy") as WaveEconomy
	var tower: ArrowTower = main.get_node("ArrowTower") as ArrowTower
	var start_button: Button = main.get_node("HUD/BottomPanel/Margin/Content/Buttons/StartButton") as Button
	var card_grid: GridContainer = main.get_node("HUD/DaySetupPanel/Margin/Content/CardGrid") as GridContainer
	var ready_button: Button = main.get_node("HUD/DaySetupPanel/Margin/Content/Controls/ReadyButton") as Button
	var defense_slot: Button = main.get_node("HUD/DefenseSlotButton") as Button
	var job_rows: HBoxContainer = main.get_node("HUD/DaySetupPanel/Margin/Content/JobSection/JobScroll/JobRows") as HBoxContainer
	var job_section: HBoxContainer = main.get_node("HUD/DaySetupPanel/Margin/Content/JobSection") as HBoxContainer
	var setup_panel: PanelContainer = main.get_node("HUD/DaySetupPanel") as PanelContainer
	var auto_button: Button = main.get_node("HUD/DaySetupPanel/Margin/Content/JobSection/AutoAssignButton") as Button
	var settlement_slots: Array[Button] = [
		main.get_node("HUD/SettlementSlot0") as Button,
		main.get_node("HUD/SettlementSlot1") as Button,
		main.get_node("HUD/SettlementSlot2") as Button,
	]

	start_button.pressed.emit()
	RunEconomy.add_resource(&"wood", 50)
	for card_index in [0, 1, 2]:
		(card_grid.get_child(card_index) as Button).pressed.emit()
		settlement_slots[card_index].pressed.emit()
	(card_grid.get_child(3) as Button).pressed.emit()
	defense_slot.pressed.emit()
	await get_tree().process_frame

	_expect_equal(job_rows.get_child_count(), 4, "four built buildings expose worker rows")
	_expect_true(
		job_section.get_global_rect().end.y <= setup_panel.get_global_rect().end.y,
		"worker controls stay inside the visible setup panel"
	)
	_expect_equal(wave_economy.assigned_workers_for(&"arrow_tower"), 1, "auto assignment staffs arrow tower first")
	_expect_equal(wave_economy.assigned_workers_for(&"lumber_camp"), 2, "auto assignment staffs lumber camp")
	_expect_equal(wave_economy.assigned_workers_for(&"farm"), 2, "auto assignment staffs farm")
	_expect_equal(wave_economy.assigned_workers_for(&"gold_mine"), 0, "five starting farmers leave gold mine unstaffed")
	_expect_equal(wave_economy.assigned_population, 5, "auto assignment uses all population")
	_expect_equal(wave_economy.idle_population, 0, "auto assignment leaves no idle population")
	var arrow_minus := job_rows.get_node("Job_arrow_tower/Controls/Minus") as Button
	var arrow_plus := job_rows.get_node("Job_arrow_tower/Controls/Plus") as Button
	var lumber_minus := job_rows.get_node("Job_lumber_camp/Controls/Minus") as Button
	var gold_plus := job_rows.get_node("Job_gold_mine/Controls/Plus") as Button
	_expect_true(arrow_minus.custom_minimum_size.x >= 44.0, "minus touch target is at least forty-four")
	_expect_true(arrow_plus.custom_minimum_size.x >= 44.0, "plus touch target is at least forty-four")

	_expect_true(not wave_economy.adjust_workers(&"gold_mine", 1), "population cap rejects extra worker")
	_expect_equal(wave_economy.assigned_workers_for(&"gold_mine"), 0, "rejected adjustment keeps assignment")
	lumber_minus.pressed.emit()
	gold_plus.pressed.emit()
	_expect_equal(wave_economy.assigned_workers_for(&"lumber_camp"), 1, "manual minus removes lumber worker")
	_expect_equal(wave_economy.assigned_workers_for(&"gold_mine"), 1, "manual plus adds gold worker")
	_expect_equal(wave_economy.assigned_population, 5, "manual reassignment preserves total cap")

	auto_button.pressed.emit()
	_expect_equal(wave_economy.assigned_workers_for(&"lumber_camp"), 2, "auto button restores lumber workers")
	_expect_equal(wave_economy.assigned_workers_for(&"gold_mine"), 0, "auto button restores defense-first distribution")
	lumber_minus.pressed.emit()
	gold_plus.pressed.emit()
	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_true(wave_economy.assignments_locked, "combat locks worker assignments")
	_expect_true(not wave_economy.adjust_workers(&"arrow_tower", -1), "combat rejects worker changes")
	_expect_true(arrow_minus.disabled and arrow_plus.disabled, "combat disables assignment buttons")
	_expect_true(tower.enabled, "staffed arrow tower remains enabled")

	var frame_budget: int = 900
	while RunState.phase == RunState.Phase.WAVE_COMBAT and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1
	_expect_equal(RunState.phase, RunState.Phase.WAVE_RESULT, "staffed defense clears wave one")
	_expect_true(int(wave_economy.total_continuous_production.get(&"wood", 0)) > 0, "one-worker lumber camp produces continuously")
	_expect_true(int(wave_economy.total_continuous_production.get(&"food", 0)) > 0, "full farm produces continuously")
	_expect_true(int(wave_economy.total_continuous_production.get(&"gold", 0)) > 0, "full gold mine produces continuously")
	_expect_true(not wave_economy.assignments_locked, "wave result unlocks assignments")
	_expect_true((main.get_node("HUD/DaySetupPanel") as PanelContainer).visible, "interwave worker panel is visible")

	_expect_true(wave_economy.adjust_workers(&"arrow_tower", -1), "interwave can unstaff arrow tower")
	wave_economy.prepare_wave(builder, tower)
	_expect_true(not tower.enabled, "zero-worker arrow tower is disabled for combat")

	var reset_button: Button = main.get_node("HUD/BottomPanel/Margin/Content/Buttons/ResetButton") as Button
	reset_button.pressed.emit()
	await get_tree().process_frame
	_expect_equal(wave_economy.job_order.size(), 0, "reset clears worker jobs")
	_expect_true(not wave_economy.assignments_locked, "reset clears worker lock")
	_expect_true(not wave_economy.user_modified_assignments, "reset clears manual assignment flag")

	Engine.time_scale = 1.0
	main.queue_free()
	get_tree().quit(failure_count)


func _expect_resource(resource_id: StringName, expected: int, label: String) -> void:
	_expect_equal(RunEconomy.amount(resource_id), expected, label)


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
