extends Node3D

const Field = preload("res://tools/moonlake_3d_level/heightfield.gd")
const Landforms = preload("res://tools/moonlake_3d_level/landforms.gd")
const Grass = preload("res://tools/moonlake_3d_level/grass.gd")
const Border = preload("res://tools/moonlake_3d_level/border.gd")
const GROUND = preload("res://tools/moonlake_3d_level/ground.gdshader")
const LAKE = preload("res://tools/moonlake_3d_level/lake.gdshader")
const FOLIAGE = preload("res://tools/moonlake_3d_art/foliage.gdshader")
const GRASS_TEXTURE = preload("res://assets/map/grass_hd_v1/detail.png")
const ROCK_TEXTURE = preload("res://assets/map_kits/moonlit_v2/materials/rock.png")
const SOIL_TEXTURE = preload("res://assets/map_kits/moonlit_v2/materials/soil.png")
const WATER_TEXTURE = preload("res://assets/map_kits/moonlit_v2/materials/water.png")
const PINE_MODEL = preload("res://assets/map_kits/moonlit_v3/models/moonlake_pine.glb")
const FOREST_PATH := "res://assets/map_kits/reference_hd_20261102/forest.json"
const CHUNK_SIZE := Vector2i(28, 20)

var field: Field
var terrain_material := ShaderMaterial.new()
var lake_material := ShaderMaterial.new()
var tree_material := ShaderMaterial.new()
var overview_texture: ImageTexture
var forest: MultiMeshInstance3D
var grass := Grass.new()
var border := Border.new()
var chunk_count := 0


func configure(source: Field, grid: GridMapModel, town_center: Vector2) -> void:
	field = source
	terrain_material.shader = GROUND
	lake_material.shader = LAKE
	tree_material.shader = FOLIAGE
	terrain_material.set_shader_parameter("grass_texture", GRASS_TEXTURE)
	terrain_material.set_shader_parameter("rock_texture", ROCK_TEXTURE)
	terrain_material.set_shader_parameter("soil_texture", SOIL_TEXTURE)
	terrain_material.set_shader_parameter("town_center", town_center)
	lake_material.set_shader_parameter("water_texture", WATER_TEXTURE)
	_build_surface_masks()
	_build_chunks()
	_build_lake()
	_build_forest()
	border.name = "ScenicBorder"
	add_child(border)
	border.configure(field, forest.multimesh.mesh, terrain_material, lake_material)
	_build_rock_outcrops()
	grass.name = "WindGrass"
	add_child(grass)
	grass.configure(field, grid, town_center, CHUNK_SIZE)


func _build_chunks() -> void:
	for y in range(0, field.size.y, CHUNK_SIZE.y):
		for x in range(0, field.size.x, CHUNK_SIZE.x):
			var rect := Rect2i(Vector2i(x, y), CHUNK_SIZE).intersection(Rect2i(Vector2i.ZERO, field.size))
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for row in range(rect.position.y, rect.end.y):
				for column in range(rect.position.x, rect.end.x):
					var cell := Vector2i(column, row)
					var a := Vector3(column, field.height(cell), row)
					var b := a + Vector3.RIGHT
					var c := b + Vector3.BACK
					var d := a + Vector3.BACK
					_quad(surface, a, b, c, d, Vector3.UP, Color.BLACK)
					var cliff := field.kind(cell) == "cliff"
					_wall(surface, a, b, cell + Vector2i.UP, Vector3.FORWARD, cliff)
					_wall(surface, b, c, cell + Vector2i.RIGHT, Vector3.RIGHT, cliff)
					_wall(surface, c, d, cell + Vector2i.DOWN, Vector3.BACK, cliff)
					_wall(surface, d, a, cell + Vector2i.LEFT, Vector3.LEFT, cliff)
			_add_surface(surface, terrain_material, true)
			chunk_count += 1


func _build_lake() -> void:
	var overview := Image.create_empty(field.size.x, field.size.y, false, Image.FORMAT_RGB8)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(field.size.y):
		for column in range(field.size.x):
			var cell := Vector2i(column, row)
			var kind := field.kind(cell)
			overview.set_pixel(column, row, field.COLORS[kind])
			if kind != "water":
				continue
			var a := Vector3(column, field.WATER_HEIGHT + 0.008, row)
			_quad(surface, a, a + Vector3.RIGHT, a + Vector3.RIGHT + Vector3.BACK, a + Vector3.BACK, Vector3.UP, Color.WHITE)
	overview_texture = ImageTexture.create_from_image(overview)
	_add_surface(surface, lake_material)


func _build_surface_masks() -> void:
	var weights := Image.create_empty(field.size.x, field.size.y, false, Image.FORMAT_RGB8)
	var coast := Image.create_empty(field.size.x, field.size.y, false, Image.FORMAT_L8)
	var water := Landforms.distance_to_water(field)
	for y in range(field.size.y):
		for x in range(field.size.x):
			var cell := Vector2i(x, y)
			var kind := field.kind(cell)
			var stone := 1.0 if kind in ["cliff", "boundary", "ramp"] else 0.0
			var trail := 1.0 if kind in ["road", "ramp"] else 0.0
			var damp := 1.0 if kind in ["shore", "water"] else 0.0
			weights.set_pixel(x, y, Color(stone, trail, damp))
			coast.set_pixel(x, y, Color(water[field.index(cell)] / Landforms.COAST_RANGE + 0.5, 0, 0))
	var coast_texture := ImageTexture.create_from_image(coast)
	terrain_material.set_shader_parameter("surface_weights", ImageTexture.create_from_image(weights))
	terrain_material.set_shader_parameter("grid_size", Vector2(field.size))
	terrain_material.set_shader_parameter("coast_distance", coast_texture)
	terrain_material.set_shader_parameter("coast_range", Landforms.COAST_RANGE)
	tree_material.set_shader_parameter("edge_grid_size", Vector2(field.size))
	lake_material.set_shader_parameter("coast_distance", coast_texture)
	lake_material.set_shader_parameter("coast_range", Landforms.COAST_RANGE)
	lake_material.set_shader_parameter("grid_size", Vector2(field.size))


func _build_forest() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOREST_PATH))
	var model := PINE_MODEL.instantiate()
	var pine := (model.get_child(0) as MeshInstance3D).mesh.duplicate() as ArrayMesh
	model.free()
	# 保留 Blender 网格的顶点色，继续使用关卡统一的树梢风动。
	pine.surface_set_material(0, tree_material)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = pine
	batch.instance_count = data.trees.size()
	for i in range(data.trees.size()):
		var entry: Dictionary = data.trees[i]
		var world := Vector2(entry.position[0], entry.position[1])
		var root := field.surface_position(world)
		if not field.inside(Vector2i(floori(root.x), floori(root.z))):
			root.y = 0.0
		var tall := float(entry.size[1]) / (field.cell_size * 3.08)
		var wide := float(entry.size[0]) / (field.cell_size * 1.56)
		var basis := Basis(Vector3.UP, float(i) * 2.39).scaled(Vector3(wide, tall, wide))
		batch.set_instance_transform(i, Transform3D(basis, root))
	forest = MultiMeshInstance3D.new()
	forest.multimesh = batch
	add_child(forest)


func _build_rock_outcrops() -> void:
	var placements: Array[Transform3D] = []
	var random := RandomNumberGenerator.new()
	random.seed = 638371
	for y in range(field.size.y):
		for x in range(field.size.x):
			var cell := Vector2i(x, y)
			var kind := field.kind(cell)
			var cliff := kind == "cliff"
			if not cliff and kind != "shore":
				continue
			if random.randf() > (0.46 if cliff else 0.29):
				continue
			var width := random.randf_range(0.30, 0.47) if cliff else random.randf_range(0.12, 0.29)
			var height := random.randf_range(0.34, 0.95) if cliff else random.randf_range(0.04, 0.14)
			var basis := Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3(width, height, width))
			var center := Vector3(x + random.randf_range(width, 1.0 - width), field.height(cell), y + random.randf_range(width, 1.0 - width))
			placements.append(Transform3D(basis, center))
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = Landforms.create_rock_mesh(terrain_material)
	batch.instance_count = placements.size()
	for i in range(placements.size()):
		batch.set_instance_transform(i, placements[i])
	var rocks := MultiMeshInstance3D.new()
	rocks.name = "RockOutcrops"
	rocks.multimesh = batch
	add_child(rocks)


func _add_surface(surface: SurfaceTool, material: Material, shadow := false) -> void:
	surface.set_material(material)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	if not shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _wall(surface: SurfaceTool, a: Vector3, b: Vector3, neighbor: Vector2i, normal: Vector3, cliff: bool) -> void:
	var bottom := field.height(neighbor)
	var rise := a.y - bottom
	if rise <= 0.0:
		return
	var foot_a := Vector3(a.x, bottom, a.z)
	var foot_b := Vector3(b.x, bottom, b.z)
	if not cliff or rise < 0.55:
		_quad(surface, b, a, foot_a, foot_b, normal, Color.WHITE)
		return
	# 只把崖面向所属禁建格内切，边角和脚点保持同一地形边界。
	var phase := sin(a.x * 5.73 + a.z * 3.97)
	var lip := a.lerp(b, 0.46 + phase * 0.14)
	var foot := lip - Vector3.UP * rise
	var seam := lip.lerp(foot, 0.48 + phase * 0.20) - normal * (0.25 + phase * 0.11)
	var profile := Vector2(bottom, 1.0 / rise)
	_facet(surface, b, lip, seam, Color("#f6f6f6"), profile)
	_facet(surface, lip, a, seam, Color.WHITE, profile)
	_facet(surface, a, foot_a, seam, Color("#e5e5e5"), profile)
	_facet(surface, seam, foot_a, foot, Color("#d4d4d4"), profile)
	_facet(surface, seam, foot, foot_b, Color("#dfdfdf"), profile)
	_facet(surface, b, seam, foot_b, Color("#e9e9e9"), profile)


func _facet(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, profile: Vector2) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for point: Vector3 in [a, b, c]:
		surface.set_normal(normal)
		surface.set_color(color)
		# UV 记录从崖脚到崖顶的相对高度，供世界坐标岩材做分层明暗。
		surface.set_uv(Vector2((point.y - profile.x) * profile.y, 1.0))
		surface.add_vertex(point)


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	for point: Vector3 in [a, b, c, a, c, d]:
		surface.set_normal(normal)
		surface.set_color(color)
		surface.set_uv(Vector2.ZERO)
		surface.add_vertex(point)
