extends Node2D
## 主城外观可独立预览，正式开局使用一级守夜厅。

const DEFAULT_APPEARANCE = preload("res://assets/buildings/town_hall_levels/level_1.tres")
const GROUND = preload("res://assets/buildings/town_hall_level_1/revision_2/ground.png")
const WATCH_HALL_SHADER = preload("res://src/gameplay/art/watch_hall.gdshader")
const CASTLE_SHADER = preload("res://src/gameplay/art/town_hall_surface.gdshader")
const HallShadow = preload("res://src/gameplay/art/town_hall_shadow.gd")
const FLAG_FRAMES: Array[Texture2D] = [
	preload("res://assets/buildings/town_hall_level_1/revision_2/flag-1.png"),
	preload("res://assets/buildings/town_hall_level_1/revision_2/flag-2.png"),
	preload("res://assets/buildings/town_hall_level_1/revision_2/flag-3.png"),
	preload("res://assets/buildings/town_hall_level_1/revision_2/flag-4.png"),
]
const FIRE_FRAMES: Array[Texture2D] = [
	preload("res://assets/buildings/town_hall_level_1/revision_2/lighting_fire/fire-1.png"),
	preload("res://assets/buildings/town_hall_level_1/revision_2/lighting_fire/fire-2.png"),
	preload("res://assets/buildings/town_hall_level_1/revision_2/lighting_fire/fire-3.png"),
	preload("res://assets/buildings/town_hall_level_1/revision_2/lighting_fire/fire-4.png"),
]

const FLAG_RECT := Vector4(279, 447, 134, 175)
const FIRE_PIXELS := 0.25
const FIRE_BASE := Vector2(64, 112)
const BOWL_POINTS := [Vector2(184, 739), Vector2(495, 764)]

@export var appearance: TownHallAppearance = DEFAULT_APPEARANCE
var lighting: WorldLighting
var preview_only := false
var body: Sprite2D
var cast: HallShadow
var ground_detail: Sprite2D
var flames: Array[Sprite2D] = []
var lights: Array[WorldLightEmitter] = []
var animation_time := 0.0
var _surface := ShaderMaterial.new()
var _watch_hall := true


func _ready() -> void:
	_watch_hall = appearance.face_mask == null
	var units_per_pixel := appearance.width / appearance.body.get_width()
	body = Sprite2D.new()
	body.name = "Body"
	body.texture = appearance.body
	body.centered = false
	body.offset = -appearance.origin
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body.scale = Vector2.ONE * units_per_pixel
	body.material = _surface
	add_child(body)
	if _watch_hall:
		_surface.shader = WATCH_HALL_SHADER
		_surface.set_shader_parameter("flag_rect", FLAG_RECT)
		_surface.set_shader_parameter("fire_left_position", BOWL_POINTS[0])
		_surface.set_shader_parameter("fire_right_position", BOWL_POINTS[1])
		_add_hearth(units_per_pixel)
	else:
		_surface.shader = CASTLE_SHADER
		_surface.set_shader_parameter("face_mask", appearance.face_mask)
		_surface.set_shader_parameter("hearth_mask", appearance.hearth_mask)
	if is_instance_valid(lighting):
		var ground_casts: Node = lighting.terrain_receiver.get("forest_lighting") if lighting.terrain_receiver != null else null
		if ground_casts != null:
			if _watch_hall:
				_add_ground_detail(ground_casts)
			cast = HallShadow.new()
			cast.configure(appearance, units_per_pixel)
			ground_casts.add_ground_projection(cast, global_position)
		lighting.main_light_changed.connect(_update_lighting)
	if preview_only:
		_on_city_health_changed(1, 1)
	else:
		RunState.city_health_changed.connect(_on_city_health_changed)
		_on_city_health_changed(RunState.city_health, RunState.city_max_health)
	_update_lighting()
	_apply_animation()


func _add_hearth(units_per_pixel: float) -> void:
	var flame_material := CanvasItemMaterial.new()
	flame_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for index in BOWL_POINTS.size():
		var source_point: Vector2 = BOWL_POINTS[index] - appearance.origin
		var flame := Sprite2D.new()
		flame.name = "FireLeft" if index == 0 else "FireRight"
		flame.centered = false
		flame.scale = Vector2.ONE * FIRE_PIXELS
		flame.position = source_point * units_per_pixel
		flame.offset = -FIRE_BASE
		flame.material = flame_material
		flame.z_index = 1
		flame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(flame)
		flames.append(flame)
		var light := WorldLightEmitter.new()
		light.position = flame.position + Vector2(0, 9)
		light.radius = 55.0
		light.base_energy = 0.35
		light.energy = light.base_energy
		light.flicker_amount = 0.075
		light.elapsed = index * 0.19
		add_child(light)
		lights.append(light)


func _add_ground_detail(ground_casts: Node) -> void:
	ground_detail = Sprite2D.new()
	ground_detail.name = "WatchHallWornGround"
	ground_detail.texture = GROUND
	ground_detail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ground_detail.scale = Vector2.ONE * (164.0 / GROUND.get_width())
	ground_detail.modulate.a = 0.86
	ground_casts.add_ground_detail(ground_detail, global_position + Vector2(-25, 6))


func _update_lighting() -> void:
	var sample := lighting.main_light_sample() if is_instance_valid(lighting) else {}
	_surface.set_shader_parameter("lighting_enabled", not sample.is_empty())
	if is_instance_valid(cast):
		cast.update_light(sample)
	var dawn: float = sample.get("dawn_weight", 0.0)
	for flame in flames:
		flame.modulate = Color.WHITE.lerp(Color(0.95, 0.88, 0.75, 0.85), dawn)
	if sample.is_empty():
		return
	var direction: Vector2 = sample.position - global_position
	var color: Color = sample.color
	_surface.set_shader_parameter("key_direction", direction.normalized())
	_surface.set_shader_parameter("key_color", Vector3(color.r, color.g, color.b))
	_surface.set_shader_parameter("dawn_weight", dawn)
	if _watch_hall:
		var exposure := 1.0 - smoothstep(0.18, 1.0, direction.length() / maxf(1.0, sample.radius))
		exposure = lerpf(exposure, sqrt(exposure), 0.72 * dawn)
		_surface.set_shader_parameter("key_strength", clampf(sample.energy / 0.48 * exposure, 0.0, 1.0))
	else:
		_surface.set_shader_parameter("key_energy", sample.energy)


func _process(delta: float) -> void:
	if get_tree().paused or (not preview_only and RunState.phase in [RunState.Phase.BOOT, RunState.Phase.RUN_WON, RunState.Phase.RUN_LOST]):
		return
	animation_time += maxf(delta, 0.0)
	_apply_animation()


func _apply_animation() -> void:
	_surface.set_shader_parameter("animation_time", animation_time)
	if _watch_hall:
		_surface.set_shader_parameter("flag_cloth", FLAG_FRAMES[floori(animation_time / 0.265) % FLAG_FRAMES.size()])
		flames[0].texture = FIRE_FRAMES[floori(animation_time * 8.9) % FIRE_FRAMES.size()]
		flames[1].texture = FIRE_FRAMES[(floori(animation_time * 7.2) + 2) % FIRE_FRAMES.size()]


func _on_city_health_changed(health: int, _maximum: int) -> void:
	var alive := health > 0
	_surface.set_shader_parameter("hearth_lit", alive)
	for node in flames:
		node.visible = alive
	for light in lights:
		light.visible = alive


func _exit_tree() -> void:
	for detail: CanvasItem in [cast, ground_detail]:
		if is_instance_valid(detail) and not detail.is_queued_for_deletion():
			detail.hide()
			detail.queue_free()
