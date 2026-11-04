extends SceneTree
## 高清地形一纹素对应一世界单位，分成14页，独立于36格玩法数据。
func _initialize() -> void:
	var root := "res://assets/map_kits/reference_hd_20261102/"
	var layer := TileMapLayer.new()
	layer.name = "ReferenceHDTerrainTiles"
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(144,144)
	layer.tile_set = tiles
	for page_y in 2:
		for page_x in 7:
			var atlas := TileSetAtlasSource.new()
			atlas.texture = load(root+"atlases/ground-%d-%d.png" % [page_x,page_y])
			atlas.texture_region_size = Vector2i(144,144)
			atlas.margins = Vector2i(8,8)
			atlas.use_texture_padding = false
			var source_id := page_y*7+page_x
			tiles.add_source(atlas,source_id)
			for y in 10:
				for x in 7:
					var cell := Vector2i(x,y)
					atlas.create_tile(cell)
					layer.set_cell(Vector2i(page_x*7+x,page_y*10+y),source_id,cell)
	var packed := PackedScene.new()
	assert(packed.pack(layer)==OK)
	assert(ResourceSaver.save(packed,root+"terrain.tscn")==OK)
	layer.free()
	print("PASS: 高清地形980格、14页、一比一世界映射")
	quit()
