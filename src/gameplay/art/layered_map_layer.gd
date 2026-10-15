extends Node2D
## 地形分块来自同一母图，使用共边世界坐标避免接缝。
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
var chunks: Array[Dictionary] = []
var grid_model: RefCounted
var rendered_cell_count := 0
var cell_size := Definition.CELL_SIZE

func configure(grid: RefCounted) -> void:
	# 暂停中仍允许查看地图；镜头移动后需要重算可见分块。
	process_mode = Node.PROCESS_MODE_ALWAYS
	grid_model = grid
	rendered_cell_count = grid.grid_size.x * grid.grid_size.y
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for entry in Definition.visual_data().get("chunks", []):
		var box: Array = entry.sourceRect
		var origin := Definition.source_to_world(Vector2(box[0], box[1]))
		var end := Definition.source_to_world(Vector2(box[2], box[3]))
		chunks.append({"texture": load("res://" + entry.path), "rect": Rect2(origin, end-origin)})
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var viewport_world := get_canvas_transform().affine_inverse() * get_viewport_rect()
	for chunk in chunks:
		if chunk.rect.intersects(viewport_world):
			draw_texture_rect(chunk.texture, chunk.rect, false)
