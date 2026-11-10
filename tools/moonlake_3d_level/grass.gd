extends Node3D

const Field = preload("res://tools/moonlake_3d_level/heightfield.gd")
const GRASS_SHADER = preload("res://tools/moonlake_3d_level/grass.gdshader")
const TUFTS = preload("res://assets/map_kits/moonlit_v3/grass/tufts.png")
const ROOT_UV := 114.0 / 128.0
const STRIPS := 6

var material := ShaderMaterial.new()
var _grid: GridMapModel
var _batches: Array[MultiMesh] = []
var _instances: Dictionary[Vector2i, Vector2i] = {}


func configure(field: Field, grid: GridMapModel, town_center: Vector2, chunk_size: Vector2i) -> void:
	_grid = grid
	material.shader = GRASS_SHADER
	material.set_shader_parameter("tuft_atlas", TUFTS)
	var mesh := _create_mesh()
	var random := RandomNumberGenerator.new()
	random.seed = 20261110
	var patches := FastNoiseLite.new()
	patches.seed = 20261110
	patches.frequency = 0.18
	for y in range(0, field.size.y, chunk_size.y):
		for x in range(0, field.size.x, chunk_size.x):
			var rect := Rect2i(Vector2i(x, y), chunk_size).intersection(Rect2i(Vector2i.ZERO, field.size))
			var cells: Array[Vector2i] = []
			for row in range(rect.position.y, rect.end.y):
				for column in range(rect.position.x, rect.end.x):
					var cell := Vector2i(column, row)
					if field.kind(cell) not in ["grass", "mountain_grass", "forest"]:
						continue
					if (Vector2(cell) + Vector2(0.5, 0.5)).distance_squared_to(town_center) < 20.25:
						continue
					var density := 0.24 + 0.23 * patches.get_noise_2d(column, row)
					if random.randf() < density:
						cells.append(cell)
			if not cells.is_empty():
				_add_batch(mesh, field, cells, random)
	grid.navigation_cells_changed.connect(_update_occupancy)


func _add_batch(mesh: ArrayMesh, field: Field, cells: Array[Vector2i], random: RandomNumberGenerator) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true
	batch.mesh = mesh
	batch.instance_count = cells.size()
	for index in range(cells.size()):
		var cell := cells[index]
		var origin := Vector3(
			cell.x + random.randf_range(0.43, 0.57),
			field.height(cell) + 0.008,
			cell.y + random.randf_range(0.35, 0.65)
		)
		var scale := Vector3(random.randf_range(0.88, 1.06), random.randf_range(1.42, 1.80), 1.0)
		batch.set_instance_transform(index, Transform3D(Basis.from_scale(scale), origin))
		batch.set_instance_custom_data(index, Color((random.randi_range(0, 3) + 0.5) / 4.0, _visible_cell(cell), 0.0, 1.0))
		_instances[cell] = Vector2i(_batches.size(), index)
	_batches.append(batch)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.extra_cull_margin = 0.30
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _visible_cell(cell: Vector2i) -> float:
	return 0.0 if _grid.is_walkable(cell) and _grid.is_solid(cell) else 1.0


func _update_occupancy(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if not _instances.has(cell):
			continue
		var slot: Vector2i = _instances[cell]
		var batch := _batches[slot.x]
		var data := batch.get_instance_custom_data(slot.y)
		data.g = _visible_cell(cell)
		batch.set_instance_custom_data(slot.y, data)


func _create_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for row in range(STRIPS):
		var top := float(row) / STRIPS
		var bottom := float(row + 1) / STRIPS
		for uv: Vector2 in [
			Vector2(0, top), Vector2(1, top), Vector2(1, bottom),
			Vector2(0, top), Vector2(1, bottom), Vector2(0, bottom),
		]:
			surface.set_normal(Vector3(0.0, 0.90, 0.436))
			surface.set_uv(uv)
			surface.add_vertex(Vector3(uv.x - 0.5, ROOT_UV - uv.y, 0.0))
	return surface.commit()
