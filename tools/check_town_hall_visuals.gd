extends Node
const MAIN = preload("res://src/main/main.tscn")
const OUT := "res://tests/reports/images/town-hall-2026-10-25/"
var failures := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for resolution in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1024,768)]:
		var view := SubViewport.new()
		view.size = resolution
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(view)
		var main := MAIN.instantiate()
		view.add_child(main)
		check(main.start_button.is_visible_in_tree() and main.top_bar.is_visible_in_tree(), "启动界面及开始按钮可见")
		await capture(view,"%dx%d-startup" % [resolution.x,resolution.y])
		main.start_button.pressed.emit()
		check(main.day_setup_panel.is_visible_in_tree() and main.card_buttons.size() == 6, "开始后显示六张选卡")
		main.opening_draft.set_countdown_paused(true)
		for index in [0,1,3,4]: main.card_buttons[index].pressed.emit()
		main.ready_button.pressed.emit()
		check(main.hand_bar.is_visible_in_tree() and not main.day_setup_panel.visible, "选四迎战后显示手牌及游戏界面")
		main.wave_controller.set_process(false)
		for enemy in main.wave_controller.enemies: enemy.set_physics_process(false)
		main.farmer_manager.set_process(false)
		for frame in range(4): await get_tree().process_frame
		main.notice_seconds = 0.0
		main.notice_panel.hide()
		var city: Node2D = main.get_node("TownHallVisual")
		city.set_process(false)
		main.map_camera.reset_view()
		await capture(view,"%dx%d-default" % [resolution.x,resolution.y])
		await verify_shadows(view, main, city, "默认")
		main.map_camera.zoom = Vector2.ONE*1.6
		main.map_camera.focus_world(city.position + Vector2(0,-55))
		await capture(view,"%dx%d-close" % [resolution.x,resolution.y])
		await verify_shadows(view, main, city, "近景")
		if resolution == Vector2i(1280,720):
			# 在主城下方的空地采样，证明投影实际进入GL画面，而非被地形层盖住。
			await RenderingServer.frame_post_draw
			var with_shadow: Image = view.get_texture().get_image()
			city.grounding.hide()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var without_shadow: Image = view.get_texture().get_image()
			var changed := 0
			var foot: Vector2 = main.map_camera.get_canvas_transform() * city.position
			for x in range(int(foot.x), int(foot.x + 105)):
				for y in range(int(foot.y + 3),int(foot.y + 30)):
					var difference := with_shadow.get_pixel(x,y) - without_shadow.get_pixel(x,y)
					if absf(difference.r) + absf(difference.g) + absf(difference.b) > .008:
						changed += 1
			check(changed > 100,"主城右下投影实际可见：%d个变化像素" % changed)
			city.grounding.show()
			for index in range(24):
				city.animation_time = float(index)*.10
				city._apply_animation()
				await capture(view,"loop-%02d" % index)
			var material_time: float = city.window_material.get_shader_parameter("animation_time")
			get_tree().paused = true
			process_mode = Node.PROCESS_MODE_ALWAYS
			city._process(.5)
			check(is_equal_approx(material_time,city.window_material.get_shader_parameter("animation_time")),"暂停时窗光着色器与动画时钟冻结")
			await capture(view,"paused")
			get_tree().paused = false
			main._on_reset_pressed()
			check(city.animation_time == 0.0,"GL重开复位动画")
			await capture(view,"reset")
		main.queue_free()
		view.queue_free()
		await get_tree().process_frame
	get_tree().quit(failures)


func verify_shadows(view: SubViewport, main: Node, city: Node2D, label: String) -> void:
	# 冻结所有动画后分别开关两层；不能用“某处像素发生变化”替代墙脚定位。
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var full := view.get_texture().get_image()
	var contact: Sprite2D = city.grounding.get_node("ContactShadow")
	contact.hide()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var without_contact := view.get_texture().get_image()
	# 实际左墙、台阶、右墙外侧地面，均在主体轮廓之外。
	for sample in [Vector2(-60,-17), Vector2(-20,0), Vector2(60,-10)]:
		var point: Vector2 = main.map_camera.get_canvas_transform() * (city.position + sample)
		var reduction := darkness_reduction(full, without_contact, Vector2i(point))
		check(reduction > .07, "%s墙脚接触影%s亮度降低%.1f%%" % [label, sample, reduction*100])
	contact.show()
	city.grounding.get_node("CastShadow").hide()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var without_cast := view.get_texture().get_image()
	var cast_point: Vector2 = main.map_camera.get_canvas_transform() * (city.position + Vector2(50,25))
	check(darkness_reduction(full, without_cast, Vector2i(cast_point)) > .20, label+"右下投影有明确对比")
	city.grounding.get_node("CastShadow").show()
	get_tree().paused = false


func darkness_reduction(shadowed: Image, clear: Image, point: Vector2i) -> float:
	var light := 0.0
	var difference := 0.0
	for x in range(point.x-1,point.x+2):
		for y in range(point.y-1,point.y+2):
			var a := shadowed.get_pixel(x,y)
			var b := clear.get_pixel(x,y)
			light += b.get_luminance()
			difference += b.get_luminance() - a.get_luminance()
	return difference / maxf(light, .001)


func capture(view: SubViewport, label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := "res://.codex-temp/town-hall-loop/" if label.begins_with("loop-") else OUT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	check(view.get_texture().get_image().save_png(folder+label+".png")==OK,"GL截图："+label)


func check(condition: bool, label: String) -> void:
	if condition: print("PASS: "+label)
	else:
		failures += 1
		push_error("FAIL: "+label)
