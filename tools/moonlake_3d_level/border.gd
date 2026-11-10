extends Node3D
## 地图外的湖林背景，与拾取和玩法网格分离。

const Field = preload("res://tools/moonlake_3d_level/heightfield.gd")
const Layout = preload("res://tools/moonlake_3d_level/v5_layout.gd")
const REACH := 128.0
const VIEW_MARGIN := 26.0


func configure(field: Field, pine: Mesh, ground_material: ShaderMaterial, lake_material: ShaderMaterial) -> void:
	var outer_ground := ground_material.duplicate() as ShaderMaterial
	outer_ground.set_shader_parameter("exterior", true)
	var plane := PlaneMesh.new()
	plane.size = Vector2(field.size) + Vector2.ONE * REACH * 2.0
	plane.material = outer_ground
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.position = Vector3(field.size.x * 0.5, 0.0, field.size.y * 0.5)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	_add_water(field, lake_material)
	var ridge := Node3D.new()
	ridge.name = "V5BackRidge"
	add_child(ridge)
	Layout.add_ridge(ridge, ground_material)
	_add_forest(field, pine)


func _add_water(field: Field, material: ShaderMaterial) -> void:
	var low := Vector2.ONE * -REACH
	var high := Vector2(field.size) + Vector2.ONE * REACH
	var a := Vector2(low.x, low.y)
	var b := Vector2(high.x, low.y)
	var c := Vector2(high.x, high.y)
	var d := Vector2(low.x, high.y)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for corner: Vector2 in [a, b, c, a, c, d]:
		surface.set_color(Color.BLACK)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(corner.x, field.WATER_HEIGHT + 0.008, corner.y))
	var water := MeshInstance3D.new()
	water.mesh = surface.commit()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _add_forest(field: Field, pine: Mesh) -> void:
	var transforms: Array[Transform3D] = []
	var random := RandomNumberGenerator.new()
	random.seed = 20261110
	var lower := PackedVector2Array(Layout.LOWER_RIDGE)
	var upper := PackedVector2Array(Layout.UPPER_RIDGE)
	for side in range(4):
		var along_x := side < 2
		var length := field.size.x if along_x else field.size.y
		for band in range(3):
			for along in range(2, length, 4):
				var near := float(along) + random.randf_range(-1.6, 1.6)
				var offset := 1.6 + band * 3.4 + random.randf_range(-0.6, 0.7)
				var across := -offset if side % 2 == 0 else (field.size.y if along_x else field.size.x) + offset
				var point := Vector2(near, across) if along_x else Vector2(across, near)
				var nearest := Vector2i(point.floor()).clamp(Vector2i.ZERO, field.size - Vector2i.ONE)
				if field.kind(nearest) == "water":
					continue
				var scale := random.randf_range(0.8, 1.4) * (1.0 - band * 0.12)
				var basis := Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale)
				if Layout.clears_tree(point, 1.56 * scale, 3.08 * scale):
					continue
				var elevation := Layout.ridge_height(point, lower, upper)
				transforms.append(Transform3D(basis, Vector3(point.x, elevation, point.y)))
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = pine
	batch.instance_count = transforms.size()
	for index in range(transforms.size()):
		batch.set_instance_transform(index, transforms[index])
	var trees := MultiMeshInstance3D.new()
	trees.multimesh = batch
	trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trees)
