extends RefCounted

const Field = preload("res://tools/moonlake_3d_level/heightfield.gd")
const COAST_RANGE := 12.0
const SIDES := 12
const SWEEP := [Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]


static func distance_to_water(field: Field) -> PackedFloat32Array:
	var inland := _distance_from(field, true)
	var lake := _distance_from(field, false)
	for i in range(inland.size()):
		inland[i] = lake[i] - 0.5 if inland[i] == 0.0 else 0.5 - inland[i]
	return inland


static func _distance_from(field: Field, from_water: bool) -> PackedFloat32Array:
	var distance := PackedFloat32Array()
	distance.resize(field.kinds.size())
	for i in range(distance.size()):
		distance[i] = 0.0 if (field.kinds[i] == "water") == from_water else COAST_RANGE * 0.5
	for step: int in [1, -1]:
		for i in range(0 if step == 1 else distance.size() - 1, distance.size() if step == 1 else -1, step):
			if distance[i] == 0.0:
				continue
			var cell := Vector2i(i % field.size.x, floori(float(i) / field.size.x))
			for offset: Vector2i in SWEEP:
				var adjacent := cell + offset * step
				if field.inside(adjacent):
					distance[i] = minf(distance[i], distance[field.index(adjacent)] + offset.length())
	return distance


static func create_rock_mesh(material: Material) -> ArrayMesh:
	var surface := _surface()
	var foot := _ring(-0.12, 0.79, 0.1, 0.15)
	var shoulder := _ring(0.48, 0.77, 0.1, 0.29)
	var ridge := _ring(0.88, 0.44, 0.23, 0.21)
	_band(surface, foot, shoulder, Color("#c0c0c0"))
	_band(surface, shoulder, ridge, Color("#dddddd"))
	_cap(surface, ridge, Vector3(0.10, 1.03, -0.13), Color("#e3e3e3"))
	return _commit(surface, material)


static func _surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	return surface


static func _commit(surface: SurfaceTool, material: Material) -> ArrayMesh:
	surface.generate_normals()
	surface.set_material(material)
	return surface.commit()


static func _ring(height: float, radius: float, phase: float, variation: float) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for i in range(SIDES):
		var angle := TAU * i / SIDES + phase
		var reach := radius * (1.0 + variation * cos(i * 2.79 + phase))
		ring.append(Vector3(cos(angle) * reach, height + variation * 0.32 * sin(i * 2.3 + phase), sin(angle) * reach))
	return ring


static func _band(surface: SurfaceTool, low: PackedVector3Array, high: PackedVector3Array, tint: Color) -> void:
	for i in range(SIDES):
		var next := (i + 1) % SIDES
		var color := tint.darkened(0.08 + 0.08 * sin(i * 2.2))
		_triangle(surface, low[i], low[next], high[next], color)
		_triangle(surface, low[i], high[next], high[i], color)


static func _cap(surface: SurfaceTool, ring: PackedVector3Array, center: Vector3, tint: Color) -> void:
	for i in range(SIDES):
		var next := (i + 1) % SIDES
		var color := tint.darkened(0.07 + 0.07 * cos(i * 2.7))
		_triangle(surface, ring[i], ring[next], center, color)


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	for vertex: Vector3 in [a, b, c]:
		surface.set_color(tint)
		surface.add_vertex(vertex)
