extends Node2D

const MapLayout = preload("res://src/gameplay/buildings/map_layout.gd")
const MapCameraScript = preload("res://src/gameplay/buildings/map_camera.gd")
const OverlayScript = preload("res://src/gameplay/buildings/placement_overlay.gd")
var map_camera: Camera2D
var placement_overlay: Node2D
var additional_towers: Array[ArrowTower] = []
var additional_barracks: Array[Barracks] = []

const COLOR_NIGHT := Color("101827")
const COLOR_GRID := Color("1b2b3d")
const COLOR_PATH := Color("37475b")
const COLOR_CITY := Color("e3a94b")

@onready var phase_value: Label = %PhaseValue
@onready var wave_value: Label = %WaveValue
@onready var city_value: Label = %CityValue
@onready var enemy_value: Label = %EnemyValue
@onready var status_label: Label = %StatusLabel
@onready var bottom_panel: PanelContainer = %BottomPanel
@onready var start_button: Button = %StartButton
@onready var reset_button: Button = %ResetButton
@onready var failure_panel: PanelContainer = %FailurePanel
@onready var failure_reset_button: Button = %FailureResetButton
@onready var build_failure_panel: PanelContainer = %BuildFailurePanel
@onready var build_failure_detail: Label = $HUD/BuildFailurePanel/Margin/Content/Detail
@onready var build_failure_close_button: Button = $HUD/BuildFailurePanel/Margin/Content/CloseButton
@onready var wave_controller: WaveController = $WaveController
@onready var opening_draft: OpeningDraft = $OpeningDraft
@onready var run_card_inventory: RunCardInventory = $RunCardInventory
@onready var interwave_draft: InterwaveDraft = $InterwaveDraft
@onready var battle_shop: BattleShop = $BattleShop
@onready var settlement_builder: SettlementBuilder = $SettlementBuilder
@onready var wave_economy: WaveEconomy = $WaveEconomy
@onready var arrow_tower: ArrowTower = $ArrowTower
@onready var wall_manager: WallManager = $WallManager
@onready var barracks: Barracks = $Barracks
@onready var day_setup_panel: PanelContainer = %DaySetupPanel
@onready var day_title: Label = %DayTitle
@onready var timer_label: Label = %TimerLabel
@onready var selection_label: Label = %SelectionLabel
@onready var card_grid: GridContainer = %CardGrid
@onready var setup_hint_label: Label = %SetupHintLabel
@onready var ready_button: Button = %ReadyButton
@onready var refresh_button: Button = %RefreshButton
@onready var pause_timer_button: Button = %PauseTimerButton
@onready var hand_bar: PanelContainer = %HandBar
@onready var hand_label: Label = %HandLabel
@onready var hand_empty_hint: Label = %HandEmptyHint
@onready var hand_slots: HBoxContainer = %HandSlots
@onready var job_rows: HBoxContainer = %JobRows
@onready var job_empty_hint: Label = %JobEmptyHint
@onready var job_summary_label: Label = %JobSummaryLabel
@onready var auto_assign_button: Button = %AutoAssignButton
@onready var defense_slot_button: Button = %DefenseSlotButton
@onready var barrier_slot_button: CardDropSlot = %BarrierSlotButton
@onready var barracks_slot_button: CardDropSlot = %BarracksSlotButton
@onready var map_drop_surface: MapDropSurface = %MapDropSurface
@onready var battle_shop_button: Button = %BattleShopButton
@onready var resource_sites_root: Node2D = $ResourceSites
@onready var farmer_manager: FarmerManager = $FarmerManager
@onready var train_farmer_button: Button = %TrainFarmerButton
@onready var wood_value: Label = %WoodValue
@onready var food_value: Label = %FoodValue
@onready var stone_value: Label = %StoneValue
@onready var iron_value: Label = %IronValue
@onready var gold_value: Label = %GoldValue
@onready var population_value: Label = %PopulationValue
@onready var notice_panel: PanelContainer = $HUD/NoticePanel
@onready var notice_label: Label = $HUD/NoticePanel/Message

var card_buttons: Array[Button] = []
var hand_card_slots: Dictionary = {}
var settlement_slot_buttons: Array[CardDropSlot] = []
var pending_resource_card_index: int = -1
var last_settlement_summary: String = ""
var job_value_labels: Dictionary = {}
var job_minus_buttons: Dictionary = {}
var job_plus_buttons: Dictionary = {}
var zero_purchase_warning_shown: bool = false
var resource_sites: Array[ResourceSite] = []
var notice_seconds: float = 0.0


func _ready() -> void:
	wave_controller.playable_bounds = MapLayout.BOUNDS
	settlement_builder.build_bounds = MapLayout.BOUNDS
	wall_manager.build_bounds = MapLayout.BOUNDS
	barracks.build_bounds = MapLayout.BOUNDS
	farmer_manager.economy = wave_economy
	wave_economy.additional_towers = additional_towers
	wave_economy.additional_barracks = additional_barracks
	wave_controller.additional_barracks = additional_barracks
	map_camera = MapCameraScript.new()
	map_camera.name = "MapCamera"
	add_child(map_camera)
	map_camera.surface = map_drop_surface
	map_drop_surface.screen_to_world = map_camera.screen_to_world
	map_drop_surface.gui_input.connect(map_camera.handle_map_input)
	placement_overlay = OverlayScript.new()
	placement_overlay.main = self
	placement_overlay.z_index = 100
	add_child(placement_overlay)
	# 保留原四个资源点，扩展区域为每种资源增加两处可建造地块。
	for index in range(4):
		var original: ResourceSite = resource_sites_root.get_child(index)
		for offset in [Vector2(-230 if index < 2 else 230, 0), Vector2(0, -170 if index % 2 == 0 else 170)]:
			var site := ResourceSite.new()
			site.site_type = original.site_type
			site.display_name = original.display_name
			site.site_color = original.site_color
			site.position = original.position + offset
			resource_sites_root.add_child(site)
	for child in resource_sites_root.get_children():
		if child is ResourceSite:
			resource_sites.append(child as ResourceSite)
	settlement_builder.set_resource_sites(resource_sites)
	RunState.phase_changed.connect(_on_state_changed)
	RunState.wave_changed.connect(_on_wave_changed)
	RunState.city_health_changed.connect(_on_city_health_changed)
	start_button.pressed.connect(_on_start_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	failure_reset_button.pressed.connect(_on_reset_pressed)
	build_failure_close_button.pressed.connect(_on_build_failure_close_pressed)
	ready_button.pressed.connect(_on_ready_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	pause_timer_button.pressed.connect(_on_pause_timer_pressed)
	auto_assign_button.pressed.connect(_on_auto_assign_pressed)
	defense_slot_button.pressed.connect(_on_defense_slot_pressed)
	barracks_slot_button.pressed.connect(_on_barracks_slot_pressed)
	barracks_slot_button.card_dropped.connect(_on_barracks_card_dropped)
	map_drop_surface.card_dropped.connect(_on_map_card_dropped)
	battle_shop_button.pressed.connect(_on_battle_shop_button_pressed)
	train_farmer_button.pressed.connect(_on_train_farmer_pressed)
	settlement_slot_buttons = [%SettlementSlot0, %SettlementSlot1, %SettlementSlot2]
	for slot_index in range(settlement_slot_buttons.size()):
		settlement_slot_buttons[slot_index].pressed.connect(
			_on_settlement_slot_pressed.bind(slot_index)
		)
		settlement_slot_buttons[slot_index].card_dropped.connect(
			_on_resource_card_dropped.bind(slot_index)
		)
	(defense_slot_button as CardDropSlot).card_dropped.connect(_on_defense_card_dropped)
	wall_manager.walls_changed.connect(_on_walls_changed)
	wall_manager.wall_destroyed.connect(_on_wall_destroyed)
	battle_shop.offers_changed.connect(_on_battle_shop_offers_changed)
	barracks.guard_roster_changed.connect(_on_guard_roster_changed)
	wave_controller.set_barrier_walls([])
	wave_controller.set_barracks(barracks)
	farmer_manager.configure(wave_controller.city_target_position, settlement_builder, arrow_tower, barracks)
	farmer_manager.delivery_completed.connect(_on_farmer_delivery_completed)
	farmer_manager.worker_lost.connect(wave_economy.remove_lost_worker)
	wave_economy.use_farmer_logistics = true
	wave_controller.enemy_count_changed.connect(_on_enemy_count_changed)
	wave_controller.wave_cleared.connect(_on_wave_cleared)
	settlement_builder.building_placed.connect(_on_building_placed)
	settlement_builder.building_placed_at.connect(_on_building_placed_at)
	settlement_builder.building_destroyed.connect(_on_building_destroyed)
	farmer_manager.roster_changed.connect(_on_farmer_roster_changed)
	arrow_tower.destroyed.connect(_on_world_defense_destroyed)
	barracks.destroyed.connect(_on_world_defense_destroyed)
	opening_draft.time_changed.connect(_on_draft_time_changed)
	opening_draft.countdown_pause_changed.connect(_on_countdown_pause_changed)
	opening_draft.selection_changed.connect(_on_draft_selection_changed)
	opening_draft.setup_finished.connect(_on_setup_finished)
	interwave_draft.selection_changed.connect(_on_interwave_selection_changed)
	interwave_draft.selection_finished.connect(_on_interwave_selection_finished)
	run_card_inventory.inventory_changed.connect(_on_inventory_changed)
	RunEconomy.resources_changed.connect(_on_resources_changed)
	wave_economy.workers_assigned.connect(_on_workers_assigned)
	wave_economy.jobs_changed.connect(_on_jobs_changed)
	wave_economy.assignments_changed.connect(_on_assignments_changed)
	_create_card_buttons()
	_remove_arrow_tower()
	_reset_walls()
	_reset_barracks()
	_reset_settlement_slots()
	RunEconomy.clear()
	RunState.reset_to_boot()
	_refresh_all_labels()
	_refresh_world_targets()
	queue_redraw()


func _process(delta: float) -> void:
	notice_seconds = maxf(0.0, notice_seconds - delta)
	notice_panel.visible = notice_seconds > 0.0 and not day_setup_panel.visible and not failure_panel.visible and not build_failure_panel.visible
	var payload: Variant = get_viewport().gui_get_drag_data()
	var card: OpeningCardDefinition = null
	if payload is Dictionary:
		card = _card_for_play_ref(int(payload.get("card_instance_id", -1)))
	for site in resource_sites:
		site.set_highlighted(card != null and site.accepts(card))
	if placement_overlay.dragged_card != card or card != null:
		placement_overlay.dragged_card = card
		placement_overlay.queue_redraw()


func _show_notice(message: String) -> void:
	status_label.text = message
	setup_hint_label.text = message
	notice_label.text = message
	notice_seconds = 4.0
	notice_panel.visible = not day_setup_panel.visible and not build_failure_panel.visible


func _draw() -> void:
	draw_rect(MapLayout.BOUNDS.grow(2000), COLOR_NIGHT)
	draw_rect(MapLayout.BOUNDS, Color("142333"))
	for x in range(int(MapLayout.BOUNDS.position.x), int(MapLayout.BOUNDS.end.x) + 1, 40):
		draw_line(Vector2(x, MapLayout.BOUNDS.position.y), Vector2(x, MapLayout.BOUNDS.end.y), COLOR_GRID, 1.0)
	for y in range(int(MapLayout.BOUNDS.position.y), int(MapLayout.BOUNDS.end.y) + 1, 40):
		draw_line(Vector2(MapLayout.BOUNDS.position.x, y), Vector2(MapLayout.BOUNDS.end.x, y), COLOR_GRID, 1.0)
	draw_rect(MapLayout.BOUNDS, Color("527078"), false, 3.0)

	var city_position := wave_controller.city_target_position
	for edge_point in [Vector2(-220, 270), Vector2(1180, 270), Vector2(480, -30), Vector2(480, 570)]:
		draw_line(edge_point, city_position, Color(COLOR_PATH, 0.38), 20.0)
	draw_circle(city_position, MapLayout.CITY_RADIUS, COLOR_CITY)
	draw_circle(city_position, 42.0, COLOR_CITY.darkened(0.18))
	draw_string(ThemeDB.fallback_font, city_position + Vector2(-24, 7), "主城", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)


func _on_start_pressed() -> void:
	if RunState.phase != RunState.Phase.BOOT:
		return
	RunState.begin_new_run()
	RunEconomy.begin_run()
	farmer_manager.begin_run(RunEconomy.current_population)
	opening_draft.begin()
	_configure_opening_setup_panel()
	day_setup_panel.visible = true
	hand_bar.visible = false
	bottom_panel.visible = false
	defense_slot_button.visible = false
	barrier_slot_button.visible = false
	barracks_slot_button.visible = false
	for slot_button in settlement_slot_buttons:
		slot_button.visible = false
	status_label.text = "白天布防开始：免费选择4张卡。"
	start_button.text = "白天布防中"
	start_button.disabled = true


func _on_reset_pressed() -> void:
	map_camera.reset_view()
	wave_controller.reset_wave()
	opening_draft.reset()
	interwave_draft.reset()
	battle_shop.reset()
	run_card_inventory.reset()
	wave_economy.reset(settlement_builder)
	farmer_manager.reset()
	for tower in additional_towers:
		tower.free()
	additional_towers.clear()
	for camp in additional_barracks:
		camp.free()
	additional_barracks.clear()
	settlement_builder.reset_buildings()
	RunEconomy.clear()
	arrow_tower.reset_statistics()
	_remove_arrow_tower()
	_reset_walls()
	_reset_barracks()
	_reset_settlement_slots()
	RunState.reset_to_boot()
	status_label.text = "已重置灰盒状态。"
	start_button.text = "开始灰盒对局"
	start_button.disabled = false
	failure_panel.visible = false
	build_failure_panel.visible = false
	_refresh_world_targets()
	day_setup_panel.visible = false
	hand_bar.visible = false
	bottom_panel.visible = true
	defense_slot_button.visible = false
	barrier_slot_button.visible = false
	barracks_slot_button.visible = false
	map_drop_surface.visible = false
	battle_shop_button.visible = false
	battle_shop_button.text = "战斗商店"
	train_farmer_button.visible = false
	notice_seconds = 0.0
	notice_panel.visible = false
	last_settlement_summary = ""
	zero_purchase_warning_shown = false
	for slot_button in settlement_slot_buttons:
		slot_button.visible = false


func _on_state_changed(_phase: int) -> void:
	phase_value.text = RunState.phase_name()
	train_farmer_button.visible = RunState.phase in [RunState.Phase.DAY_SETUP, RunState.Phase.WAVE_COMBAT, RunState.Phase.WAVE_RESULT]
	if RunState.phase in [RunState.Phase.RUN_LOST, RunState.Phase.RUN_WON]:
		day_setup_panel.visible = false
		build_failure_panel.visible = false
		_set_hand_interaction_enabled(false)
		hand_bar.visible = false
		bottom_panel.visible = true
		defense_slot_button.visible = false
		barrier_slot_button.visible = false
		barracks_slot_button.visible = false
		map_drop_surface.visible = false
		battle_shop_button.visible = false
		battle_shop_button.text = "战斗商店"
		battle_shop.close()
		for slot_button in settlement_slot_buttons:
			slot_button.visible = false
		var won: bool = RunState.phase == RunState.Phase.RUN_WON
		status_label.text = "十波守城成功，本局胜利！" if won else "主城已被摧毁，本局失败。"
		var result_title: Label = $HUD/FailurePanel/Margin/Content/Title
		result_title.text = "黎明到来，防守胜利！" if won else "主城已被摧毁"
		result_title.add_theme_color_override("font_color", Color("9ad58b") if won else Color("e64d59"))
		$HUD/FailurePanel/Margin/Content/Detail.text = (
			"已守住全部10波｜主城耐久 %d" % RunState.city_health
			if won else "第%d波防守失败" % RunState.current_wave
		)
		failure_panel.visible = true
		start_button.text = "本局已结束"
		start_button.disabled = true
	elif RunState.phase == RunState.Phase.WAVE_RESULT:
		_set_hand_interaction_enabled(false)
		hand_bar.visible = false
		bottom_panel.visible = true
		defense_slot_button.visible = false
		barrier_slot_button.visible = false
		barracks_slot_button.visible = false
		map_drop_surface.visible = false
		battle_shop_button.visible = false
		battle_shop_button.text = "战斗商店"
		battle_shop.close()
		for slot_button in settlement_slot_buttons:
			slot_button.visible = false
		status_label.text = "第%d波已清空。%s" % [RunState.current_wave - 1, last_settlement_summary]
		start_button.disabled = true
		if RunState.current_wave >= 2 and RunState.current_wave <= RunState.LAST_WAVE:
			_begin_interwave_shop()
		else:
			_configure_interwave_job_panel()


func _on_wave_changed(wave_index: int) -> void:
	wave_value.text = "%d / %d" % [wave_index, RunState.LAST_WAVE]


func _on_city_health_changed(current_health: int, maximum_health: int) -> void:
	city_value.text = "%d / %d" % [current_health, maximum_health]


func _on_enemy_count_changed(active_count: int, total_spawned: int) -> void:
	enemy_value.text = "%d / %d" % [active_count, total_spawned]


func _on_wave_cleared(wave_index: int) -> void:
	if wave_economy.settle_wave(wave_index, settlement_builder):
		last_settlement_summary = wave_economy.last_summary
	wave_economy.unlock_for_planning()
	status_label.text = "第%d波已清空。%s" % [wave_index, last_settlement_summary]


func _on_ready_pressed() -> void:
	if battle_shop.active:
		_close_battle_shop()
		return
	if interwave_draft.active:
		if (
			interwave_draft.is_purchase_mode()
			and interwave_draft.purchased_indices.is_empty()
			and not zero_purchase_warning_shown
		):
			zero_purchase_warning_shown = true
			setup_hint_label.text = "本波尚未购买卡牌；再次点击迎战确认承担风险。"
			return
		if not interwave_draft.finish():
			setup_hint_label.text = "请先完成当前商店要求。"
		return
	if not opening_draft.finish(false):
		setup_hint_label.text = "请选满4张，并至少包含1张可造成伤害的卡牌。"


func _on_pause_timer_pressed() -> void:
	opening_draft.set_countdown_paused(not opening_draft.countdown_paused)


func _on_refresh_pressed() -> void:
	if battle_shop.active:
		var battle_cost: int = battle_shop.current_refresh_cost()
		if not battle_shop.refresh():
			setup_hint_label.text = "%s 牌面、金币与库存保持不变。" % battle_shop.last_error
			return
		setup_hint_label.text = "战斗继续：已花费%d金币刷新未购买牌。" % battle_cost
		return
	if not interwave_draft.active:
		return
	var cost: int = interwave_draft.current_refresh_cost()
	if not interwave_draft.refresh():
		setup_hint_label.text = "%s 牌面与库存保持不变。" % interwave_draft.last_error
		return
	setup_hint_label.text = "已花费%d金币刷新未选牌；已选免费牌和额度保持不变。" % cost


func _on_countdown_pause_changed(is_paused: bool) -> void:
	pause_timer_button.text = "继续计时" if is_paused else "暂停计时"
	timer_label.text = (
		"计时已暂停" if is_paused
		else "剩余 %d 秒" % int(ceil(opening_draft.seconds_remaining))
	)


func _on_card_button_pressed(card_index: int) -> void:
	if battle_shop.active:
		_on_battle_shop_card_pressed(card_index)
		return
	if interwave_draft.active:
		_on_interwave_card_pressed(card_index)
		return
	if opening_draft.is_card_locked(card_index):
		setup_hint_label.text = "这张卡已经建造，不能重复使用。"
		return
	var card: OpeningCardDefinition = opening_draft.offered_cards[card_index]
	if (
		card_index in opening_draft.selected_indices
		and card.category == "resource"
		and pending_resource_card_index != card_index
	):
		pending_resource_card_index = card_index
		setup_hint_label.text = "已选择%s；继续选满4张，迎战后从底部手牌部署。" % card.display_name
		return
	if not opening_draft.toggle_card(card_index):
		setup_hint_label.text = "最多只能选择4张；可先取消一张。"
		return
	if card_index in opening_draft.selected_indices and card.category == "resource":
		pending_resource_card_index = card_index
		setup_hint_label.text = "已选择%s；继续选满4张，迎战后从底部手牌部署。" % card.display_name
	elif pending_resource_card_index == card_index:
		pending_resource_card_index = -1
	if not opening_draft.is_card_selected(&"arrow_tower"):
		_remove_arrow_tower()
	if card.category != "resource":
		setup_hint_label.text = "已选择该卡；选满4张并迎战后，底部手牌栏才会出现。"


func _on_defense_slot_pressed() -> void:
	if not _card_play_allowed():
		return
	var arrow_card_index: int = -1
	if opening_draft.active:
		if opening_draft.is_card_selected(&"arrow_tower"):
			arrow_card_index = opening_draft.offered_cards.find(_card_by_id(&"arrow_tower"))
	else:
		arrow_card_index = run_card_inventory.first_instance_for_card(&"arrow_tower")
	if arrow_card_index < 0:
		setup_hint_label.text = "需要先选择箭塔卡。"
		return
	_try_place_defense_card(arrow_card_index)


func _on_defense_card_dropped(card_index: int) -> void:
	_try_place_defense_card(card_index)


func _on_map_card_dropped(card_index: int, map_position: Vector2) -> void:
	var card: OpeningCardDefinition = _card_for_play_ref(card_index)
	if card == null:
		return
	match card.card_id:
		&"wall":
			_try_place_wall_card(card_index, map_position)
		&"arrow_tower":
			_try_place_defense_card(card_index, map_position)
		&"barracks":
			_try_place_barracks_card(card_index, map_position)
		_:
			if card.category in ["resource", "population"]:
				_try_place_map_building_card(card_index, map_position)
	_show_notice(setup_hint_label.text)


func _on_barracks_slot_pressed() -> void:
	if not _card_play_allowed():
		return
	var barracks_card_index: int = run_card_inventory.first_instance_for_card(&"barracks")
	if barracks_card_index < 0:
		setup_hint_label.text = "需要先获得兵营卡。"
		return
	_try_place_barracks_card(barracks_card_index)


func _on_barracks_card_dropped(card_index: int) -> void:
	_try_place_barracks_card(card_index)


func _try_place_barracks_card(card_index: int, map_position: Vector2 = Vector2.INF) -> bool:
	if not _card_play_allowed() or card_index < 0:
		return false
	var barracks_card: OpeningCardDefinition = _card_for_play_ref(card_index)
	if barracks_card == null:
		return false
	if barracks_card.card_id != &"barracks":
		setup_hint_label.text = "这张卡不能放入当前兵营格。"
		return false
	var target_position: Vector2 = barracks.global_position if map_position == Vector2.INF else map_position
	if not _can_place_free_building(target_position, MapLayout.BARRACKS_RADIUS):
		return false
	if not RunEconomy.can_pay(barracks_card.build_costs):
		_show_build_failure(barracks_card)
		setup_hint_label.text = "建造兵营的资源不足，已显示缺口。"
		return false
	if not RunEconomy.try_pay(barracks_card.build_costs):
		_show_build_failure(barracks_card)
		return false
	var placed_camp: Barracks = barracks
	if placed_camp.is_built():
		placed_camp = preload("res://src/gameplay/defenses/barracks.tscn").instantiate()
		add_child(placed_camp)
		placed_camp.build_bounds = MapLayout.BOUNDS
		additional_barracks.append(placed_camp)
		placed_camp.destroyed.connect(_on_world_defense_destroyed)
		placed_camp.guard_roster_changed.connect(wave_controller._on_guard_roster_changed)
	placed_camp.global_position = target_position
	placed_camp.build(barracks_card)
	_consume_played_card(card_index, barracks_card)
	wave_economy.refresh_jobs(settlement_builder, arrow_tower, barracks)
	wave_controller.set_barracks(barracks)
	_refresh_world_targets()
	barracks_slot_button.disabled = true
	setup_hint_label.text = "兵营已在空地部署；每名上岗人口生成一名守卫。"
	build_failure_panel.visible = false
	return true


func _try_place_wall_card(card_index: int, map_position: Vector2) -> bool:
	if not _card_play_allowed() or card_index < 0:
		return false
	var wall_card: OpeningCardDefinition = _card_for_play_ref(card_index)
	if wall_card == null:
		return false
	if wall_card.card_id != &"wall":
		setup_hint_label.text = "只有城墙卡可以直接放到地图。"
		return false
	var obstacles: Array[Dictionary] = _wall_placement_obstacles()
	if not wall_manager.can_place_wall(map_position, obstacles):
		setup_hint_label.text = wall_manager.last_error
		return false
	if not RunEconomy.can_pay(wall_card.build_costs):
		_show_build_failure(wall_card)
		setup_hint_label.text = "建造城墙的资源不足，已显示缺口。"
		return false
	if not RunEconomy.try_pay(wall_card.build_costs):
		_show_build_failure(wall_card)
		return false
	var wall: BarrierWall = wall_manager.place_wall(wall_card, map_position, obstacles)
	if wall == null:
		for resource_id: Variant in wall_card.build_costs:
			RunEconomy.add_resource(StringName(resource_id), int(wall_card.build_costs[resource_id]))
		setup_hint_label.text = wall_manager.last_error
		return false
	_consume_played_card(card_index, wall_card)
	setup_hint_label.text = (
		"城墙部署完成，已进入路线阻挡。"
		if wall.blocks_route(wave_controller.city_target_position.y)
		else "城墙部署完成；当前位置偏离路线，不会阻挡野狼。"
	)
	build_failure_panel.visible = false
	return true


func _wall_placement_obstacles() -> Array[Dictionary]:
	return _free_placement_obstacles(true)


func _try_place_defense_card(card_index: int, map_position: Vector2 = Vector2.INF) -> bool:
	if not _card_play_allowed() or card_index < 0:
		return false
	var arrow_card: OpeningCardDefinition = _card_for_play_ref(card_index)
	if arrow_card == null:
		return false
	if arrow_card.card_id != &"arrow_tower":
		setup_hint_label.text = "这张卡不能放入当前防御格。"
		return false
	if opening_draft.active and card_index not in opening_draft.selected_indices:
		setup_hint_label.text = "需要先选择箭塔卡。"
		return false
	if opening_draft.active and opening_draft.is_card_locked(card_index):
		setup_hint_label.text = "箭塔卡已经使用。"
		return false
	var target_position: Vector2 = arrow_tower.global_position if map_position == Vector2.INF else map_position
	if not _can_place_free_building(target_position, MapLayout.TOWER_RADIUS):
		return false
	if not RunEconomy.can_pay(arrow_card.build_costs):
		_show_build_failure(arrow_card)
		setup_hint_label.text = "建造箭塔的资源不足，已显示缺口。"
		return false
	if not RunEconomy.try_pay(arrow_card.build_costs):
		_show_build_failure(arrow_card)
		return false
	var placed_tower: ArrowTower = arrow_tower
	if placed_tower.is_attackable():
		placed_tower = preload("res://src/gameplay/defenses/arrow_tower.tscn").instantiate()
		placed_tower.target_provider_path = NodePath("../WaveController")
		add_child(placed_tower)
		additional_towers.append(placed_tower)
		placed_tower.destroyed.connect(_on_world_defense_destroyed)
	placed_tower.visible = true
	placed_tower.reset_statistics()
	placed_tower.enabled = true
	placed_tower.global_position = target_position
	placed_tower.queue_redraw()
	_consume_played_card(card_index, arrow_card)
	wave_economy.refresh_jobs(settlement_builder, arrow_tower, barracks)
	_refresh_world_targets()
	defense_slot_button.text = "箭塔已放置"
	defense_slot_button.disabled = true
	setup_hint_label.text = "箭塔已在空地部署。"
	build_failure_panel.visible = false
	return true


func _on_draft_time_changed(seconds_remaining: float) -> void:
	timer_label.text = "剩余 %d 秒" % int(ceil(seconds_remaining))


func _on_draft_selection_changed(selected_indices: Array[int], free_choices_remaining: int) -> void:
	if interwave_draft.active:
		return
	selection_label.text = "剩余免费名额：%d" % free_choices_remaining
	refresh_button.text = "刷新 %d金" % interwave_draft.current_refresh_cost()
	ready_button.disabled = not opening_draft.can_finish()
	if selected_indices.size() == opening_draft.free_choice_limit and not opening_draft.selection_has_damage_card():
		selection_label.text = "还需要1张伤害牌才能迎战"
	for card_index in range(card_buttons.size()):
		var card: OpeningCardDefinition = opening_draft.offered_cards[card_index]
		var selected: bool = card_index in selected_indices
		var locked: bool = opening_draft.is_card_locked(card_index)
		var state_text: String = "已使用" if locked else ("已选择" if selected else card.category_label())
		card_buttons[card_index].text = "%s【%s】\n建造：%s" % [
			card.display_name,
			state_text,
			card.build_cost_text,
		]
		card_buttons[card_index].modulate = Color("9ad58b") if selected else Color.WHITE
		card_buttons[card_index].disabled = locked
	_sync_hand_bar()


func _on_setup_finished(selected_indices: Array[int]) -> void:
	for card_index in selected_indices:
		if opening_draft.is_card_locked(card_index):
			continue
		run_card_inventory.add_card(
			opening_draft.offered_cards[card_index],
			1,
			card_index,
			card_index
		)
	day_setup_panel.visible = false
	bottom_panel.visible = false
	_populate_battle_hand()
	hand_bar.visible = true
	defense_slot_button.visible = false
	barrier_slot_button.visible = false
	barracks_slot_button.visible = false
	map_drop_surface.visible = true
	battle_shop_button.visible = true
	for slot_button in settlement_slot_buttons:
		slot_button.visible = false
	wave_economy.prepare_wave(settlement_builder, arrow_tower, barracks)
	if not wave_controller.start_wave(1):
		status_label.text = "第1波数据无效，无法开始。"
		start_button.text = "无法迎战"
		return
	RunState.start_current_wave()
	status_label.text = "第1波：4只野狼正在进攻主城。"
	start_button.text = "战斗进行中"
	start_button.disabled = true


func _create_card_buttons() -> void:
	for card_index in range(opening_draft.offered_cards.size()):
		var card: OpeningCardDefinition = opening_draft.offered_cards[card_index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(286.0, 52.0)
		button.tooltip_text = card.description
		button.pressed.connect(_on_card_button_pressed.bind(card_index))
		card_grid.add_child(button)
		card_buttons.append(button)
	_on_draft_selection_changed([], opening_draft.free_choice_limit)


func _sync_hand_bar() -> void:
	if hand_bar.visible:
		_populate_battle_hand()


func _populate_battle_hand() -> void:
	for child in hand_slots.get_children():
		hand_slots.remove_child(child)
		child.queue_free()
	hand_card_slots.clear()
	for entry in run_card_inventory.entries():
		var instance_id: int = int(entry["instance_id"])
		var card: OpeningCardDefinition = entry["card"] as OpeningCardDefinition
		var star: int = int(entry.get("star", 1))
		var hand_card := HandCardSlot.new()
		hand_card.configure(instance_id, card, star, run_card_inventory.count_matching(card.card_id, star))
		hand_card.set_interaction_enabled(true)
		hand_card.fusion_requested.connect(_on_hand_fusion_requested)
		hand_slots.add_child(hand_card)
		hand_card_slots[instance_id] = hand_card
	var hand_count: int = hand_card_slots.size()
	hand_label.text = "部署手牌\n%d / %d" % [hand_count, RunCardInventory.MAX_CARDS]
	hand_empty_hint.visible = hand_count == 0


func _on_hand_fusion_requested(card_id: StringName, star: int) -> void:
	var result_id: int = run_card_inventory.fuse_first_matching(card_id, star)
	if result_id < 0:
		status_label.text = "合成失败：需要3张同名同星手牌，且最高为3星。"
		return
	var result: Dictionary = run_card_inventory.entry_for(result_id)
	var card: OpeningCardDefinition = result.get("card") as OpeningCardDefinition
	status_label.text = "合成成功：%s升至%d星。" % [card.display_name, int(result.get("star", star + 1))]


func _set_hand_interaction_enabled(is_enabled: bool) -> void:
	for hand_card: HandCardSlot in hand_card_slots.values():
		hand_card.set_interaction_enabled(is_enabled)


func _remove_arrow_tower() -> void:
	arrow_tower.visible = false
	arrow_tower.enabled = false
	defense_slot_button.text = "防御格\n拖入箭塔卡"
	defense_slot_button.disabled = false
	if opening_draft.active:
		wave_economy.refresh_jobs(settlement_builder, arrow_tower, barracks)


func _reset_walls() -> void:
	wall_manager.reset_walls()
	barrier_slot_button.visible = false


func _on_walls_changed(active_walls: Array[BarrierWall]) -> void:
	wave_controller.set_barrier_walls(active_walls)
	_refresh_world_targets()


func _on_wall_destroyed(_wall: BarrierWall) -> void:
	setup_hint_label.text = "一面城墙已被摧毁，野狼正在寻找下一处阻挡。"


func _reset_barracks() -> void:
	barracks.reset()
	barracks_slot_button.text = "兵营格\n拖入兵营卡"
	barracks_slot_button.disabled = false


func _on_guard_roster_changed(active_count: int, assigned_workers: int) -> void:
	if not barracks.is_built():
		return
	barracks_slot_button.text = "兵营守卫\n%d / %d" % [active_count, assigned_workers]


func _on_settlement_slot_pressed(slot_index: int) -> void:
	if not _card_play_allowed():
		return
	if pending_resource_card_index < 0:
		setup_hint_label.text = "请先选择一张资源建筑卡。"
		return
	_try_place_resource_card(pending_resource_card_index, slot_index)


func _on_resource_card_dropped(card_index: int, slot_index: int) -> void:
	_try_place_resource_card(card_index, slot_index)


func _try_place_resource_card(card_index: int, slot_index: int) -> bool:
	if not _card_play_allowed() or card_index < 0:
		return false
	if opening_draft.active and card_index not in opening_draft.selected_indices:
		setup_hint_label.text = "这张资源建筑卡尚未选择。"
		return false
	var card: OpeningCardDefinition = _card_for_play_ref(card_index)
	if card == null:
		return false
	if card.category != "resource":
		setup_hint_label.text = "这张卡不能放入聚落格。"
		return false
	if not RunEconomy.can_pay(card.build_costs):
		_show_build_failure(card)
		setup_hint_label.text = "建造%s的资源不足，已显示缺口。" % card.display_name
		return false
	if not settlement_builder.place_card(card, slot_index):
		setup_hint_label.text = settlement_builder.last_error
		return false
	_consume_played_card(card_index, card)
	settlement_slot_buttons[slot_index].text = "%s\n已建造" % card.display_name
	settlement_slot_buttons[slot_index].disabled = true
	setup_hint_label.text = "%s建造完成，材料已扣除。" % card.display_name
	build_failure_panel.visible = false
	pending_resource_card_index = -1
	return true


func _on_resources_changed(
	_balances: Dictionary,
	current_population: int,
	population_capacity: int
) -> void:
	wood_value.text = "木 %d" % RunEconomy.amount(&"wood")
	food_value.text = "食 %d" % RunEconomy.amount(&"food")
	stone_value.text = "石 %d" % RunEconomy.amount(&"stone")
	iron_value.text = "铁 %d" % RunEconomy.amount(&"iron")
	gold_value.text = "金 %d" % RunEconomy.amount(&"gold")
	population_value.text = "人口 %d/%d" % [current_population, population_capacity]
	train_farmer_button.visible = RunState.phase not in [RunState.Phase.BOOT, RunState.Phase.RUN_LOST, RunState.Phase.RUN_WON]
	train_farmer_button.text = "主城招募 · 10金"
	train_farmer_button.tooltip_text = "生产一名农民，占1人口；当前%d/%d。民屋可增加2人口容量。" % [current_population, population_capacity]
	farmer_manager.sync_population(current_population)
	wave_economy.refresh_population_totals()


func _on_train_farmer_pressed() -> void:
	if RunState.phase in [RunState.Phase.BOOT, RunState.Phase.RUN_LOST, RunState.Phase.RUN_WON]:
		return
	if RunEconomy.current_population >= RunEconomy.population_capacity:
		_show_notice("人口已满：请先建造民屋增加人口容量。")
		return
	if RunEconomy.amount(&"gold") < 10:
		_show_notice("金币不足：生产1名农民需要10金币。")
		return
	if RunEconomy.try_train_farmer(10):
		_show_notice("主城已生产1名农民，消耗10金币。")


func _on_farmer_delivery_completed(resource_id: StringName, amount: int) -> void:
	wave_economy.record_farmer_delivery(resource_id, amount)
	status_label.text = "农民已向主城运回%d%s。" % [amount, _resource_display_name(resource_id)]


func _resource_display_name(resource_id: StringName) -> String:
	return str({
		&"wood": "木材",
		&"food": "食物",
		&"stone": "石材",
		&"iron": "铁矿",
		&"gold": "金币",
	}.get(resource_id, "资源"))


func _on_inventory_changed(_card_count: int) -> void:
	_sync_hand_bar()


func _on_build_failure_close_pressed() -> void:
	build_failure_panel.visible = false


func _show_build_failure(card: OpeningCardDefinition) -> void:
	var resource_names: Dictionary = {
		&"wood": "木材",
		&"food": "食物",
		&"stone": "石材",
		&"iron": "铁矿",
		&"gold": "金币",
	}
	var missing: Dictionary = RunEconomy.missing_resources(card.build_costs)
	var lines: Array[String] = []
	for resource_id in RunEconomy.RESOURCE_IDS:
		var amount: int = int(missing.get(resource_id, 0))
		if amount > 0:
			lines.append("%s还缺 %d" % [resource_names[resource_id], amount])
	var detail: String = "资源状态已变化，请重试。" if lines.is_empty() else "\n".join(lines)
	build_failure_detail.text = "无法建造%s\n%s\n卡牌和格位均已保留。" % [
		card.display_name,
		detail,
	]
	build_failure_panel.visible = true


func _on_workers_assigned(assigned_population: int, idle_population: int) -> void:
	population_value.text = "人口 %d/%d 岗%d 闲%d" % [
		RunEconomy.current_population,
		RunEconomy.population_capacity,
		assigned_population,
		idle_population,
	]


func _on_building_placed(_slot_index: int, _card_id: StringName) -> void:
	wave_economy.refresh_jobs(settlement_builder, arrow_tower, barracks)
	_refresh_world_targets()


func _on_building_placed_at(_building: ResourceBuilding, _card_id: StringName) -> void:
	_refresh_world_targets()


func _on_building_destroyed(_building: ResourceBuilding, _card_id: StringName) -> void:
	wave_economy.refresh_jobs(settlement_builder, arrow_tower, barracks)
	_refresh_world_targets()


func _on_farmer_roster_changed(_active_count: int) -> void:
	_refresh_world_targets()


func _on_world_defense_destroyed(_defense: Node2D) -> void:
	wave_economy.refresh_jobs(settlement_builder, arrow_tower, barracks)
	_refresh_world_targets()


func _refresh_world_targets() -> void:
	var targets: Array[Node2D] = []
	for tower in active_towers():
		targets.append(tower)
	for camp in active_barracks():
		targets.append(camp)
	for building in settlement_builder.placed_buildings():
		if is_instance_valid(building) and building.is_attackable():
			targets.append(building)
	for farmer in farmer_manager.active_farmers():
		targets.append(farmer)
	wave_controller.set_world_targets(targets)


func _try_place_map_building_card(card_index: int, map_position: Vector2) -> bool:
	if not _card_play_allowed() or card_index < 0:
		return false
	var card: OpeningCardDefinition = _card_for_play_ref(card_index)
	if card == null or card.category not in ["resource", "population"]:
		return false
	if not RunEconomy.can_pay(card.build_costs):
		_show_build_failure(card)
		setup_hint_label.text = "建造%s的资源不足，已显示缺口。" % card.display_name
		return false
	var building: ResourceBuilding = settlement_builder.place_card_at(
		card,
		map_position,
		_free_placement_obstacles(true, card.category != "resource")
	)
	if building == null:
		setup_hint_label.text = settlement_builder.last_error
		return false
	_consume_played_card(card_index, card)
	wave_economy.refresh_jobs(settlement_builder, arrow_tower, barracks)
	setup_hint_label.text = (
		"%s已吸附到对应资源点。" % card.display_name
		if card.category == "resource"
		else "%s建造完成，人口容量增加%d。" % [card.display_name, card.population_capacity_bonus]
	)
	build_failure_panel.visible = false
	return true


func _can_place_free_building(map_position: Vector2, radius: float) -> bool:
	if not wall_manager.build_bounds.grow(-radius).has_point(map_position):
		setup_hint_label.text = "建筑必须放在地图可建造区域内。"
		return false
	for obstacle in _free_placement_obstacles(true):
		var obstacle_position: Vector2 = obstacle.get("position", Vector2.ZERO)
		var obstacle_radius: float = float(obstacle.get("radius", 0.0))
		if obstacle_position.distance_to(map_position) < radius + obstacle_radius:
			setup_hint_label.text = "这里已有建筑或单位，不能放置。"
			return false
	return true


func active_towers() -> Array[ArrowTower]:
	var result: Array[ArrowTower] = []
	for tower in [arrow_tower] + additional_towers:
		if is_instance_valid(tower) and tower.is_attackable():
			result.append(tower)
	return result


func active_barracks() -> Array[Barracks]:
	var result: Array[Barracks] = []
	for camp in [barracks] + additional_barracks:
		if is_instance_valid(camp) and camp.is_built():
			result.append(camp)
	return result


func building_footprints(include_defenses: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"position": wave_controller.city_target_position, "radius": MapLayout.CITY_RADIUS}]
	if include_defenses:
		for tower in active_towers():
			result.append({"position": tower.global_position, "radius": MapLayout.TOWER_RADIUS})
		for camp in active_barracks():
			result.append({"position": camp.global_position, "radius": MapLayout.BARRACKS_RADIUS})
	for wall in wall_manager.active_walls():
		result.append({"position": wall.global_position, "radius": WallManager.WALL_RADIUS})
	for building in settlement_builder.placed_buildings():
		if is_instance_valid(building) and building.definition != null:
			result.append({"position": building.global_position, "radius": building.definition.footprint_radius})
	return result


func _free_placement_obstacles(include_defenses: bool = true, reserve_resource_sites: bool = true) -> Array[Dictionary]:
	var obstacles: Array[Dictionary] = building_footprints(include_defenses)
	if reserve_resource_sites:
		for site in resource_sites:
			if site.is_occupied():
				continue
			obstacles.append({"position": site.global_position, "radius": site.radius})
	for enemy in wave_controller.enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			obstacles.append({"position": enemy.global_position, "radius": 18.0})
	for farmer in farmer_manager.active_farmers():
		obstacles.append({"position": farmer.global_position, "radius": farmer.attackable_radius()})
	for camp in active_barracks():
		for guard in camp.active_guards():
			obstacles.append({"position": guard.global_position, "radius": guard.attackable_radius()})
	return obstacles


func placement_preview(card: OpeningCardDefinition, point: Vector2) -> Dictionary:
	var radius: float = card.footprint_radius
	if card.card_id == &"arrow_tower":
		radius = MapLayout.TOWER_RADIUS
	elif card.card_id == &"barracks":
		radius = MapLayout.BARRACKS_RADIUS
	elif card.card_id == &"wall":
		radius = MapLayout.WALL_RADIUS
	var valid: bool = true
	if card.category == "resource":
		var site: ResourceSite = settlement_builder._matching_site(card, point)
		valid = site != null
		if site != null:
			point = site.global_position
	valid = valid and MapLayout.BOUNDS.grow(-radius).has_point(point) and RunEconomy.can_pay(card.build_costs)
	for obstacle in _free_placement_obstacles(true, card.category != "resource"):
		if point.distance_to(obstacle.position) < radius + float(obstacle.radius):
			valid = false
	return {"position": point, "radius": radius, "valid": valid}


func _on_jobs_changed(current_job_order: Array[StringName]) -> void:
	for child in job_rows.get_children():
		child.free()
	job_value_labels.clear()
	job_minus_buttons.clear()
	job_plus_buttons.clear()
	job_empty_hint.visible = current_job_order.is_empty()
	for job_id in current_job_order:
		var column := VBoxContainer.new()
		column.name = "Job_%s" % String(job_id)
		column.custom_minimum_size = Vector2(120.0, 66.0)
		var name_label := Label.new()
		name_label.text = wave_economy.job_label(job_id)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name_label)
		var controls := HBoxContainer.new()
		controls.name = "Controls"
		controls.alignment = BoxContainer.ALIGNMENT_CENTER
		var minus_button := Button.new()
		minus_button.name = "Minus"
		minus_button.text = "−"
		minus_button.custom_minimum_size = Vector2(44.0, 44.0)
		minus_button.pressed.connect(_on_job_adjust_pressed.bind(job_id, -1))
		controls.add_child(minus_button)
		var value_label := Label.new()
		value_label.name = "Value"
		value_label.custom_minimum_size = Vector2(32.0, 44.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		controls.add_child(value_label)
		var plus_button := Button.new()
		plus_button.name = "Plus"
		plus_button.text = "+"
		plus_button.custom_minimum_size = Vector2(44.0, 44.0)
		plus_button.pressed.connect(_on_job_adjust_pressed.bind(job_id, 1))
		controls.add_child(plus_button)
		column.add_child(controls)
		job_rows.add_child(column)
		job_value_labels[job_id] = value_label
		job_minus_buttons[job_id] = minus_button
		job_plus_buttons[job_id] = plus_button


func _on_assignments_changed(
	assignments: Dictionary,
	assigned_population: int,
	idle_population: int,
	is_locked: bool
) -> void:
	job_summary_label.text = "岗位 %d/%d\n空闲 %d" % [
		assigned_population,
		RunEconomy.current_population,
		idle_population,
	]
	population_value.text = "人口 %d/%d 岗%d 闲%d" % [
		RunEconomy.current_population,
		RunEconomy.population_capacity,
		assigned_population,
		idle_population,
	]
	for job_id in wave_economy.job_order:
		if job_id not in job_value_labels:
			continue
		var assigned: int = int(assignments.get(job_id, 0))
		var capacity: int = wave_economy.job_capacity(job_id)
		(job_value_labels[job_id] as Label).text = "%d/%d" % [assigned, capacity]
		(job_minus_buttons[job_id] as Button).disabled = is_locked or assigned <= 0
		(job_plus_buttons[job_id] as Button).disabled = (
			is_locked or assigned >= capacity or idle_population <= 0
		)
	auto_assign_button.disabled = is_locked or wave_economy.job_order.is_empty()
	farmer_manager.apply_assignments(assignments, wave_economy.job_order)


func _on_job_adjust_pressed(job_id: StringName, delta: int) -> void:
	if not wave_economy.adjust_workers(job_id, delta):
		setup_hint_label.text = "岗位调整失败：岗位已满、无人可用或战斗已锁定。"
		return
	setup_hint_label.text = "岗位已调整；迎战后将锁定当前方案。"


func _on_auto_assign_pressed() -> void:
	if wave_economy.auto_assign_workers():
		setup_hint_label.text = "已恢复防御优先的自动岗位方案。"


func _on_battle_shop_button_pressed() -> void:
	if RunState.phase != RunState.Phase.WAVE_COMBAT:
		return
	if battle_shop.active:
		_close_battle_shop()
		return
	if not battle_shop.open_for_wave(RunState.current_wave):
		status_label.text = "战斗商店数据无效，暂时无法打开。"
		return
	_configure_battle_shop_panel()


func _configure_battle_shop_panel() -> void:
	build_failure_panel.visible = false
	day_setup_panel.visible = true
	hand_bar.visible = false
	defense_slot_button.visible = false
	barrier_slot_button.visible = false
	barracks_slot_button.visible = false
	map_drop_surface.visible = false
	battle_shop_button.visible = true
	battle_shop_button.text = "关闭商店"
	for slot_button in settlement_slot_buttons:
		slot_button.visible = false
	day_title.text = "第%d波战斗商店（怪潮继续）" % RunState.current_wave
	timer_label.visible = false
	selection_label.visible = true
	pause_timer_button.visible = false
	card_grid.visible = true
	refresh_button.visible = true
	ready_button.visible = true
	ready_button.disabled = false
	ready_button.text = "关闭商店"
	setup_hint_label.text = "购买立即进入手牌；打开商店不会暂停敌人和资源生产。"
	_on_battle_shop_offers_changed()


func _close_battle_shop() -> void:
	battle_shop.close()
	day_setup_panel.visible = false
	_populate_battle_hand()
	hand_bar.visible = true
	_set_hand_interaction_enabled(true)
	defense_slot_button.visible = false
	barrier_slot_button.visible = false
	barracks_slot_button.visible = false
	map_drop_surface.visible = true
	battle_shop_button.visible = true
	battle_shop_button.text = "战斗商店"
	for slot_button in settlement_slot_buttons:
		slot_button.visible = false
	status_label.text = "战斗商店已关闭，新购卡牌已加入底部手牌。"


func _on_battle_shop_card_pressed(card_index: int) -> void:
	if not battle_shop.purchase_card(card_index, run_card_inventory):
		setup_hint_label.text = battle_shop.last_error
		return
	var card: OpeningCardDefinition = battle_shop.offered_cards[card_index]
	_populate_battle_hand()
	setup_hint_label.text = "已购买%s；关闭商店后可从底部手牌部署。" % card.display_name


func _on_battle_shop_offers_changed() -> void:
	if not battle_shop.active:
		return
	selection_label.text = "金币购买：已买%d张｜战斗仍在继续" % battle_shop.purchased_indices.size()
	refresh_button.text = "刷新 %d金" % battle_shop.current_refresh_cost()
	for card_index in range(card_buttons.size()):
		if card_index >= battle_shop.offered_cards.size():
			card_buttons[card_index].visible = false
			continue
		var card: OpeningCardDefinition = battle_shop.offered_cards[card_index]
		var purchased: bool = card_index in battle_shop.purchased_indices
		card_buttons[card_index].visible = true
		card_buttons[card_index].text = "%s【%s】\n价格：%d金｜建造：%s" % [
			card.display_name,
			"已购买" if purchased else "点击购买",
			card.shop_price,
			card.build_cost_text,
		]
		card_buttons[card_index].tooltip_text = card.description
		card_buttons[card_index].modulate = Color("8b8f94") if purchased else Color.WHITE
		card_buttons[card_index].disabled = purchased


func _begin_interwave_shop() -> void:
	zero_purchase_warning_shown = false
	if not interwave_draft.begin(RunState.current_wave, run_card_inventory.card_count()):
		_configure_interwave_job_panel()
		setup_hint_label.text = "第%d波商店数据无效，暂时只能调整岗位。" % RunState.current_wave
		return
	_configure_interwave_shop_panel()
	_on_interwave_selection_changed([], interwave_draft.free_choice_limit)


func _on_interwave_card_pressed(card_index: int) -> void:
	if interwave_draft.is_purchase_mode():
		if not interwave_draft.purchase_card(card_index, run_card_inventory):
			setup_hint_label.text = interwave_draft.last_error
			return
		zero_purchase_warning_shown = false
		var purchased_card: OpeningCardDefinition = interwave_draft.offered_cards[card_index]
		setup_hint_label.text = "已购买%s；打出建筑时仍需支付%s。" % [
			purchased_card.display_name,
			purchased_card.build_cost_text,
		]
		return
	if not interwave_draft.toggle_card(card_index):
		setup_hint_label.text = "当前商店不能选择该卡，请检查购买状态。"
		return
	setup_hint_label.text = "免费卡会在迎战后加入底部手牌；旧手牌会继续保留。"


func _on_interwave_selection_changed(
	selected_indices: Array[int],
	free_choices_remaining: int
) -> void:
	if not interwave_draft.active:
		return
	if interwave_draft.is_purchase_mode():
		selection_label.text = "金币购买：已买%d张（可买0～6张）" % interwave_draft.purchased_indices.size()
		ready_button.disabled = false
		for card_index in range(card_buttons.size()):
			var purchase_card: OpeningCardDefinition = interwave_draft.offered_cards[card_index]
			var purchased: bool = card_index in interwave_draft.purchased_indices
			card_buttons[card_index].text = "%s【%s】\n价格：%d金｜建造：%s" % [
				purchase_card.display_name,
				"已售罄" if purchased else "点击购买",
				purchase_card.shop_price,
				purchase_card.build_cost_text,
			]
			card_buttons[card_index].tooltip_text = purchase_card.description
			card_buttons[card_index].modulate = Color("8b8f94") if purchased else Color.WHITE
			card_buttons[card_index].disabled = purchased
		return
	selection_label.text = "剩余免费名额：%d" % free_choices_remaining
	ready_button.disabled = selected_indices.size() != interwave_draft.free_choice_limit
	for card_index in range(card_buttons.size()):
		var card: OpeningCardDefinition = interwave_draft.offered_cards[card_index]
		var selected: bool = card_index in selected_indices
		card_buttons[card_index].text = "%s【%s】\n建造：%s" % [
			card.display_name,
			"已选择" if selected else "免费",
			card.build_cost_text,
		]
		card_buttons[card_index].tooltip_text = card.description
		card_buttons[card_index].modulate = Color("9ad58b") if selected else Color.WHITE
		card_buttons[card_index].disabled = false


func _on_interwave_selection_finished(selected_cards: Array[OpeningCardDefinition]) -> void:
	for card in selected_cards:
		run_card_inventory.add_card(card, RunState.current_wave)
	day_setup_panel.visible = false
	bottom_panel.visible = false
	_populate_battle_hand()
	hand_bar.visible = true
	defense_slot_button.visible = false
	barrier_slot_button.visible = false
	barracks_slot_button.visible = false
	map_drop_surface.visible = true
	battle_shop_button.visible = true
	for slot_button in settlement_slot_buttons:
		slot_button.visible = false
	wave_economy.prepare_wave(settlement_builder, arrow_tower, barracks)
	var wave_index: int = RunState.current_wave
	if not wave_controller.start_wave(wave_index):
		status_label.text = "第%d波数据无效，无法开始。" % wave_index
		hand_bar.visible = false
		bottom_panel.visible = true
		return
	RunState.start_current_wave()
	status_label.text = "第%d波：%d只野狼正在进攻主城。" % [
		wave_index,
		wave_controller.active_enemy_count,
	]
	start_button.text = "战斗进行中"
	start_button.disabled = true


func _card_for_play_ref(card_ref: int) -> OpeningCardDefinition:
	if opening_draft.active:
		if card_ref < 0 or card_ref >= opening_draft.offered_cards.size():
			return null
		return opening_draft.offered_cards[card_ref]
	return run_card_inventory.card_for(card_ref)


func _consume_played_card(card_ref: int, card: OpeningCardDefinition) -> void:
	if opening_draft.active:
		opening_draft.lock_card(card.card_id)
		return
	var entry: Dictionary = run_card_inventory.entry_for(card_ref)
	if entry.is_empty():
		return
	if int(entry.get("source_wave", 0)) == 1:
		opening_draft.lock_card(card.card_id)
	run_card_inventory.consume(card_ref)


func _configure_opening_setup_panel() -> void:
	day_title.text = "白天布防"
	timer_label.visible = true
	selection_label.visible = true
	pause_timer_button.visible = true
	card_grid.visible = true
	refresh_button.visible = false
	ready_button.visible = true
	ready_button.text = "迎战"
	setup_hint_label.text = "免费选4张；点击迎战后，底部手牌栏出现并可拖牌部署。"


func _configure_interwave_shop_panel() -> void:
	build_failure_panel.visible = false
	bottom_panel.visible = false
	day_setup_panel.visible = true
	hand_bar.visible = false
	day_title.text = "第%d波六卡商店" % RunState.current_wave
	timer_label.visible = false
	selection_label.visible = true
	pause_timer_button.visible = false
	card_grid.visible = true
	refresh_button.visible = true
	refresh_button.text = "刷新 %d金" % interwave_draft.current_refresh_cost()
	ready_button.visible = true
	ready_button.text = "迎战第%d波" % RunState.current_wave
	setup_hint_label.text = (
		"点击卡牌支付金币购买；可买0～6张，建造材料另付。"
		if interwave_draft.is_purchase_mode()
		else "免费选2张；旧手牌保留，迎战后一起进入底部卡槽。"
	)


func _configure_interwave_job_panel() -> void:
	bottom_panel.visible = false
	day_setup_panel.visible = true
	hand_bar.visible = false
	day_title.text = "第%d波休整" % RunState.current_wave
	timer_label.visible = false
	selection_label.visible = false
	pause_timer_button.visible = false
	card_grid.visible = false
	refresh_button.visible = false
	ready_button.visible = false
	setup_hint_label.text = "%s 可继续调整岗位；第%d波购买商店将在下一步开放。" % [
		last_settlement_summary,
		RunState.current_wave,
	]


func _reset_settlement_slots() -> void:
	pending_resource_card_index = -1
	for slot_index in range(settlement_slot_buttons.size()):
		settlement_slot_buttons[slot_index].text = "聚落格%d\n拖入资源卡" % (slot_index + 1)
		settlement_slot_buttons[slot_index].disabled = false


func _card_by_id(card_id: StringName) -> OpeningCardDefinition:
	for card in opening_draft.offered_cards:
		if card.card_id == card_id:
			return card
	return null


func _card_play_allowed() -> bool:
	return opening_draft.active or RunState.phase == RunState.Phase.WAVE_COMBAT


func _refresh_all_labels() -> void:
	phase_value.text = RunState.phase_name()
	wave_value.text = "%d / %d" % [RunState.current_wave, RunState.LAST_WAVE]
	city_value.text = "%d / %d" % [RunState.city_health, RunState.city_max_health]
	enemy_value.text = "0 / 0"
