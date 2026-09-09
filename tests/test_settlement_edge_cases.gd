extends Node

const MAIN = preload("res://src/main/main.tscn")
const STONE = preload("res://src/data/cards/stone_mine.tres")
const HOUSE = preload("res://src/data/cards/house.tres")
const WOLF = preload("res://src/data/enemies/wolf.tres")
var failures: int = 0


func _ready() -> void:
	await run_checks()
	get_tree().quit(failures)


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func run_checks() -> void:
	_test_carried_job_change()
	var main = MAIN.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	main._on_start_pressed()
	main.opening_draft.set_countdown_paused(true)
	var manager: FarmerManager = main.farmer_manager
	manager.set_process(false)
	var builder: SettlementBuilder = main.settlement_builder
	for resource_id in RunEconomy.RESOURCE_IDS:
		RunEconomy.add_resource(resource_id, 2000)
	var stone: ResourceBuilding = builder.place_card_at(STONE, Vector2(770, 350))
	main.wave_economy.refresh_jobs(builder, main.arrow_tower, main.barracks)
	manager.advance(10)
	manager.advance(1.1)
	var carrier: FarmerAgent = manager.farmers[0]
	check(carrier.carried_amount == 2, "石矿农民采集两石后返回")
	var balance: int = RunEconomy.amount(&"stone")
	stone.apply_enemy_attack(9999, &"wolf")
	check(builder.building_count() == 0, "摧毁建筑移除建造记录")
	check(carrier.carried_amount == 2, "建筑摧毁仍保留已采集货物")
	manager.advance(10)
	check(RunEconomy.amount(&"stone") == balance + 4, "两名携货农民在建筑毁坏后仍可交付")
	check(main.wave_economy.job_order.is_empty(), "摧毁建筑移除岗位")
	check(builder.place_card_at(STONE, Vector2(770, 350)) != null, "摧毁后可以重建资源点")
	main.wave_economy.refresh_jobs(builder, main.arrow_tower, main.barracks)
	var victim: FarmerAgent = manager.farmers[0]
	var survivor: FarmerAgent = manager.farmers[1]
	manager.advance(10)
	manager.advance(1.1)
	var population: int = RunEconomy.current_population
	victim.apply_enemy_attack(999, &"wolf")
	check(RunEconomy.current_population == population - 1, "农民死亡只扣一人口")
	check(main.wave_economy.assigned_workers_for(&"stone_mine") == 1, "死亡扣除死者的岗位")
	check(survivor.job_id == &"stone_mine" and survivor.carried_amount == 2, "死亡不打乱幸存者岗位或货物")
	check(manager.active_farmers().size() == RunEconomy.current_population, "死亡后人口和实体一致")
	balance = RunEconomy.amount(&"stone")
	manager.advance(10)
	check(RunEconomy.amount(&"stone") == balance + 2, "死亡农民的货物不会到账，仅幸存者交付")
	var gold: int = RunEconomy.amount(&"gold")
	main._on_train_farmer_pressed()
	check(RunEconomy.current_population == 5 and RunEconomy.amount(&"gold") == gold - 10, "死亡空位可以补充一名农民")
	main._on_train_farmer_pressed()
	check(RunEconomy.amount(&"gold") == gold - 10, "人口满员失败不扣金币")
	check(main.status_label.text.contains("人口已满"), "满员生产提供明确提示")
	check(builder.place_card_at(HOUSE, Vector2(600, 128)) == null, "民屋完整占地不能越界")
	var house: ResourceBuilding = builder.place_card_at(HOUSE, Vector2(600, 175))
	check(house != null and RunEconomy.population_capacity == 7, "民屋增加两人口容量")
	RunEconomy.try_pay({&"gold": RunEconomy.amount(&"gold")})
	main._on_train_farmer_pressed()
	check(RunEconomy.current_population == 5, "金币不足不新增农民")
	check(main.status_label.text.contains("金币不足"), "金币不足生产提供提示")
	RunEconomy.add_resource(&"gold", 10000)
	main._on_train_farmer_pressed()
	house.apply_enemy_attack(9999, &"wolf")
	check(RunEconomy.current_population == 6 and RunEconomy.population_capacity == 5, "民屋毁坏只扣容量不杀农民")
	check(not RunEconomy.try_train_farmer(), "人口超额不能继续生产")
	check(not main._can_place_free_building(manager.farmers[2].global_position, 34), "不能在农民占位上建造")
	check(not main._can_place_free_building(Vector2(70, 220), 34), "箭塔完整占地不能越界")
	check(not main._can_place_free_building(Vector2(190, 180), 34), "防御建筑不能占用空闲树林资源点")
	_test_shop(main.battle_shop, true)
	_test_shop(main.interwave_draft, false)
	_test_route(main)
	main._on_reset_pressed()
	check(manager.active_farmers().is_empty() and builder.building_count() == 0, "重置清空实体和建筑")
	main._on_start_pressed()
	check(manager.active_farmers().size() == 5 and RunEconomy.population_capacity == 5, "新局恢复五农民五容量")
	main.queue_free()


func _test_carried_job_change() -> void:
	var farmer := FarmerAgent.new()
	var workplace := Node2D.new()
	add_child(workplace)
	add_child(farmer)
	farmer.configure(0, Vector2.ZERO)
	workplace.position = Vector2(160, 0)
	var deliveries: Array = []
	farmer.delivery_completed.connect(func(resource_id: StringName, amount: int): deliveries.append([resource_id, amount]))
	farmer.assign_job(&"lumber_camp", workplace, &"wood", 2)
	farmer.advance(10)
	farmer.advance(1.1)
	farmer.assign_job(&"gold_mine", workplace, &"gold", 1)
	check(farmer.carried_resource == &"wood" and farmer.carried_amount == 2, "携木换到金矿岗位后仍保留原货物")
	farmer.advance(10)
	check(deliveries == [[&"wood", 2]], "换岗后的首次交付仍是两木而非金币")
	farmer.advance(10)
	farmer.advance(1.1)
	check(farmer.carried_resource == &"gold" and farmer.carried_amount == 1, "交付旧货后按新岗位采集金币")
	farmer.clear_job()
	farmer.advance(10)
	check(deliveries == [[&"wood", 2], [&"gold", 1]], "撤销岗位仍交付已采集金币")
	farmer.advance(10)
	check(deliveries.size() == 2, "空闲农民不会重复交付旧货")
	farmer.queue_free()
	workplace.queue_free()


func _test_shop(shop: Node, battle: bool) -> void:
	if battle:
		shop.open_for_wave(4)
	else:
		shop.begin(4, 0)
	var initial: Array = shop.offered_cards.duplicate()
	shop.purchased_indices.assign([0, 1, 2, 3, 4])
	var seen_new: bool = false
	for attempt in range(20):
		check(shop.refresh(), "单个未购槽仍能付费刷新")
		if shop.offered_cards[5] not in initial:
			seen_new = true
	check(seen_new, "刷新可抽到原来六张之外的牌")
	check(shop.offered_cards[0] == initial[0], "刷新不改变已购买的牌")
	shop.reset()


func _test_route(main: Node) -> void:
	main.opening_draft.active = false
	RunState.start_current_wave()
	var controller: WaveController = main.wave_controller
	controller.set_process(false)
	controller.world_targets.clear()
	var enemy := EnemyActor.new()
	controller.add_child(enemy)
	enemy.configure(WOLF, Vector2(100, 270), Vector2(480, 270))
	enemy.set_physics_process(false)
	controller.enemies.append(enemy)
	var off_route := FarmerAgent.new()
	controller.add_child(off_route)
	off_route.configure(0, Vector2(480, 270))
	off_route.position = Vector2(180, 180)
	var near := FarmerAgent.new()
	controller.add_child(near)
	near.configure(1, Vector2(480, 270))
	near.position = Vector2(220, 270)
	var far := FarmerAgent.new()
	controller.add_child(far)
	far.configure(2, Vector2(480, 270))
	far.position = Vector2(330, 270)
	controller.set_world_targets([off_route, far, near])
	check(enemy.world_target == near, "沿路线选择近目标而非数组顺序或路线外目标")
	enemy.world_target_attack_requested.connect(controller._on_enemy_world_target_attack_requested)
	enemy.position = near.position - Vector2(5, 0)
	enemy.has_reached_target = true
	near.position.y -= 100
	enemy._physics_process(2)
	check(near.current_health == near.maximum_health, "农民离开近战范围不会受到远程伤害")
	controller._assign_defensive_targets()
	check(enemy.world_target != near, "农民离开进攻路线后解除锁定")
	enemy._resume_to_city()
	enemy.position = Vector2(100, 270)
	near.position = Vector2(220, 270)
	controller.set_world_targets([far, near])
	near.apply_enemy_attack(999, &"wolf")
	enemy._physics_process(0.01)
	controller._assign_defensive_targets()
	check(enemy.world_target == far, "目标死亡后继续攻击后续目标")
	enemy._resume_to_city()
	enemy.position = Vector2(370, 270)
	controller._assign_defensive_targets()
	check(enemy.attack_target_kind == &"city", "已越过目标不会回头")
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		enemy._resume_to_city()
		enemy.position = Vector2(480, 270) + direction * 130
		near.position = Vector2(480, 270) + direction * 80
		near.current_health = near.maximum_health
		near.visible = true
		controller.set_world_targets([near])
		check(enemy.world_target == near, "四方向均能识别沿途农民：%s" % direction)
	enemy._resume_to_city()
	enemy.position = Vector2(100, 270)
	near.position = Vector2(220, 270)
	far.position = Vector2(330, 270)
	controller.set_world_targets([far, near])
	check(controller.get_priority_target(Vector2(100, 270), 1000) == enemy, "箭塔索敌覆盖存活敌人")
	var nearer_enemy := EnemyActor.new()
	controller.add_child(nearer_enemy)
	nearer_enemy.configure(WOLF, Vector2(450, 270), Vector2(480, 270), 99)
	controller.enemies.append(nearer_enemy)
	nearer_enemy.set_physics_process(false)
	check(controller.get_priority_target(Vector2(100, 270), 1000) == nearer_enemy, "箭塔优先离主城最近的敌人而非出生序号")
	# 防御和人口建筑都通过同一个世界目标接口参与沿途受击。
	main.arrow_tower.visible = true
	main.arrow_tower.current_health = main.arrow_tower.maximum_health
	main.arrow_tower.position = Vector2(300, 270)
	controller.set_world_targets([main.arrow_tower])
	check(enemy.world_target == main.arrow_tower, "路线上的箭塔可以被攻击")
	main.arrow_tower.apply_enemy_attack(9999, &"wolf")
	check(not main.arrow_tower.is_attackable(), "箭塔摧毁后失去目标资格")
	var card_id: int = main.run_card_inventory.add_card(preload("res://src/data/cards/arrow_tower_card.tres"), 1)
	check(main._try_place_defense_card(card_id, Vector2(680, 270)), "摧毁后可消费新卡重建箭塔")
	check(main.arrow_tower.current_health == main.arrow_tower.maximum_health, "重建箭塔恢复完整生命")
	off_route.queue_free()
	near.queue_free()
	far.queue_free()
