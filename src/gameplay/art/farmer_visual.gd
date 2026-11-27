extends Sprite2D
## 两款农民共用世界尺度。姿态、鞋底与地面投影始终读同一帧。

const HEIGHT := 64.0
const CELL := 256.0
const ORIGIN := Vector2(128.0, 234.0)
const RUN_FRAME_SECONDS := 0.11
const TEXTURES := {
	&"male": preload("res://assets/units/farmers/male.png"),
	&"female": preload("res://assets/units/farmers/female.png"),
}
const SURFACE = preload("res://src/gameplay/art/farmer_surface.gdshader")
const CAST = preload("res://src/gameplay/art/farmer_shadow.gdshader")
const SHADOW_ROWS := [-0.22, 0.0, 0.13, 0.32, 0.54, 0.75, 0.96, 1.18, 1.38]
const POSES = preload("res://assets/units/farmers/feet.gd").POSES

var variant_name: StringName
var standing_height: float
var lighting: WorldLighting
var shadow: Polygon2D
var _surface := ShaderMaterial.new()
var _shade := ShaderMaterial.new()
var _visible_contacts: Array[Vector2] = []
var _stance := 0
var _run_time := 0.0
var _last_position := Vector2.INF
var _frame_changed := true


func configure(variant: StringName, world_lighting: WorldLighting) -> void:
	variant_name = variant
	lighting = world_lighting
	texture = TEXTURES[variant]
	hframes = 4
	vframes = 2
	centered = false
	offset = -ORIGIN
	standing_height = POSES[variant].standing_height
	scale = Vector2.ONE * (HEIGHT / standing_height)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_surface.shader = SURFACE
	material = _surface


func _ready() -> void:
	if not is_instance_valid(lighting):
		return
	var terrain := lighting.terrain_receiver
	var ground: Node = terrain.get("forest_lighting") if terrain != null else null
	if ground != null:
		shadow = Polygon2D.new()
		shadow.name = "FarmerGroundShadow"
		shadow.material = _shade
		shadow.texture = texture
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_shade.shader = CAST
		ground.add_ground_projection(shadow, global_position)
	lighting.main_light_changed.connect(_update_light)
	get_parent().visibility_changed.connect(_sync_shadow_visibility)
	_update_light()


func _exit_tree() -> void:
	if is_instance_valid(shadow) and not shadow.is_queued_for_deletion():
		shadow.hide()
		shadow.queue_free()


func advance_pose(movement: Vector2, delta: float) -> void:
	var wanted_frame := _stance
	var mirror := false
	if movement.length_squared() > 0.0001:
		var left := movement.x < -0.03 or (absf(movement.x) <= 0.03 and _stance in [1, 2])
		# 背向使用已出图的背面姿态。正面跑步使用原图及左右镜像。
		if movement.y < -absf(movement.x) * 0.25:
			_stance = 2 if left else 3
			wanted_frame = _stance
			_run_time = 0.0
		else:
			_stance = 1 if left else 0
			wanted_frame = 4 + floori(_run_time / RUN_FRAME_SECONDS) % 4
			mirror = left
			_run_time = fposmod(_run_time + delta, RUN_FRAME_SECONDS * 4.0)
	else:
		_run_time = 0.0
	if frame != wanted_frame or flip_h != mirror:
		frame = wanted_frame
		flip_h = mirror
		_frame_changed = true
	if _frame_changed or _last_position != global_position:
		_update_light()


func _sync_shadow_visibility() -> void:
	if is_instance_valid(shadow):
		shadow.visible = is_visible_in_tree() and is_instance_valid(lighting) and lighting.lighting_enabled


func _update_light() -> void:
	_last_position = global_position
	var sample := lighting.main_light_sample() if is_instance_valid(lighting) else {}
	_surface.set_shader_parameter("key_enabled", not sample.is_empty())
	_surface.set_shader_parameter("frame_column", float(frame % 4))
	_surface.set_shader_parameter("mirror", flip_h)
	if _frame_changed:
		_visible_contacts.clear()
		for foot: Vector2 in POSES[variant_name].feet[frame]:
			var point := foot
			if flip_h:
				point.x = CELL - point.x
			_visible_contacts.append((point - ORIGIN) * scale.x)
		_visible_contacts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		_frame_changed = false
	if is_instance_valid(shadow):
		shadow.visible = is_visible_in_tree() and not sample.is_empty()
	if sample.is_empty():
		return
	var to_light: Vector2 = sample.position - global_position
	var key := to_light.normalized()
	var color: Color = sample.color
	var dawn: float = sample.dawn_weight
	var energy: float = sample.energy
	_surface.set_shader_parameter("key_direction", key)
	_surface.set_shader_parameter("key_color", Vector3(color.r, color.g, color.b))
	_surface.set_shader_parameter("key_strength", clampf(energy / 0.48, 0.0, 1.0))
	_surface.set_shader_parameter("dawn_weight", dawn)
	if is_instance_valid(shadow):
		_update_shadow(-key, dawn, energy)


func _update_shadow(direction: Vector2, dawn: float, energy: float) -> void:
	var foot := _visible_contacts[0]
	var slope := 0.0
	if _visible_contacts.size() == 2:
		var second := _visible_contacts[1]
		slope = (second.y - foot.y) / maxf(2.0, second.x - foot.x)
		foot = (foot + second) * 0.5
	var reach := HEIGHT * lerpf(0.49, 0.18, dawn)
	var across := Vector2(direction.y, -direction.x) * 0.76
	var box := Vector2(frame_coords) * CELL
	var points := PackedVector2Array()
	var coordinates := PackedVector2Array()
	var triangles: Array[PackedInt32Array] = []
	# 底段保留各鞋底的真实坐标。越靠身体上方，轮廓越顺着背光方向展开。
	for t in SHADOW_ROWS:
		var blend: float = smoothstep(0.0, 0.56, t)
		for sprite_x in [0.0, CELL]:
			var lateral: float = (sprite_x - ORIGIN.x) * scale.x - foot.x
			var sole_y := foot.y + slope * lateral
			var sprite_y: float = ORIGIN.y + (sole_y - t * HEIGHT) / scale.y
			var width_axis := Vector2(1.0, slope).lerp(across, blend)
			points.append(foot + width_axis * lateral + direction * maxf(0.0, t) * reach + Vector2(0.0, minf(0.0, t) * 9.0))
			var sample_x: float = CELL - sprite_x if flip_h else sprite_x
			coordinates.append(box + Vector2(sample_x, sprite_y))
	for index in SHADOW_ROWS.size() - 1:
		var a := index * 2
		triangles.append(PackedInt32Array([a, a + 1, a + 2]))
		triangles.append(PackedInt32Array([a + 1, a + 3, a + 2]))
	shadow.global_position = global_position
	shadow.polygon = points
	shadow.uv = coordinates
	shadow.polygons = triangles
	_shade.set_shader_parameter("frame_rect", Vector4(box.x, box.y, CELL, CELL))
	_shade.set_shader_parameter("shade", Color(0.025, 0.046, 0.067, (0.46 + 0.30 * energy) * lerpf(1.0, 0.59, dawn)))
	_shade.set_shader_parameter("left_sole", _visible_contacts[0])
	_shade.set_shader_parameter("right_sole", _visible_contacts[-1])
