extends Node
## 人工看图入口：冻结战斗与计时，保留镜头/手牌/建筑交互；正式入口仍为main。
func _ready() -> void:
	var main=preload("res://src/main/main.tscn").instantiate()
	add_child(main)
	main._on_start_pressed()
	main.opening_draft.set_countdown_paused(true)
	for index in [0,1,3,4]: main.card_buttons[index].pressed.emit()
	main.ready_button.pressed.emit()
	main.wave_controller.set_process(false)
	main.farmer_manager.set_process(false)
	for enemy in main.wave_controller.enemies: enemy.set_physics_process(false)
	main.set_process(false)
	await get_tree().process_frame
	main._update_map_view_rect()
	main.map_camera.show_full_map()
