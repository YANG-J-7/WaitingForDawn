extends SceneTree
## 离线素材装配；不绘制草叶或石头，不修改生成原稿，不改正式关卡。

const PACK := "res://assets/map/grass_variants_v1/"
const BASE := "res://assets/map/grass_reference_v3/grass.png"
const NAMES := ["grass", "small-stones", "boulders", "wildflowers"]

func _initialize() -> void:
	assemble.call_deferred()

func assemble() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("装配需要真实GL渲染器，请勿添加--headless")
		quit(1)
		return
	var base := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(BASE)))
	for tile_name in NAMES:
		var raw_path: String = BASE if tile_name == "grass" else PACK + "source/" + tile_name + ".png"
		var source := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(raw_path)))
		var view := SubViewport.new()
		view.size = Vector2i(1254, 1254)
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var rect := ColorRect.new()
		rect.size = Vector2(1254, 1254)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://tools/assemble_grass_variant_tiles.gdshader")
		mat.set_shader_parameter("base_grass", base)
		mat.set_shader_parameter("dressed_grass", source)
		mat.set_shader_parameter("plain_grass", tile_name == "grass")
		rect.material = mat
		view.add_child(rect)
		await process_frame
		await RenderingServer.frame_post_draw
		var output := view.get_texture().get_image()
		output.convert(Image.FORMAT_RGB8)
		var result := output.save_png(PACK + tile_name + ".png")
		if result != OK:
			push_error("保存失败：" + tile_name)
			quit(1)
			return
		print("PASS: assembled " + tile_name)
		view.queue_free()
		await process_frame
	quit(0)
