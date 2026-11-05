extends Node
## 真实GL验证：原画面/夜间/黎明、局部灯照明、HUD隔离、多画幅与受控压力。
const OUT := "res://tests/reports/images/building-unit-shadow-2026-11-05/"
var failures := 0
var metrics := {}
var view: SubViewport
var main: Node2D

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
	main.arrow_tower.visible = true
	main.arrow_tower.enabled = false
	main.barracks.visible = true
	main.barracks.set_process(false)
	main.notice_panel.hide()
	for unit in get_tree().get_nodes_in_group(&"map_units"):
		unit.set_process(false)
		unit.set_physics_process(false)
	await frame()
	for node in main.find_children("*","",true,false):
		if node is ArtVisual or node is TownHallVisual or node is WorldLightEmitter: node.set_process(false)
	main._update_map_view_rect()
	main.map_camera.set_view_level(&"detail")
	var system = main.world_lighting
	system.profile = system.profile.duplicate()
	if "--forest-only" in OS.get_cmdline_user_args():
		await check_forest_shadows()
		get_tree().quit(failures)
		return
	await check_terrain_response()
	if "--terrain-only" in OS.get_cmdline_user_args():
		get_tree().quit(failures)
		return
	for dimensions in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(2560,1080),Vector2i(3840,2160)]:
		view.size = dimensions
		view.size_2d_override = Vector2i(1024,768) if dimensions.x == 1024 else (Vector2i(1280,540) if dimensions.x == 2560 else Vector2i(960,540))
		await frame()
		main._update_map_view_rect()
		main.map_camera.set_view_level(&"detail")
		main.map_camera.focus_world(main.map_runtime.city_position)
		system.preview_dawn = 0.0
		system._on_campaign_time_changed(3600)
		system.set_lighting_enabled(false)
		var original := await shot("%dx%d-original"%[dimensions.x,dimensions.y])
		system.set_lighting_enabled(true)
		var night := await shot("%dx%d-night"%[dimensions.x,dimensions.y])
		check(system.drawn_shadow_count > 0,"%s真实绘制可见投影"%dimensions)
		var changes := count_changes(original,night,Rect2i(0,0,dimensions.x,dimensions.y))
		check(changes > 1000,"%s光影改变实际地图像素"%dimensions)
		var hud_rect := Rect2i(0,0,dimensions.x,int(main.top_bar.size.y*dimensions.y/float(view.size_2d_override.y)))
		# 背景原有0.97透明度；按夜色变化量推导透色上界，单独严查文字核心。
		var ambient_delta: Color = Color.WHITE-system.profile.night_ambient
		var background_alpha: float = main.top_bar.get_theme_stylebox("panel").bg_color.a
		var transparency_bound: float = ceilf(255.0*(1.0-background_alpha)*maxf(ambient_delta.r,maxf(ambient_delta.g,ambient_delta.b)))/255.0
		check(max_difference(original,night,hud_rect) <= transparency_bound+0.0001,"%s顶栏背景差异在既有透明度理论上界内"%dimensions)
		check(max_difference(original,night,hud_rect,true) <= 1.0/255.0+0.0001,"%s顶栏文字核心保留原色"%dimensions)
		system.preview_dawn = 1.0
		system._on_campaign_time_changed(0)
		for ref in system.emitters: ref.get_ref()._process(0)
		var dawn := await shot("%dx%d-dawn"%[dimensions.x,dimensions.y])
		check(count_changes(night,dawn,Rect2i(Vector2i.ZERO,dimensions)) > 1000,"%s黎明与夜间可见差异"%dimensions)
		main.map_camera.show_full_map()
		await shot("%dx%d-overview"%[dimensions.x,dimensions.y])
		check(main.map_camera.screen_view_rect().grow(0.1).encloses(main.map_camera.get_canvas_transform()*main.map_runtime.bounds),"%s全图与镜头边界保持"%dimensions)
	view.size = Vector2i(1280,720)
	view.size_2d_override = Vector2i(960,540)
	await frame()
	main._update_map_view_rect()
	main.map_camera.set_view_level(&"detail")
	main.map_camera.focus_world(main.map_runtime.city_position)
	system.preview_dawn = 0.0
	system._on_campaign_time_changed(3600)
	for ref in system.emitters: ref.get_ref().enabled = false
	var unlit := await shot("city-without-lamps")
	for ref in system.emitters: ref.get_ref()._process(0)
	var lit := await shot("city-with-lamps")
	metrics["lamp_changed_samples"] = count_changes(unlit,lit,Rect2i(0,50,1280,500))
	check(metrics.lamp_changed_samples > 100,"真实局部灯照亮地图，非仅火焰自身变色")
	var actor_rect := Rect2i()
	for ref in system.casters:
		var caster = ref.get_ref()
		if caster.source is ArtVisual and caster.source.animation_kind == &"walk" and caster.source.is_visible_in_tree():
			var screen_rect: Rect2 = main.map_camera.get_canvas_transform()*caster.source.global_transform*caster.source.get_rect()
			actor_rect = Rect2i(screen_rect.position*Vector2(1280.0/960.0,720.0/540.0),screen_rect.size*Vector2(1280.0/960.0,720.0/540.0))
			break
	check(actor_rect.has_area() and count_changes(unlit,lit,actor_rect.intersection(Rect2i(0,0,1280,720))) > 5,"局部灯同时照亮实际农民所在区域")
	main.map_camera.focus_world(Vector2(900,2390))
	await shot("forest-night")
	main.map_camera.focus_world(Vector2(5100,990))
	await shot("mountain-night")
	main.map_camera.focus_world(main.map_runtime.city_position)
	# 受控50精灵负载测渲染增量，不冒充50真实单位AI/寻路性能。
	for index in range(50):
		var unit := Node2D.new()
		unit.position = main.map_runtime.city_position + Vector2(-600+(index%10)*120,200+(index/10)*85)
		main.add_child(unit)
		var art := preload("res://src/gameplay/art/art_visual.gd").new()
		unit.add_child(art)
		art.configure_world("wolf" if index%2 == 0 else "villager",Vector2(20,24))
	await frame()
	await frame()
	for mode in [false,true]:
		system.set_lighting_enabled(mode)
		for index in 20: await get_tree().process_frame
		var timings: Array[float] = []
		var last := Time.get_ticks_usec()
		for index in 120:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			timings.append(float(now-last)/1000.0)
			last = now
		timings.sort()
		metrics["on" if mode else "off"] = {"frame_p95_ms":timings[113],"shadow_draws":system.drawn_shadow_count,"casters":system.casters.size(),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)}
	await shot("city-50-sprite-stress")
	metrics["renderer"] = RenderingServer.get_video_adapter_name()
	metrics["texture_memory_bytes"] = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	metrics["notes"] = "GL受控50精灵增量，不含AI/寻路，不等于GPU计时或自然长局性能；纹理监视为进程总量。"
	var file := FileAccess.open(OUT+"metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(failures)

func check_forest_shadows() -> void:
	var forest := main.get_node("BorderForest")
	var baseline := "--forest-baseline" in OS.get_cmdline_user_args()
	if baseline:
		# 用旧投影参数在同一镜头复现修订前画面。
		for pine in forest.get_children():
			var old_caster: WorldShadowCaster = pine.get_node("WorldShadowCaster")
			old_caster.contact_strength = 1.0
			old_caster.directional_projection_width = 0.0
			old_caster.strength = 1.0
	var tree: Sprite2D = forest.get_node("pine-057")
	var caster: WorldShadowCaster = tree.get_node("WorldShadowCaster")
	main.map_camera.focus_world(tree.global_position+Vector2(65,-85))
	var normal := await shot("forest-before" if baseline else "forest-shadow")
	var strength := caster.strength
	var contact_strength := caster.contact_strength
	caster.contact_strength = 0.0
	var cast_only := await frame()
	var foot := Vector2i(main.map_camera.get_canvas_transform()*tree.global_position*Vector2(view.size)/Vector2(view.size_2d_override))
	var foot_strip := Rect2i(foot-Vector2i(35,4),Vector2i(70,12))
	var strip_changes := count_changes(normal,cast_only,foot_strip)
	check(strip_changes == 0,"树根区无额外横向接触影，隔离差异采样%d"%strip_changes)
	caster.strength = 0.0
	var without_cast := await shot("forest-before-without-sample-cast" if baseline else "forest-without-sample-cast")
	var darkened := 0
	for y in range(foot.y,foot.y+145):
		for x in range(foot.x+8,foot.x+170):
			var base := without_cast.get_pixel(x,y).v
			var drop := base-cast_only.get_pixel(x,y).v
			if drop > 0.025 and drop/maxf(base,0.01) >= 0.28: darkened += 1
	check(darkened >= 300,"树冠方向投影保留至少300个可辨暗部像素，实际%d"%darkened)
	var root_difference := max_difference(without_cast,cast_only,Rect2i(foot-Vector2i(5,1),Vector2i(11,5)))
	check(root_difference > 0.025,"方向投影贴近树根%s，暗化%.3f"%[foot,root_difference])
	caster.strength = strength
	caster.contact_strength = contact_strength
	view.size = Vector2i(3840,2160)
	await frame()
	await shot("forest-before-4k" if baseline else "forest-shadow-4k")

func check_terrain_response() -> void:
	var tile_layer: TileMapLayer = main.terrain_grid_layer.tile_layer
	var receiver := tile_layer.material
	var grid: GridMapModel = main.grid_map_model
	var lamp := WorldLightEmitter.new()
	lamp.radius = 240.0
	lamp.base_energy = 0.65
	lamp.flicker_amount = 0.0
	lamp.hide()
	main.add_child(lamp)
	# 三类样点都取地图内连续区域，避免混入边缘羽化和主城灯火。
	for sample in [[&"grass", Vector2(3520,1450), 0.9,1.1], [&"cliff",Vector2(5040,850),0.58,0.85], [&"water",Vector2(5810,2170),0.24,0.52]]:
		var point := Vector2.INF
		for cell in grid.cells_of_type(sample[0]):
			var center := grid.cell_center(cell)
			if center.distance_squared_to(sample[1]) >= point.distance_squared_to(sample[1]): continue
			var interior := true
			for offset in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
				interior = interior and grid.cell_data(cell+offset).get("terrain_type") == sample[0]
			if interior: point = center
		check(point.is_finite(),"找到%s连续地形样点"%sample[0])
		if not point.is_finite(): continue
		main.map_camera.focus_world(point)
		lamp.global_position = point
		var screen: Vector2 = main.map_camera.get_canvas_transform()*point*Vector2(view.size)/Vector2(view.size_2d_override)
		var patch := Rect2i(Vector2i(screen)-Vector2i(6,6),Vector2i(12,12))
		tile_layer.material = null
		lamp.hide()
		var native_unlit := await frame()
		lamp.show()
		var native_lit := await frame()
		tile_layer.material = receiver
		var lit := await shot("surface-%s-lit"%sample[0])
		lamp.hide()
		var unlit := await shot("surface-%s-unlit"%sample[0])
		check(max_difference(native_unlit,unlit,patch) <= 1.0/255.0,"%s关闭试灯时保留原地表像素"%sample[0])
		var native_gain := mean_light_gain(native_unlit,native_lit,patch)
		var gain := mean_light_gain(unlit,lit,patch)
		var relative := gain/maxf(native_gain,0.0001)
		check(native_gain > 2.0/255.0 and relative >= sample[2] and relative <= sample[3],"%s实景局部受光相对原生灯为%.2f，原生平均RGB增量%.3f"%[sample[0],relative,native_gain])
	lamp.queue_free()
	await get_tree().process_frame

func mean_light_gain(unlit: Image,lit: Image,patch: Rect2i) -> float:
	var gain := 0.0
	for y in range(patch.position.y,patch.end.y):
		for x in range(patch.position.x,patch.end.x):
			var difference := lit.get_pixel(x,y)-unlit.get_pixel(x,y)
			gain += difference.r+difference.g+difference.b
	return gain/(3.0*float(patch.get_area()))

func frame() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func shot(label: String) -> Image:
	var result := await frame()
	check(result.save_png(OUT+label+".png") == OK,"保存 "+label)
	return result

func count_changes(a: Image,b: Image,rect: Rect2i) -> int:
	var changes := 0
	for y in range(rect.position.y,rect.end.y,3):
		for x in range(rect.position.x,rect.end.x,3):
			if a.get_pixel(x,y) != b.get_pixel(x,y): changes += 1
	return changes

func max_difference(a: Image,b: Image,rect: Rect2i,bright_core: bool = false) -> float:
	var difference: float = 0.0
	for y in range(rect.position.y,rect.end.y,3):
		for x in range(rect.position.x,rect.end.x,3):
			var before := a.get_pixel(x,y)
			if bright_core and minf(before.r,minf(before.g,before.b)) < 0.67: continue
			var c := a.get_pixel(x,y)-b.get_pixel(x,y)
			difference = maxf(difference,maxf(absf(c.r),maxf(absf(c.g),absf(c.b))))
	return difference

func check(value: bool,label: String) -> void:
	if value: print("PASS: "+label)
	else:
		failures += 1
		push_error("FAIL: "+label)
