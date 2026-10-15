extends Node

const GridMapModelScript = preload("res://src/gameplay/grid/grid_map_model.gd")
const TerrainMapDataScript = preload("res://src/gameplay/grid/terrain_map_data.gd")
const TerrainGridLayerScript = preload("res://src/gameplay/art/terrain_grid_layer.gd")
const BuildingGroundingScript = preload("res://src/gameplay/art/building_grounding.gd")
const GRASS_ATLAS_PATH := "res://assets/tilesets/moonlit_grass_detail_v3/moonlit_grass_atlas.png"
const GRASS_BUNDLE_PATH := "res://assets/tilesets/moonlit_grass_detail_v3/terrain-bundle.json"
const CRISP_TERRAIN_PATH := "res://assets/map/moonlit_terrain_detail.png"
const MAIN_SCENE: PackedScene = preload("res://src/main/main.tscn")

var failures: int = 0


func _ready() -> void:
	var grid = GridMapModelScript.new()
	TerrainMapDataScript.apply_to(grid)
	var counts := {&"grass": 0, &"shore": 0, &"water": 0, &"cliff": 0}
	for y in range(grid.grid_size.y):
		for x in range(grid.grid_size.x):
			var data: Dictionary = grid.cell_data(Vector2i(x, y))
			var terrain: StringName = data.terrain_type
			if counts.has(terrain):
				counts[terrain] += 1
	check(counts[&"grass"] > 2000, "地图保留大面积可建草地")
	check(counts[&"shore"] > 20, "湖水边缘自动生成岸边格")
	check(counts[&"water"] > 200, "湖泊由精细网格轮廓生成")
	check(counts[&"cliff"] > 20, "山坡崖壁写入权威网格")

	var right_water := false
	var bottom_water := false
	for y in range(grid.grid_size.y):
		right_water = right_water or grid.cell_data(Vector2i(grid.grid_size.x - 1, y)).terrain_type == &"water"
	for x in range(grid.grid_size.x):
		bottom_water = bottom_water or grid.cell_data(Vector2i(x, grid.grid_size.y - 1)).terrain_type == &"water"
	check(right_water, "湖泊延伸到地图右边界")
	check(bottom_water, "湖泊延伸到地图下边界")

	var shore := TerrainMapDataScript.first_cell_of_type(grid, &"shore")
	var water := TerrainMapDataScript.first_cell_of_type(grid, &"water")
	var cliff := TerrainMapDataScript.first_cell_of_type(grid, &"cliff")
	var shore_data: Dictionary = grid.cell_data(shore)
	check(bool(shore_data.walkable) and not bool(shore_data.buildable), "岸边可走但不可建造")
	check(is_equal_approx(float(shore_data.movement_cost), 1.2), "岸边移动代价为1.2")
	check(grid.is_solid(water), "水域是固体阻挡")
	check(grid.is_solid(cliff), "崖壁是固体阻挡")

	var layer := TerrainGridLayerScript.new()
	add_child(layer)
	layer.configure(grid)
	check(is_equal_approx(layer.cell_size, 36.0), "地形渲染使用36像素原生格")
	check(layer.rendered_cell_count == 128 * 72, "地形工具覆盖当前128×72逻辑格")
	check(layer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "地形层使用最近邻过滤")
	check(layer.material is ShaderMaterial and layer.material.shader == TerrainGridLayerScript.RELIEF_SHADER, "草地使用保留岩面和坡脚明暗的材质")
	check(layer.grass_cells_per_tile == 2, "草地覆盖2×2逻辑格72世界像素，建造网格仍为36像素")
	check(layer.clear_left_plain_rocks and bool(layer.material.get_shader_parameter("clear_left_plain_rocks")), "左侧平原装饰石头清理已启用")
	check(not Geometry2D.is_point_in_polygon(Vector2(1215, 1530), TerrainGridLayerScript.LEFT_PLAIN_CLEANUP_POLYGON), "平原清理向内退让，不截断精修图左下湖岸")
	check(layer.material.get_shader_parameter("left_plain_cleanup_polygon") == PackedVector2Array(TerrainGridLayerScript.LEFT_PLAIN_CLEANUP_POLYGON), "清理按左侧平原轮廓覆盖，不再仅限红框")
	for point in [Vector2(360, 150), Vector2(360, 900), Vector2(720, 1450), Vector2(1350, 1330)]:
		check(Geometry2D.is_point_in_polygon(point, TerrainGridLayerScript.LEFT_PLAIN_CLEANUP_POLYGON), "清理包含左侧平原上中下部：%s" % point)
	for point in [Vector2(1080, 300), Vector2(2100, 600), Vector2(2100, 1350)]:
		check(not Geometry2D.is_point_in_polygon(point, TerrainGridLayerScript.LEFT_PLAIN_CLEANUP_POLYGON), "清理避开山坡或湖岸：%s" % point)
	check(is_equal_approx(float(layer.material.get_shader_parameter("plain_grass_light")), 0.88), "平原草地统一基准亮度，不按清理区域切换调色")
	var grass_atlas := load(GRASS_ATLAS_PATH) as Texture2D
	var tile_pixels := grass_atlas.get_height()
	check(grass_atlas != null and grass_atlas.get_size() == Vector2(2508, 627), "草地图集保留4个627×627原生细节变体，不放大36像素旧稿")
	var colors := {}
	var atlas_image := grass_atlas.get_image()
	var edges_match := true
	for y in range(tile_pixels):
		for x in range(tile_pixels * 4):
			colors[atlas_image.get_pixel(x, y).to_rgba32()] = true
		for variant in range(4):
			edges_match = edges_match and atlas_image.get_pixel(variant * tile_pixels, y) == atlas_image.get_pixel(variant * tile_pixels + tile_pixels - 1, y)
			edges_match = edges_match and atlas_image.get_pixel(variant * tile_pixels + y, 0) == atlas_image.get_pixel(variant * tile_pixels + y, tile_pixels - 1)
			edges_match = edges_match and atlas_image.get_pixel(variant * tile_pixels, y) == atlas_image.get_pixel(0, y)
	check(colors.size() > 12 and colors.size() <= 64, "细节草地共享64色以内，保留细草叶的明暗层次")
	check(edges_match, "四个草地变体自身及互相拼接的边缘颜色一致")
	check(TerrainGridLayerScript.GRASS_VARIANT_COUNT == 4, "草地渲染保留4个可复用变体")
	check(TerrainGridLayerScript.GRASS_VARIANT_LOOKUP.count(0) == 4, "基础草地占一半混铺权重")
	var bundle_file := FileAccess.open(GRASS_BUNDLE_PATH, FileAccess.READ)
	var bundle: Dictionary = JSON.parse_string(bundle_file.get_as_text()) if bundle_file != null else {}
	check(bundle.get("schema", "") == "generate2dmap.terrain_tile_bundle.v1", "草地素材保留标准地形图集清单")
	check(bool(bundle.get("qc", {}).get("passed", false)), "草地素材通过对比度与变体差异检查")
	check(bundle.get("runtime", {}).get("edge_policy", "") == "seamless", "草地素材声明无缝网格拼接")
	check(is_equal_approx(float(bundle.get("runtime", {}).get("world_size", 0)), 72.0), "素材清单的72世界像素显示比例与运行一致")
	check(layer.grass_source_rect(Vector2(72, 72), 3) == Rect2(1881, 0, 627, 627), "第四变体取完整高分辨率源区域")
	check(layer.grass_source_rect(Vector2(72, 36), 0) == Rect2(0, 0, 627, 313.5), "地图末行按比例裁切，不拉伸或压缩草地细节")
	var city_art := preload("res://src/gameplay/art/art_visual.gd").new()
	city_art.configure("town_hall", Vector2(90, 88))
	var city_density := 1.0 / city_art.base_scale.x
	var grass_density := float(tile_pixels) / 72.0
	print("METRIC: 草地纹理密度=%.4f 主城密度=%.4f 比值=%.4f 最大1.6镜头草地源像素屏幕尺寸=%.4f" % [grass_density, city_density, grass_density / city_density, 1.6 / grass_density])
	check(grass_density / city_density >= 0.7 and grass_density / city_density <= 1.3, "草地源纹理密度接近主城，不再使用放大的低分辨率块")
	check(1.6 / grass_density < 1.0, "最大1.6倍率时草地源像素不放大为屏幕方块")
	city_art.free()
	var import_settings := ConfigFile.new()
	check(import_settings.load(GRASS_ATLAS_PATH + ".import") == OK and import_settings.get_value("params", "compress/mode", -1) == 0 and not import_settings.get_value("params", "mipmaps/generate", true), "草地图集无损导入且无mipmap，避免压缩与低精度采样")
	verify_crisp_terrain(layer)

	var grounding := BuildingGroundingScript.new()
	add_child(grounding)
	grounding.configure(Vector2i(2, 2), &"farm")
	check(grounding.footprint_size == Vector2(72, 72), "双格建筑地基匹配72×72占地")
	check(grounding.shadow_size.x > 0.0 and grounding.shadow_size.y >= 4.0, "建筑生成脚点接触阴影")

	for path in [
		"res://src/main/main.gd",
		"res://src/gameplay/buildings/resource_building.gd",
		"res://src/gameplay/defenses/arrow_tower.gd",
		"res://src/gameplay/defenses/barracks.gd",
		"res://src/gameplay/defenses/barrier_wall.gd",
	]:
		var file := FileAccess.open(path, FileAccess.READ)
		check(file != null and file.get_as_text().contains("BuildingGroundingScript"), "%s接入建筑地基" % path.get_file())

	var main := MAIN_SCENE.instantiate()
	add_child(main)
	var terrain_node: Node2D = main.get_node("TerrainGridLayer") as Node2D
	var forest_node: Sprite2D = main.get_node("BorderForest") as Sprite2D
	check(terrain_node.chunks.size()==12 and terrain_node.chunks[0].texture.resource_path == "res://assets/map/dawn_large_hd_v2/ground-0-0.png", "运行高清底图分块加载，不再叠加旧图专用草地遮罩")
	check(main.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "精修底图连续采样，不强制放大像素格")
	var city_keeps_nearest := false
	for child in main.get_children():
		if child is ArtVisual and child.texture.resource_path.ends_with("town_hall.png"):
			city_keeps_nearest = child.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
	check(city_keeps_nearest, "建筑保留原最近邻过滤，不随底图改成平滑")
	check(forest_node.texture != null and forest_node.visible, "地图边界树林运行时可见")
	check(terrain_node.z_index >= 0 and forest_node.z_index >= 0, "地形和边界树林不会绘制在主底图之后被覆盖")
	check(terrain_node.get_index() < forest_node.get_index(), "地形层先于边界树林绘制")
	check(forest_node.get_index() < main.get_node("ResourceSites").get_index(), "边界树林位于资源与单位层下方")
	main.queue_free()

	get_tree().quit(failures)


func verify_crisp_terrain(layer: Node2D) -> void:
	var source: Image = layer.relief_source.get_image()
	check(layer.relief_source.resource_path == CRISP_TERRAIN_PATH, "运行地形使用重绘稿，不是旧底图像素化")
	check(source.get_size() == Vector2i(3344, 1882), "四片区高细节地形图为3344×1882，世界范围仍2880×1620")
	var palette := {}
	var same_blocks := 0
	var sampled_blocks := 0
	for y in range(0, source.get_height() - 1, 4):
		for x in range(0, source.get_width() - 1, 4):
			var color := source.get_pixel(x, y)
			palette[color.to_rgba32()] = true
			sampled_blocks += 1
			if color == source.get_pixel(x + 1, y) and color == source.get_pixel(x, y + 1) and color == source.get_pixel(x + 1, y + 1):
				same_blocks += 1
	check(float(same_blocks) / sampled_blocks < 0.1, "底图没有2×2整数复制像素块，不使用旧稿简单放大")
	check(palette.size() > 512, "精修岩面保留完整明暗，不再量化成64色大块")
	var metadata_file := FileAccess.open(CRISP_TERRAIN_PATH.get_basename() + ".json", FileAccess.READ)
	var metadata: Dictionary = JSON.parse_string(metadata_file.get_as_text()) if metadata_file != null else {}
	check(metadata.get("schema", "") == "waiting_for_dawn.terrain_artwork.v2" and metadata.get("source_origin", "") == "builtin_imagegen", "精修地形记录分区图像生成来源与规范")
	check(float(metadata.get("pixel_world_size", 2)) < 1.0 and metadata.get("sampling", "") == "linear" and metadata.get("quantization", "") == "none", "素材不再降采样后整数放大，底图采用连续采样")
	check(PackedInt32Array(metadata.get("world_size", [])) == PackedInt32Array([2880, 1620]) and PackedInt32Array(metadata.get("native_size", [])) == PackedInt32Array([3344, 1882]), "贴图尺寸和世界范围解耦，地图与格数不变")
	var region_entries: Array = metadata.get("regions", [])
	check(region_entries.size() == 4, "四个片区分别生成高精度细节，不复用整图放大")
	for region in region_entries:
		var region_root := CRISP_TERRAIN_PATH.get_base_dir().path_join(metadata.get("region_directory", ""))
		check(FileAccess.file_exists(region_root.path_join(region.source)) and FileAccess.file_exists(region_root.path_join(region.prompt)), "片区源图与完整提示词可追溯：%s" % region.source)
	var shader_text := FileAccess.get_file_as_string("res://src/gameplay/art/grass_relief.gdshader")
	check(shader_text.contains("ground_position / map_size") and not shader_text.contains("floor(ground_position / 2.0)"), "保坡遮罩不再将高清轮廓量化为2世界像素")
	check(FileAccess.file_exists(CRISP_TERRAIN_PATH.get_base_dir().path_join(metadata.get("source", "缺失"))) and FileAccess.file_exists(CRISP_TERRAIN_PATH.get_base_dir().path_join(metadata.get("prompt", "缺失"))), "生成源图与提示词保存在项目内可追溯")
	var settings := ConfigFile.new()
	var imported := settings.load(CRISP_TERRAIN_PATH + ".import") == OK
	check(imported and settings.get_value("params", "compress/mode", -1) == 0 and settings.get_value("params", "mipmaps/generate", true) == false, "地形无损导入且不生成mipmap，不会再次压糊")
	var sites_file := FileAccess.open("res://assets/map/moonlit_resource_map_16x9_sites.json", FileAccess.READ)
	var sites: Dictionary = JSON.parse_string(sites_file.get_as_text()) if sites_file != null else {}
	check("res://" + sites.get("base", "") == CRISP_TERRAIN_PATH, "资源地图清单引用当前运行清晰地形")


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
