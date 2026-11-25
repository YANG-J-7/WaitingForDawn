extends Node2D
## 第一关林缘装饰，布局随机种固定，主图与小地图共用落点。
const ROOT_SHADER = preload("res://src/gameplay/art/level_forest_root.gdshader")
const FOREST_DIR := "res://assets/levels/level_001/forest/"
const ROCK_DIR := "res://assets/props/rocks_transparent_v1/"
const TREES := [
	["low-oak", Vector2(495, 570), Vector2(128, 196)],
	["tall-broadleaf", Vector2(413, 930), Vector2(175, 275)],
]
const ROCKS := [
	["01-broad-boulder", Vector2(626, 1012), 1087],
	["02-upright-cracked", Vector2(618, 1121), 977],
	["03-low-layered", Vector2(629, 941), 1102],
]
const GRASS_MARGIN := 44.0
const ROOT_DISTANCE_SQUARED := 66.0 * 66.0
var props: Node2D
var shadows: Node2D
var tree_count := 0
var edge_tree_count := 0
var rock_count := 0
var errors: PackedStringArray = []
var _roots: Array[Vector2] = []


func configure(path: String, grid: GridMapModel) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.has_all(["seed", "groves", "rock_groups"]):
		errors.append("林缘布局无法读取：" + path)
		return
	var tree_textures := _textures(TREES, FOREST_DIR)
	var rock_textures := _textures(ROCKS, ROCK_DIR)
	if not errors.is_empty():
		return
	props = Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	shadows = Node2D.new()
	shadows.name = "ContactShadows"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(shadows)
	add_child(props)

	var tree_material := ShaderMaterial.new()
	tree_material.shader = ROOT_SHADER
	var shadow_material := CanvasItemMaterial.new()
	shadow_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var shadow_texture := _shadow_texture()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.seed)
	var rock_points: Array[Vector2] = []
	_plant_groves(data.groves, grid, rng, tree_textures, tree_material, shadow_texture, shadow_material, rock_points)

	for group: Array in data.rock_groups:
		var center := Vector2(group[0][0], group[0][1])
		var group_points: Array[Vector2] = []
		for attempt in int(group[1]) * 12:
			var point := center + _scatter(rng) * Vector2(88, 58)
			if not _on_grass(grid, point) or _near_tree(point, 32.0 * 32.0):
				continue
			if group_points.any(func(other: Vector2) -> bool: return other.distance_squared_to(point) < 30.0 * 30.0):
				continue
			var variant := rng.randi_range(0, ROCKS.size() - 1)
			var spec: Array = ROCKS[variant]
			var width := rng.randf_range(31.0, 73.0)
			_place(spec[0], rock_textures[variant], spec[1], point, width / float(spec[2]), rng.randf() < 0.5, null)
			_shadow(shadow_texture, shadow_material, point, Vector2(width * 0.97, width * 0.35))
			group_points.append(point)
			rock_points.append(point)
			rock_count += 1
			if group_points.size() == int(group[1]):
				break

	# 补植在原布局生成后执行，既有树石保留原坐标和朝向。
	_plant_groves(data.get("infill_groves", []), grid, rng, tree_textures, tree_material, shadow_texture, shadow_material, rock_points)
	rng.seed = int(data.seed) + 1
	_plant_edge_rows(data.get("edge_rows", []), rng, tree_textures, tree_material)


func _plant_groves(
	groves: Array, grid: GridMapModel, rng: RandomNumberGenerator, tree_textures: Array[Texture2D],
	tree_material: Material, shadow_texture: Texture2D, shadow_material: Material, rock_points: Array[Vector2],
) -> void:
	for grove: Array in groves:
		var center := Vector2(grove[0][0], grove[0][1])
		var radius := Vector2(grove[1][0], grove[1][1])
		var remaining := int(grove[2])
		for attempt in remaining * 12:
			var point := center + _scatter(rng) * radius
			if not _on_grass(grid, point) or _near_tree(point, ROOT_DISTANCE_SQUARED):
				continue
			if rock_points.any(func(other: Vector2) -> bool: return other.distance_squared_to(point) < 38.0 * 38.0):
				continue
			var variant := rng.randi_range(0, TREES.size() - 1)
			var spec: Array = TREES[variant]
			var texture: Texture2D = tree_textures[variant]
			var height_range: Vector2 = spec[2]
			var factor := rng.randf_range(height_range.x, height_range.y) / texture.get_height()
			_place(spec[0], texture, spec[1], point, factor, rng.randf() < 0.5, tree_material)
			_shadow(shadow_texture, shadow_material, point, Vector2(41, 16) * factor * 4.2)
			_roots.append(point)
			tree_count += 1
			remaining -= 1
			if remaining == 0:
				break

func _plant_edge_rows(rows: Array, rng: RandomNumberGenerator, textures: Array[Texture2D], material: Material) -> void:
	# 树根在玩法区域外，树冠延伸进地图，由视口自然裁切。
	for row: Dictionary in rows:
		var x := float(row.span[0])
		var end := float(row.span[1])
		var spacing := float(row.spacing)
		if spacing <= 0.0:
			errors.append("裁边树林间距必须大于零")
			continue
		while x <= end:
			var variant := rng.randi_range(0, TREES.size() - 1)
			var spec: Array = TREES[variant]
			var texture := textures[variant]
			var height := rng.randf_range(float(row.height[0]), float(row.height[1]))
			var point := Vector2(x, float(row.root_y) + rng.randf_range(-16.0, 16.0))
			var sprite := _place(spec[0], texture, spec[1], point, height / texture.get_height(), rng.randf() < 0.5, material)
			sprite.set_meta("edge_tree", true)
			edge_tree_count += 1
			tree_count += 1
			x += spacing * rng.randf_range(0.84, 1.16)


func _textures(specs: Array, directory: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for spec: Array in specs:
		var path := directory + String(spec[0]) + ".png"
		var texture := load(path) as Texture2D
		if texture == null:
			errors.append("林缘贴图无法读取：" + path)
		textures.append(texture)
	return textures


func _on_grass(grid: GridMapModel, point: Vector2) -> bool:
	for direction in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var sample: Vector2 = point + direction * GRASS_MARGIN
		if grid.cell_data(grid.world_to_cell(sample)).get("terrain_type") != &"grass":
			return false
	return true


func _near_tree(point: Vector2, distance_squared: float) -> bool:
	return _roots.any(func(root: Vector2) -> bool: return root.distance_squared_to(point) < distance_squared)


func _scatter(rng: RandomNumberGenerator) -> Vector2:
	return Vector2.from_angle(rng.randf_range(0.0, TAU)) * sqrt(rng.randf())


func _place(kind: String, texture: Texture2D, foot: Vector2, point: Vector2, factor: float, mirror: bool, material: Material) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = point
	sprite.scale = Vector2.ONE * factor
	sprite.flip_h = mirror
	sprite.offset = Vector2(-texture.get_width() + foot.x if mirror else -foot.x, -foot.y)
	sprite.material = material
	sprite.set_meta("asset_kind", kind)
	props.add_child(sprite)
	return sprite


func _shadow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.015, 0.035, 0.051, 0.27), Color(0.015, 0.035, 0.051, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _shadow(texture: Texture2D, material: Material, point: Vector2, size: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.material = material
	sprite.position = point + Vector2(size.x * 0.12, size.y * 0.16)
	sprite.scale = size / texture.get_size()
	shadows.add_child(sprite)
