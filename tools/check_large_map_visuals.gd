extends Node
const MAIN = preload("res://src/main/main.tscn")
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
var failures := 0
var directory := "res://tests/reports/images/map-visual-fixes-2026-10-14/"

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			directory = argument.trim_prefix("--evidence-dir=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1024,768)]:
		var view := SubViewport.new()
		view.size = size
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
		for frame in range(3): await get_tree().process_frame
		check(is_equal_approx(main.top_bar.size.y,32),"%s薄顶栏保持32" % size)
		check(main.hand_bar.visible and main.map_drop_surface.visible,"%s地图和手牌保持" % size)
		check(main.get_node("HUD/MapNavigation").visible,"%s小地图可见" % size)
		var representative: FarmerAgent = main.farmer_manager.active_farmers()[0]
		var worker_height := 0.0
		for child in representative.get_children():
			if child is ArtVisual: worker_height = child.get_rect().size.y*child.scale.y
		check(worker_height>=Definition.CELL_SIZE and worker_height<Definition.CELL_SIZE*1.2,"%s村民高度与36像素地图格相称" % size)
		var play_rect: Rect2 = main.map_view_rect()
		check(play_rect.position.y>=main.hud_reference.day_night_clock.visual_rect().end.y and play_rect.end.y==main.hand_bar.get_global_rect().position.y,"%s地图视口避开顶栏胶囊，下沿紧接手牌" % size)
		check(main.map_drop_surface.get_global_rect().is_equal_approx(play_rect),"%s交互区域与地图视口一致" % size)
		check((main.map_camera.get_canvas_transform()*Definition.CITY_POSITION).distance_to(play_rect.get_center())<.01,"%s主城映射到中间视口中心" % size)
		await capture(view,"%dx%d-city" % [size.x,size.y])
		main.map_camera.show_full_map()
		check(play_rect.grow(.01).encloses(main.map_camera.get_canvas_transform()*Definition.BOUNDS),"%s全图四边在上下栏之间完整可见" % size)
		await capture(view,"%dx%d-full" % [size.x,size.y])
		# 临时隐藏HUD，验证地图本身也没有渲染到栏位后方。
		main.set_process(false)
		main.get_node("HUD").hide()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var clip_image: Image = view.get_texture().get_image()
		var clipped := true
		var clear := clip_image.get_pixel(0,0)
		for x in range(0,size.x,13):
			for y in [4,size.y-4]:
				clipped = clipped and clip_image.get_pixel(x,y).is_equal_approx(clear)
		check(clipped,"%s隐藏HUD后顶底区域无地图像素" % size)
		clip_image.save_png(directory+"%dx%d-clip-proof.png" % [size.x,size.y])
		main.get_node("HUD").show()
		main.set_process(true)
		var nav: Control = main.get_node("HUD/MapNavigation")
		var before: Vector2 = main.map_camera.position
		var event := InputEventMouseButton.new()
		event.position = nav.position + Vector2(125,30)
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		view.push_input(event,true)
		event.pressed = false
		view.push_input(event,true)
		await get_tree().process_frame
		check(main.map_camera.position!=before,"%s引擎小地图点击移动镜头" % size)
		nav.city_button.pressed.emit()
		check(main.map_camera.position==Definition.CITY_POSITION,"%s回主城按钮有效" % size)
		if size == Vector2i(960,540):
			RunEconomy.add_resource(&"wood",100)
			var forest: ResourceSite = main.get_node("ResourceSites/forest_04")
			main.map_camera.focus_world(forest.position)
			await capture(view,"forest-before")
			var near_actor: FarmerAgent = main.farmer_manager.active_farmers()[0]
			var old_position := near_actor.position
			near_actor.position = forest.forest_rect.end-Vector2(30,70)
			for frame in range(20): await get_tree().process_frame
			check(forest.art_visual.visible and is_equal_approx(forest.art_visual.modulate.a,1),"单位靠近树簇矩形仍保持完全不透明")
			await capture(view,"forest-near-actor")
			near_actor.position = old_position
			var id: int = main.run_card_inventory.add_card(preload("res://src/data/cards/lumber_camp.tres"),1)
			check(main._try_place_map_building_card(id,forest.position),"真实伐木场占用树林")
			var lumber: ResourceBuilding = forest.occupied_building
			var roof: Vector2 = lumber.position-Vector2(0,70)
			check(main._job_at_world_point(roof)==lumber.get_meta("job_id"),"放大后的建筑屋顶可点选岗位")
			await capture(view,"forest-claimed")
			forest.occupied_building.apply_enemy_attack(99999,&"wolf")
			check(forest.art_visual.visible and is_equal_approx(forest.art_visual.modulate.a,1),"建筑释放后树林恢复完全不透明")
			await capture(view,"forest-restored")
			main.map_camera.zoom = Vector2.ONE * 1.6
			main.map_camera.focus_world(Definition.source_to_world(Vector2(1040,350)))
			await capture(view,"stairs-max-zoom")
			# 同一镜头保留旧源图对照，不改变HUD、地图坐标或实体尺度。
			var hd_chunks: Array = main.terrain_grid_layer.chunks.duplicate(true)
			var occlusion: Node2D = main.get_node("MapOcclusionLayer")
			occlusion.hide()
			var old_map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/dawn_large_v1/map.json"))
			var old_chunks: Array[Dictionary] = []
			for entry in old_map.chunks:
				var box: Array = entry.sourceRect
				var origin: Vector2 = Definition.source_to_world(Vector2(box[0],box[1]))
				var end: Vector2 = Definition.source_to_world(Vector2(box[2],box[3]))
				old_chunks.append({"texture":load("res://"+entry.path),"rect":Rect2(origin,end-origin)})
			main.terrain_grid_layer.chunks=old_chunks
			await capture(view,"stairs-max-zoom-old-source")
			main.terrain_grid_layer.chunks = hd_chunks
			occlusion.show()
			check(main.terrain_grid_layer.chunks[6].texture.get_width()>=1100,"运行地形使用独立高清像素，未继续拉伸418像素旧图")
			main.map_camera.focus_world(forest.position)
			await capture(view,"forest-max-zoom")
			var hd_forest: Texture2D = forest.art_visual.texture
			var hd_scale: Vector2 = forest.art_visual.scale
			forest.art_visual.texture = load("res://assets/map/dawn_large_v1/forest_04.png")
			forest.art_visual.scale = Definition.SOURCE_WORLD_SIZE/Definition.SOURCE_SIZE
			await capture(view,"forest-max-zoom-old-source")
			forest.art_visual.texture = hd_forest
			forest.art_visual.scale = hd_scale
			check(hd_forest.get_width()>=1300,"独立树簇也使用高清细节")
			for corner in [Vector2.ZERO,Vector2(Definition.BOUNDS.size.x,0),Definition.BOUNDS.end,Vector2(0,Definition.BOUNDS.size.y)]:
				main.map_camera.focus_world(corner)
				var visible_rect: Rect2 = main.map_camera.visible_world_rect()
				check(Definition.BOUNDS.grow(.01).encloses(visible_rect),"镜头到达%s时仍停在世界边界" % corner)
				await capture(view,"boundary-%d-%d" % [int(corner.x),int(corner.y)])
			get_tree().paused = true
			main.map_camera.reset_view()
			main.map_camera.focus_world(Vector2(500,1000))
			await capture(view,"paused-pan")
			check(main.terrain_grid_layer.process_mode==Node.PROCESS_MODE_ALWAYS,"暂停平移仍刷新地形分块")
			get_tree().paused = false
			main.map_camera.zoom = Vector2.ONE * .72
			main.map_camera.focus_world(Definition.source_to_world(Vector2(1040,350)))
			var actor: FarmerAgent = main.farmer_manager.active_farmers()[0]
			var original_position := actor.position
			for entry in Definition.navigation_data().cells:
				if int(entry.stair)==5 and entry.ends.is_empty():
					actor.position = main.grid_map_model.cell_center(Vector2i(entry.cell[0],entry.cell[1]))
					break
			check(not main.grid_map_model.is_solid(main.grid_map_model.world_to_cell(actor.position)),"石阶上的代表单位位于实际可通行格")
			await capture(view,"stairs-actor")
			actor.position = original_position
			var workers: Array[FarmerAgent] = []
			var site: ResourceSite = main.get_node("ResourceSites/stone_01")
			for index in range(50):
				var pressure_worker := FarmerAgent.new()
				main.add_child(pressure_worker)
				pressure_worker.configure(index,Definition.CITY_POSITION)
				pressure_worker.position = Definition.CITY_POSITION+Vector2(108+(index%5)*8,(index/5)*3)
				pressure_worker.set_pathfinder(main.grid_pathfinder)
				pressure_worker.assign_job(&"pressure",site,&"stone",2)
				workers.append(pressure_worker)
			var elapsed: Array[float] = []
			var frames: Array[float] = []
			var last := Time.get_ticks_usec()
			var open := true
			for frame in range(180):
				var began := Time.get_ticks_usec()
				for worker in workers:
					worker.advance(1.0/60.0)
					open = open and not main.grid_map_model.is_solid(main.grid_map_model.world_to_cell(worker.position))
				elapsed.append((Time.get_ticks_usec()-began)/1000.0)
				await get_tree().process_frame
				frames.append((Time.get_ticks_usec()-last)/1000.0)
				last = Time.get_ticks_usec()
			elapsed.sort(); frames.sort()
			print("METRIC: 50实际单位180帧 更新P95=%.3fms 最大=%.3fms GL帧P95=%.3fms 内存=%.2fMiB" % [elapsed[171],elapsed[-1],frames[171],Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0])
			check(open,"50单位实际沿合法格移动")
			await capture(view,"fifty-units")
			for worker in workers: worker.free()
		main._on_reset_pressed()
		check(not get_tree().paused and main.resource_sites.all(func(s):return not s.is_occupied()),"%s重开恢复地图状态" % size)
		main.queue_free()
		view.queue_free()
		await get_tree().process_frame
	get_tree().quit(failures)

func capture(view: SubViewport,label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(view.get_texture().get_image().save_png(directory+label+".png")==OK,"截图："+label)

func check(condition: bool,label: String) -> void:
	if condition: print("PASS: "+label)
	else:
		failures+=1
		push_error("FAIL: "+label)
