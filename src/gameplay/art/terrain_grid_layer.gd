class_name TerrainGridLayer
extends Node2D

const CELL_SIZE: float = 36.0
const GRASS_ATLAS: Texture2D = preload("res://assets/tilesets/moonlit_grass_v1/moonlit_grass_atlas.png")
const GRASS_VARIANT_COUNT: int = 4
const GRASS_VARIANT_LOOKUP: Array[int] = [0, 0, 0, 0, 1, 2, 3, 3]

var grid_model: RefCounted
var cell_size: float = CELL_SIZE
var rendered_cell_count: int = 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func configure(model: RefCounted) -> void:
	grid_model = model
	cell_size = float(model.CELL_SIZE)
	rendered_cell_count = model.grid_size.x * model.grid_size.y
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	if grid_model == null:
		return
	for y in range(grid_model.grid_size.y):
		for x in range(grid_model.grid_size.x):
			_draw_cell(Vector2i(x, y), grid_model.cell_data(Vector2i(x, y)))


func _draw_cell(cell: Vector2i, data: Dictionary) -> void:
	var origin := Vector2(cell) * cell_size
	var rect := Rect2(origin, Vector2.ONE * cell_size)
	var terrain := StringName(data.get("terrain_type", &"grass"))
	match terrain:
		&"water":
			draw_rect(rect, Color(0.025, 0.15, 0.27, 0.36), true)
			if (cell.x + cell.y) % 3 == 0:
				draw_line(origin + Vector2(7, 20), origin + Vector2(26, 20), Color(0.28, 0.57, 0.72, 0.34), 2.0)
		&"shore":
			draw_rect(rect, Color(0.22, 0.31, 0.33, 0.48), true)
			draw_rect(rect.grow(-3.0), Color(0.43, 0.55, 0.52, 0.30), false, 2.0)
		&"cliff":
			draw_rect(rect, Color(0.12, 0.16, 0.24, 0.50), true)
			draw_line(origin + Vector2(4, 8), origin + Vector2(31, 27), Color(0.40, 0.52, 0.64, 0.40), 3.0)
			draw_line(origin + Vector2(8, 31), origin + Vector2(31, 12), Color(0.08, 0.12, 0.20, 0.55), 2.0)
		_:
			var region_hash := cell.x * 17 + cell.y * 31 + floori(cell.x / 3.0) + floori(cell.y / 2.0)
			var lookup_index: int = absi(region_hash % GRASS_VARIANT_LOOKUP.size())
			var variant: int = GRASS_VARIANT_LOOKUP[lookup_index]
			var source := Rect2(Vector2(variant * CELL_SIZE, 0.0), Vector2.ONE * CELL_SIZE)
			draw_texture_rect_region(GRASS_ATLAS, rect, source)
