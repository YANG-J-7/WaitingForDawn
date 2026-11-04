extends SceneTree
## 新底层保存为独立原生瓦片场景，保留独立玩法网格。
func _initialize() -> void:
	var root := "res://assets/map_kits/reference_20261029/"
	var layer := TileMapLayer.new()
	layer.name="ReferenceTerrainTiles"
	layer.scale=Vector2.ONE*3.6
	layer.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tiles := TileSet.new()
	tiles.tile_size=Vector2i(40,40)
	var atlas := TileSetAtlasSource.new()
	atlas.texture=load(root+"terrain.png")
	atlas.texture_region_size=Vector2i(40,40)
	atlas.use_texture_padding=false
	tiles.add_source(atlas,0)
	layer.tile_set=tiles
	for y in 20:
		for x in 49:
			var cell := Vector2i(x,y)
			atlas.create_tile(cell)
			layer.set_cell(cell,0,cell)
	var packed := PackedScene.new()
	assert(packed.pack(layer)==OK)
	assert(ResourceSaver.save(packed,root+"terrain.tscn")==OK)
	layer.free()
	print("PASS: 新参考图980格场景已保存")
	quit()
