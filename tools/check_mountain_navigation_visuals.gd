extends Node
const MAIN = preload("res://src/main/main.tscn")
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
var directory := "res://tests/reports/images/mountain-routing-2026-10-15/"
var failures := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var view := SubViewport.new()
	view.size = Vector2i(1280,720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var main := MAIN.instantiate()
	view.add_child(main)
	main._on_start_pressed()
	main.opening_draft.set_countdown_paused(true)
	for index in [0,1,3,4]: main.card_buttons[index].pressed.emit()
	main.ready_button.pressed.emit()
	main.wave_controller.set_process(false)
	for enemy in main.wave_controller.enemies: enemy.set_physics_process(false)
	main.farmer_manager.set_process(false)
	for frame in range(4): await get_tree().process_frame
	main.map_camera.zoom = Vector2.ONE * 1.2
	main.map_camera.focus_world(Definition.source_to_world(Vector2(200,260)))
	var border: Sprite2D = main.get_node("BorderForest")
	border.material.set_shader_parameter("remove_ground", false)
	await capture(view,"border-before")
	var before := view.get_texture().get_image()
	border.material.set_shader_parameter("remove_ground", true)
	await capture(view,"border-after")
	var after := view.get_texture().get_image()
	var pine := 0
	var preserved := 0
	var changed := 0
	for y in range(100,450):
		for x in range(190,600):
			var original := before.get_pixel(x,y)
			var revised := after.get_pixel(x,y)
			var difference := Vector3(original.r-revised.r,original.g-revised.g,original.b-revised.b).length()
			if original.b-original.g>.035 and original.r<original.g*.9:
				pine+=1
				if difference<.012: preserved+=1
			if difference>.04: changed+=1
	check(pine>1000 and float(preserved)/pine>.95,"边界冷蓝树冠像素保留超过95%")
	check(changed>10000,"去除边界树林浅色草地贴片产生实际画面差异")
	print("METRIC: 冷蓝树冠保留=%d/%d 改变像素=%d" % [preserved,pine,changed])
	main.map_camera.zoom = Vector2.ONE * .72
	main.map_camera.focus_world(Definition.source_to_world(Vector2(1160,300)))
	await capture(view,"mountain-clean")
	main.map_camera.show_full_map()
	await capture(view,"full-map")
	main.queue_free()
	view.queue_free()
	get_tree().quit(failures)

func check(condition: bool,label: String) -> void:
	if condition: print("PASS: "+label)
	else:
		failures+=1
		push_error("FAIL: "+label)

func capture(view: SubViewport,label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := view.get_texture().get_image().save_png(directory+label+".png")
	if result == OK: print("PASS: 截图："+label)
	else: failures+=1
