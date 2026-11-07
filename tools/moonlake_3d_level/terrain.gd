extends Node3D

const Field = preload("res://tools/moonlake_3d_level/heightfield.gd")
const Pine = preload("res://tools/moonlake_3d_art/stage.gd")
const GROUND = preload("res://tools/moonlake_3d_art/ground.gdshader")
const LAKE = preload("res://tools/moonlake_3d_art/lake.gdshader")
const FOLIAGE = preload("res://tools/moonlake_3d_art/foliage.gdshader")
const FOREST_PATH := "res://assets/map_kits/reference_hd_20261102/forest.json"
const CHUNK_SIZE := Vector2i(28, 20)

var field: Field
var terrain_material := ShaderMaterial.new()
var lake_material := ShaderMaterial.new()
var tree_material := ShaderMaterial.new()
var overview_texture: ImageTexture
var forest: MultiMeshInstance3D
var chunk_count := 0


func configure(source: Field) -> void:
	field = source
	terrain_material.shader = GROUND
	lake_material.shader = LAKE
	tree_material.shader = FOLIAGE
	_build_chunks()
	_build_lake()
	_build_forest()


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
					_quad(surface, a, b, c, d, Vector3.UP, field.COLORS[field.kind(cell)])
					_wall(surface, a, b, cell + Vector2i.UP, Vector3.FORWARD)
					_wall(surface, b, c, cell + Vector2i.RIGHT, Vector3.RIGHT)
					_wall(surface, c, d, cell + Vector2i.DOWN, Vector3.BACK)
					_wall(surface, d, a, cell + Vector2i.LEFT, Vector3.LEFT)
			_add_surface(surface, terrain_material)
			chunk_count += 1


func _build_lake() -> void:
	var wet := Image.create_empty(field.size.x, field.size.y, false, Image.FORMAT_L8)
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
			wet.set_pixel(column, row, Color.WHITE)
			var a := Vector3(column, field.WATER_HEIGHT + 0.008, row)
			_quad(surface, a, a + Vector3.RIGHT, a + Vector3.RIGHT + Vector3.BACK, a + Vector3.BACK, Vector3.UP, Color.WHITE)
	lake_material.set_shader_parameter("wet_cells", ImageTexture.create_from_image(wet))
	lake_material.set_shader_parameter("grid_size", Vector2(field.size))
	overview_texture = ImageTexture.create_from_image(overview)
	_add_surface(surface, lake_material)


func _build_forest() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOREST_PATH))
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = Pine.create_pine_mesh(tree_material)
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
	forest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(forest)


func _add_surface(surface: SurfaceTool, material: Material) -> void:
	surface.set_material(material)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _wall(surface: SurfaceTool, a: Vector3, b: Vector3, neighbor: Vector2i, normal: Vector3) -> void:
	var bottom := field.height(neighbor)
	if bottom < a.y:
		_quad(surface, b, a, Vector3(a.x, bottom, a.z), Vector3(b.x, bottom, b.z), normal, Color("#5b6571"))


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	for point: Vector3 in [a, b, c, a, c, d]:
		surface.set_normal(normal)
		surface.set_color(color)
		surface.add_vertex(point)
