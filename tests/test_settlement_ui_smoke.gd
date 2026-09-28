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
	await camera_inputs()
	var lumber: HandCardSlot = main.hand_card_slots[0]
	var forest_position: Vector2 = (main.get_node("ResourceSites/forest_02") as Node2D).global_position
	await drag(lumber.get_global_rect().get_center(), world_to_screen(forest_position))
	check(main.settlement_builder.building_count() == 1, "引擎鼠标拖动伐木卡生成建筑")
	check(main.run_card_inventory.card_count() == 3, "拖牌成功才消耗手牌")
	await click(world_to_screen(forest_position))
	check(main.building_worker_panel.visible and main.selected_job_id == &"lumber_camp", "真实鼠标点击地图建筑打开人口分配面板")
	check(main.building_worker_minus_button.size.x >= 44 and main.building_worker_plus_button.size.x >= 44, "建筑人口按钮满足44像素目标")
	check(main.building_worker_panel.get_global_rect().end.y <= main.hand_bar.get_global_rect().position.y, "建筑人口面板不会覆盖底部手牌")
	main.map_camera.zoom_at(1.5, Vector2(480, 270))
	await get_tree().process_frame
	var worker_panel_before_pan: Vector2 = main.building_worker_panel.position
	await mouse_pan(Vector2(540, 330), Vector2(580, 350))
	check(main.building_worker_panel.position != worker_panel_before_pan, "镜头平移后建筑人口面板继续跟随目标")
	check(main.building_worker_panel.get_global_rect().end.y <= main.hand_bar.get_global_rect().position.y, "镜头移动后建筑人口面板仍避让手牌")
	await capture("building-workers")
	await click(main.building_worker_close_button.get_global_rect().get_center())
	await click(main.train_farmer_button.get_global_rect().get_center())
	check(main.notice_panel.visible and main.notice_label.text.contains("人口已满"), "战斗中招募失败提示可见")
	check(main.train_farmer_button.size.y >= 44, "主城招募按钮至少44像素高")
	await capture("battle")
	await click(main.battle_shop_button.get_global_rect().get_center())
	check(main.battle_shop.active and not main.build_failure_panel.visible, "输入事件打开商店且没有旧提示遮挡")
	check(main.map_drop_surface.visible and main.hand_bar.visible, "商店展开时地图与底部手牌保持可见")
	await capture("shop")
	await click(main.shop_close_button.get_global_rect().get_center())
	check(not main.battle_shop.active and main.hand_bar.visible, "输入事件关闭商店回到手牌")
	var wall: HandCardSlot = main.hand_card_slots[3]
	await drag(wall.get_global_rect().get_center(), world_to_screen(Vector2(980, 1030)), true)
	check(main.placement_overlay.dragged_card == null, "拖牌结束后隐藏占地覆盖层")
	for _index in range(RunCardInventory.MAX_CARDS - main.run_card_inventory.card_count()):
		main.run_card_inventory.add_card(preload("res://src/data/cards/farm.tres"), 2)
	main._populate_battle_hand()
	await get_tree().process_frame
	var hand_scroll: ScrollContainer = main.get_node("HUD/HandBar/Margin/Content/HandScroll") as ScrollContainer
	check(main.hand_slots.get_child_count() == RunCardInventory.MAX_CARDS, "满手牌显示全部18张卡")
	check(hand_scroll.get_h_scroll_bar().max_value > hand_scroll.get_h_scroll_bar().page, "满手牌提供横向滚动而不互相遮挡")
	hand_scroll.scroll_horizontal = 0
	await get_tree().process_frame
	await click(main.hand_next_button.get_global_rect().get_center())
	check(hand_scroll.scroll_horizontal > 0, "右翻页按钮可浏览后续手牌")
	await click(main.hand_prev_button.get_global_rect().get_center())
	check(hand_scroll.scroll_horizontal == 0, "左翻页按钮可返回手牌起点")
	await capture("full-hand")
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


func world_to_screen(point: Vector2) -> Vector2:
	return main.map_camera.get_canvas_transform() * point


func drag(origin: Vector2, target: Vector2, inspect_footprints: bool = false) -> void:
	pointer(origin)
	button(origin, true)
	await get_tree().process_frame
	for step in range(1, 6):
		pointer(origin.lerp(target, float(step) / 5.0), true)
		await get_tree().process_frame
	if inspect_footprints:
		check(main.placement_overlay.dragged_card != null, "拖动建筑时启用占地覆盖层")
		check(main.building_footprints().size() == 2, "拖牌时包含主城与已建伐木场的实际占地")
		await capture("footprints")
	button(target, false)
	await get_tree().process_frame
	await get_tree().process_frame


func camera_inputs() -> void:
	var camera = main.map_camera
	var before: float = camera.zoom.x
	var event := InputEventMouseButton.new()
	event.position = Vector2(440, 250)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	playfield.push_input(event, true)
	await get_tree().process_frame
	check(camera.zoom.x > before, "真实滚轮事件放大地图")
	event.pressed = false
	playfield.push_input(event, true)
	await get_tree().process_frame
	var mouse_position_before: Vector2 = camera.position
	await mouse_pan(Vector2(360, 220), Vector2(410, 245))
	check(camera.position != mouse_position_before, "真实鼠标左键拖动平移地图")
	check(not main.building_worker_panel.visible, "鼠标拖动地图不会误开建筑岗位面板")
	var old_position: Vector2 = camera.position
	await touch(0, Vector2(400, 260), true)
	await finger_drag(0, Vector2(420, 260))
	check(camera.position != old_position, "真实单指滑动事件平移地图")
	await touch(1, Vector2(520, 260), true)
	before = camera.zoom.x
	await finger_drag(1, Vector2(570, 260))
	check(camera.zoom.x > before, "真实双指拉开事件放大地图")
	await finger_drag(1, Vector2(490, 260))
	check(camera.zoom.x < before, "真实双指合拢事件缩小地图")
	await touch(0, Vector2(420, 260), false)
	await touch(1, Vector2(490, 260), false)
	check(camera.touches.is_empty(), "手指释放清理镜头手势")
	camera.reset_view()
	for index in range(3):
		event.pressed = true
		playfield.push_input(event, true)
		await get_tree().process_frame
		event.pressed = false
		playfield.push_input(event, true)
		await get_tree().process_frame
	# 合成触控会留下模拟鼠标的按钮状态；显式释放以继续验证真实的鼠标拖牌路径。
	button(Vector2.ZERO, false)
	await get_tree().process_frame


func mouse_pan(origin: Vector2, target: Vector2) -> void:
	pointer(origin)
	button(origin, true)
	await get_tree().process_frame
	for step in range(1, 5):
		pointer(origin.lerp(target, float(step) / 4.0), true)
		await get_tree().process_frame
	button(target, false)
	await get_tree().process_frame


func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	playfield.push_input(event, true)
	await get_tree().process_frame


func finger_drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	playfield.push_input(event, true)
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
