extends Node2D
## 关卡装配的视觉入口；各组件保持独立变换和共享材质来源。
const Runtime = preload("res://src/gameplay/map/level_map_runtime.gd")
const PART = preload("res://src/gameplay/art/modular_surface_part.gd")
const SHADER = preload("res://src/gameplay/art/modular_terrain.gdshader")
const GRASS = preload("res://assets/map/grass_hd_v1/detail.png")
var runtime: RefCounted
var grid_model: RefCounted
var cell_size := 36.0
var rendered_cell_count := 0
var chunks: Array[Dictionary] = []
var parts: Array[Node2D] = []

func configure(grid: RefCounted, context: RefCounted = null) -> void:
	runtime = context if context != null else Runtime.create_default()
	grid_model = grid
	rendered_cell_count = grid.grid_size.x*grid.grid_size.y
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	z_index = 0
	for component in runtime.modules:
		if component.role not in ["ground","mountain","lake"]: continue
		var part := PART.new()
		part.name = component.instance_id
		part.position = component.origin
		var size: Array = component.payload.get("world_size",[runtime.bounds.size.x,runtime.bounds.size.y])
		var rect := Rect2(Vector2.ZERO,Vector2(size[0],size[1]))
		if component.role in ["ground","lake"]: rect=runtime.bounds.grow(8192)
		part.surface_rect = rect
		var shader_material := ShaderMaterial.new()
		shader_material.shader = SHADER
		shader_material.set_shader_parameter("grass_detail",GRASS)
		shader_material.set_shader_parameter("meadow_detail",load("res://assets/map_kits/moonlit_v3/meadow.png"))
		for pair in [["rock_detail","rock"],["water_detail","water"],["soil_detail","soil"]]:
			var path := "res://assets/map_kits/moonlit_v2/materials/%s.png" % pair[1]
			if ResourceLoader.exists(path): shader_material.set_shader_parameter(pair[0],load(path))
		shader_material.set_shader_parameter("module_origin",component.origin)
		shader_material.set_shader_parameter("module_size",Vector2(size[0],size[1]))
		shader_material.set_shader_parameter("world_size",runtime.bounds.size)
		shader_material.set_shader_parameter("surface_kind",{"ground":0,"mountain":1,"lake":2}[component.role])
		if component.payload.has("control"): shader_material.set_shader_parameter("control_map",load("res://"+component.payload.control))
		part.material = shader_material
		add_child(part)
		parts.append(part)
		chunks.append({"module_id":component.module_id,"rect":Rect2(component.origin+rect.position,rect.size),"role":component.role})
	var structures := preload("res://src/gameplay/art/map_structure_art.gd").new()
	structures.name = "StructureArt"
	structures.configure(runtime)
	add_child(structures)
	var stairs := preload("res://src/gameplay/art/modular_stair_layer.gd").new()
	stairs.name = "Stairs"
	stairs.configure(runtime)
	add_child(stairs)
	var edges:=preload("res://src/gameplay/art/modular_edge_dressing.gd").new()
	edges.name="EdgeDressing"
	edges.configure(runtime,grid)
	add_child(edges)

func _process(_delta: float) -> void:
	# 只作可见性裁剪，不把它冒充流式卸载或影响地图模拟。
	if not is_inside_tree(): return
	var visible_world := get_canvas_transform().affine_inverse()*get_viewport_rect()
	for index in parts.size(): parts[index].visible = chunks[index].rect.intersects(visible_world)
