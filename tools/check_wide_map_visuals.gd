extends Node
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
const MAIN = preload("res://src/main/main.tscn")
var failures := 0
var OUT = "res://tests/reports/images/grass-transition-v2-2026-10-22/"

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): OUT = argument.trim_prefix("--output=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for resolution in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1024,768)]:
		var view := SubViewport.new()
		view.size=resolution
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
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
		main.notice_seconds=0
		main.notice_panel.hide()
		main.map_camera.show_full_map()
		var play: Rect2 = main.map_view_rect()
		var mapped: Rect2 = main.map_camera.get_canvas_transform()*Definition.BOUNDS
		check(play.grow(.01).encloses(mapped),"%s全图边界完整露出且避开HUD" % resolution)
		check(mapped.get_center().is_equal_approx(play.get_center()),"%s全图在可玩视口居中" % resolution)
		print("METRIC: %s地图视口=%s 覆盖=%s" % [resolution,play,mapped.size/play.size])
		await capture(view,"%dx%d-full" % [resolution.x,resolution.y])
		main.map_camera.reset_view()
		await capture(view,"%dx%d-city" % [resolution.x,resolution.y])
		check((main.map_camera.get_canvas_transform()*Definition.CITY_POSITION).distance_to(play.get_center())<.01,"%s回城落在实际视口中心" % resolution)
		var nav: Control = main.get_node("HUD/MapNavigation")
		nav.focus_minimap(nav.MAP_RECT.position+nav.MAP_RECT.size*Vector2(.30,.55))
		check(main.map_camera.position.distance_to(Vector2(.30,.55)*Definition.BOUNDS.size)<.01,"%s小地图点击与宽地图一致" % resolution)
		check(absf(nav.MAP_RECT.size.x/nav.MAP_RECT.size.y-Definition.BOUNDS.size.x/Definition.BOUNDS.size.y)<.001,"%s小地图保持地形比例" % resolution)
		if resolution==Vector2i(960,540):
			for target in [Vector2(3650,600),Vector2(4500,1500),Vector2(4500,2450),Vector2(4100,350),Vector2(5800,350)]:
				main.map_camera.zoom=Vector2.ONE*.72
				main.map_camera.focus_world(target)
				await capture(view,"join-%d-%d" % [target.x,target.y])
			main.map_camera.zoom=Vector2.ONE*1.6
			main.map_camera.focus_world(Vector2(4500,1500))
			await capture(view,"grass-join-detail")
			main.map_camera.focus_world(Vector2(4750,350))
			await capture(view,"north-join-detail")
			main.map_camera.zoom=Vector2.ONE*1.6
			main.map_camera.focus_world(Definition.source_to_world(Vector2(418,390)))
			await capture(view,"grass-repair-max-zoom")
			main.map_camera.zoom=Vector2.ONE*.72
			main.map_camera.focus_world(Vector2(5400,288))
			await capture(view,"north-cap")
			main.map_camera.focus_world(Vector2(1800,1512))
			await capture(view,"west-plain")
			var actor: FarmerAgent = main.farmer_manager.active_farmers()[0]
			actor.position=Vector2(1800,1512)
			await capture(view,"west-actor")
			check(main.terrain_grid_layer.chunks.size()==18,"运行使用同一连续地表的18片素材")
			main.map_camera.focus_world(Definition.source_to_world(Vector2(1180,430)))
			await capture(view,"s6-preserved")
			main.set_process(false)
			main.get_node("HUD").hide()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var pixels: Image = view.get_texture().get_image()
			var clear := pixels.get_pixel(0,0)
			var clipped := true
			for x in range(0,960,17):
				for y in [4,536]: clipped=clipped and pixels.get_pixel(x,y).is_equal_approx(clear)
			check(clipped,"扩边后地图仍被上下HUD之间的实际视口裁剪")
			pixels.save_png(OUT+"clip-proof.png")
			main.get_node("HUD").show()
			main.set_process(true)
		main._on_reset_pressed()
		check(not get_tree().paused and main.resource_sites.all(func(s):return not s.is_occupied()),"%s重开保持资源与暂停状态" % resolution)
		main.queue_free()
		view.queue_free()
		await get_tree().process_frame
	get_tree().quit(failures)

func capture(view: SubViewport,label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(view.get_texture().get_image().save_png(OUT+label+".png")==OK,"截图："+label)

func check(condition: bool,label: String) -> void:
	if condition: print("PASS: "+label)
	else:
		failures+=1
		push_error("FAIL: "+label)
