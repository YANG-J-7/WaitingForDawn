extends Node

const MAIN = preload("res://src/main/main.tscn")
const FIXTURE = preload("res://tests/helpers/shop_wave_fixture.gd")
var failures: int = 0
var clear_count: int = 0


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
	var controller: WaveController = main.wave_controller
	check(controller.wave_definitions.size() == 10, "主场景加载十份怪潮数据")
	# 缺少后期数据时明确失败退出，避免测试挂起。
	if controller.wave_definitions.size() != 10:
		main.free()
		return
	var multipliers = [1.0, 1.0, 1.0, 1.0, 1.0, 1.1, 1.21, 1.331, 1.4641, 1.61051]
	var counts = [5, 6, 6, 7, 7, 8]
	for wave in range(1, 11):
		var definition = controller._definition_for_wave(wave)
		check(definition != null and definition.is_valid(), "第%d波数据有效" % wave)
		check(is_equal_approx(definition.strength_multiplier(), multipliers[wave - 1]), "第%d波预算倍率正确" % wave)
		if wave >= 5:
			check(definition.spawn_count() == counts[wave - 5], "第%d波整数编成正确" % wave)
			check(abs(definition.total_threat() - definition.threat_budget()) <= 2, "第%d波编成取最近威胁点" % wave)
	check(not controller.start_wave(0) and not controller.start_wave(11), "拒绝越界波次")
	var invalid = controller._definition_for_wave(10).duplicate()
	invalid.enemy_count = 0
	check(not invalid.is_valid() and invalid.spawn_count() == 0, "拒绝零敌人数据")
	invalid.enemy_count = 5
	invalid.spawn_interval = 0.0
	check(not invalid.is_valid(), "拒绝零出生间隔")
	main.start_button.pressed.emit()
	for index in [0, 1, 2, 3]:
		main.card_buttons[index].pressed.emit()
	main.ready_button.pressed.emit()
	main.farmer_manager.set_process(false)
	controller.set_process(false)
	RunEconomy.add_resource(&"gold", 1000)
	RunEconomy.add_resource(&"food", 1000)
	# 使用真实建筑与农民交付，手动步进避免受控清怪测试依赖墙钟。
	var building = main.settlement_builder.place_card_at(preload("res://src/data/cards/lumber_camp.tres"), main.resource_sites[0].global_position)
	check(building != null, "创建后期运输验证建筑")
	controller.wave_cleared.connect(func(_wave): clear_count += 1)
	for wave in range(1, 11):
		check(RunState.current_wave == wave and RunState.phase == RunState.Phase.WAVE_COMBAT, "第%d波可迎战" % wave)
		check(controller.active_enemy_count == controller.active_wave_definition.spawn_count(), "第%d波实际生成采用预算编成" % wave)
		controller._spawn_enemy()
		var enemy: EnemyActor = controller.enemies[0]
		check(enemy.current_health == 55 and enemy.definition.base_damage == 8, "第%d波未叠乘生命与伤害" % wave)
		if wave >= 5:
			main._on_battle_shop_button_pressed()
			check(main.battle_shop.active, "第%d波战斗商店可打开" % wave)
			main._on_battle_shop_button_pressed()
		FIXTURE.clear_wave(controller)
		await get_tree().process_frame
		check(clear_count == wave and main.wave_economy.settled_waves.size() == wave, "第%d波只清场结算一次" % wave)
		var balance = RunEconomy.balances.duplicate(true)
		check(not main.wave_economy.settle_wave(wave, main.settlement_builder), "第%d波拒绝重复结算" % wave)
		check(balance == RunEconomy.balances, "第%d波重复结算不扣资源" % wave)
		check(not main.interwave_draft.active, "连续守城不打开旧波间商店")
		check(RunState.phase == RunState.Phase.WAVE_COMBAT, "第%d波后自动衔接下一轮" % wave)
		check(RunState.current_wave == wave + 1, "清场后威胁轮次递增")
		var expected_template: int = wave + 1 if wave < 10 else 1
		check(controller.active_wave_index == expected_template, "下一轮使用正确循环模板")
		var wood_before: int = RunEconomy.amount(&"wood")
		main.farmer_manager.advance(100.0)
		main.farmer_manager.advance(2.0)
		main.farmer_manager.advance(100.0)
		check(RunEconomy.amount(&"wood") > wood_before, "连续战斗期间运输可交付")
	check(RunState.phase == RunState.Phase.WAVE_COMBAT and RunState.current_wave == 11, "第十波清场后进入第十一轮而非胜利")
	check(not main.failure_panel.visible, "第十波清场不显示终局结果")
	check(not main.interwave_draft.active, "第十一轮不打开旧波间商店")
	if "--capture-victory" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.codex-temp/story-018")
		check(get_viewport().get_texture().get_image().save_png("res://.codex-temp/story-018/victory.png") == OK, "保存胜利界面截图")
	RunState.advance_campaign_time(RunState.CAMPAIGN_DURATION_SECONDS)
	await get_tree().process_frame
	check(RunState.phase == RunState.Phase.RUN_WON and main.failure_panel.visible, "守满60分钟显示胜利结果")
	var balances = RunEconomy.balances.duplicate(true)
	main.farmer_manager.advance(100.0)
	check(balances == RunEconomy.balances, "实际通关后运输停止")
	main.failure_reset_button.pressed.emit()
	check(RunState.current_wave == 1 and main.run_card_inventory.card_count() == 0 and main.wave_economy.settled_waves.is_empty(), "通关重置清空本局记录")
	main.start_button.pressed.emit()
	check(main.farmer_manager.active_farmers().size() == 5, "新局恢复五名农民")
	# 后期每波失败，以及同帧最后一只死亡后主城归零，均不能误判胜利。
	for wave in range(5, 11):
		main._on_reset_pressed()
		main.start_button.pressed.emit()
		main.opening_draft.reset()
		RunState.current_wave = wave
		controller.start_wave(wave)
		RunState.start_current_wave()
		if wave == 10:
			FIXTURE.clear_wave(controller)
		RunState.damage_city(RunState.city_health)
		await get_tree().process_frame
		check(RunState.phase == RunState.Phase.RUN_LOST and not controller.spawning, "第%d波主城摧毁立即失败并停止出怪" % wave)
		check(main.wave_economy.settled_waves.is_empty(), "失败不触发迟到清场结算")
	main._on_reset_pressed()
	main.start_button.pressed.emit()
	main.opening_draft.reset()
	controller.start_wave(1)
	RunState.start_current_wave()
	FIXTURE.clear_wave(controller)
	main._on_reset_pressed()
	main.start_button.pressed.emit()
	await get_tree().process_frame
	check(RunState.phase == RunState.Phase.DAY_SETUP and RunState.current_wave == 1, "清场当帧重置不推进新局")
	check(main.wave_economy.settled_waves.is_empty(), "重置前清场回调不污染新局结算")
	main.free()
