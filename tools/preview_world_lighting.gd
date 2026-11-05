extends Node
## 人工光影预览：冻结玩法，保留镜头和美术动画；不改变正式主场景入口。
var main: Node2D
var status: Label
var mode: int = 1

func _ready() -> void:
	get_window().title = "Waiting for Dawn · 接触影与短投影修订版 · F6切换原图/夜间/黎明 · M全图 Home回城"
	main = preload("res://src/main/main.tscn").instantiate()
	add_child(main)
	main._on_start_pressed()
	main.opening_draft.set_countdown_paused(true)
	for index in [0,1,3,4]: main.card_buttons[index].pressed.emit()
	main.ready_button.pressed.emit()
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
	# 仅预览的真实单位样本，冻结AI且不接入战斗/经济，便于比较三类单位的影子。
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
	status = Label.new()
	panel.add_child(status)
	_set_mode(1)
	await get_tree().process_frame
	main._update_map_view_rect()
	main.map_camera.set_view_level(&"detail")

func _set_mode(value: int) -> void:
	mode = value
	main.world_lighting.preview_dawn = 1.0 if mode == 2 else 0.0
	main.world_lighting._on_campaign_time_changed(3600)
	main.world_lighting.set_lighting_enabled(mode != 0)
	status.text = "当前：" + ["原画面","夜间","黎明"][mode] + " · F6切换 · 滚轮缩放 / 拖动地图"

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		_set_mode((mode+1)%3)
		get_viewport().set_input_as_handled()
