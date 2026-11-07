extends Node3D
## P0 样区。只读取第一关地形数据，以独立场景验证 S6 的高差、网格和镜头。

const MOUNTAIN_PATH := "res://assets/levels/level_001/mountain.json"
const LAKE_PATH := "res://assets/levels/level_001/lake.json"
const CROP := Rect2i(150, 33, 21, 19)
const CELL_SIZE := 36.0
const TERRACE_HEIGHT := 3.2
const WATER_HEIGHT := -0.36
const LOWER_PLOT := Rect2i(150, 44, 2, 2)
const UPPER_PLOT := Rect2i(158, 33, 2, 2)
const PLOT_COLOR := Color(0.39, 1.0, 0.8)
const KINDS := {
	"grass": "平地 · 可走可建",
	"mountain_grass": "山台草地 · 可建，行走沿山路",
	"road": "道路 · 可走可建",
	"ramp": "S6 石梯 · 可走",
	"shore": "岸边 · 可走",
	"cliff": "岩壁 · 禁走禁建",
	"water": "水域 · 禁走禁建",
}

@onready var camera: Camera3D = $Camera3D
@onready var readout: Label = $HUD/Panel/Text/Readout

var terrain_cells: Dictionary[Vector2i, String] = {}
var surface_heights: Dictionary[Vector2i, float] = {}
var stair_points := PackedVector2Array()
var grid_overlay: MeshInstance3D
var selection: MeshInstance3D
var trees_root: Node3D
var pending_pick := Vector2.INF


func _ready() -> void:
	_load_terrain()
	_build_terrain()
	_build_guides()
	_build_trees()
	set_view(1)
	readout.text = "青色框为平地与山台的 2×2 样例占地"


func _load_terrain() -> void:
	var mountain: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MOUNTAIN_PATH))
	var lake: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAKE_PATH))
	var offset := Vector2i(mountain.origin[0], mountain.origin[1]) / int(CELL_SIZE)
	for path: Dictionary in mountain.paths:
		if path.id == "stair_6":
			for point: Array in path.points:
				stair_points.append(Vector2(point[0], point[1]) / CELL_SIZE + Vector2(offset - CROP.position))
			break

	_mark_cells(mountain.navigation.mountainCells, offset, "mountain_grass")
	_mark_cells(mountain.navigation.cliffCells, offset, "cliff")
	for entry: Dictionary in mountain.navigation.cells:
		var cell := Vector2i(entry.cell[0], entry.cell[1]) + offset
		if CROP.has_point(cell):
			terrain_cells[cell] = entry.kind
			if entry.stair == 6:
				surface_heights[cell] = _stair_height(Vector2(cell - CROP.position) + Vector2(0.5, 0.5))
			else:
				surface_heights[cell] = TERRACE_HEIGHT * maxf(0.0, float(entry.level))
	var water_offset := Vector2i(lake.origin[0], lake.origin[1]) / int(CELL_SIZE)
	_mark_cells(lake.terrain.water, water_offset, "water")
	for point: Array in lake.terrain.water:
		var water_cell := Vector2i(point[0], point[1]) + water_offset
		for y in range(-1, 2):
			for x in range(-1, 2):
				var neighbor := water_cell + Vector2i(x, y)
				if CROP.has_point(neighbor) and kind_at(neighbor) in ["grass", "road"]:
					terrain_cells[neighbor] = "shore"


func _mark_cells(points: Array, offset: Vector2i, kind: String) -> void:
	for point: Array in points:
		var cell := Vector2i(point[0], point[1]) + offset
		if CROP.has_point(cell):
			terrain_cells[cell] = kind


func kind_at(cell: Vector2i) -> String:
	return terrain_cells.get(cell, "grass")


func height_at(cell: Vector2i) -> float:
	match kind_at(cell):
		"water":
			return WATER_HEIGHT
		"mountain_grass":
			return 0.0 if cell.y >= 44 else TERRACE_HEIGHT
		"cliff":
			# 岩壁高度是样区占位，通行和建造分类沿用原网格。
			var base_height := 0.4 if cell.y >= 44 else 1.6
			return base_height + 0.2 * float(posmod(cell.x * 7 + cell.y * 11, 4))
		_:
			return surface_heights.get(cell, 0.0)


func _stair_height(point: Vector2) -> float:
	var heights := PackedFloat32Array([0.0, 1.6, 1.6, 1.6, 2.6, TERRACE_HEIGHT])
	var distance := INF
	var height := 0.0
	for i in range(stair_points.size() - 1):
		var start := stair_points[i]
		var end := stair_points[i + 1]
		var nearest := Geometry2D.get_closest_point_to_segment(point, start, end)
		var candidate := point.distance_squared_to(nearest)
		if candidate < distance:
			distance = candidate
			height = lerpf(heights[i], heights[i + 1], nearest.distance_to(start) / start.distance_to(end))
	return snappedf(height, 0.4)


func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(CROP.position.y, CROP.end.y):
		for x in range(CROP.position.x, CROP.end.x):
			var cell := Vector2i(x, y)
			var height := height_at(cell)
			var local := cell - CROP.position
			var a := Vector3(local.x, height, local.y)
			var b := a + Vector3.RIGHT
			var c := b + Vector3.BACK
			var d := a + Vector3.BACK
			var color := _cell_color(cell)
			_quad(surface, a, b, c, d, Vector3.UP, color)
			_wall(surface, a, b, cell + Vector2i.UP, Vector3.FORWARD)
			_wall(surface, b, c, cell + Vector2i.RIGHT, Vector3.RIGHT)
			_wall(surface, c, d, cell + Vector2i.DOWN, Vector3.BACK)
			_wall(surface, d, a, cell + Vector2i.LEFT, Vector3.LEFT)

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	surface.set_material(material)
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = surface.commit()
	add_child(terrain)
	terrain.create_trimesh_collision()


func _cell_color(cell: Vector2i) -> Color:
	match kind_at(cell):
		"water":
			return Color("#31687d")
		"shore":
			return Color("#8d8261")
		"cliff":
			return Color("#626d79")
		"ramp":
			return Color("#c5a47d")
		"road":
			return Color("#988668")
		"mountain_grass":
			return Color("#648777")
		_:
			return Color("#739371")


func _wall(surface: SurfaceTool, a: Vector3, b: Vector3, neighbor: Vector2i, normal: Vector3) -> void:
	var bottom := height_at(neighbor) if CROP.has_point(neighbor) else -0.8
	if bottom >= a.y:
		return
	var color := Color("#5b6571")
	_quad(surface, b, a, Vector3(a.x, bottom, a.z), Vector3(b.x, bottom, b.z), normal, color)


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	for point: Vector3 in [a, b, c, a, c, d]:
		surface.set_normal(normal)
		surface.set_color(color)
		surface.add_vertex(point)


func _build_guides() -> void:
	var grid_lines := PackedVector3Array()
	for y in range(CROP.position.y, CROP.end.y):
		for x in range(CROP.position.x, CROP.end.x):
			var cell := Vector2i(x, y)
			grid_lines.append_array(_outline(cell, Vector2i.ONE, 0.015))
	grid_overlay = _lines(grid_lines, Color("#405c67"))
	grid_overlay.hide()
	for plot: Rect2i in [LOWER_PLOT, UPPER_PLOT]:
		_lines(_outline(plot.position, plot.size, 0.04), PLOT_COLOR)
	selection = _lines(_outline(LOWER_PLOT.position, Vector2i.ONE, 0.065), Color("#ffe49e"))
	selection.hide()


func _outline(cell: Vector2i, size: Vector2i, lift: float) -> PackedVector3Array:
	var local := cell - CROP.position
	var a := Vector3(local.x, height_at(cell) + lift, local.y)
	var b := a + Vector3.RIGHT * size.x
	var c := b + Vector3.BACK * size.y
	var d := a + Vector3.BACK * size.y
	return PackedVector3Array([a, b, b, c, c, d, d, a])


func _lines(points: PackedVector3Array, color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for point: Vector3 in points:
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)
	return instance


func _build_trees() -> void:
	trees_root = Node3D.new()
	trees_root.name = "TreePlaceholders"
	add_child(trees_root)
	var crown := CylinderMesh.new()
	crown.radial_segments = 7
	crown.rings = 0
	crown.top_radius = 0.0
	crown.bottom_radius = 0.44
	crown.height = 1.05
	var foliage := StandardMaterial3D.new()
	foliage.albedo_color = Color("#3c655b")
	crown.material = foliage
	var trunk := CylinderMesh.new()
	trunk.radial_segments = 6
	trunk.top_radius = 0.067
	trunk.bottom_radius = 0.09
	trunk.height = 0.65
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color("#58483e")
	trunk.material = bark
	for cell: Vector2i in [Vector2i(165, 34), Vector2i(167, 33), Vector2i(168, 35), Vector2i(166, 36),
			Vector2i(169, 37), Vector2i(168, 39), Vector2i(170, 34), Vector2i(170, 38)]:
		var tree := Node3D.new()
		var local := cell - CROP.position
		tree.position = Vector3(local.x + 0.5, height_at(cell), local.y + 0.5)
		tree.scale *= 0.9 + 0.13 * float(posmod(cell.x + cell.y * 2, 4))
		trees_root.add_child(tree)
		for i in range(3):
			var part := MeshInstance3D.new()
			part.mesh = trunk if i == 0 else crown
			part.position.y = 0.325 if i == 0 else 0.55 + 0.52 * i
			tree.add_child(part)


func set_view(view: int, focus: Vector3 = Vector3.INF) -> void:
	var target := Vector3(10.5, 0.8, 9.4)
	var offset := Vector3(-6.0, 20.0, 23.0)
	camera.size = 23.0
	if view == 2:
		target = Vector3(9.3, 1.4, 7.8)
		camera.size = 11.5
	elif view == 3:
		offset = Vector3(0.0, 24.0, 0.0)
		camera.size = 21.0
		grid_overlay.show()
	if focus.is_finite():
		target = focus
	camera.position = target + offset
	camera.look_at(target, Vector3.FORWARD if view == 3 else Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: set_view(1)
			KEY_2: set_view(2)
			KEY_3: set_view(3)
			KEY_G: grid_overlay.visible = not grid_overlay.visible
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pending_pick = event.position


func _physics_process(_delta: float) -> void:
	if not pending_pick.is_finite():
		return
	var origin := camera.project_ray_origin(pending_pick)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(pending_pick) * camera.far)
	pending_pick = Vector2.INF
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	selection.hide()
	if hit.is_empty():
		readout.text = "请选择样区地面"
		return
	if hit.normal.y < 0.8:
		readout.text = "岩壁立面 · 禁走禁建"
		return
	var point: Vector3 = hit.position
	var cell := Vector2i(floori(point.x), floori(point.z)) + CROP.position
	if not CROP.has_point(cell):
		return
	var local := cell - LOWER_PLOT.position
	selection.position = Vector3(local.x, height_at(cell) - height_at(LOWER_PLOT.position), local.y)
	selection.show()
	readout.text = "原网格 (%d, %d)   %s   高度 %.2f" % [cell.x, cell.y, KINDS[kind_at(cell)], height_at(cell)]
