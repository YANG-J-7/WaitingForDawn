class_name TownHallVisual
extends Node2D
## 主城表现与占格/战斗解耦；动画仅推进局部图层，不改变建筑主体变换。

const ROOT := "res://assets/buildings/town_hall_v2/"
const DISPLAY_SIZE := Vector2(180, 176)
const BODY_TEXTURE: Texture2D = preload(ROOT + "body.png")
const CAST_TEXTURE: Texture2D = preload(ROOT + "cast-shadow.png")
const CONTACT_TEXTURE: Texture2D = preload(ROOT + "contact-shadow.png")
const GROUND_TEXTURE: Texture2D = preload(ROOT + "ground-base/ground-base.png")
const GROUND_RECT := Rect2(-166, -120, 320, 198)
const WINDOW_SHADER: Shader = preload("res://src/gameplay/art/town_hall_windows.gdshader")

var body: Sprite2D
var flag: Sprite2D
var fire_left: Sprite2D
var fire_right: Sprite2D
var smoke: Sprite2D
var smoke_next: Sprite2D
var grounding: Node2D
var ground_base: Sprite2D
var animation_time := 0.0
var animation_frame := 0
var frame_sets: Dictionary = {}
var window_material: ShaderMaterial


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var file := FileAccess.open(ROOT + "manifest.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	grounding = Node2D.new()
	grounding.name = "TownHallGrounding"
	# 阴影独立到地面层，不能涂暗从城前经过的单位。
	get_parent().add_child.call_deferred(grounding)
	grounding.position = position
	# 地面、草缘在投影之下，沿用主城脚点，不参与输入、占格或碰撞。
	ground_base = _sprite(GROUND_TEXTURE, grounding)
	ground_base.name = "GroundBase"
	ground_base.position = GROUND_RECT.position
	ground_base.scale = GROUND_RECT.size / GROUND_TEXTURE.get_size()
	ground_base.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var cast := _sprite(CAST_TEXTURE, grounding)
	cast.name = "CastShadow"
	var cast_rect := _shadow_rect(data, false)
	cast.position = cast_rect.position
	cast.scale = cast_rect.size / CAST_TEXTURE.get_size()
	cast.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var contact := _sprite(CONTACT_TEXTURE, grounding)
	contact.name = "ContactShadow"
	var contact_rect := _shadow_rect(data, true)
	contact.position = contact_rect.position
	contact.scale = contact_rect.size / CONTACT_TEXTURE.get_size()
	contact.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_place_grounding.call_deferred()
	body = _sprite(BODY_TEXTURE)
	body.name = "Body"
	body.position = Vector2(-90, -176)
	body.scale = DISPLAY_SIZE / BODY_TEXTURE.get_size()
	window_material = ShaderMaterial.new()
	window_material.shader = WINDOW_SHADER
	body.material = window_material
	for kind in ["flag", "flame", "smoke"]:
		var frames: Array[Texture2D] = []
		for index in range(4):
			frames.append(load(ROOT + "%s/%d.png" % [kind, index]) as Texture2D)
		frame_sets[kind] = frames
	flag = _effect("flag", data.anchors.flag, Vector2(48, 128), 0.235)
	flag.name = "Flag"
	fire_left = _effect("flame", data.anchors.fire_left, Vector2(128, 232), 0.085)
	fire_right = _effect("flame", data.anchors.fire_right, Vector2(128, 232), 0.085)
	smoke = _effect("smoke", data.anchors.smoke, Vector2(128, 232), 0.40)
	smoke_next = _effect("smoke", data.anchors.smoke, Vector2(128, 232), 0.40)
	smoke.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	smoke_next.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	RunState.phase_changed.connect(_on_phase_changed)
	RunState.city_health_changed.connect(_on_health_changed)
	_on_phase_changed(RunState.phase)
	_on_health_changed(RunState.city_health, RunState.city_max_health)
	_apply_animation()


func _shadow_rect(data: Dictionary, contact: bool) -> Rect2:
	# 旧版素材清单没有shadows字段，仍能启动并按旧贴图位置显示。
	if not data.has("shadows"):
		return Rect2(-90, -25, 180, 25) if contact else Rect2(-100, -10, 290, 70)
	var origin: Array = data.shadows.origin
	var size: Array = data.shadows.size
	return Rect2(origin[0], origin[1], size[0], size[1])


func _sprite(image: Texture2D, parent: Node = self) -> Sprite2D:
	var result := Sprite2D.new()
	result.texture = image
	result.centered = false
	parent.add_child(result)
	return result


func _effect(kind: String, normalized: Array, root: Vector2, magnification: float) -> Sprite2D:
	var result := _sprite(frame_sets[kind][0])
	result.scale = Vector2.ONE * magnification
	result.position = Vector2(-90, -176) + Vector2(normalized[0], normalized[1]) * DISPLAY_SIZE - root * magnification
	return result


func _place_grounding() -> void:
	if not is_instance_valid(grounding) or not grounding.is_inside_tree():
		return
	if get_parent().y_sort_enabled:
		# 地基固定在公共排序域底部；主体仍按真实墙脚Y排序。
		var origin := grounding.position
		for child in grounding.get_children():
			if child is Node2D: child.position += origin
		grounding.position = Vector2.ZERO
	var forest := get_parent().get_node_or_null("BorderForest")
	if forest != null:
		get_parent().move_child(grounding, forest.get_index() + 1)


func _process(delta: float) -> void:
	if get_tree().paused or RunState.phase in [RunState.Phase.BOOT, RunState.Phase.RUN_WON, RunState.Phase.RUN_LOST]:
		return
	animation_time += maxf(0.0, delta)
	_apply_animation()


func _apply_animation() -> void:
	animation_frame = int(animation_time / 0.23) % 4
	flag.texture = frame_sets.flag[animation_frame]
	fire_left.texture = frame_sets.flame[int(animation_time / 0.12) % 4]
	fire_right.texture = frame_sets.flame[(int(animation_time / 0.12) + 2) % 4]
	# 两个同根部烟帧交叉淡入，避免稀薄烟雾逐帧跳变。
	var smoke_phase := animation_time / 0.65
	var smoke_index := int(smoke_phase) % 4
	var blend := smoothstep(0.0, 1.0, fmod(smoke_phase, 1.0))
	smoke.texture = frame_sets.smoke[smoke_index]
	smoke_next.texture = frame_sets.smoke[(smoke_index + 1) % 4]
	smoke.modulate.a = 0.32 * (1.0 - blend)
	smoke_next.modulate.a = 0.32 * blend
	window_material.set_shader_parameter("animation_time", animation_time)


func _on_phase_changed(phase: int) -> void:
	if phase in [RunState.Phase.BOOT, RunState.Phase.DAY_SETUP]:
		animation_time = 0.0
		_apply_animation()


func _on_health_changed(current: int, _maximum: int) -> void:
	var alive := current > 0
	for effect in [flag, fire_left, fire_right, smoke, smoke_next]:
		effect.visible = alive


func _exit_tree() -> void:
	if is_instance_valid(grounding):
		grounding.queue_free()
