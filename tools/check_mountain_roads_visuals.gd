extends Node
## GL实景截图：薄顶栏、全图路网、矿点坡道、草台建造预览。
var viewport: SubViewport
var main: Node
var failures := 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("道路视觉检查需要真实GL后端")
		get_tree().quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	main = preload("res://src/main/main.tscn").instantiate()
	viewport.add_child.call_deferred(main)
	await frames()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.bottom_panel.hide()
	var road_layer: Node2D = main.get_node("MountainRoadLayer")
	road_layer.hide()
	await frames()
	var before: Image = viewport.get_texture().get_image()
	road_layer.show()
	await frames()
	var after: Image = viewport.get_texture().get_image()
	check(is_equal_approx(main.top_bar.size.y,32.0), "GL顶栏实际高度为32逻辑像素")
	verify_road_pixels(before, after)
	await capture("thin-hud-mountain-roads-full")
	main.get_node("HUD").hide()
	main.map_camera.zoom = Vector2.ONE * 1.1
	main.map_camera.position = Vector2(1370,480)
	main.map_camera.force_update_scroll()
	await capture("mountain-roads-west-mines")
	main.map_camera.position = Vector2(2190,615)
	main.map_camera.force_update_scroll()
	await capture("mountain-roads-east-mine")
	main.map_camera.zoom = Vector2.ONE * 1.6
	main.map_camera.position = Vector2(1250,410)
	main.map_camera.force_update_scroll()
	await capture("mountain-rock-closeup")
	main.map_camera.zoom = Vector2.ONE * 1.1
	main._on_start_pressed()
	main.opening_draft.active = false
	RunState.start_current_wave()
	RunEconomy.add_resource(&"wood",1000)
	RunEconomy.add_resource(&"stone",1000)
	var farm = preload("res://src/data/cards/farm.tres")
	for point in [Vector2(1116,252),Vector2(1368,360)]:
		var card_id: int = main.run_card_inventory.add_card(farm,1)
		check(main._try_place_map_building_card(card_id,point), "GL山地草台真实落成建筑：%s" % point)
	main.get_node("HUD").hide()
	main.map_camera.position = Vector2(1370,480)
	main.map_camera.force_update_scroll()
	await capture("mountain-grass-building")
	get_tree().quit(failures)

func verify_road_pixels(before: Image, after: Image) -> void:
	var changed := 0
	var outside := 0
	var inverse: Transform2D = main.map_camera.get_canvas_transform().affine_inverse()
	for y in range(40,720,2):
		for x in range(0,1280,2):
			var a := before.get_pixel(x,y)
			var b := after.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))) <= 1.0/255.0 + 0.000001:
				continue
			changed += 1
			var world := inverse * Vector2(x+0.5,y+0.5)
			var inside := false
			for shift in [Vector2.ZERO,Vector2(2,0),Vector2(-2,0),Vector2(0,2),Vector2(0,-2)]:
				inside = inside or MountainRoadData.contains_point(world+shift)
			if not inside:
				outside += 1
	print("METRIC: 路网显示变化抽样=%d 路幅外变化=%d" % [changed,outside])
	check(changed > 1000 and outside == 0, "GL道路可见且只影响设计路幅，不重绘其他地图")

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func frames() -> void:
	for index in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	await frames()
	var path := ProjectSettings.globalize_path("res://tests/reports/images/roads-restored-2026-10-10/" + name + ".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error := viewport.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("道路实景截图保存失败")
		get_tree().quit(1)
	check(error == OK, "GL保存实景截图：" + name)
