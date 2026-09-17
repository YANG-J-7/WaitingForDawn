extends Node

var failures: int = 0
var main: Node

func _ready() -> void:
	main = preload("res://src/main/main.tscn").instantiate()
	add_child.call_deferred(main)
	await get_tree().process_frame
	check(main.has_method("active_towers"), "支持多箭塔实例")
	check(main.has_method("active_barracks"), "支持多兵营实例")
	check(main.get_node_or_null("MapCamera") != null, "大地图有独立镜头")
	check(main.wave_controller.playable_bounds.size == Vector2(1400, 600), "地图扩大为1400×600")
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
	check(main.map_camera.zoom.is_equal_approx(Vector2.ONE * 0.48), "重置恢复远景")
	check(main.resource_sites.all(func(site): return not site.is_occupied()), "重置释放所有资源点")
	main.queue_free()
	get_tree().quit(failures)

func _test_buildings() -> void:
	var tower = preload("res://src/data/cards/arrow_tower_card.tres")
	var camp = preload("res://src/data/cards/barracks.tres")
	for point in [Vector2(300, 90), Vector2(370, 90)]:
		var id: int = main.run_card_inventory.add_card(tower, 2)
		check(main._try_place_defense_card(id, point), "独立卡片可重复建造箭塔")
	check(main.active_towers().size() == 2, "两座箭塔同时存活")
	for point in [Vector2(620, 360), Vector2(700, 450)]:
		var id: int = main.run_card_inventory.add_card(camp, 2)
		check(main._try_place_barracks_card(id, point), "独立卡片可重复建造兵营")
	check(main.active_barracks().size() == 2, "两座兵营同时存活")
	for building in main.active_barracks():
		check(building.active_guards().size() == 2, "每座兵营独立生成两名守卫")
	var seen: Dictionary = {}
	for job_id in main.wave_economy.job_order:
		seen[job_id] = true
	check(seen.size() == 4, "同类防御具有四个独立岗位")
	var cards: Array = [preload("res://src/data/cards/lumber_camp.tres"), preload("res://src/data/cards/farm.tres"), preload("res://src/data/cards/gold_mine.tres"), preload("res://src/data/cards/stone_mine.tres")]
	for card in cards:
		var count: int = 0
		for site in main.resource_sites:
			if site.accepts(card) and count < 2:
				var id: int = main.run_card_inventory.add_card(card, 2)
				check(main._try_place_map_building_card(id, site.global_position), "资源地块允许多座同类建筑：" + card.display_name)
				count += 1
	check(main.settlement_builder.building_count() == 8, "四类资源建筑各有两座")
	check(main.wave_economy.job_order.size() == 12, "八座资源建筑各有独立岗位")
	var lumber_a: ResourceBuilding = main.settlement_builder.placed_buildings()[0]
	var lumber_b: ResourceBuilding = main.settlement_builder.placed_buildings()[1]
	var a_id: StringName = lumber_a.get_meta("job_id")
	var b_id: StringName = lumber_b.get_meta("job_id")
	main.wave_economy.unlock_for_planning()
	check(main.wave_economy.adjust_workers(a_id, -1), "可以只减少第一座伐木场岗位")
	check(lumber_a.assigned_workers == 1 and lumber_b.assigned_workers == 2, "同类资源建筑岗位不串联")
	main.farmer_manager.advance(100)
	main.farmer_manager.advance(1.1)
	var wood: int = RunEconomy.amount(&"wood")
	lumber_a.apply_enemy_attack(99999, &"wolf")
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
	check(main._try_place_defense_card(id, Vector2(-140, 270)), "大地图负坐标允许合法建筑")
	check(not main._try_place_defense_card(id, Vector2(-140, 400)), "同一库存卡不能重复使用")
	var footprint: Dictionary = main.placement_preview(tower, second_tower.global_position)
	check(not footprint.valid and footprint.radius == 24.0, "箭塔预览使用缩小后的实际碰撞半径")
	check(main.building_footprints().size() == 11, "占地预览包含主城与所有存活建筑")

func _test_camera() -> void:
	var camera = main.map_camera
	var hud_size: Vector2 = main.train_farmer_button.size
	var anchor := Vector2(420, 250)
	var world_before: Vector2 = camera.screen_to_world(anchor)
	camera.zoom_at(1.5, anchor)
	check(camera.screen_to_world(anchor).is_equal_approx(world_before), "缩放保持鼠标锚点的世界位置")
	check(main.train_farmer_button.size == hud_size, "缩放不改变HUD尺寸")
	camera.zoom_at(100, anchor)
	check(is_equal_approx(camera.zoom.x, 1.6), "放大有上限")
	camera.zoom_at(0.0001, anchor)
	check(is_equal_approx(camera.zoom.x, 0.35), "缩小有下限")
	camera.reset_view()
	camera.pan_by(Vector2(40, 10))
	check(not camera.position.is_equal_approx(Vector2(480, 270)), "拖动可移动地图视野")
	camera.zoom_at(1.5, anchor)
	var card = preload("res://src/data/cards/house.tres")
	var id: int = main.run_card_inventory.add_card(card, 2)
	var point := Vector2(900, 300)
	var screen: Vector2 = camera.get_canvas_transform() * point
	main.map_drop_surface._drop_data(screen - main.map_drop_surface.global_position, {"card_index": id, "card_instance_id": id, "card_id": &"house"})
	check(not main.run_card_inventory.has_card(id), "平移缩放后的UI投放成功消费卡片")
	check(main.settlement_builder.placed_buildings().back().global_position.is_equal_approx(point), "UI投放反变换回准确世界坐标")
	camera.pan_by(Vector2(100000, 100000))
	check(camera.position == Vector2(-220, -30), "平移不能无限离开地图")

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
