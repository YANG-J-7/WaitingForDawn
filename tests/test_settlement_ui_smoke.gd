extends Node

var main: Node
var failures: int = 0
var last_pointer: Vector2 = Vector2.ZERO
var playfield: SubViewport


func _ready() -> void:
	# 独立视口只接收本测试的引擎事件，避免桌面真实鼠标覆盖合成拖动坐标。
	playfield = SubViewport.new()
	playfield.size = Vector2i(960, 540)
	playfield.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(playfield)
	main = preload("res://src/main/main.tscn").instantiate()
	playfield.add_child.call_deferred(main)
	await get_tree().process_frame
	await click(main.start_button.get_global_rect().get_center())
	main.opening_draft.set_countdown_paused(true)
	for index in [0, 1, 3, 4]:
		await click(main.card_buttons[index].get_global_rect().get_center())
	check(not main.hand_bar.visible, "选卡阶段没有底部手牌")
	await capture("selection")
	await click(main.ready_button.get_global_rect().get_center())
	check(main.hand_bar.visible and main.hand_slots.get_child_count() == 4, "迎战后显示四张真实手牌")
	# 冻结战斗推进，单独观察输入和布局；不在生产代码加入作弊入口。
	main.wave_controller.set_process(false)
	for enemy in main.wave_controller.enemies:
		enemy.set_physics_process(false)
	main.farmer_manager.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var lumber: HandCardSlot = main.hand_card_slots[0]
	await drag(lumber.get_global_rect().get_center(), Vector2(190, 180))
	check(main.settlement_builder.building_count() == 1, "引擎鼠标拖动伐木卡生成建筑")
	check(main.run_card_inventory.card_count() == 3, "拖牌成功才消耗手牌")
	await click(main.train_farmer_button.get_global_rect().get_center())
	check(main.notice_panel.visible and main.notice_label.text.contains("人口已满"), "战斗中招募失败提示可见")
	check(main.train_farmer_button.size.y >= 44, "主城招募按钮至少44像素高")
	await capture("battle")
	await click(main.battle_shop_button.get_global_rect().get_center())
	check(main.battle_shop.active and not main.build_failure_panel.visible, "输入事件打开商店且没有旧提示遮挡")
	await capture("shop")
	await click(main.ready_button.get_global_rect().get_center())
	check(not main.battle_shop.active and main.hand_bar.visible, "输入事件关闭商店回到手牌")
	main.queue_free()
	get_tree().quit(failures)


func pointer(position: Vector2, pressed: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - last_pointer
	last_pointer = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	playfield.push_input(event, true)


func button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	playfield.push_input(event, true)


func click(position: Vector2) -> void:
	pointer(position)
	await get_tree().process_frame
	button(position, true)
	button(position, false)
	await get_tree().process_frame


func drag(origin: Vector2, target: Vector2) -> void:
	pointer(origin)
	button(origin, true)
	await get_tree().process_frame
	for step in range(1, 6):
		pointer(origin.lerp(target, float(step) / 5.0), true)
		await get_tree().process_frame
	button(target, false)
	await get_tree().process_frame


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path("res://.codex-temp/ui-settlement")
	DirAccess.make_dir_recursive_absolute(directory)
	playfield.get_texture().get_image().save_png(directory.path_join(label + ".png"))


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
