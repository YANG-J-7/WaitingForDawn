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
	var worker_panel: PanelContainer = main.get_node("HUD/BuildingWorkerPanel") as PanelContainer
	var worker_minus: Button = main.get_node("HUD/BuildingWorkerPanel/Margin/Content/Controls/MinusButton") as Button
	var worker_plus: Button = main.get_node("HUD/BuildingWorkerPanel/Margin/Content/Controls/PlusButton") as Button
	var auto_button: Button = main.get_node("HUD/BuildingWorkerPanel/Margin/Content/Actions/AutoButton") as Button
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
	_expect_true(not job_section.visible, "shop and opening panel no longer expose the global worker list")
	_expect_equal(wave_economy.assigned_workers_for(&"arrow_tower"), 1, "auto assignment staffs arrow tower first")
	_expect_equal(wave_economy.assigned_workers_for(&"lumber_camp"), 2, "auto assignment staffs lumber camp")
	_expect_equal(wave_economy.assigned_workers_for(&"farm"), 2, "auto assignment staffs farm")
	_expect_equal(wave_economy.assigned_workers_for(&"stone_mine"), 0, "five starting farmers leave stone mine unstaffed")
	_expect_equal(wave_economy.assigned_population, 5, "auto assignment uses all population")
	_expect_equal(wave_economy.idle_population, 0, "auto assignment leaves no idle population")
	main._select_building_job(&"lumber_camp")
	_expect_true(worker_panel.visible, "click-selected building opens contextual worker panel")
	_expect_true(worker_minus.custom_minimum_size.x >= 44.0, "minus touch target is at least forty-four")
	_expect_true(worker_plus.custom_minimum_size.x >= 44.0, "plus touch target is at least forty-four")

	_expect_true(not wave_economy.adjust_workers(&"stone_mine", 1), "population cap rejects extra worker")
	_expect_equal(wave_economy.assigned_workers_for(&"stone_mine"), 0, "rejected adjustment keeps assignment")
	worker_minus.pressed.emit()
	main._select_building_job(&"stone_mine")
	worker_plus.pressed.emit()
	_expect_equal(wave_economy.assigned_workers_for(&"lumber_camp"), 1, "manual minus removes lumber worker")
	_expect_equal(wave_economy.assigned_workers_for(&"stone_mine"), 1, "manual plus adds stone worker")
	_expect_equal(wave_economy.assigned_population, 5, "manual reassignment preserves total cap")

	auto_button.pressed.emit()
	_expect_equal(wave_economy.assigned_workers_for(&"lumber_camp"), 2, "auto button restores lumber workers")
	_expect_equal(wave_economy.assigned_workers_for(&"stone_mine"), 0, "auto button restores defense-first distribution")
	main._select_building_job(&"lumber_camp")
	worker_minus.pressed.emit()
	main._select_building_job(&"stone_mine")
	worker_plus.pressed.emit()
	ready_button.pressed.emit()
	await get_tree().process_frame
	_expect_true(not wave_economy.assignments_locked, "continuous combat keeps worker assignments editable")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	click.position = main.map_camera.get_canvas_transform() * tower.global_position - main.map_drop_surface.global_position
	main.map_camera.last_mouse_pan_distance = 0.0
	main._on_map_surface_gui_input(click)
	_expect_equal(main.selected_job_id, &"arrow_tower", "left-clicking the world building selects its independent job")
	worker_minus.pressed.emit()
	_expect_equal(wave_economy.assigned_workers_for(&"arrow_tower"), 0, "combat building panel removes an arrow tower worker")
	_expect_true(not tower.enabled, "removing the combat worker immediately disables the arrow tower")
	worker_plus.pressed.emit()
	_expect_equal(wave_economy.assigned_workers_for(&"arrow_tower"), 1, "combat building panel restores an arrow tower worker")
	_expect_true(not worker_minus.disabled and worker_plus.disabled, "contextual worker buttons reflect current capacity")
	_expect_true(tower.enabled, "staffed arrow tower remains enabled")
	main._on_battle_shop_button_pressed()
	_expect_true(setup_panel.visible and not job_section.visible and not worker_panel.visible, "battle shop contains no worker allocation controls")
	main._on_battle_shop_button_pressed()
	main._select_building_job(&"lumber_camp")
	worker_minus.pressed.emit()
	_expect_equal(wave_economy.assigned_workers_for(&"lumber_camp"), 0, "map building panel can remove a resource worker")
	main._select_building_job(&"stone_mine")
	worker_plus.pressed.emit()
	_expect_equal(wave_economy.assigned_workers_for(&"stone_mine"), 2, "map building panel can reassign the freed worker")

	var frame_budget: int = 900
	while 1 not in wave_economy.settled_waves and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1
	_expect_true(1 in wave_economy.settled_waves, "staffed defense clears wave one")
	_expect_true(int(wave_economy.total_continuous_production.get(&"food", 0)) > 0, "full farm produces continuously")
	_expect_true(int(wave_economy.total_continuous_production.get(&"stone", 0)) > 0, "staffed stone mine produces continuously")
	_expect_equal(int(wave_economy.total_continuous_production.get(&"gold", 0)), 0, "prototype resource jobs produce no passive gold")
	_expect_true(not wave_economy.assignments_locked, "continuous defense keeps assignments editable")
	_expect_true(not (main.get_node("HUD/DaySetupPanel") as PanelContainer).visible, "continuous defense does not open interwave panel")
	_expect_true(wave_economy.adjust_workers(&"arrow_tower", -1), "continuous defense accepts later reassignment")

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
