extends SceneTree
## 三款露土区域离线装配；内部不单独处理每块边缘，保持连续母图。

const PACK := "res://assets/map/mud_regions_v1/"
const IDS := ["01-sparse-grass", "02-stony-earth", "03-damp-earth"]

func _initialize() -> void:
	assemble.call_deferred()

func assemble() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("离线装配需要GL渲染器")
		quit(1)
		return
	var grass_path := ProjectSettings.globalize_path("res://assets/map/grass_variants_v1/grass.png")
	var grass_original := Image.load_from_file(grass_path)
	for id in IDS:
		var original := Image.load_from_file(ProjectSettings.globalize_path(PACK + "source/" + id + ".png"))
		if original == null:
			push_error("缺少生成原稿：" + id)
			quit(1)
			return
		var side := mini(original.get_width() / 3, original.get_height() / 2)
		if side > mini(grass_original.get_width(), grass_original.get_height()):
			push_error("现有底草原生尺寸不足，不能放大装配")
			quit(1)
			return
		var grass_origin := (grass_original.get_size() - Vector2i(side, side)) / 2
		var grass_crop := grass_original.get_region(Rect2i(grass_origin, Vector2i(side, side)))
		var grass := ImageTexture.create_from_image(grass_crop)
		var size := Vector2i(side * 3, side * 2)
		var origin := (original.get_size() - size) / 2
		var aligned := original.get_region(Rect2i(origin, size))
		var output_dir: String = PACK + id + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
		var region := ImageTexture.create_from_image(aligned)
		var output := await render_region(grass, region, side, false)
		if output.save_png(output_dir + "assembled.png") != OK:
			push_error("区域保存失败：" + id)
			quit(1)
			return
		var companion := await render_region(grass, region, side, true)
		if companion.save_png(output_dir + "grass-companion.png") != OK:
			push_error("配套草地保存失败：" + id)
			quit(1)
			return
		var meta := {"source_size": [original.get_width(), original.get_height()],
			"crop_origin": [origin.x, origin.y], "region_size": [size.x, size.y],
			"tile_size": side, "grid": [3, 2], "resized": false,
			"grass_source_crop": [grass_origin.x, grass_origin.y, side, side], "grass_native_density": 1.0}
		var file := FileAccess.open(output_dir + "assembly.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(meta, "\t") + "\n")
		file.close()
		print("PASS: assembled %s (%d x %d), six %d-square tiles" % [id, size.x, size.y, side])
	quit(0)

func render_region(grass: Texture2D, region: Texture2D, side: int, plain: bool) -> Image:
	var view := SubViewport.new()
	view.size = Vector2i(side, side) if plain else Vector2i(side * 3, side * 2)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var rect := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = load("res://tools/assemble_mud_regions.gdshader")
	material.set_shader_parameter("existing_grass", grass)
	material.set_shader_parameter("mud_region", region)
	material.set_shader_parameter("grid_size", Vector2.ONE if plain else Vector2(3, 2))
	material.set_shader_parameter("tile_size", float(side))
	material.set_shader_parameter("plain_grass", plain)
	rect.material = material
	rect.size = Vector2(view.size)
	view.add_child(rect)
	await process_frame
	await RenderingServer.frame_post_draw
	var output := view.get_texture().get_image()
	output.convert(Image.FORMAT_RGB8)
	view.queue_free()
	await process_frame
	return output
