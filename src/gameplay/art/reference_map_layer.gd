extends Node2D
## 7056×2880分区重绘地形与独立树木；远近景和小地图共享同一来源。
const ROOT="res://assets/map_kits/reference_hd_20261102/"
const TERRAIN_LIGHT_SHADER := preload("res://src/gameplay/art/terrain_light_receiver.gdshader")
var parts: Array[Node2D]=[]
var detail_patches: Array[Sprite2D]=[]
var tile_layer: TileMapLayer
var rendered_cell_count:=0
var data: Dictionary
var _surface_bounds: Rect2
var _surface_material: ShaderMaterial

func configure(grid: RefCounted,context: RefCounted,overview_only: bool=false) -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"map.json"))
	rendered_cell_count=grid.grid_size.x*grid.grid_size.y
	# 非地图比例总览采用安静的衬底，不补画不存在的地图或拉伸边缘。
	material=null
	tile_layer=context.definition.terrain_tiles.instantiate()
	add_child(tile_layer)
	parts.append(tile_layer)
	if overview_only:
		var forest := preload("res://src/gameplay/art/reference_border_forest.gd").new()
		forest.configure(context)
		add_child(forest)
	else:
		_configure_terrain_lighting(grid,context)
	queue_redraw()

func _configure_terrain_lighting(grid: RefCounted, context: RefCounted) -> void:
	var mask: Texture2D = context.definition.terrain_light_mask
	if mask == null:
		# 只在装载时构建一次。颜色是材质权重，原始地形与通行数据保持只读。
		var image := Image.create(grid.grid_size.x,grid.grid_size.y,false,Image.FORMAT_RGB8)
		for cell in grid.cells_of_type(&"cliff"): image.set_pixelv(cell,Color.RED)
		for cell in grid.cells_of_type(&"water"): image.set_pixelv(cell,Color.GREEN)
		mask = ImageTexture.create_from_image(image)
	_surface_bounds = context.bounds
	_surface_material = ShaderMaterial.new()
	_surface_material.shader = TERRAIN_LIGHT_SHADER
	_surface_material.set_shader_parameter(&"surface_mask",mask)
	_surface_material.set_shader_parameter(&"surface_world_size",_surface_bounds.size)
	var profile: Resource = context.definition.lighting_profile
	if profile != null:
		_surface_material.set_shader_parameter(&"surface_response",profile.terrain_local_response.clamp(Vector3.ZERO,Vector3(2,2,2)))
	tile_layer.material = _surface_material
	set_notify_transform(true)
	_update_surface_transform()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and _surface_material != null:
		_update_surface_transform()

func _update_surface_transform() -> void:
	var inverse := global_transform.affine_inverse()
	_surface_material.set_shader_parameter(&"uv_axis_x",inverse.x/_surface_bounds.size)
	_surface_material.set_shader_parameter(&"uv_axis_y",inverse.y/_surface_bounds.size)
	_surface_material.set_shader_parameter(&"uv_origin",(inverse.origin-_surface_bounds.position)/_surface_bounds.size)

func update_terrain_shadow(light_world: Vector2, opacity: float, reach: float) -> void:
	if _surface_material == null: return
	_surface_material.set_shader_parameter(&"shadow_light_uv",(to_local(light_world)-_surface_bounds.position)/_surface_bounds.size)
	_surface_material.set_shader_parameter(&"terrain_shadow_opacity",opacity)
	_surface_material.set_shader_parameter(&"terrain_shadow_reach",reach)

func _draw() -> void:
	# 总览余量只用新素材连续延伸，不拉长旧图边缘。
	draw_rect(Rect2(-6000,-6000,18000,15000),Color("0b1825"))
