extends Node

const MAIN = preload("res://src/main/main.tscn")
const FIXTURE = preload("res://tests/helpers/shop_wave_fixture.gd")
var failures: int = 0


func _ready() -> void:
	await run_test()
	get_tree().quit(failures)


func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func run_test() -> void:
	var main = MAIN.instantiate()
	add_child(main)
	main.set_process(false)
	check(RunState.CAMPAIGN_DURATION_SECONDS == 3600.0, "战役时长固定为60分钟")
	check(main.campaign_time_value.text == "60:00", "开局HUD显示60:00")
	main.start_button.pressed.emit()
	check(RunState.campaign_elapsed_seconds == 0.0, "免费选四期间不推进战役计时")
	for index in [0, 1, 2, 3]:
		main.card_buttons[index].pressed.emit()
	main.ready_button.pressed.emit()
	main.wave_controller.set_process(false)
	main.farmer_manager.set_process(false)
	check(RunState.phase == RunState.Phase.WAVE_COMBAT, "确认四张卡后进入连续守城")
	check(main.battle_shop.initialized_stage == 1, "战斗商店初始化为第一威胁阶段")
	var elapsed_before_pause: float = RunState.campaign_elapsed_seconds
	main._on_campaign_pause_pressed()
	check(get_tree().paused, "手动暂停冻结场景树")
	RunState.advance_campaign_time(30.0)
	check(RunState.campaign_elapsed_seconds == elapsed_before_pause, "暂停期间有效游戏时间不推进")
	main._on_campaign_pause_pressed()
	check(not get_tree().paused, "继续按钮恢复场景树")

	RunEconomy.add_resource(&"gold", 100)
	main._on_battle_shop_button_pressed()
	check(main.battle_shop.refresh(), "第一威胁阶段可以刷新商店")
	check(main.battle_shop.refresh_count == 1, "刷新次数已累计")
	main._on_battle_shop_button_pressed()
	RunState.advance_campaign_time(600.0)
	check(RunState.threat_stage == 2, "10分钟进入第二威胁阶段")
	check(main.battle_shop.initialized_stage == 2, "新阶段自动补满战斗商店")
	check(main.battle_shop.refresh_count == 0, "新阶段刷新费恢复初始值")

	RunState.current_wave = 10
	main.wave_controller.start_wave(10)
	FIXTURE.clear_wave(main.wave_controller)
	await get_tree().process_frame
	check(RunState.phase == RunState.Phase.WAVE_COMBAT, "第十轮清场后继续战斗而非胜利")
	check(RunState.current_wave == 11, "第十轮清场后进入第十一轮")
	check(main.wave_controller.active_wave_index == 1, "第十一轮循环使用第一份威胁模板")
	check(not main.interwave_draft.active, "连续守城不打开旧波间商店")

	RunState.advance_campaign_time(2999.0)
	check(RunState.campaign_remaining_seconds() == 1.0, "59:59仍未提前胜利")
	RunState.advance_campaign_time(1.0)
	RunState.damage_city(RunState.city_health)
	await get_tree().process_frame
	check(RunState.phase == RunState.Phase.RUN_LOST, "60:00同帧主城摧毁优先判负")

	main._on_reset_pressed()
	main.start_button.pressed.emit()
	for index in [0, 1, 2, 3]:
		main.card_buttons[index].pressed.emit()
	main.ready_button.pressed.emit()
	main.set_process(false)
	RunState.advance_campaign_time(3600.0)
	await get_tree().process_frame
	check(RunState.phase == RunState.Phase.RUN_WON, "主城存活至60:00立即胜利")
	check("60分钟" in main.status_label.text, "胜利结算显示60分钟守城")

	main._on_reset_pressed()
	check(RunState.campaign_elapsed_seconds == 0.0, "新局重置清空战役计时")
	check(main.campaign_time_value.text == "60:00", "重置后HUD恢复60:00")
	main.free()
