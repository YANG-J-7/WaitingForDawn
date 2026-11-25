extends Node
## 第一关主图共用主光时钟与树体原图；投射几何由顶点着色器随光源更新。
const TREE_SHADER = preload("res://src/gameplay/art/level_forest_light.gdshader")
const CAST_SHADER = preload("res://src/gameplay/art/level_forest_cast.gdshader")
const ROOT_SHADER = preload("res://src/gameplay/art/level_forest_root.gdshader")

var _trees: Array[Sprite2D] = []
var _original_material: Material
var _tree_material := ShaderMaterial.new()
var _cast_material := ShaderMaterial.new()
var _shadow_layer := Node2D.new()
var _active := false


func configure(forest: Node2D, bounds: Rect2, visual_bounds: Rect2, lake: Node2D, mountain: Sprite2D) -> void:
	_tree_material.shader = TREE_SHADER
	_cast_material.shader = CAST_SHADER
	_bind_receivers(bounds, visual_bounds, lake, mountain)
	_cast_material.set_shader_parameter("ground_depth", bounds.size.y * 0.21)
	_shadow_layer.name = "MovingTreeShadows"
	forest.add_child(_shadow_layer)
	forest.move_child(_shadow_layer, forest.props.get_index())
	_shadow_layer.hide()
	for sprite: Sprite2D in forest.props.get_children():
		if not sprite.material is ShaderMaterial or sprite.material.shader != ROOT_SHADER:
			continue
		_trees.append(sprite)
		_original_material = sprite.material
		var rect := sprite.global_transform * sprite.get_rect()
		sprite.set_instance_shader_parameter("crown_center", rect.position + rect.size * Vector2(0.5, 0.37))
		sprite.set_instance_shader_parameter("crown_radius", rect.size * Vector2(0.43, 0.41))
		_add_cast(sprite, rect)


func update_lighting(lighting: Node2D) -> void:
	var moon: PointLight2D = lighting.sky_light
	_set_active(lighting.lighting_enabled and is_instance_valid(moon))
	if not _active:
		return
	var sun: PointLight2D = lighting.sun_light
	var moon_energy := moon.energy if moon.enabled else 0.0
	var sun_energy := sun.energy if is_instance_valid(sun) and sun.enabled else 0.0
	var energy := moon_energy + sun_energy
	var dawn_weight := sun_energy / maxf(energy, 0.0001)
	var key_position := moon.global_position
	var key_color := moon.color
	var key_radius := _light_radius(moon)
	if is_instance_valid(sun):
		key_position = key_position.lerp(sun.global_position, dawn_weight)
		key_color = key_color.lerp(sun.color, dawn_weight)
		key_radius = lerpf(key_radius, _light_radius(sun), dawn_weight)
	_tree_material.set_shader_parameter("key_position", key_position)
	_tree_material.set_shader_parameter("key_color", Vector3(key_color.r, key_color.g, key_color.b))
	_tree_material.set_shader_parameter("key_energy", energy)
	_tree_material.set_shader_parameter("key_radius", key_radius)
	_tree_material.set_shader_parameter("moon_weight", 1.0 - lighting.dawn_progress)
	var opacity := lerpf(0.49, 0.32, dawn_weight) * clampf(energy / 0.48, 0.0, 1.0)
	_cast_material.set_shader_parameter("shade", Color(0.025, 0.045, 0.069, opacity))
	_cast_material.set_shader_parameter("key_position", key_position)
	_cast_material.set_shader_parameter("dawn_weight", dawn_weight)


func _set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	_shadow_layer.visible = value
	for tree in _trees:
		tree.material = _tree_material if value else _original_material


func _light_radius(light: PointLight2D) -> float:
	return light.texture.get_width() * light.texture_scale * 0.5


func _bind_receivers(bounds: Rect2, visual: Rect2, lake: Node2D, mountain: Sprite2D) -> void:
	_cast_material.set_shader_parameter("visual_rect", Vector4(visual.position.x, visual.position.y, visual.size.x, visual.size.y))
	_cast_material.set_shader_parameter("world_size", bounds.size)
	if is_instance_valid(lake) and lake.water_material != null:
		_cast_material.set_shader_parameter("has_water", true)
		for parameter in ["water_control", "extend_boundary", "coast_field", "field_rect", "north_coast_x"]:
			var value: Variant = lake.water_material.get_shader_parameter(parameter)
			if value != null:
				_cast_material.set_shader_parameter(parameter, value)
	if is_instance_valid(mountain) and mountain.texture != null:
		var rect := mountain.global_transform * mountain.get_rect()
		_cast_material.set_shader_parameter("has_mountain", true)
		_cast_material.set_shader_parameter("mountain_art", mountain.texture)
		_cast_material.set_shader_parameter("mountain_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))


func _add_cast(tree: Sprite2D, rect: Rect2) -> void:
	var shade := Polygon2D.new()
	shade.position = _shadow_layer.to_local(tree.global_position + Vector2(0.0, 3.0))
	shade.texture = tree.texture
	shade.material = _cast_material
	var left := (rect.position.x - tree.global_position.x) * 0.70
	var right := (rect.end.x - tree.global_position.x) * 0.70
	# 顶点位移由灯光驱动，原始矩形覆盖所有可能投射方向，以供视口裁剪使用。
	var extent := rect.size.y * 1.02 + maxf(absf(left), absf(right))
	shade.polygon = PackedVector2Array([
		Vector2(-extent, -extent), Vector2(extent, -extent),
		Vector2(extent, extent), Vector2(-extent, extent),
	])
	var size := tree.texture.get_size()
	var u_left := size.x if tree.flip_h else 0.0
	var u_right := 0.0 if tree.flip_h else size.x
	shade.uv = PackedVector2Array([
		Vector2(u_left, 0.0), Vector2(u_right, 0.0),
		Vector2(u_right, size.y), Vector2(u_left, size.y),
	])
	shade.set_instance_shader_parameter("cast_shape", Vector3(rect.size.y, left, right))
	if tree.has_meta("edge_tree"):
		shade.set_instance_shader_parameter("cast_opacity", 0.74)
	_shadow_layer.add_child(shade)

