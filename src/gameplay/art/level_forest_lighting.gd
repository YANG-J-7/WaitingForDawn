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
		var local_rect := sprite.get_rect()
		var rect := sprite.global_transform * local_rect
		sprite.set_instance_shader_parameter("crown_center", rect.position + rect.size * Vector2(0.5, 0.37))
		sprite.set_instance_shader_parameter("crown_radius", rect.size * Vector2(0.43, 0.41))
		var opacity := 0.74 if sprite.has_meta("edge_tree") else 1.0
		# 精灵原点是布局的树脚，贴图底边还包含根尖与透明留白。
		var root_y := -local_rect.position.y / local_rect.size.y
		add_ground_cast(sprite, sprite.global_position, rect.size.y, 0.70, opacity, root_y)


func update_lighting(lighting: Node2D) -> void:
	var sample: Dictionary = lighting.main_light_sample()
	_set_active(not sample.is_empty())
	if not _active:
		return
	var key_color: Color = sample.color
	var dawn_weight: float = sample.dawn_weight
	_tree_material.set_shader_parameter("key_position", sample.position)
	_tree_material.set_shader_parameter("key_color", Vector3(key_color.r, key_color.g, key_color.b))
	_tree_material.set_shader_parameter("key_energy", sample.energy)
	_tree_material.set_shader_parameter("key_radius", sample.radius)
	_tree_material.set_shader_parameter("moon_weight", 1.0 - lighting.dawn_progress)
	var opacity := lerpf(0.49, 0.32, dawn_weight) * clampf(sample.energy / 0.48, 0.0, 1.0)
	_cast_material.set_shader_parameter("shade", Color(0.025, 0.045, 0.069, opacity))
	_cast_material.set_shader_parameter("key_position", sample.position)
	_cast_material.set_shader_parameter("dawn_weight", dawn_weight)


func _set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	_shadow_layer.visible = value
	for tree in _trees:
		tree.material = _tree_material if value else _original_material


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


func add_ground_cast(source: Sprite2D, root: Vector2, reach: float, width_ratio: float, opacity: float, root_y: float = 1.0) -> Polygon2D:
	var shade := Polygon2D.new()
	shade.position = _shadow_layer.to_local(root)
	shade.texture = source.texture
	shade.material = _cast_material
	var rect := source.global_transform * source.get_rect()
	var left := (rect.position.x - root.x) * width_ratio
	var right := (rect.end.x - root.x) * width_ratio
	# 顶点位移由灯光驱动，原始矩形覆盖所有可能投射方向，以供视口裁剪使用。
	var extent := reach * 1.02 + maxf(absf(left), absf(right))
	shade.polygon = PackedVector2Array([
		Vector2(-extent, -extent), Vector2(extent, -extent),
		Vector2(extent, extent), Vector2(-extent, extent),
	])
	var size := source.texture.get_size()
	var u_left := size.x if source.flip_h else 0.0
	var u_right := 0.0 if source.flip_h else size.x
	shade.uv = PackedVector2Array([
		Vector2(u_left, 0.0), Vector2(u_right, 0.0),
		Vector2(u_right, size.y), Vector2(u_left, size.y),
	])
	shade.set_instance_shader_parameter("cast_shape", Vector3(reach, left, right))
	shade.set_instance_shader_parameter("cast_opacity", opacity)
	shade.set_instance_shader_parameter("cast_root_y", root_y)
	_shadow_layer.add_child(shade)
	return shade


func add_ground_projection(shadow: Polygon2D, world_position: Vector2) -> void:
	for parameter in ["visual_rect", "has_water", "water_control", "world_size", "extend_boundary",
			"coast_field", "field_rect", "north_coast_x", "has_mountain", "mountain_art", "mountain_rect"]:
		var value: Variant = _cast_material.get_shader_parameter(parameter)
		if value != null:
			shadow.material.set_shader_parameter(parameter, value)
	_shadow_layer.add_child(shadow)
	shadow.global_position = world_position



func add_ground_detail(detail: Sprite2D, world_position: Vector2) -> void:
	var surface := _shadow_layer.get_parent() as Node2D
	detail.position = surface.to_local(world_position)
	surface.add_child(detail)
	surface.move_child(detail, _shadow_layer.get_index())

