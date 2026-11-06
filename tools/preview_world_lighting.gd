extends Node
## 人工光影预览：冻结玩法，保留镜头和美术动画；不改变正式主场景入口。
var main: Node2D
var status: Label
var mode: int = 1
var terrain_lamp: WorldLightEmitter
var terrain_lamp_button: Button
var time_slider: HSlider

func _ready() -> void:
	get_window().title = "Waiting for Dawn · 地图无阴影预览 · F6切换光照 · M全图 Home回城"
	main = preload("res://src/main/main.tscn").instantiate()
	add_child(main)
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
	status = Label.new()
	panel.add_child(status)
	time_slider = HSlider.new()
	time_slider.position = Vector2(12,82)
	time_slider.size = Vector2(280,18)
	time_slider.max_value = RunState.CAMPAIGN_DURATION_SECONDS
	time_slider.step = 1.0
	time_slider.tooltip_text = "拖动预览整局光源移动"
	time_slider.value_changed.connect(_preview_time)
	overlay.add_child(time_slider)
	_set_mode(1)
	await get_tree().process_frame
	main._update_map_view_rect()
	main.map_camera.set_view_level(&"detail")
	var sample_tree := main.get_node_or_null("BorderForest/pine-037") as Sprite2D
	if sample_tree != null: main.map_camera.focus_world(sample_tree.global_position+Vector2(0,-110))

func _process(_delta: float) -> void:
	if terrain_lamp_button == null: return
	terrain_lamp.visible = terrain_lamp_button.button_pressed and mode != 0 and main.map_view_rect().has_point(get_viewport().get_mouse_position())
	if terrain_lamp.visible: terrain_lamp.global_position = main.get_global_mouse_position()

func _set_mode(value: int) -> void:
	mode = value
	main.world_lighting.set_lighting_enabled(mode != 0)
	time_slider.set_value_no_signal(RunState.CAMPAIGN_DURATION_SECONDS if mode == 2 else 0.0)
	_preview_time(time_slider.value)

func _preview_time(elapsed: float) -> void:
	var remaining := RunState.CAMPAIGN_DURATION_SECONDS-elapsed
	main.world_lighting._on_campaign_time_changed(remaining)
	main._on_campaign_time_changed(remaining)
	status.text = "%s · 已过 %02d:%02d / 60:00" % ["原画面" if mode == 0 else "移动光源",floori(elapsed/60.0),int(elapsed)%60]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		_set_mode((mode+1)%3)
		get_viewport().set_input_as_handled()
