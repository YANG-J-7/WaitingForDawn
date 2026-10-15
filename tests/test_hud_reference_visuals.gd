extends Node
## 验证改版后卡面读取真实交易状态，且新增展示层不截获输入。
var main: Node
var playfield: SubViewport
var failures: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	playfield = SubViewport.new()
	playfield.size = Vector2i(960,540)
	playfield.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	playfield.gui_embed_subwindows = true
	add_child(playfield)
	main = preload("res://src/main/main.tscn").instantiate()
	playfield.add_child.call_deferred(main)
	await frames()
	await capture("boot-960x540")
	var icon_script = preload("res://src/gameplay/art/hud_icon.gd")
	var atlas_rect := Rect2(Vector2.ZERO,icon_script.SOURCE.get_size())
	for id in icon_script.REGIONS:
		check(atlas_rect.encloses(icon_script.REGIONS[id]),"图标区域在共享透明图集内：%s" % id)
	main.start_button.pressed.emit()
	for index in [0,1,3,4]:
		main.card_buttons[index].pressed.emit()
	main.ready_button.pressed.emit()
	main.wave_controller.set_process(false)
	main.set_process(false)
	for enemy in main.wave_controller.enemies:
		enemy.set_physics_process(false)
	main.farmer_manager.set_process(false)
	var elapsed: float = RunState.campaign_elapsed_seconds
	await click(main.campaign_pause_button.get_global_rect().get_center())
	await frames()
	check(get_tree().paused and main.hud_reference.pause_symbol.paused,"真实鼠标点击暂停，白色符号切换为继续")
	RunState.advance_campaign_time(30.0)
	check(RunState.campaign_elapsed_seconds == elapsed,"图形暂停按钮仍冻结真实有效时间")
	await capture("paused-960x540")
	await click(main.hud_reference.settings_button.get_global_rect().get_center())
	check(main.hud_reference.settings_panel.visible and get_tree().paused,"暂停时真实鼠标可打开设置且不误恢复对局")
	await capture("settings-paused-960x540")
	var settings_content: VBoxContainer = main.hud_reference.settings_panel.get_child(0)
	settings_content.get_child(settings_content.get_child_count()-1).pressed.emit()
	await frames()
	await click(main.campaign_pause_button.get_global_rect().get_center())
	await frames()
	check(not get_tree().paused and not main.hud_reference.pause_symbol.paused,"真实鼠标点击继续，符号恢复双竖条")
	RunState.damage_city(80)
	check(main.city_value.text == "520 / 600" and main.city_health_bar.value == 520,"主城受伤实时同步白色数值和细生命条")
	check(is_equal_approx(main.city_health_bar.value/main.city_health_bar.max_value,520.0/600.0),"生命条保持真实耐久比例")
	RunEconomy.add_resource(&"gold",24)
	main._on_battle_shop_button_pressed()
	main.battle_shop.offered_cards.assign(main.opening_draft.offered_cards)
	main._on_battle_shop_offers_changed()
	await frames()
	for button in main.card_buttons:
		var face: Control = button.get_node("ReferenceFace")
		check(face.visible and face.illustration != null,"六格卡面有独立建筑插画")
		check(face.mouse_filter == Control.MOUSE_FILTER_IGNORE,"展示层不截获购买输入")
	check(main.card_buttons[0].get_node("ReferenceFace").state_text == "购买","金币足够显示购买")
	main.card_buttons[0].pressed.emit()
	check(RunEconomy.amount(&"gold") == 18,"真实购买扣除6金币")
	check(main.card_buttons[0].get_node("ReferenceFace").state_text == "已售罄","购买成功即时显示售罄")
	main.refresh_button.pressed.emit()
	check(RunEconomy.amount(&"gold") == 16,"真实刷新扣除2金币")
	check(main.battle_shop.purchased_indices.is_empty(),"刷新恢复六格购买状态")
	main.battle_shop.offered_cards.assign(main.opening_draft.offered_cards)
	main._on_battle_shop_offers_changed()
	main.run_card_inventory.add_card(main.opening_draft.offered_cards[0],1)
	main._populate_battle_hand()
	main._on_battle_shop_offers_changed()
	await frames()
	var hand: HandCardSlot = main.hand_card_slots.values()[0]
	check(hand.reference_face.count == 3 and hand.reference_face.highlighted,"三张同星手牌角标和金边同步")
	check(main.card_buttons[0].get_node("ReferenceFace").count == 3,"商店持有数量同步手牌")
	for resolution in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1024,768)]:
		playfield.size = resolution
		await frames()
		var shop: Rect2 = main.day_setup_panel.get_global_rect()
		check(shop.end.y <= main.hand_bar.get_global_rect().position.y,"%s商店与手牌不重叠" % resolution)
		for button in main.card_buttons:
			check(shop.encloses(button.get_global_rect()),"%s六格在面板内" % resolution)
		var row: HBoxContainer = main.top_bar.get_child(main.top_bar.get_child_count()-1)
		check(row.get_global_rect().end.x <= resolution.x,"%s顶栏不越界" % resolution)
		var status: Rect2 = main.hud_reference.right_status.get_global_rect()
		check(main.top_bar.get_global_rect().encloses(status),"%s威胁主城控制区位于顶栏内" % resolution)
		check(status.position.x >= main.hud_reference.day_night_clock.get_global_rect().end.x,"%s右侧状态区不压住日月胶囊" % resolution)
		for button in [main.campaign_pause_button, main.hud_reference.settings_button]:
			check(button.size.x >= 44 and button.size.y >= 32 and status.encloses(button.get_global_rect()),"%s薄顶栏图形按钮可点击且不越界" % resolution)
		check(is_equal_approx(main.top_bar.size.y,32.0),"%s顶栏压至32逻辑像素" % resolution)
		await capture("shop-%dx%d" % [resolution.x,resolution.y])
	main.run_card_inventory.fuse_first_matching(&"lumber_camp",1)
	main._populate_battle_hand()
	main._on_battle_shop_offers_changed()
	check(main.card_buttons[0].get_node("ReferenceFace").count == 0,"合成后商店不计入高星手牌")
	RunEconomy.try_pay({&"gold":RunEconomy.amount(&"gold")})
	main._on_battle_shop_offers_changed()
	check(main.card_buttons[0].disabled and main.card_buttons[0].get_node("ReferenceFace").state_text == "金币不足","金币不足文案与购买禁用同步")
	main.shop_close_button.pressed.emit()
	main._on_reset_pressed()
	main.start_button.pressed.emit()
	await frames()
	check(not main.card_buttons[0].get_node("ReferenceFace").visible,"重开恢复免费选卡显示")
	check(main.card_buttons[0].get_theme_stylebox("normal") is StyleBoxFlat,"重开后免费卡面恢复可见背景")
	check(main.city_health_bar.value == 600 and not main.hud_reference.pause_symbol.paused,"重开恢复满耐久与暂停符号")
	main.queue_free()
	get_tree().quit(failures)

func frames() -> void:
	for i in range(4):
		await get_tree().process_frame

func click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	playfield.push_input(motion,true)
	await get_tree().process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		playfield.push_input(event,true)
	await frames()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	# 截图前移开指针，保存正常按钮外观，避免残留悬停态。
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100,120)
	motion.global_position = motion.position
	playfield.push_input(motion,true)
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://.codex-temp/hud-reference")
	DirAccess.make_dir_recursive_absolute(directory)
	playfield.get_texture().get_image().save_png(directory.path_join(label+".png"))

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)
