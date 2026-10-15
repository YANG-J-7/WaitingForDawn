extends Node

# 必须在真实图形后端执行，禁止以无头渲染代替像素验证。
const BASE: Texture2D = preload("res://assets/map/moonlit_terrain_detail.png")
const OLD_BASE: Texture2D = preload("res://assets/map/moonlit_resource_map_16x9_terrain_crisp.png")
var failures := 0
var viewport: SubViewport
var camera: Camera2D
var terrain: Node2D
var output: String


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("地形视觉验证需要真实GL后端")
		get_tree().quit(1)
		return
	output = ProjectSettings.globalize_path("res://.codex-temp/terrain-detail-20261008")
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main := preload("res://src/main/main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	main.get_node("HUD").hide()
	# 停止实体动画，让前后差异只来自左侧平原清理开关。
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var cleanup_material := main.get_node("TerrainGridLayer").material as ShaderMaterial
	cleanup_material.set_shader_parameter("clear_left_plain_rocks", false)
	var before_cleanup := await capture("before-left-plain-cleanup")
	cleanup_material.set_shader_parameter("clear_left_plain_rocks", true)
	var after_cleanup := await capture("full-map")
	verify_cleanup(before_cleanup, after_cleanup, main.map_camera)
	var grass_layer := main.get_node("TerrainGridLayer") as TerrainGridLayer
	var detail_atlas := grass_layer.grass_atlas
	# 同镜头、同建筑、同材质比较旧36像素草地和原生高密度草地。
	main.map_camera.position = Vector2(1320, 1000)
	for comparison_zoom in [1.0, 1.6]:
		main.map_camera.zoom = Vector2.ONE * comparison_zoom
		main.map_camera.force_update_scroll()
		grass_layer.grass_atlas = preload("res://assets/tilesets/moonlit_grass_v2/moonlit_grass_atlas.png")
		grass_layer.queue_redraw()
		await capture("grass-density-before-%.1fx" % comparison_zoom)
		grass_layer.grass_atlas = detail_atlas
		grass_layer.queue_redraw()
		await capture("grass-density-after-%.1fx" % comparison_zoom)
	main.map_camera.position = Vector2(1080, 1020)
	main.map_camera.zoom = Vector2.ONE * 1.6
	main.map_camera.force_update_scroll()
	await capture("left-plain-cleanup-1.6x")
	main.queue_free()
	await get_tree().process_frame
	var base := Sprite2D.new()
	base.texture = BASE
	base.centered = false
	base.scale = Vector2(2880, 1620) / BASE.get_size()
	base.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	viewport.add_child(base)
	var grid := preload("res://src/gameplay/grid/grid_map_model.gd").new()
	preload("res://src/gameplay/grid/terrain_map_data.gd").apply_to(grid)
	terrain = preload("res://src/gameplay/art/terrain_grid_layer.gd").new()
	terrain.configure(grid)
	viewport.add_child(terrain)
	camera = Camera2D.new()
	viewport.add_child(camera)
	camera.position = Vector2(1440, 810)
	camera.zoom = Vector2.ONE / 3.0
	camera.force_update_scroll()
	var clean_ground := await capture("plain-ground")
	# 测试夹具：无岩面单色遮罩只用于生成同图集、同亮度的参考，不生成运行美术。
	var fixture_image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	fixture_image.fill(Color(0.12, 0.22, 0.19))
	var fixture := ImageTexture.create_from_image(fixture_image)
	var ground_material := terrain.material as ShaderMaterial
	ground_material.set_shader_parameter("relief_source", fixture)
	ground_material.set_shader_parameter("macro_source", fixture)
	var uniform_ground := await capture("uniform-grass-reference")
	verify_plain_color(clean_ground, uniform_ground)
	camera.position = Vector2(650, 950)
	camera.zoom = Vector2.ONE * 1.6
	camera.force_update_scroll()
	var detail_reference := await capture("grass-detail-reference-1.6x")
	var new_atlas: Texture2D = terrain.grass_atlas
	terrain.grass_atlas = preload("res://assets/tilesets/moonlit_grass_v2/moonlit_grass_atlas.png")
	terrain.queue_redraw()
	var coarse_reference := await capture("grass-coarse-reference-1.6x")
	verify_grass_detail(coarse_reference, detail_reference)
	terrain.grass_atlas = new_atlas
	terrain.queue_redraw()
	ground_material.set_shader_parameter("relief_source", BASE)
	ground_material.set_shader_parameter("macro_source", BASE)
	for zoom_value in [1.0, 1.5, 1.6]:
		camera.zoom = Vector2.ONE * zoom_value
		camera.position = Vector2(1250, 470)
		camera.force_update_scroll()
		terrain.show()
		var rendered := await capture("hill-%.1fx" % zoom_value)
		terrain.hide()
		var original := await capture("original-hill-%.1fx" % zoom_value)
		verify_relief(rendered, original, zoom_value)
	camera.position = Vector2(1300, 1030)
	camera.zoom = Vector2.ONE * 1.5
	camera.force_update_scroll()
	terrain.show()
	await capture("grass-1.5x")
	# 在同一个镜头和相同草地材质下，仅切换地形源图做前后对照。
	camera.zoom = Vector2.ONE * 1.6
	var relief_material := terrain.material as ShaderMaterial
	for area in [{"name": "plain", "center": Vector2(1000, 1020)}, {"name": "shore", "center": Vector2(1700, 1230)}, {"name": "cliff", "center": Vector2(1250, 470)}, {"name": "water", "center": Vector2(2300, 1390)}]:
		camera.position = area.center
		camera.force_update_scroll()
		base.texture = OLD_BASE
		relief_material.set_shader_parameter("left_plain_cleanup_polygon", PackedVector2Array(TerrainGridLayer.LEGACY_LEFT_PLAIN_CLEANUP_POLYGON))
		base.scale = Vector2(2880, 1620) / OLD_BASE.get_size()
		base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		relief_material.set_shader_parameter("relief_source", OLD_BASE)
		relief_material.set_shader_parameter("macro_source", OLD_BASE)
		var old_render := await capture("before-%s-1.6x" % area.name)
		base.texture = BASE
		relief_material.set_shader_parameter("left_plain_cleanup_polygon", PackedVector2Array(TerrainGridLayer.LEFT_PLAIN_CLEANUP_POLYGON))
		base.scale = Vector2(2880, 1620) / BASE.get_size()
		base.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		relief_material.set_shader_parameter("relief_source", BASE)
		relief_material.set_shader_parameter("macro_source", BASE)
		var new_render := await capture("after-%s-1.6x" % area.name)
		if area.name in ["cliff", "shore", "water"]:
			verify_terrain_detail(old_render, new_render, area.name)
	for area in [{"name": "seam-lower-shore", "center": Vector2(1440, 1430)}, {"name": "seam-upper-cliff", "center": Vector2(1440, 470)}, {"name": "seam-middle", "center": Vector2(1900, 810)}]:
		camera.position = area.center
		camera.force_update_scroll()
		var joined_render := await capture("%s-1.6x" % area.name)
		if area.name == "seam-lower-shore":
			terrain.hide()
			var shoreline_source := await capture("original-lower-shore-1.6x")
			terrain.show()
			verify_lower_shore(joined_render, shoreline_source)
	get_tree().quit(failures)


func capture(label: String) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image()
	check(result.save_png(output.path_join(label + ".png")) == OK, "保存截图：" + label)
	return result


func verify_relief(rendered: Image, original: Image, zoom_value: float) -> void:
	var rock_count := 0
	var rock_difference := 0.0
	var grass_changed := 0
	var transform := camera.get_canvas_transform().affine_inverse()
	var source := BASE.get_image()
	for y in range(20, 520, 2):
		for x in range(20, 940, 2):
			var world := transform * Vector2(x, y)
			var texture_position := world * Vector2(source.get_size()) / Vector2(2880, 1620)
			var color := source.get_pixel(int(texture_position.x), int(texture_position.y))
			var before := original.get_pixel(x, y)
			var after := rendered.get_pixel(x, y)
			var difference := absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b)
			if color.b - color.g > 0.075 and not Geometry2D.is_point_in_polygon(world, terrain.LEFT_PLAIN_CLEANUP_POLYGON):
				rock_count += 1
				rock_difference += difference
			elif color.g - color.b > 0.015 and difference > 0.03:
				grass_changed += 1
	var average := rock_difference / maxf(1.0, rock_count)
	print("METRIC: %.1fx 岩面像素=%d 平均RGB差=%.6f 草地改动像素=%d" % [zoom_value, rock_count, average, grass_changed])
	check(rock_count > 100 and average < 0.015, "%.1fx草地保留原始岩面亮暗" % zoom_value)
	check(grass_changed > 500, "%.1fx草地新材质真实绘制" % zoom_value)


func verify_cleanup(before: Image, after: Image, map_camera: Camera2D) -> void:
	var inverse := map_camera.get_canvas_transform().affine_inverse()
	var region: PackedVector2Array = preload("res://src/gameplay/art/terrain_grid_layer.gd").LEFT_PLAIN_CLEANUP_POLYGON
	var outside_changed := 0
	var outside_rounding := 0
	var inside_changed := 0
	for y in range(before.get_height()):
		for x in range(before.get_width()):
			if before.get_pixel(x, y) == after.get_pixel(x, y):
				continue
			# 光栅化取像素中心；取左上角会把边界像素误算成框外。
			# 调色近邻最多向轮廓外延伸40世界像素，保护真正的岩面本体。
			var world := inverse * Vector2(x + 0.5, y + 0.5)
			# 半开射线与着色器一致，避免Geometry2D斜射线恰好穿过顶点时误判内点。
			var in_region := inside_cleanup_polygon(world, region)
			for i in range(region.size()):
				in_region = in_region or world.distance_to(Geometry2D.get_closest_point_to_segment(world, region[i], region[(i + 1) % region.size()])) <= 40.0
			if in_region:
				inside_changed += 1
			else:
				var old_color := before.get_pixel(x, y)
				var new_color := after.get_pixel(x, y)
				var max_delta := maxf(absf(old_color.r - new_color.r), maxf(absf(old_color.g - new_color.g), absf(old_color.b - new_color.b)))
				# 允许GL浮点输出到8位PNG时的一色阶舍入，不放宽真实内容差异。
				if max_delta > 1.0 / 255.0 + 0.000001:
					outside_changed += 1
					if outside_changed <= 3:
						print("DIFF: 区域外像素=%s 世界位置=%s 差异=%.6f" % [Vector2i(x, y), world, max_delta])
				else:
					outside_rounding += 1
	print("METRIC: 左侧平原变化像素=%d 区域外内容变化像素=%d 一色阶舍入像素=%d" % [inside_changed, outside_changed, outside_rounding])
	check(inside_changed > 100, "左侧整片平原覆盖并统一调色")
	check(outside_changed == 0, "清理区域外无超出一色阶的像素差异，保留其他地形与实体")


func inside_cleanup_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		if (a.y > point.y) != (b.y > point.y):
			var crossing_x := a.x + (point.y - a.y) * (b.x - a.x) / (b.y - a.y)
			if point.x < crossing_x:
				inside = not inside
	return inside


func verify_grass_detail(coarse: Image, detailed: Image) -> void:
	var coarse_colors := {}
	var detail_colors := {}
	var coarse_blocks := 0
	var detail_blocks := 0
	var total := 0
	for y in range(20, 520, 2):
		for x in range(20, 940, 2):
			total += 1
			coarse_colors[coarse.get_pixel(x, y).to_rgba32()] = true
			detail_colors[detailed.get_pixel(x, y).to_rgba32()] = true
			if same_pixel_block(coarse, x, y):
				coarse_blocks += 1
			if same_pixel_block(detailed, x, y):
				detail_blocks += 1
	print("METRIC: 最大1.6倍率草地颜色层次 旧=%d 新=%d；同色2×2屏幕块比例 旧=%.4f 新=%.4f" % [coarse_colors.size(), detail_colors.size(), float(coarse_blocks) / total, float(detail_blocks) / total])
	check(detail_colors.size() > coarse_colors.size() * 2, "最大倍率保留更多源图细节明暗，不是放大旧低分辨率草地")
	check(detail_blocks < coarse_blocks, "最大倍率同色大像素块减少，细草叶边缘保持变化")


func same_pixel_block(picture: Image, x: int, y: int) -> bool:
	var color := picture.get_pixel(x, y)
	return color == picture.get_pixel(x + 1, y) and color == picture.get_pixel(x, y + 1) and color == picture.get_pixel(x + 1, y + 1)


func verify_lower_shore(rendered: Image, source: Image) -> void:
	var inverse := camera.get_canvas_transform().affine_inverse()
	var sampled := 0
	var difference := 0.0
	for y in range(20, 520, 2):
		for x in range(20, 940, 2):
			var world := inverse * Vector2(x + 0.5, y + 0.5)
			var before := source.get_pixel(x, y)
			# 只抽样原清理轮廓会误遮的左下冷蓝湖岸/水面，不能以别处岩壁代替。
			if not inside_cleanup_polygon(world, PackedVector2Array(TerrainGridLayer.LEGACY_LEFT_PLAIN_CLEANUP_POLYGON)) or before.b - before.g < 0.09:
				continue
			var after := rendered.get_pixel(x, y)
			sampled += 1
			difference += absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b)
	var average := difference / maxi(1, sampled)
	print("METRIC: 原清理区内左下湖岸保护抽样=%d 平均RGB差=%.6f" % [sampled, average])
	check(sampled > 100 and average < 0.015, "最大倍率左下湖岸未被平原除石遮罩截断")


func verify_terrain_detail(before: Image, after: Image, label: String) -> void:
	var sampled := 0
	var old_blocks := 0
	var new_blocks := 0
	var old_colors := {}
	var new_colors := {}
	for y in range(20, 520, 2):
		for x in range(20, 940, 2):
			var old_color := before.get_pixel(x, y)
			var new_color := after.get_pixel(x, y)
			# 只比较双方均为冷蓝岩面/水面的像素，排除草地和边界轻微位移。
			if old_color.b - old_color.g <= 0.035 or new_color.b - new_color.g <= 0.035:
				continue
			sampled += 1
			old_colors[old_color.to_rgba32()] = true
			new_colors[new_color.to_rgba32()] = true
			old_blocks += int(same_pixel_block(before, x, y))
			new_blocks += int(same_pixel_block(after, x, y))
	print("METRIC: %s最大1.6倍率共同岩面/水面抽样=%d；同色2×2屏幕块 旧=%.6f 新=%.6f；颜色层次 旧=%d 新=%d" % [label, sampled, float(old_blocks) / maxi(1, sampled), float(new_blocks) / maxi(1, sampled), old_colors.size(), new_colors.size()])
	check(sampled > 100 and new_blocks < old_blocks * 0.5, "%s最大倍率粗像素同色块减少超过一半" % label)
	check(new_colors.size() > old_colors.size() * 1.5, "%s精修岩面/水面保留更多明暗细节" % label)


func verify_plain_color(rendered: Image, reference: Image) -> void:
	var regions := [
		{"name": "上方", "rect": Rect2(100, 50, 450, 450)},
		{"name": "原红框", "rect": Rect2(250, 650, 650, 500)},
		{"name": "下方", "rect": Rect2(200, 1340, 800, 220)},
	]
	var inverse := camera.get_canvas_transform().affine_inverse()
	for region in regions:
		var sampled := 0
		var different := 0
		for y in range(0, rendered.get_height(), 2):
			for x in range(0, rendered.get_width(), 2):
				if not region.rect.has_point(inverse * Vector2(x + 0.5, y + 0.5)):
					continue
				sampled += 1
				var actual := rendered.get_pixel(x, y)
				var expected := reference.get_pixel(x, y)
				if maxf(absf(actual.r - expected.r), maxf(absf(actual.g - expected.g), absf(actual.b - expected.b))) > 1.0 / 255.0 + 0.000001:
					different += 1
		print("METRIC: %s平原草地参考抽样=%d 色差或残影像素=%d" % [region.name, sampled, different])
		check(sampled > 100 and different == 0, "%s平原无石头残影且共用统一草地颜色" % region.name)


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
