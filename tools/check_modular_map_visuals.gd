extends Node
## 真实GL截图与组件位移验证；不把截图替代自然长局试玩。
const MAIN = preload("res://src/main/main.tscn")
const OUT = "res://tests/reports/images/modular-map-2026-10-27/"
var failures := 0
var metrics := {}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var view := SubViewport.new()
	view.size=Vector2i(1280,720)
	view.size_2d_override=Vector2i(960,540)
	view.size_2d_override_stretch=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(view)
	var main := MAIN.instantiate()
	view.add_child(main)
	main._on_start_pressed()
	main.opening_draft.set_countdown_paused(true)
	for index in [0,1,3,4]: main.card_buttons[index].pressed.emit()
	main.ready_button.pressed.emit()
	main.wave_controller.set_process(false)
	main.farmer_manager.set_process(false)
	for enemy in main.wave_controller.enemies: enemy.set_physics_process(false)
	main.notice_seconds=0
	main.notice_panel.hide()
	for resolution in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(2560,1080),Vector2i(3840,2160)]:
		view.size=resolution
		if resolution==Vector2i(1024,768): view.size_2d_override=Vector2i(1024,768)
		elif resolution==Vector2i(2560,1080): view.size_2d_override=Vector2i(1280,540)
		else: view.size_2d_override=Vector2i(960,540)
		await frame(view)
		main._update_map_view_rect()
		main.map_camera.show_full_map()
		var shot := await frame(view)
		shot.save_png(OUT+"%dx%d-overview.png" % [resolution.x,resolution.y])
		check(main.map_camera.overview,"%s全图使用独立总览状态" % resolution)
		main.map_camera.reset_view()
		shot=await frame(view)
		shot.save_png(OUT+"%dx%d-city.png" % [resolution.x,resolution.y])
		main.map_camera.zoom_at(.001,Vector2(480,270))
		var projected: Rect2=main.map_camera.get_canvas_transform()*main.map_runtime.bounds
		check(projected.grow(.1).encloses(main.map_view_rect()),"%s操作最远镜头由地图填满" % resolution)
		for place in [{"name":"city-max","point":main.map_runtime.city_position},{"name":"mountain-max","point":Vector2(5100,990)},{"name":"shore-max","point":Vector2(5210,2160)}]:
			main.map_camera.zoom=Vector2.ONE*1.6
			main.map_camera.focus_world(place.point)
			shot=await frame(view)
			check(shot.get_size()==resolution,"%s-%s实际渲染尺寸" % [resolution,place.name])
			shot.save_png(OUT+"%dx%d-%s.png" % [resolution.x,resolution.y,place.name])
		if resolution.x==3840: shot.get_region(Rect2i(1450,480,1000,800)).save_png(OUT+"4k-native-shore-crop.png")
	main._on_reset_pressed()
	check(main.resource_sites.all(func(site):return not site.is_occupied()),"重开释放全部资源点")
	metrics["parts"]=main.terrain_grid_layer.parts.size()
	metrics["border_trees"]=main.get_node("BorderForest").tree_count
	metrics["texture_memory_bytes"]=Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	metrics["notes"]="渲染纹理监视值为当前进程总量，不等于独立地图最低显存"
	var file=FileAccess.open(OUT+"metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	view.queue_free()
	get_tree().quit(failures)

func frame(view: SubViewport) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func check(value: bool,label: String) -> void:
	if value: print("PASS: "+label)
	else:
		failures+=1
		push_error("FAIL: "+label)
