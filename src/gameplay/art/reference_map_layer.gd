extends Node2D
## 7056×2880分区重绘地形与独立树木；远近景和小地图共享同一来源。
const ROOT="res://assets/map_kits/reference_hd_20261102/"
var parts: Array[Node2D]=[]
var detail_patches: Array[Sprite2D]=[]
var tile_layer: TileMapLayer
var rendered_cell_count:=0
var data: Dictionary
func configure(grid: RefCounted,context: RefCounted,overview_only: bool=false) -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"map.json"))
	rendered_cell_count=grid.grid_size.x*grid.grid_size.y
	# 非地图比例总览采用安静的衬底，不补画不存在的地图或拉伸边缘。
	material=null
	tile_layer=context.definition.terrain_tiles.instantiate()
	# 直接显示地图原图；不加载任何额外草地贴图或地表覆盖材质。
	tile_layer.material=null
	add_child(tile_layer)
	parts.append(tile_layer)
	if overview_only:
		var forest := preload("res://src/gameplay/art/reference_border_forest.gd").new()
		forest.configure(context)
		add_child(forest)
	queue_redraw()
func _draw() -> void:
	# 总览余量只用新素材连续延伸，不拉长旧图边缘。
	draw_rect(Rect2(-6000,-6000,18000,15000),Color("0b1825"))
