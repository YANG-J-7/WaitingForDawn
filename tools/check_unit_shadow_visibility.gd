extends Node
## 逐个关闭投影取差图，验证实际农民/野狼/守卫在底座和草地上的可见性。
const OUT := "res://tests/reports/images/building-unit-shadow-2026-11-05/"
var failures := 0
var view: SubViewport
var main: Node2D
var metrics := {}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	view = SubViewport.new()
	view.size = Vector2i(1280,720)
	view.size_2d_override = Vector2i(960,540)
	view.size_2d_override_stretch = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	main = preload("res://src/main/main.tscn").instantiate()
	view.add_child(main)
	main._on_start_pressed()
	main.opening_draft.set_countdown_paused(true)
	for index in [0,1,3,4]: main.card_buttons[index].pressed.emit()
	main.ready_button.pressed.emit()
	main.set_process(false)
	main.wave_controller.set_process(false)
	main.farmer_manager.set_process(false)
	for unit in get_tree().get_nodes_in_group(&"map_units"):
		unit.set_process(false)
		unit.set_physics_process(false)
		unit.hide()
	main.notice_panel.hide()
	var samples := []
	for entry in [
		["farmer-on-base",preload("res://src/gameplay/population/farmer_agent.gd"),Vector2(-72,28)],
		["wolf-on-base",preload("res://src/gameplay/enemies/enemy.gd"),Vector2(115,28)],
		["guard-on-grass",preload("res://src/gameplay/defenses/barracks_guard.gd"),Vector2(300,180)],
	]:
		var unit: Node2D = entry[1].new()
		unit.position = main.map_runtime.city_position + entry[2]
		main.add_child(unit)
		unit.set_process(false)
		unit.set_physics_process(false)
		samples.append({"id":entry[0],"unit":unit})
	main.arrow_tower.visible = true
	main.arrow_tower.enabled = false
	samples.append({"id":"tower-on-grass","unit":main.arrow_tower})
	await frame()
	await frame()
	for node in main.find_children("*","",true,false):
		if node is ArtVisual or node is TownHallVisual or node is WorldLightEmitter: node.set_process(false)
	main._update_map_view_rect()
	main.map_camera.set_view_level(&"detail")
	main.map_camera.focus_world(main.map_runtime.city_position+Vector2(0,70))
	for sample in samples:
		# 近景上限变化后仍以样本为中心，避免把离城较远的单位移出视口。
		main.map_camera.focus_world(sample.unit.global_position)
		var art: ArtVisual
		for child in sample.unit.get_children():
			if child is ArtVisual: art = child
		var caster = art.get_node("WorldShadowCaster")
		var strength: float = caster.strength
		check(caster.system == main.world_lighting,"%s实际单位已注册投影"%sample.id)
		caster.strength = 0.0
		var without := await frame()
		caster.strength = strength
		var with_shadow := await frame()
		var contact_strength: float = caster.contact_strength
		caster.contact_strength = 0.0
		var only_cast := await frame()
		var shadow_area := Rect2i(380,190,550,360)
		check(not has_difference(with_shadow,only_cast,shadow_area),"%s没有额外叠加的独立黑影"%sample.id)
		caster.contact_strength = contact_strength
		var foot_contacts := visible_contact_edges(caster)
		check(foot_contacts.size() >= 2,"%s具备鞋底或背光底缘检查点"%sample.id)
		for contact in foot_contacts:
			# 从素材原始鞋底出发检查，不能用已偏移的影子中心替代鞋底。
			var sole := contact.get_center()-Vector2(0,contact.size.y*0.22)
			var screen: Vector2 = main.map_camera.get_canvas_transform()*sole*Vector2(1280.0/960.0,720.0/540.0)
			var joined := false
			for dy in range(0,4):
				for dx in range(-3,4):
					var point := Vector2i(screen)+Vector2i(dx,dy)
					if point.x<0 or point.x>=1280 or point.y<0 or point.y>=720: continue
					var difference := without.get_pixelv(point)-with_shadow.get_pixelv(point)
					if difference.r+difference.g+difference.b>0.018: joined = true
			check(joined,"%s脚底或背光底缘下方3像素内连接投影"%sample.id)
		var dark_pixels := 0
		var peak := 0.0
		for y in range(80,560):
			for x in range(1280):
				var a := without.get_pixel(x,y)
				var b := with_shadow.get_pixel(x,y)
				var darkening: float = ((a.r-b.r)+(a.g-b.g)+(a.b-b.b))/3.0
				peak = maxf(peak,darkening)
				if darkening > 10.0/255.0: dark_pixels += 1
		metrics[sample.id] = {"dark_pixels":dark_pixels,"peak_darkening":peak}
		check(dark_pixels >= 20,"%s独立影子至少20像素产生明显暗化"%sample.id)
		check(peak > 0.08,"%s影子有足够明暗对比"%sample.id)
		without.save_png(OUT+sample.id+"-without.png")
		with_shadow.save_png(OUT+sample.id+"-with.png")
		# 对照隐藏地面底座，检查有多少本应可见的投影被地面贴图盖掉。
		var ground: Node2D = main.get_node("TownHallVisual").grounding
		ground.hide()
		caster.strength = 0.0
		var no_floor_without := await frame()
		caster.strength = strength
		var no_floor_with := await frame()
		var expected := 0
		var kept := 0
		for y in range(80,560):
			for x in range(1280):
				var d := no_floor_without.get_pixel(x,y)-no_floor_with.get_pixel(x,y)
				if maxf(d.r,maxf(d.g,d.b)) <= 2.0/255.0: continue
				expected += 1
				var actual := without.get_pixel(x,y)-with_shadow.get_pixel(x,y)
				if maxf(actual.r,maxf(actual.g,actual.b)) > 1.0/255.0: kept += 1
		var coverage: float = float(kept)/maxi(1,expected)
		metrics[sample.id]["floor_shadow_coverage"] = coverage
		check(coverage >= 0.9,"%s底座不遮盖至少90%%的应有投影"%sample.id)
		ground.show()
		# 同一只单位移到裸草地，避免只验证特定落点。
		var previous: Vector2 = sample.unit.position
		sample.unit.position = main.map_runtime.city_position+Vector2(-450,220)
		main.map_camera.focus_world(sample.unit.global_position)
		caster.strength = 0.0
		without = await frame()
		caster.strength = strength
		with_shadow = await frame()
		var changed := 0
		for y in range(80,560,2):
			for x in range(0,1280,2):
				var a := without.get_pixel(x,y)
				var b := with_shadow.get_pixel(x,y)
				if a.r-b.r > 0.02 or a.g-b.g > 0.02: changed += 1
		check(changed >= 10,"%s移动到草地后投影仍可见"%sample.id)
		# 以实体屏幕面积归一化，避免几个差异像素也被误当作肉眼清晰。
		for level in [&"detail", &"build"]:
			main.map_camera.set_view_level(level)
			caster.strength = 0.0
			without = await frame()
			caster.strength = strength
			with_shadow = await frame()
			var screen_transform: Transform2D = Transform2D.IDENTITY.scaled(Vector2(1280.0/960.0,720.0/540.0))*main.map_camera.get_canvas_transform()*art.global_transform
			var screen_bounds: Rect2 = screen_transform*art.get_rect()
			var readable := 0
			var mask := Image.create(1280,720,false,Image.FORMAT_RGB8)
			for y in range(80,560):
				for x in range(1280):
					var a := without.get_pixel(x,y)
					var b := with_shadow.get_pixel(x,y)
					var base: float = (a.r+a.g+a.b)/3.0
					var drop: float = (a.r-b.r+a.g-b.g+a.b-b.b)/3.0
					if drop > 0.025 and drop/maxf(base,0.01) >= 0.28: readable += 1
					mask.set_pixel(x,y,Color.WHITE*clampf(drop/maxf(base,0.01),0.0,1.0))
			var ratio: float = float(readable)/maxf(1.0,screen_bounds.get_area())
			metrics[sample.id][str(level)] = {"readable_pixels":readable,"body_screen_area":screen_bounds.get_area(),"readable_area_ratio":ratio}
			var minimum := 0.18 if caster.is_grounded_actor() else 0.04
			check(ratio >= minimum,"%s %s倍率下显著暗化面积达到实体框%.0f%%（实际%.1f%%）"%[sample.id,level,minimum*100.0,ratio*100.0])
			var connected := true
			for contact in visible_contact_edges(caster):
				var sole: Vector2 = contact.get_center()-Vector2(0,contact.size.y*0.22)
				var screen: Vector2 = main.map_camera.get_canvas_transform()*sole*Vector2(1280.0/960.0,720.0/540.0)
				var touching := 0
				for dy in range(0,4):
					for dx in range(-3,4):
						var pixel := Vector2i(screen)+Vector2i(dx,dy)
						if pixel.x<0 or pixel.x>=1280 or pixel.y<0 or pixel.y>=720: continue
						var delta := without.get_pixelv(pixel)-with_shadow.get_pixelv(pixel)
						if delta.r+delta.g+delta.b > 0.018: touching += 1
				connected = connected and touching >= 2
			check(connected,"%s %s倍率下鞋底或背光底缘贴合投影"%[sample.id,level])
			if caster.is_grounded_actor(): check(ratio <= 0.65,"%s %s单位短影不扩成大块黑色包络"%[sample.id,level])
			with_shadow.save_png(OUT+sample.id+"-"+str(level)+".png")
			mask.save_png(OUT+sample.id+"-"+str(level)+"-mask.png")
		main.map_camera.set_view_level(&"detail")
		sample.unit.position = previous
	main.map_camera.focus_world(main.map_runtime.city_position)
	var final := await frame()
	final.save_png(OUT+"all-unit-shadows.png")
	var file := FileAccess.open(OUT+"unit-metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	get_tree().quit(failures)

func visible_contact_edges(caster: WorldShadowCaster) -> Array[Rect2]:
	var contacts := caster.ground_contacts()
	if caster.is_grounded_actor(): return contacts
	# 单向投影从背光底缘伸出，迎光侧不再要求有一圈额外黑影。
	var direction: Vector2 = main.world_lighting.profile.shadow_direction.normalized()
	return contacts.filter(func(contact: Rect2) -> bool:
		return (contact.get_center()-caster.anchor.global_position).dot(direction) >= -4.0
	)

func has_difference(a: Image,b: Image,area: Rect2i) -> bool:
	for y in range(area.position.y,area.end.y,2):
		for x in range(area.position.x,area.end.x,2):
			if a.get_pixel(x,y) != b.get_pixel(x,y): return true
	return false

func frame() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func check(value: bool,label: String) -> void:
	if value: print("PASS: "+label)
	else:
		failures += 1
		push_error("FAIL: "+label)
