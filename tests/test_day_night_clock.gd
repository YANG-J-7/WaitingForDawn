extends Node
## 验证日月胶囊由真实有效时间驱动，暂停、商店和重开不会错位。
var main: Node
var playfield: SubViewport
var failures: int = 0

func _ready() -> void:
	playfield = SubViewport.new()
	playfield.size = Vector2i(960, 540)
	playfield.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(playfield)
	main = preload("res://src/main/main.tscn").instantiate()
	playfield.add_child.call_deferred(main)
	await frames()
	main.set_process(false)
	var clock: Control = main.hud_reference.day_night_clock
	check(main.campaign_time_value.get_parent() == clock, "真实倒计时位于独立胶囊内")
	check(clock.current_frame == 0 and is_zero_approx(clock.progress), "免费选卡前保持月牙与起始圆弧")
	check(clock.SHEET.get_size() == Vector2(512, 256), "日月图集为八个128像素固定画布")
	var sheet: Image = clock.SHEET.get_image()
	for index in range(8):
		var cell := sheet.get_region(Rect2i((index % 4) * 128, (index / 4) * 128, 128, 128))
		var bounds := cell.get_used_rect()
		check(bounds.has_area() and bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < 128 and bounds.end.y < 128, "第%d帧主体完整且四边透明" % (index + 1))
	main.start_button.pressed.emit()
	for index in [0, 1, 2, 3]:
		main.card_buttons[index].pressed.emit()
	main.ready_button.pressed.emit()
	main.wave_controller.set_process(false)
	main.farmer_manager.set_process(false)
	for enemy in main.wave_controller.enemies:
		enemy.set_physics_process(false)
	RunState.advance_campaign_time(1062.0)
	check(main.campaign_time_value.text == "42:18", "有效时间同步参考图42:18倒计时")
	check(is_equal_approx(clock.progress, 1062.0 / 3600.0), "圆弧读取整局真实进度")
	check(clock.current_frame == 0 and is_zero_approx(clock.blend), "黎明前保持参考图的蓝色月牙")
	for resolution in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1024, 768)]:
		playfield.size = resolution
		await frames()
		print("METRIC: 胶囊=%s 计时标签=%s 最小尺寸=%s" % [clock.get_global_rect(), main.campaign_time_value.get_global_rect(), main.campaign_time_value.get_combined_minimum_size()])
		check(clock.get_global_rect().encloses(main.campaign_time_value.get_global_rect()), "%s计时文字在胶囊内" % resolution)
		var row: HBoxContainer = main.top_bar.get_child(main.top_bar.get_child_count() - 1)
		check(row.get_global_rect().end.x <= resolution.x, "%s新增胶囊后顶栏不越界" % resolution)
		check(clock.get_global_rect().position.x > main.train_farmer_button.get_global_rect().end.x and clock.get_global_rect().end.x < main.wave_value.get_global_rect().position.x, "%s胶囊与招募威胁区不重叠" % resolution)
		await capture("reference-%dx%d" % [resolution.x, resolution.y])
	playfield.size = Vector2i(960, 540)
	RunState.advance_campaign_time(2238.0)
	check(clock.current_frame == 0 and is_zero_approx(clock.transition_progress), "最后5分钟从月牙开始转换")
	main._on_battle_shop_button_pressed()
	RunState.advance_campaign_time(150.0)
	check(clock.current_frame == 3 and clock.next_frame == 4 and is_equal_approx(clock.blend, 0.5), "商店展开时日月继续随计时转换并混合相邻帧")
	check(main.campaign_time_value.text == "02:30", "转换中倒计时继续显示真实时间")
	main.shop_close_button.pressed.emit()
	await frames()
	await capture("transition-02-30")
	var paused_position: float = clock.frame_position
	var paused_progress: float = clock.progress
	main._on_campaign_pause_pressed()
	RunState.advance_campaign_time(30.0)
	check(clock.frame_position == paused_position and clock.progress == paused_progress and main.campaign_time_value.text == "02:30", "暂停同时冻结日月帧、圆弧与倒计时")
	main._on_campaign_pause_pressed()
	RunState.advance_campaign_time(150.0)
	await frames()
	check(clock.current_frame == 7 and clock.next_frame == 7 and is_zero_approx(clock.blend), "计时归零停留完整太阳帧")
	check(RunState.phase == RunState.Phase.RUN_WON and main.campaign_time_value.text == "00:00", "日月展示不改变主城存活胜利判定")
	await capture("dawn-00-00")
	main._on_reset_pressed()
	await frames()
	check(clock.current_frame == 0 and is_zero_approx(clock.progress) and main.campaign_time_value.text == "60:00", "重开恢复月牙、圆弧与60:00")
	await capture("reset-60-00")
	# 加速预览只改变展示值，不把预览播放当作自然60分钟试玩证据。
	if DisplayServer.get_name() != "headless":
		for index in range(15):
			var seconds: float = 300.0 * (1.0 - float(index) / 14.0)
			clock.set_remaining_time(seconds)
			main._on_campaign_time_changed(seconds)
			await frames()
			await capture("preview-%02d" % index)
		clock.set_remaining_time(3600.0)
		main._on_campaign_time_changed(3600.0)
	main.queue_free()
	get_tree().quit(failures)

func frames() -> void:
	for i in range(4):
		await get_tree().process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://.codex-temp/day-night-clock")
	DirAccess.make_dir_recursive_absolute(directory)
	playfield.get_texture().get_image().save_png(directory.path_join(label + ".png"))

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
