extends Node2D

const COLOR_NIGHT := Color("101827")
const COLOR_GRID := Color("1b2b3d")
const COLOR_PATH := Color("37475b")
const COLOR_CITY := Color("e3a94b")

@onready var phase_value: Label = %PhaseValue
@onready var wave_value: Label = %WaveValue
@onready var city_value: Label = %CityValue
@onready var enemy_value: Label = %EnemyValue
@onready var status_label: Label = %StatusLabel
@onready var start_button: Button = %StartButton
@onready var reset_button: Button = %ResetButton
@onready var failure_panel: PanelContainer = %FailurePanel
@onready var failure_reset_button: Button = %FailureResetButton
@onready var wave_controller: WaveController = $WaveController
@onready var opening_draft: OpeningDraft = $OpeningDraft
@onready var settlement_builder: SettlementBuilder = $SettlementBuilder
@onready var wave_economy: WaveEconomy = $WaveEconomy
@onready var arrow_tower: ArrowTower = $ArrowTower
@onready var day_setup_panel: PanelContainer = %DaySetupPanel
@onready var day_title: Label = %DayTitle
@onready var timer_label: Label = %TimerLabel
@onready var selection_label: Label = %SelectionLabel
@onready var card_grid: GridContainer = %CardGrid
@onready var setup_hint_label: Label = %SetupHintLabel
@onready var ready_button: Button = %ReadyButton
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
@onready var wood_value: Label = %WoodValue
@onready var food_value: Label = %FoodValue
@onready var stone_value: Label = %StoneValue
@onready var iron_value: Label = %IronValue
@onready var gold_value: Label = %GoldValue
@onready var population_value: Label = %PopulationValue

var card_buttons: Array[Button] = []
var hand_card_slots: Dictionary = {}
var settlement_slot_buttons: Array[CardDropSlot] = []
var pending_resource_card_index: int = -1
var last_settlement_summary: String = ""
var job_value_labels: Dictionary = {}
var job_minus_buttons: Dictionary = {}
var job_plus_buttons: Dictionary = {}


func _ready() -> void:
	RunState.phase_changed.connect(_on_state_changed)
	RunState.wave_changed.connect(_on_wave_changed)
	RunState.city_health_changed.connect(_on_city_health_changed)
	start_button.pressed.connect(_on_start_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	failure_reset_button.pressed.connect(_on_reset_pressed)
	ready_button.pressed.connect(_on_ready_pressed)
	pause_timer_button.pressed.connect(_on_pause_timer_pressed)
	auto_assign_button.pressed.connect(_on_auto_assign_pressed)
	defense_slot_button.pressed.connect(_on_defense_slot_pressed)
	settlement_slot_buttons = [%SettlementSlot0, %SettlementSlot1, %SettlementSlot2]
	for slot_index in range(settlement_slot_buttons.size()):
		settlement_slot_buttons[slot_index].pressed.connect(
			_on_settlement_slot_pressed.bind(slot_index)
		)
		settlement_slot_buttons[slot_index].card_dropped.connect(
			_on_resource_card_dropped.bind(slot_index)
		)
	(defense_slot_button as CardDropSlot).card_dropped.connect(_on_defense_card_dropped)
	wave_controller.enemy_count_changed.connect(_on_enemy_count_changed)
	wave_controller.wave_cleared.connect(_on_wave_cleared)
	settlement_builder.building_placed.connect(_on_building_placed)
	opening_draft.time_changed.connect(_on_draft_time_changed)
	opening_draft.countdown_pause_changed.connect(_on_countdown_pause_changed)
	opening_draft.selection_changed.connect(_on_draft_selection_changed)
	opening_draft.setup_finished.connect(_on_setup_finished)
	RunEconomy.resources_changed.connect(_on_resources_changed)
	wave_economy.workers_assigned.connect(_on_workers_assigned)
	wave_economy.jobs_changed.connect(_on_jobs_changed)
	wave_economy.assignments_changed.connect(_on_assignments_changed)
	_create_card_buttons()
	_remove_arrow_tower()
	_reset_settlement_slots()
	RunEconomy.clear()
	RunState.reset_to_boot()
	_refresh_all_labels()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 540)), COLOR_NIGHT)
	for x in range(0, 961, 32):
		draw_line(Vector2(x, 96), Vector2(x, 540), COLOR_GRID, 1.0)
	for y in range(96, 541, 32):
		draw_line(Vector2(0, y), Vector2(960, y), COLOR_GRID, 1.0)

	draw_rect(Rect2(64, 286, 736, 54), COLOR_PATH)
	draw_rect(Rect2(782, 244, 112, 138), COLOR_CITY)
	draw_string(ThemeDB.fallback_font, Vector2(799, 405), "主城", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(68, 278), "第1波野狼路线", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("a9bbca"))


func _on_start_pressed() -> void:
	if RunState.phase != RunState.Phase.BOOT:
		return
	RunState.begin_new_run()
	RunEconomy.begin_run()
	opening_draft.begin()
	_configure_opening_setup_panel()
	day_setup_panel.visible = true
	defense_slot_button.visible = true
	for slot_button in settlement_slot_buttons:
		slot_button.visible = true
	status_label.text = "白天布防开始：免费选择4张卡。"
	start_button.text = "白天布防中"
	start_button.disabled = true


func _on_reset_pressed() -> void:
	wave_controller.reset_wave()
	opening_draft.reset()
	wave_economy.reset(settlement_builder)
	settlement_builder.reset_buildings()
	RunEconomy.clear()
	arrow_tower.reset_statistics()
	_remove_arrow_tower()
	_reset_settlement_slots()
	RunState.reset_to_boot()
	status_label.text = "已重置灰盒状态。"
	start_button.text = "开始灰盒对局"
	start_button.disabled = false
	failure_panel.visible = false
	day_setup_panel.visible = false
	hand_bar.visible = false
	defense_slot_button.visible = false
	last_settlement_summary = ""
	for slot_button in settlement_slot_buttons:
		slot_button.visible = false


func _on_state_changed(_phase: int) -> void:
	phase_value.text = RunState.phase_name()
	if RunState.phase == RunState.Phase.RUN_LOST:
		status_label.text = "主城已被摧毁，本局失败。"
		failure_panel.visible = true
		start_button.disabled = true
	elif RunState.phase == RunState.Phase.WAVE_RESULT:
		hand_bar.visible = false
		status_label.text = "第1波已清空。%s" % last_settlement_summary
		start_button.disabled = true
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
	if not opening_draft.finish(false):
		setup_hint_label.text = "请先选满4张免费卡。"


func _on_pause_timer_pressed() -> void:
	opening_draft.set_countdown_paused(not opening_draft.countdown_paused)


func _on_countdown_pause_changed(is_paused: bool) -> void:
	pause_timer_button.text = "继续计时" if is_paused else "暂停计时"
	timer_label.text = (
		"计时已暂停" if is_paused
		else "剩余 %d 秒" % int(ceil(opening_draft.seconds_remaining))
	)


func _on_card_button_pressed(card_index: int) -> void:
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
		setup_hint_label.text = "已选择%s；请从手牌栏拖到空聚落格。" % card.display_name
		return
	if not opening_draft.toggle_card(card_index):
		setup_hint_label.text = "最多只能选择4张；可先取消一张。"
		return
	if card_index in opening_draft.selected_indices and card.category == "resource":
		pending_resource_card_index = card_index
		setup_hint_label.text = "已选择%s；请从手牌栏拖到空聚落格。" % card.display_name
	elif pending_resource_card_index == card_index:
		pending_resource_card_index = -1
	if not opening_draft.is_card_selected(&"arrow_tower"):
		_remove_arrow_tower()
	if card.category != "resource":
		setup_hint_label.text = "已选卡已进入手牌栏，请从手牌栏拖到地图格。"


func _on_defense_slot_pressed() -> void:
	if not opening_draft.active:
		return
	if not opening_draft.is_card_selected(&"arrow_tower"):
		setup_hint_label.text = "需要先选择箭塔卡。"
		return
	var arrow_card_index: int = opening_draft.offered_cards.find(_card_by_id(&"arrow_tower"))
	_try_place_defense_card(arrow_card_index)


func _on_defense_card_dropped(card_index: int) -> void:
	_try_place_defense_card(card_index)


func _try_place_defense_card(card_index: int) -> bool:
	if not opening_draft.active or card_index < 0 or card_index >= opening_draft.offered_cards.size():
		return false
	var arrow_card: OpeningCardDefinition = opening_draft.offered_cards[card_index]
	if arrow_card.card_id != &"arrow_tower":
		setup_hint_label.text = "这张卡不能放入当前防御格。"
		return false
	if card_index not in opening_draft.selected_indices:
		setup_hint_label.text = "需要先选择箭塔卡。"
		return false
	if opening_draft.is_card_locked(card_index):
		setup_hint_label.text = "箭塔卡已经使用。"
		return false
	if not RunEconomy.try_pay(arrow_card.build_costs):
		setup_hint_label.text = "建造箭塔的资源不足。"
		return false
	arrow_tower.visible = true
	arrow_tower.enabled = true
	opening_draft.lock_card(&"arrow_tower")
	wave_economy.refresh_jobs(settlement_builder, arrow_tower)
	defense_slot_button.text = "箭塔已放置"
	defense_slot_button.disabled = true
	setup_hint_label.text = "箭塔已放置；选满4张后可以迎战。"
	return true


func _on_draft_time_changed(seconds_remaining: float) -> void:
	timer_label.text = "剩余 %d 秒" % int(ceil(seconds_remaining))


func _on_draft_selection_changed(selected_indices: Array[int], free_choices_remaining: int) -> void:
	selection_label.text = "剩余免费名额：%d" % free_choices_remaining
	ready_button.disabled = selected_indices.size() != opening_draft.free_choice_limit
	for card_index in range(card_buttons.size()):
		var card: OpeningCardDefinition = opening_draft.offered_cards[card_index]
		var selected: bool = card_index in selected_indices
		var locked: bool = opening_draft.is_card_locked(card_index)
		var state_text: String = "已使用" if locked else ("已加入手牌" if selected else card.category_label())
		card_buttons[card_index].text = "%s【%s】\n建造：%s" % [
			card.display_name,
			state_text,
			card.build_cost_text,
		]
		card_buttons[card_index].modulate = Color("9ad58b") if selected else Color.WHITE
		card_buttons[card_index].disabled = locked
	_sync_hand_bar(selected_indices)


func _on_setup_finished(_selected_indices: Array[int]) -> void:
	_set_hand_interaction_enabled(false)
	hand_bar.visible = false
	day_setup_panel.visible = false
	defense_slot_button.visible = false
	for slot_button in settlement_slot_buttons:
		slot_button.visible = false
	wave_economy.prepare_wave(settlement_builder, arrow_tower)
	if not wave_controller.start_first_wave():
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


func _sync_hand_bar(selected_indices: Array[int]) -> void:
	for child in hand_slots.get_children():
		hand_slots.remove_child(child)
		child.queue_free()
	hand_card_slots.clear()
	var selection_complete: bool = selected_indices.size() == opening_draft.free_choice_limit
	hand_bar.visible = opening_draft.active and selection_complete
	if not selection_complete:
		hand_label.text = "手牌\n0 / %d" % opening_draft.free_choice_limit
		hand_empty_hint.visible = true
		return
	for card_index in selected_indices:
		if opening_draft.is_card_locked(card_index):
			continue
		var hand_card := HandCardSlot.new()
		hand_card.configure(card_index, opening_draft.offered_cards[card_index])
		hand_card.set_interaction_enabled(opening_draft.active)
		hand_slots.add_child(hand_card)
		hand_card_slots[card_index] = hand_card
	var hand_count: int = hand_card_slots.size()
	hand_label.text = "手牌\n%d / %d" % [hand_count, opening_draft.free_choice_limit]
	hand_empty_hint.visible = hand_count == 0


func _set_hand_interaction_enabled(is_enabled: bool) -> void:
	for hand_card: HandCardSlot in hand_card_slots.values():
		hand_card.set_interaction_enabled(is_enabled)


func _remove_arrow_tower() -> void:
	arrow_tower.visible = false
	arrow_tower.enabled = false
	defense_slot_button.text = "防御格\n拖入箭塔卡"
	defense_slot_button.disabled = false
	if opening_draft.active:
		wave_economy.refresh_jobs(settlement_builder, arrow_tower)


func _on_settlement_slot_pressed(slot_index: int) -> void:
	if not opening_draft.active:
		return
	if pending_resource_card_index < 0:
		setup_hint_label.text = "请先选择一张资源建筑卡。"
		return
	_try_place_resource_card(pending_resource_card_index, slot_index)


func _on_resource_card_dropped(card_index: int, slot_index: int) -> void:
	_try_place_resource_card(card_index, slot_index)


func _try_place_resource_card(card_index: int, slot_index: int) -> bool:
	if not opening_draft.active or card_index < 0 or card_index >= opening_draft.offered_cards.size():
		return false
	if card_index not in opening_draft.selected_indices:
		setup_hint_label.text = "这张资源建筑卡尚未选择。"
		return false
	var card: OpeningCardDefinition = opening_draft.offered_cards[card_index]
	if card.category != "resource":
		setup_hint_label.text = "这张卡不能放入聚落格。"
		return false
	if not settlement_builder.place_card(card, slot_index):
		setup_hint_label.text = settlement_builder.last_error
		return false
	opening_draft.lock_card(card.card_id)
	settlement_slot_buttons[slot_index].text = "%s\n已建造" % card.display_name
	settlement_slot_buttons[slot_index].disabled = true
	setup_hint_label.text = "%s建造完成，材料已扣除。" % card.display_name
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


func _on_workers_assigned(assigned_population: int, idle_population: int) -> void:
	population_value.text = "人口 %d/%d 岗%d 闲%d" % [
		RunEconomy.current_population,
		RunEconomy.population_capacity,
		assigned_population,
		idle_population,
	]


func _on_building_placed(_slot_index: int, _card_id: StringName) -> void:
	wave_economy.refresh_jobs(settlement_builder, arrow_tower)


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


func _on_job_adjust_pressed(job_id: StringName, delta: int) -> void:
	if not wave_economy.adjust_workers(job_id, delta):
		setup_hint_label.text = "岗位调整失败：岗位已满、无人可用或战斗已锁定。"
		return
	setup_hint_label.text = "岗位已调整；迎战后将锁定当前方案。"


func _on_auto_assign_pressed() -> void:
	if wave_economy.auto_assign_workers():
		setup_hint_label.text = "已恢复防御优先的自动岗位方案。"


func _configure_opening_setup_panel() -> void:
	day_title.text = "白天布防"
	timer_label.visible = true
	selection_label.visible = true
	pause_timer_button.visible = true
	card_grid.visible = true
	ready_button.visible = true
	_set_hand_interaction_enabled(true)
	setup_hint_label.text = "免费选4张；选中的卡进入上方手牌栏，再拖到地图建造。"


func _configure_interwave_job_panel() -> void:
	day_setup_panel.visible = true
	hand_bar.visible = false
	day_title.text = "第2波休整"
	timer_label.visible = false
	selection_label.visible = false
	pause_timer_button.visible = false
	card_grid.visible = false
	ready_button.visible = false
	setup_hint_label.text = "%s 可继续调整岗位；第2波商店将在下一步开放。" % last_settlement_summary


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


func _refresh_all_labels() -> void:
	phase_value.text = RunState.phase_name()
	wave_value.text = "%d / %d" % [RunState.current_wave, RunState.LAST_WAVE]
	city_value.text = "%d / %d" % [RunState.city_health, RunState.city_max_health]
	enemy_value.text = "0 / 0"
