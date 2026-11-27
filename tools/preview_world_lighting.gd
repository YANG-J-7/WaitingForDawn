extends Node
## 人工光影预览：冻结玩法，保留镜头和美术动画；不改变正式主场景入口。
const PREVIEW_SECONDS_PER_SECOND := 300.0
const WatchHallVisual = preload("res://src/gameplay/art/watch_hall_visual.gd")
const HALL_APPEARANCES: Array[TownHallAppearance] = [
	preload("res://assets/buildings/town_hall_levels/level_1.tres"),
	preload("res://assets/buildings/town_hall_levels/level_2.tres"),
	preload("res://assets/buildings/town_hall_levels/level_3.tres"),
	preload("res://assets/buildings/town_hall_levels/level_4.tres"),
	preload("res://assets/buildings/town_hall_levels/level_5.tres"),
]
@export var include_units := false
var main: Node2D
var play_button: Button
var status: Label
var mode: int = 1
var terrain_lamp: WorldLightEmitter
var terrain_lamp_button: Button
var time_slider: HSlider
var hall_selector: OptionButton
var preview_hall: WatchHallVisual

func _ready() -> void:
	get_window().title = "Waiting for Dawn · 移动主光预览"
	main = preload("res://src/main/main.tscn").instantiate()
	var preview_level: Resource = main.level_definition.duplicate()
	preview_level.environment_only = not include_units
	preview_level.place_city_at_start = false
	main.level_definition = preview_level
	add_child(main)
	if not main.level_definition.environment_only:
		_prepare_unit_samples()
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	var panel := HBoxContainer.new()
	panel.position = Vector2(12,52)
	panel.add_theme_constant_override("separation",8)
	overlay.add_child(panel)
	for index in range(3):
		var button := Button.new()
		button.text = ["原画面对比","夜间光影","黎明光影"][index]
		button.pressed.connect(_set_mode.bind(index))
		panel.add_child(button)
	terrain_lamp = WorldLightEmitter.new()
	terrain_lamp.radius = 240.0
	terrain_lamp.base_energy = 0.65
	terrain_lamp.flicker_amount = 0.0
	terrain_lamp.hide()
	main.add_child(terrain_lamp)
	terrain_lamp_button = Button.new()
	terrain_lamp_button.text = "地形试灯"
	terrain_lamp_button.toggle_mode = true
	panel.add_child(terrain_lamp_button)
	play_button = Button.new()
	play_button.text = "播放光源"
	play_button.tooltip_text = "每秒预览五分钟，按一下暂停"
	play_button.toggle_mode = true
	play_button.toggled.connect(_toggle_playback)
	panel.add_child(play_button)
	status = Label.new()
	panel.add_child(status)
	time_slider = HSlider.new()
	time_slider.position = Vector2(12,82)
	time_slider.size = Vector2(280,18)
	time_slider.max_value = RunState.CAMPAIGN_DURATION_SECONDS
	time_slider.step = 0.0
	time_slider.tooltip_text = "拖动预览整局光源移动"
	time_slider.value_changed.connect(_preview_time)
	overlay.add_child(time_slider)
	if main.level_definition.environment_only:
		hall_selector = OptionButton.new()
		hall_selector.position = Vector2(306, 76)
		hall_selector.add_item("主城外观")
		for level in HALL_APPEARANCES.size():
			hall_selector.add_item("%d 级 · %s" % [level + 1, HALL_APPEARANCES[level].display_name])
		hall_selector.item_selected.connect(_select_hall)
		overlay.add_child(hall_selector)
	_set_mode(1)
	await get_tree().process_frame
	main._update_map_view_rect()
	main.map_camera.show_full_map()


func _select_hall(index: int) -> void:
	if is_instance_valid(preview_hall):
		preview_hall.free()
		preview_hall = null
	if index == 0:
		main.map_camera.show_full_map()
		return
	var appearance: TownHallAppearance = HALL_APPEARANCES[index - 1]
	preview_hall = WatchHallVisual.new()
	preview_hall.preview_only = true
	preview_hall.appearance = appearance
	preview_hall.lighting = main.world_lighting
	var site: Vector2 = main.map_runtime.city_position + Vector2(-360, 0)
	preview_hall.position = site
	main.add_child(preview_hall)
	var height := appearance.body.get_height() * appearance.width / appearance.body.get_width()
	var camera: Camera2D = main.map_camera
	camera.set_view_level(&"detail")
	var fit_zoom := minf(main.map_view_rect().size.y * 0.58 / height, camera.zoom.x)
	camera.zoom = Vector2.ONE * fit_zoom
	camera.focus_world(site + Vector2(0.0, -height * 0.31))


func _prepare_unit_samples() -> void:
	main._on_start_pressed()
	main.opening_draft.set_countdown_paused(true)
	for index in [0,1,3,4]: main.card_buttons[index].pressed.emit()
	main.ready_button.pressed.emit()
	main.notice_panel.hide()
	main.set_process(false)
	main.wave_controller.set_process(false)
	main.farmer_manager.set_process(false)
	main.arrow_tower.visible = true
	main.arrow_tower.enabled = false
	main.barracks.visible = true
	main.barracks.set_process(false)
	for unit in get_tree().get_nodes_in_group(&"map_units"):
		unit.set_process(false)
		unit.set_physics_process(false)
	# 冻结预览样本，便于观察地图与实体在同一光照下的画面。
	for entry in [
		[preload("res://src/gameplay/defenses/barracks_guard.gd"),Vector2(-360,230)],
		[preload("res://src/gameplay/enemies/enemy.gd"),Vector2(360,230)],
	]:
		var unit: Node2D = entry[0].new()
		unit.position = main.map_runtime.city_position+entry[1]
		main.add_child(unit)
		unit.set_process(false)
		unit.set_physics_process(false)

func _process(_delta: float) -> void:
	if terrain_lamp_button == null: return
	terrain_lamp.visible = terrain_lamp_button.button_pressed and mode != 0 and main.map_view_rect().has_point(get_viewport().get_mouse_position())
	if terrain_lamp.visible: terrain_lamp.global_position = main.get_global_mouse_position()
	if play_button.button_pressed:
		time_slider.value = minf(time_slider.max_value, time_slider.value + _delta * PREVIEW_SECONDS_PER_SECOND)
		if time_slider.value >= time_slider.max_value:
			play_button.button_pressed = false


func _toggle_playback(playing: bool) -> void:
	play_button.text = "暂停光源" if playing else "播放光源"
	if playing and time_slider.value >= time_slider.max_value:
		time_slider.value = 0.0

func _set_mode(value: int) -> void:
	mode = value
	play_button.button_pressed = false
	play_button.disabled = mode == 0
	main.world_lighting.set_lighting_enabled(mode != 0)
	time_slider.set_value_no_signal(RunState.CAMPAIGN_DURATION_SECONDS if mode == 2 else 0.0)
	_preview_time(time_slider.value)

func _preview_time(elapsed: float) -> void:
	var remaining := RunState.CAMPAIGN_DURATION_SECONDS-elapsed
	main.world_lighting._on_campaign_time_changed(remaining)
	main._on_campaign_time_changed(remaining)
	main.hud_reference.day_night_clock.set_remaining_time(remaining)
	status.text = "%s · 已过 %02d:%02d / 60:00" % ["原画面" if mode == 0 else "移动光源",floori(elapsed/60.0),int(elapsed)%60]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		_set_mode((mode+1)%3)
		get_viewport().set_input_as_handled()
