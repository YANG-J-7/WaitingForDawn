extends Node
## 必须使用真实GL运行；同时检查主场景和隔离地表的实际像素。
const MAIN = preload("res://src/main/main.tscn")
const Layer = preload("res://src/gameplay/art/layered_map_layer.gd")
const Grid = preload("res://src/gameplay/grid/grid_map_model.gd")
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
const OUT = "res://tests/reports/images/grass-static-2026-10-27/"
var failures := 0
var metrics: Dictionary = {}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await verify_ground()
	await capture_game()
	var file := FileAccess.open(OUT + "metrics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "\t") + "\n")
	get_tree().quit(failures)

func pixels(view: SubViewport) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func check(condition: bool, label: String) -> void:
	if condition: print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func different(a: Image, b: Image, rect: Rect2i) -> int:
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not a.get_pixel(x,y).is_equal_approx(b.get_pixel(x,y)): count += 1
	return count

func max_channel_difference(a: Image, b: Image) -> float:
	var result := 0.0
	var bytes_a := a.get_data()
	var bytes_b := b.get_data()
	for index in bytes_a.size():
		result = maxf(result, absf(float(bytes_a[index])-float(bytes_b[index])))
	return result

func focus(view: SubViewport, target: Vector2, scale_factor: float) -> void:
	view.canvas_transform = Transform2D(Vector2(scale_factor,0), Vector2(0,scale_factor), Vector2(view.size)*.5-target*scale_factor)

func verify_ground() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1280,720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var layer := Layer.new()
	layer.configure(Grid.new())
	view.add_child(layer)
	var saved_material: Material = layer.material
	check(Layer.GRASS_DETAIL.get_image().has_mipmaps(), "导入高清细节包含缩远mipmap")
	check(Layer.GRASS_DETAIL.get_size() == Vector2(1448,1086), "原生细节未缩小或插值放大")
	check(1.6 * 4.0 / (1448.0/216.0) <= 1.0, "4K窗口最大镜头像素预算无需放大源像素")
	# 在纯草地四块交点检查18片与单张地表输出一致。
	focus(view, Vector2(2352,960), 1.6*1280.0/960.0)
	var tiled := await pixels(view)
	var saved_chunks: Array[Dictionary] = layer.chunks.duplicate()
	layer.chunks = [{"texture": load("res://assets/map/dawn_wide_v3/base.png"), "rect": Definition.BOUNDS}]
	var single := await pixels(view)
	single.save_png(OUT + "single-ground-reference.png")
	var seam_difference := different(tiled, single, Rect2i(0,0,1280,720))
	# GL对不同大小矩形的插值有末位舍入差异，实测只有1/255；
	# 不要求字节相同，但不允许超过一个8位色阶的纹理或接缝差异。
	var seam_max := max_channel_difference(tiled, single)
	check(seam_max <= 1.0, "跨四块交点与整张底图最大通道差≤1：实际%.0f/255" % seam_max)
	metrics["chunk_seam_changed_pixels"] = seam_difference
	metrics["chunk_seam_max_channel_difference"] = seam_max
	layer.chunks = saved_chunks
	check(tiled.save_png(OUT + "chunk-crossing-max.png") == OK, "保存最大倍率四块交点")
	layer.material = null
	var old := await pixels(view)
	var changed := different(tiled, old, Rect2i(0,0,1280,720))
	check(changed > 800000, "新版草地实际进入渲染：%d像素变化" % changed)
	metrics["grass_changed_pixels"] = changed
	old.save_png(OUT + "grass-before.png")
	layer.material = saved_material
	var baseline := await pixels(view)
	for frame in range(5): await get_tree().process_frame
	var later := await pixels(view)
	check(different(baseline, later, Rect2i(0,0,1280,720)) == 0, "静态地表跨帧完全稳定，没有昆虫或时间漂移")
	# 先平移再返回，纹理必须固定在地图坐标上。
	focus(view, Vector2(2452,1020), 1.6*1280.0/960.0)
	await pixels(view)
	focus(view, Vector2(2352,960), 1.6*1280.0/960.0)
	var returned := await pixels(view)
	check(different(baseline, returned, Rect2i(0,0,1280,720)) == 0, "平移返回草叶位置不跳变")
	for point in [Vector2(5800,900),Vector2(6500,2400)]:
		focus(view, point, 2.0)
		layer.material = null
		var protected_old := await pixels(view)
		layer.material = saved_material
		var protected_new := await pixels(view)
		var delta := different(protected_old, protected_new, Rect2i(0,0,1280,720))
		check(delta == 0, "保护山区/湖岸%s与旧地表像素相同：%d差异" % [point,delta])
		metrics["protected_%d_%d" % [point.x,point.y]] = delta
	view.queue_free()
	await get_tree().process_frame

func capture_game() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1280,720)
	view.size_2d_override = Vector2i(960,540)
	view.size_2d_override_stretch = true
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
	main.get_node("TownHallVisual").set_process(false)
	main.notice_seconds = 0.0
	main.notice_panel.hide()
	for resolution in [Vector2i(1280,720),Vector2i(3840,2160)]:
		view.size = resolution
		main.map_camera.zoom = Vector2.ONE*1.6
		for place in [{"name":"city", "point":Definition.CITY_POSITION}, {"name":"plain", "point":Vector2(1800,1512)}]:
			main.map_camera.focus_world(place.point)
			var shot := await pixels(view)
			check(shot.get_size() == resolution, "%s实际渲染目标尺寸%s" % [place.name,resolution])
			check(shot.save_png(OUT + "%dx%d-%s-max.png" % [resolution.x,resolution.y,place.name]) == OK, "保存实景最大倍率%s-%s" % [resolution,place.name])
		if resolution.x == 3840:
			# 1:1局部裁图便于检查原生4K细节，不做缩放。
			var shot := await pixels(view)
			shot.get_region(Rect2i(1536,780,768,640)).save_png(OUT + "4k-native-crop.png")
	main._on_reset_pressed()
	check(main.terrain_grid_layer.material != null and not get_tree().paused, "重开保留静态草地并恢复暂停状态")
	view.queue_free()
	await get_tree().process_frame
