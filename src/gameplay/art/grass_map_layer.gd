extends Node2D
## 正式关卡与小地图共用生成草地、装饰和连续泥地；不改玩法地形。
const GRASS: Texture2D = preload("res://assets/map/grass_variants_v1/grass.png")
const SHADER = preload("res://src/gameplay/art/grass_map.gdshader")
const PATCH_SHADER = preload("res://src/gameplay/art/ground_patch.gdshader")
var rendered_cell_count := 0
var surface: Polygon2D
var dressing: Node2D
var mud_regions: Node2D
var layout: Dictionary = {}
var layout_errors: PackedStringArray = []
var decoration_count := 0
var mud_tile_count := 0
var lake: Node2D
var forest: Node2D
var forest_lighting: Node
var _forest_visual_bounds: Rect2
var _forest_bounds: Rect2
var mountains: Node2D
var _dawn_progress := 0.0

func configure(grid: RefCounted, context: RefCounted, _overview_only: bool = false) -> void:
	# 本节点只绘制总览留白，实际地表由各子节点接收主光。
	light_mask = 0
	rendered_cell_count = grid.grid_size.x * grid.grid_size.y
	surface = Polygon2D.new()
	surface.name = "GrassSurface"
	var bounds: Rect2 = context.visual_bounds
	surface.polygon = PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	var grass_material := ShaderMaterial.new()
	grass_material.shader = SHADER
	grass_material.set_shader_parameter("grass_texture", GRASS)
	grass_material.set_shader_parameter("detail_world_size", Vector2.ONE * 360.0)
	surface.material = grass_material
	add_child(surface)
	_build_dressing(context)
	mountains = preload("res://src/gameplay/art/level_mountain_layer.gd").new()
	mountains.name = "Mountains"
	for component: Dictionary in context.modules:
		if component.role!="lake": continue
		lake=preload("res://src/gameplay/art/level_lake_layer.gd").new()
		lake.name="Lake"
		add_child(lake)
		lake.configure(context,_overview_only)
		break
	# 湖水和旧岸置于山体后方，避免把完整山壁遮成草石岸线。
	add_child(mountains)
	mountains.configure(context, _overview_only)
	var forest_path: String = layout.get("forest_layout", "")
	if not forest_path.is_empty():
		forest = preload("res://src/gameplay/art/level_forest_layer.gd").new()
		forest.name = "ForestEdge"
		forest.configure(forest_path, grid)
		add_child(forest)
		layout_errors.append_array(forest.errors)
		if not _overview_only and forest.errors.is_empty() and layout.get("forest_lighting", false):
			_forest_visual_bounds = context.visual_bounds
			_forest_bounds = context.bounds


func update_forest_lighting(lighting: Node2D) -> void:
	if not _forest_visual_bounds.has_area():
		return
	# 首次光照更新时主图已进入场景，此时可以读取树体的全局坐标。
	if forest_lighting == null:
		forest_lighting = preload("res://src/gameplay/art/level_forest_lighting.gd").new()
		forest_lighting.name = "ForestLighting"
		add_child(forest_lighting)
		var mountain := mountains.get_child(0) as Sprite2D if mountains.get_child_count() > 0 else null
		forest_lighting.configure(forest, _forest_bounds, _forest_visual_bounds, lake, mountain)
	forest_lighting.update_lighting(lighting)

func _build_dressing(context: RefCounted) -> void:
	dressing = Node2D.new()
	dressing.name = "GroundDressing"
	add_child(dressing)
	mud_regions = Node2D.new()
	mud_regions.name = "MudRegions"
	add_child(mud_regions)
	# 连续泥地最后绘制，避免装饰图的底草横跨泥地内部。
	var path: String = context.definition.surface_layout_path
	if path.is_empty(): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		layout_errors.append("地表布局无法读取：" + path)
		return
	layout = parsed
	var density: float = float(layout.texels_per_world)
	var grass_path: String = layout.get("grass_texture", GRASS.resource_path)
	var grass_texture := load(grass_path) as Texture2D
	if grass_texture == null:
		layout_errors.append("草地贴图无法读取：" + grass_path)
		grass_texture = GRASS
	surface.material.set_shader_parameter("grass_texture", grass_texture)
	surface.material.set_shader_parameter("detail_world_size", grass_texture.get_size() / density)
	for kind: String in layout.decorations:
		var spec: Dictionary = layout.decorations[kind]
		var texture: Texture2D = load(spec.texture)
		for point: Array in spec.positions:
			var patch := _patch(texture, Vector2.ONE, texture.get_size() / density)
			patch.name = kind + "_%02d" % decoration_count
			patch.position = context.bounds.position + Vector2(float(point[0]), float(point[1])) * context.bounds.size
			patch.set_meta("asset_kind", kind)
			dressing.add_child(patch)
			decoration_count += 1
	var mud_atlases: Dictionary = layout.get("mud_atlases", {})
	var mud_soil_warmth: Dictionary = layout.get("mud_soil_warmth", {})
	for entry: Dictionary in layout.mud_regions:
		var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entry.map))
		var side := int(metadata.tile_pixels)
		var directory: String = String(entry.map).get_base_dir()
		var atlas_path: String = mud_atlases.get(entry.map, directory.path_join("reassembled.png"))
		var atlas := load(atlas_path) as Texture2D
		if atlas == null:
			layout_errors.append("泥地图集无法读取：" + atlas_path)
			continue
		var group := Node2D.new()
		group.name = entry.id
		group.position = context.bounds.position + Vector2(float(entry.position[0]), float(entry.position[1])) * context.bounds.size
		group.set_meta("source_map", entry.map)
		mud_regions.add_child(group)
		var world_side := float(side) / density
		var soil_warmth := float(mud_soil_warmth.get(entry.map, 0.0))
		for tile: Dictionary in metadata.tiles:
			var patch := _patch(atlas, Vector2(3, 2), Vector2.ONE * world_side)
			patch.material.set_shader_parameter("soil_warmth", soil_warmth)
			patch.name = "Tile%02d" % int(tile.number)
			patch.region_enabled = true
			patch.region_rect = Rect2(int(tile.column)*side, int(tile.row)*side, side, side)
			patch.scale = Vector2.ONE / density
			patch.position = Vector2(float(tile.column)+0.5, float(tile.row)+0.5) * world_side
			patch.set_meta("source_tile", directory + "/" + String(tile.file))
			group.add_child(patch)
			mud_tile_count += 1

func _patch(texture: Texture2D, columns: Vector2, world_size: Vector2) -> Sprite2D:
	var patch := Sprite2D.new()
	patch.texture = texture
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	patch.scale = world_size / texture.get_size()
	var material := ShaderMaterial.new()
	material.shader = PATCH_SHADER
	material.set_shader_parameter("patch_grid_size", columns)
	patch.material = material
	return patch

func update_terrain_shadow(_light_world: Vector2, _opacity: float, _reach: float) -> void:
	# 新底层没有岩壁高度；运行时阴影保持关闭。
	pass

func update_dawn(progress: float) -> void:
	if is_equal_approx(_dawn_progress, progress):
		return
	_dawn_progress = progress
	mountains.set_dawn_progress(progress)
	if lake != null:
		lake.set_dawn_progress(progress)

func _draw() -> void:
	# 非地图比例总览留衬底，不拉伸地图边缘。
	draw_rect(Rect2(-6000, -6000, 18000, 15000), Color("0b1825"))
