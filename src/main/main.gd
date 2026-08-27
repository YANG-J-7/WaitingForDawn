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


func _ready() -> void:
	RunState.phase_changed.connect(_on_state_changed)
	RunState.wave_changed.connect(_on_wave_changed)
	RunState.city_health_changed.connect(_on_city_health_changed)
	start_button.pressed.connect(_on_start_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	failure_reset_button.pressed.connect(_on_reset_pressed)
	wave_controller.enemy_count_changed.connect(_on_enemy_count_changed)
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
	if RunState.phase == RunState.Phase.BOOT:
		RunState.begin_new_run()
		status_label.text = "工程运行正常。下一步：实现第1波敌人移动、攻击与主城失败。"
		start_button.text = "进入第1波"
	elif RunState.phase == RunState.Phase.DAY_SETUP:
		RunState.start_current_wave()
		if wave_controller.start_first_wave():
			status_label.text = "第1波：4只野狼正在进攻主城。"
			start_button.disabled = true
		else:
			status_label.text = "第1波数据无效，无法开始。"


func _on_reset_pressed() -> void:
	wave_controller.reset_wave()
	RunState.reset_to_boot()
	status_label.text = "已重置灰盒状态。"
	start_button.text = "开始灰盒对局"
	start_button.disabled = false
	failure_panel.visible = false


func _on_state_changed(_phase: int) -> void:
	phase_value.text = RunState.phase_name()
	if RunState.phase == RunState.Phase.RUN_LOST:
		status_label.text = "主城已被摧毁，本局失败。"
		failure_panel.visible = true
		start_button.disabled = true


func _on_wave_changed(wave_index: int) -> void:
	wave_value.text = "%d / %d" % [wave_index, RunState.LAST_WAVE]


func _on_city_health_changed(current_health: int, maximum_health: int) -> void:
	city_value.text = "%d / %d" % [current_health, maximum_health]


func _on_enemy_count_changed(active_count: int, total_spawned: int) -> void:
	enemy_value.text = "%d / %d" % [active_count, total_spawned]


func _refresh_all_labels() -> void:
	phase_value.text = RunState.phase_name()
	wave_value.text = "%d / %d" % [RunState.current_wave, RunState.LAST_WAVE]
	city_value.text = "%d / %d" % [RunState.city_health, RunState.city_max_health]
	enemy_value.text = "0 / 0"
