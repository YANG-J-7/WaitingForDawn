class_name TerrainGridLayer
extends Node2D

const CELL_SIZE: float = 36.0
const GRASS_ATLAS: Texture2D = preload("res://assets/tilesets/moonlit_grass_detail_v3/moonlit_grass_atlas.png")
const GRASS_VARIANT_COUNT: int = 4
const GRASS_VARIANT_LOOKUP: Array[int] = [0, 0, 0, 0, 1, 2, 3, 3]
const RELIEF_SHADER: Shader = preload("res://src/gameplay/art/grass_relief.gdshader")
const RELIEF_SOURCE: Texture2D = preload("res://assets/map/moonlit_terrain_detail.png")
# 沿左侧平原外缘划定清理范围，上下延伸到地图边界，避开崖壁和湖岸。
const LEGACY_LEFT_PLAIN_CLEANUP_POLYGON := [
	Vector2(0, 0), Vector2(720, 0), Vector2(720, 300),
	Vector2(810, 420), Vector2(990, 510), Vector2(1296, 648),
	Vector2(1440, 720), Vector2(1512, 792), Vector2(1620, 900),
	Vector2(1575, 990), Vector2(1455, 1125), Vector2(1500, 1185),
	Vector2(1545, 1215), Vector2(1695, 1233), Vector2(1695, 1263),
	Vector2(1536, 1305), Vector2(1425, 1356), Vector2(1320, 1410),
	Vector2(1254, 1455), Vector2(1215, 1530), Vector2(1203, 1620),
	Vector2(0, 1620),
]
# 精修岸线在左下方略向内陆偏移，清理轮廓退让；不改变权威水域或碰撞。
const LEFT_PLAIN_CLEANUP_POLYGON := [
	Vector2(0, 0), Vector2(720, 0), Vector2(720, 300),
	Vector2(810, 420), Vector2(990, 510), Vector2(1296, 648),
	Vector2(1440, 720), Vector2(1512, 792), Vector2(1620, 900),
	Vector2(1575, 990), Vector2(1383, 1125), Vector2(1428, 1185),
	Vector2(1473, 1215), Vector2(1623, 1233), Vector2(1623, 1263),
	Vector2(1464, 1305), Vector2(1353, 1356), Vector2(1176, 1410),
	Vector2(1110, 1455), Vector2(1071, 1530), Vector2(1059, 1620),
	Vector2(0, 1620),
]
const PLAIN_GRASS_LIGHT: float = 0.88

var grid_model: RefCounted
var cell_size: float = CELL_SIZE
var rendered_cell_count: int = 0
@export_range(1, 4) var grass_cells_per_tile: int = 2
@export var grass_atlas: Texture2D = GRASS_ATLAS
@export var relief_source: Texture2D = RELIEF_SOURCE
@export var clear_left_plain_rocks: bool = true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func configure(model: RefCounted) -> void:
	grid_model = model
	grass_cells_per_tile = clampi(grass_cells_per_tile, 1, 4)
	cell_size = float(model.CELL_SIZE)
	rendered_cell_count = model.grid_size.x * model.grid_size.y
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var relief_material := ShaderMaterial.new()
	relief_material.shader = RELIEF_SHADER
	relief_material.set_shader_parameter("relief_source", relief_source)
	relief_material.set_shader_parameter("macro_source", relief_source)
	relief_material.set_shader_parameter("map_size", Vector2(model.grid_size) * cell_size)
	# 清理整片左侧平原装饰；独立资源、树林和权威地形均不改动。
	relief_material.set_shader_parameter("clear_left_plain_rocks", clear_left_plain_rocks)
	relief_material.set_shader_parameter("left_plain_cleanup_polygon", PackedVector2Array(LEFT_PLAIN_CLEANUP_POLYGON))
	relief_material.set_shader_parameter("plain_grass_light", PLAIN_GRASS_LIGHT)
	material = relief_material
	queue_redraw()


func _draw() -> void:
	if grid_model == null:
		return
	for y in range(0, grid_model.grid_size.y, grass_cells_per_tile):
		for x in range(0, grid_model.grid_size.x, grass_cells_per_tile):
			_draw_cell(Vector2i(x, y), grid_model.cell_data(Vector2i(x, y)))


func _draw_cell(cell: Vector2i, _data: Dictionary) -> void:
	var origin := Vector2(cell) * cell_size
	var remaining := Vector2(grid_model.grid_size - cell)
	var span := Vector2.ONE * grass_cells_per_tile
	var rect := Rect2(origin, remaining.min(span) * cell_size)
	# 逻辑阻挡格只管理玩法，连续视觉轮廓由材质保护，不能留下方格边界。
	var tile_cell := Vector2i(Vector2(cell) / grass_cells_per_tile)
	var region_hash := (tile_cell.x * 73856093) ^ (tile_cell.y * 19349663) ^ (tile_cell.x * tile_cell.y * 83492791)
	var lookup_index: int = posmod(region_hash >> 8, GRASS_VARIANT_LOOKUP.size())
	var variant: int = GRASS_VARIANT_LOOKUP[lookup_index]
	# 像建筑贴图一样保留源图细节后缩小展示；源像素尺寸与36世界像素逻辑格解耦。
	var source := grass_source_rect(rect.size, variant)
	draw_texture_rect_region(grass_atlas, rect, source)


func grass_source_rect(world_size: Vector2, variant: int) -> Rect2:
	var tile_pixels := float(grass_atlas.get_height())
	var texels_per_world := tile_pixels / (cell_size * grass_cells_per_tile)
	# 末行不足两格时只裁掉对应源区域，不把完整地块压缩到一格。
	return Rect2(Vector2(variant * tile_pixels, 0.0), world_size * texels_per_world)
