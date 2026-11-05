extends Node
## 真实GL验证：原画面/夜间/黎明、局部灯照明、HUD隔离、多画幅与受控压力。
const OUT := "res://tests/reports/images/world-lighting-readable-2026-11-05/"
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
