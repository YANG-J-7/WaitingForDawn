extends Node

const MapLayout = preload("res://src/gameplay/buildings/map_layout.gd")

var failures: int = 0
var main: Node

func _ready() -> void:
	main = preload("res://src/main/main.tscn").instantiate()
	add_child.call_deferred(main)
	await get_tree().process_frame
	check(main.has_method("active_towers"), "支持多箭塔实例")
	check(main.has_method("active_barracks"), "支持多兵营实例")
	check(main.get_node_or_null("MapCamera") != null, "大地图有独立镜头")
	check(main.wave_controller.playable_bounds.size == Vector2(7056, 2880), "运行地图使用7056×2880视口比例地图")
	check(main.resource_sites.size() == 8, "新地图加载四处树林、两处石矿和两处铁矿")
	check(not MapLayout.is_buildable(Vector2(4200, 2200)+MapLayout.Definition.SOURCE_WORLD_ORIGIN, 24), "湖泊内部拒绝普通建筑")
	check(MapLayout.is_buildable(Vector2(800, 1000), 24), "中央草地保持可建造")
	main._on_start_pressed()
	main.opening_draft.active = false
	RunState.start_current_wave()
	main.day_setup_panel.hide()
	main.map_drop_surface.show()
	main.farmer_manager.set_process(false)
	for resource in RunEconomy.RESOURCE_IDS:
		RunEconomy.add_resource(resource, 10000)
	RunEconomy.change_population_capacity(30)
	for index in range(20):
		RunEconomy.try_train_farmer()
	_test_buildings()
	_test_camera()
	main._on_reset_pressed()
	check(main.active_towers().is_empty() and main.active_barracks().is_empty(), "重置清理所有防御实例")
	check(main.additional_towers.is_empty() and main.additional_barracks.is_empty(), "重置释放新增实体记录")
	check(main.wave_economy.job_targets.is_empty(), "重置清空独立岗位目标")
	check(main.map_camera.zoom.is_equal_approx(Vector2.ONE * .72), "重置恢复主城近景")
	check(main.resource_sites.all(func(site): return not site.is_occupied()), "重置释放所有资源点")
	main.queue_free()
	get_tree().quit(failures)

func _test_buildings() -> void:
	var tower = preload("res://src/data/cards/arrow_tower_card.tres")
	var camp = preload("res://src/data/cards/barracks.tres")
	for point in [Vector2(900, 900), Vector2(1008, 900)]:
		var id: int = main.run_card_inventory.add_card(tower, 2)
		check(main._try_place_defense_card(id, point), "独立卡片可重复建造箭塔")
	check(main.active_towers().size() == 2, "两座箭塔同时存活")
	for point in [Vector2(900, 1200), Vector2(900, 1350)]:
		var id: int = main.run_card_inventory.add_card(camp, 2)
		check(main._try_place_barracks_card(id, point), "独立卡片可重复建造兵营")
	check(main.active_barracks().size() == 2, "两座兵营同时存活")
	for building in main.active_barracks():
		check(building.active_guards().size() == 2, "每座兵营独立生成两名守卫")
	var seen: Dictionary = {}
	for job_id in main.wave_economy.job_order:
		seen[job_id] = true
	check(seen.size() == 4, "同类防御具有四个独立岗位")
	var cards: Array = [preload("res://src/data/cards/lumber_camp.tres"), preload("res://src/data/cards/stone_mine.tres"), preload("res://src/data/cards/iron_mine.tres")]
	for card in cards:
		var count: int = 0
		for site in main.resource_sites:
			if site.accepts(card) and count < 2:
				var id: int = main.run_card_inventory.add_card(card, 2)
				check(main._try_place_map_building_card(id, site.global_position), "资源地块允许多座同类建筑：" + card.display_name)
				count += 1
	var farm = preload("res://src/data/cards/farm.tres")
	for point in [Vector2(900, 1650), Vector2(1008, 1836)]:
		var farm_id: int = main.run_card_inventory.add_card(farm, 2)
		check(main._try_place_map_building_card(farm_id, point), "农场可在草地空地自由建造")
	check(main.settlement_builder.building_count() == 8, "三类资源点建筑及两座自由农场完成建造")
	check(main.wave_economy.job_order.size() == 12, "八座资源建筑各有独立岗位")
	var lumber_a: ResourceBuilding = main.settlement_builder.placed_buildings()[0]
	var lumber_b: ResourceBuilding = main.settlement_builder.placed_buildings()[1]
	check(not lumber_a.resource_site.art_visual.visible, "伐木场占用后隐藏独立树林素材")
	check(main.settlement_builder.placed_buildings().any(func(building): return building.definition.card_id == &"iron_mine" and building.definition.production_resource == &"iron"), "铁矿场岗位生产铁矿")
	var a_id: StringName = lumber_a.get_meta("job_id")
	var b_id: StringName = lumber_b.get_meta("job_id")
	main.wave_economy.unlock_for_planning()
	check(main.wave_economy.adjust_workers(a_id, -1), "可以只减少第一座伐木场岗位")
	check(lumber_a.assigned_workers == 1 and lumber_b.assigned_workers == 2, "同类资源建筑岗位不串联")
	main.farmer_manager.advance(100)
	main.farmer_manager.advance(1.1)
	var wood: int = RunEconomy.amount(&"wood")
	lumber_a.apply_enemy_attack(99999, &"wolf")
	check(lumber_a.resource_site.art_visual.visible, "伐木场销毁后恢复树林素材")
	check(main.wave_economy.job_targets.get(b_id) == lumber_b and lumber_b.assigned_workers == 2, "摧毁一座保留另一座资源岗位")
	main.farmer_manager.advance(100)
	check(RunEconomy.amount(&"wood") == wood + 6, "两座伐木场携货分别交付且销毁不中断旧货")
	var second_tower: ArrowTower = main.active_towers()[1]
	var second_id: StringName = second_tower.get_meta("job_id")
	main.arrow_tower.apply_enemy_attack(99999, &"wolf")
	check(second_tower.enabled and main.wave_economy.job_targets.get(second_id) == second_tower, "摧毁首塔不影响第二塔岗位与攻击启用")
	var other_camp: Barracks = main.active_barracks()[1]
	main.barracks.apply_enemy_attack(99999, &"wolf")
	check(other_camp.active_guards().size() == 2, "摧毁第一兵营不清除第二兵营守卫")
	var id: int = main.run_card_inventory.add_card(tower, 2)
	var balance: int = RunEconomy.amount(&"wood")
	check(not main._try_place_defense_card(id, second_tower.global_position), "重复建筑仍拒绝重叠")
	check(main.run_card_inventory.has_card(id) and RunEconomy.amount(&"wood") == balance, "非法位置不消耗卡片或材料")
	check(main._try_place_defense_card(id, Vector2(900, 1980)), "新地图草地允许合法建筑")
	check(not main._try_place_defense_card(id, Vector2(180, 650)), "同一库存卡不能重复使用")
	var footprint: Dictionary = main.placement_preview(tower, second_tower.global_position)
	check(not footprint.valid and footprint.radius == 24.0, "箭塔预览使用缩小后的实际碰撞半径")
	check(main.building_footprints().size() == 11, "占地预览包含主城与所有存活建筑")

func _test_camera() -> void:
	var camera = main.map_camera
	main._update_map_view_rect()
	var play_rect: Rect2 = main.map_view_rect()
	check(main.map_drop_surface.get_global_rect().is_equal_approx(play_rect), "地图交互层仅覆盖上下栏之间的可用区域")
	var hud_size: Vector2 = main.train_farmer_button.size
	var anchor := Vector2(420, 250)
	var world_before: Vector2 = camera.screen_to_world(anchor)
	camera.zoom_at(1.5, anchor)
	check(camera.screen_to_world(anchor).is_equal_approx(world_before), "缩放保持鼠标锚点的世界位置")
	check(main.train_farmer_button.size == hud_size, "缩放不改变HUD尺寸")
	camera.zoom_at(100, anchor)
	check(is_equal_approx(camera.zoom.x, 1.6), "放大有上限")
	camera.zoom_at(0.0001, anchor)
	var expected_fit_zoom: float = maxf(
		play_rect.size.x / MapLayout.BOUNDS.size.x,
		play_rect.size.y / MapLayout.BOUNDS.size.y
	)
	check(is_equal_approx(camera.zoom.x, expected_fit_zoom), "操作镜头最远按cover填满可用视口")
	camera.show_full_map()
	camera.pan_by(Vector2(40, 10))
	check(camera.position.is_equal_approx(MapLayout.BOUNDS.get_center()), "全图倍率下不能把地图边界拖出视口")
	var map_screen: Rect2 = camera.get_canvas_transform() * MapLayout.BOUNDS
	check(play_rect.grow(.01).encloses(map_screen), "完整地图落在中间视口内")
	check(map_screen.get_center().is_equal_approx(play_rect.get_center()), "全图以可用视口中心居中，保留等比留边")
	var left_press := InputEventMouseButton.new()
	left_press.button_index = MOUSE_BUTTON_LEFT
	left_press.pressed = true
	left_press.position = Vector2(420, 250)
	camera.handle_map_input(left_press)
	var left_drag := InputEventMouseMotion.new()
	left_drag.relative = Vector2(36, 12)
	camera._input(left_drag)
	var left_release := InputEventMouseButton.new()
	left_release.button_index = MOUSE_BUTTON_LEFT
	left_release.pressed = false
	camera._input(left_release)
	check(camera.last_mouse_pan_distance > camera.MOUSE_DRAG_THRESHOLD, "按住鼠标左键拖动地图并记录为拖拽")
	camera.zoom_at(1.5, anchor)
	var half_visible: Vector2 = play_rect.size / (camera.zoom * 2.0)
	var card = preload("res://src/data/cards/house.tres")
	var id: int = main.run_card_inventory.add_card(card, 2)
	# 原900,300落点已按可见岩面登记为崖壁，反变换测试改用左侧平原。
	var point := Vector2(1440, 1836)
	check(main.grid_map_model.can_place(point, Vector2i(2,2)), "镜头投放夹具位于可建草地")
	var screen: Vector2 = camera.get_canvas_transform() * point
	main.map_drop_surface._drop_data(screen - main.map_drop_surface.global_position, {"card_index": id, "card_instance_id": id, "card_id": &"house"})
	print("METRIC: 投放世界坐标=%s 屏幕坐标=%s 结果=%s" % [point, screen, main.setup_hint_label.text])
	check(not main.run_card_inventory.has_card(id), "平移缩放后的UI投放成功消费卡片")
	var snapped_point: Vector2 = main.grid_map_model.snap_footprint_center(point, Vector2i(2, 2))
	check(main.settlement_builder.placed_buildings().back().global_position.is_equal_approx(snapped_point), "UI投放反变换后吸附到准确网格中心")
	camera.pan_by(Vector2(100000, 100000))
	check(camera.position.is_equal_approx(MapLayout.BOUNDS.position + half_visible), "放大后平移最多到地图左上边界")

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
