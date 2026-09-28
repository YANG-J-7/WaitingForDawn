extends Node

const GridMapModelScript = preload("res://src/gameplay/grid/grid_map_model.gd")
const TerrainMapDataScript = preload("res://src/gameplay/grid/terrain_map_data.gd")
const TerrainGridLayerScript = preload("res://src/gameplay/art/terrain_grid_layer.gd")
const BuildingGroundingScript = preload("res://src/gameplay/art/building_grounding.gd")
const GRASS_ATLAS_PATH := "res://assets/tilesets/moonlit_grass_v1/moonlit_grass_atlas.png"
const GRASS_BUNDLE_PATH := "res://assets/tilesets/moonlit_grass_v1/terrain-bundle.json"
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
	check(layer.rendered_cell_count == 80 * 45, "地形渲染覆盖完整80×45地图")
	check(layer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "地形层使用最近邻过滤")
	var grass_atlas := load(GRASS_ATLAS_PATH) as Texture2D
	check(grass_atlas != null and grass_atlas.get_size() == Vector2(144, 36), "草地图集提供4个36×36原生变体")
	check(TerrainGridLayerScript.GRASS_VARIANT_COUNT == 4, "草地渲染保留4个可复用变体")
	check(TerrainGridLayerScript.GRASS_VARIANT_LOOKUP.count(0) == 4, "基础草地占一半混铺权重")
	var bundle_file := FileAccess.open(GRASS_BUNDLE_PATH, FileAccess.READ)
	var bundle: Dictionary = JSON.parse_string(bundle_file.get_as_text()) if bundle_file != null else {}
	check(bundle.get("schema", "") == "generate2dmap.terrain_tile_bundle.v1", "草地素材保留标准地形图集清单")
	check(bool(bundle.get("qc", {}).get("passed", false)), "草地素材通过对比度与变体差异检查")
	check(bundle.get("runtime", {}).get("edge_policy", "") == "seamless", "草地素材声明无缝网格拼接")

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
	check(forest_node.texture != null and forest_node.visible, "地图边界树林运行时可见")
	check(terrain_node.z_index >= 0 and forest_node.z_index >= 0, "地形和边界树林不会绘制在主底图之后被覆盖")
	check(terrain_node.get_index() < forest_node.get_index(), "地形层先于边界树林绘制")
	check(forest_node.get_index() < main.get_node("ResourceSites").get_index(), "边界树林位于资源与单位层下方")
	main.queue_free()

	get_tree().quit(failures)


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
