extends SceneTree
## 将可审查的瓦片数据保存为Godot原生可编辑场景。
func _initialize() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/tilesets/dawn_20261029/tiles.json"))
	var layer := TileMapLayer.new()
	layer.name="TerrainTiles"
	layer.position=Vector2.ZERO
	layer.scale=Vector2.ONE*3.6
	layer.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tiles := TileSet.new()
	tiles.tile_size=Vector2i(40,40)
	var atlas := TileSetAtlasSource.new()
	atlas.texture=load("res://assets/tilesets/dawn_20261029/terrain.png")
	atlas.texture_region_size=Vector2i(40,40)
	atlas.use_texture_padding=false
	tiles.add_source(atlas,0)
	for entry in data.cells:
		var cell:=Vector2i(entry.cell[0],entry.cell[1])
		atlas.create_tile(cell)
		layer.tile_set=tiles
		layer.set_cell(cell,0,cell)
	var packed := PackedScene.new()
	assert(packed.pack(layer)==OK)
	assert(ResourceSaver.save(packed,"res://assets/tilesets/dawn_20261029/terrain.tscn")==OK)
	layer.free()
	print("PASS: 保存980格原生TileMapLayer")
	quit()
