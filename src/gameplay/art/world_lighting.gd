class_name WorldLighting
extends Node2D
## 每个世界画布一个控制器；置于所有地面贴花之后、单位/建筑主体之前。
const Profile = preload("res://src/gameplay/art/world_lighting_profile.gd")
const SHADOW_SHADER = preload("res://src/gameplay/art/world_shadow.gdshader")
var profile: Resource = Profile.new()
var scope: Node
var ambient: CanvasModulate
var lighting_enabled := true
var dawn_blend: float = 0.0
var preview_dawn: float = -1.0
var casters: Array[WeakRef] = []
var emitters: Array[WeakRef] = []
var drawn_shadow_count := 0
var legacy_shadows: Array[WeakRef] = []
var _draw_colors := PackedColorArray([Color.WHITE])
var ground_layers: Array[WeakRef] = []
var contact_texture: GradientTexture2D
var contact_layer: GroundShadowLayer

# 接触纹理已有羽化，单独绘制，避免再次经过轮廓影的八纹素模糊。
class GroundShadowLayer extends Node2D:
	var lighting: Node2D
	func _draw() -> void:
		lighting._draw_ground_shadows(self)

func _make_contact_texture() -> void:
	contact_texture = GradientTexture2D.new()
	contact_texture.width = 96
	contact_texture.height = 96
	contact_texture.fill = GradientTexture2D.FILL_RADIAL
	contact_texture.fill_from = Vector2(0.5,0.5)
	contact_texture.fill_to = Vector2(1.0,0.5)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.48,0.78,1.0])
	gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0.92),Color(1,1,1,0.38),Color(1,1,1,0)])
	contact_texture.gradient = gradient

func register_ground_layer(ground: Node2D) -> void:
	# 地面层由组件声明，不依赖主城名称或地图固定坐标。
	for ref in ground_layers:
		if ref.get_ref() == ground: return
	ground_layers.append(weakref(ground))
	_sort_after_ground.call_deferred()

func _sort_after_ground() -> void:
	if not is_inside_tree() or not is_instance_valid(scope): return
	if get_parent() != scope: reparent(scope,true)
	var last_ground := -1
	for ref in ground_layers:
		var ground = ref.get_ref()
		if ground != null and ground.get_parent() == scope:
			last_ground = maxi(last_ground,ground.get_index())
	if last_ground >= 0:
		# 已在最晚地面之后时不重复移动，防止同级索引收缩产生反向越位。
		if get_index() <= last_ground: scope.move_child(self,last_ground)

func register_legacy_shadow(shadow: CanvasItem) -> void:
	for index in range(legacy_shadows.size()-1,-1,-1):
		if legacy_shadows[index].get_ref() == shadow: return
		if legacy_shadows[index].get_ref() == null: legacy_shadows.remove_at(index)
	legacy_shadows.append(weakref(shadow))
	shadow.visible = not lighting_enabled
	if shadow.get_parent() is Node2D: register_ground_layer(shadow.get_parent())

func _ready() -> void:
	add_to_group(&"world_lighting_systems")
	_make_contact_texture()
	ambient = CanvasModulate.new()
	ambient.name = "Ambient"
	add_child(ambient)
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = SHADOW_SHADER
	material = shadow_material
	contact_layer = GroundShadowLayer.new()
	contact_layer.name = "GroundShadows"
	contact_layer.lighting = self
	var contact_material := CanvasItemMaterial.new()
	contact_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	contact_layer.material = contact_material
	add_child(contact_layer)
	RunState.campaign_time_changed.connect(_on_campaign_time_changed)
	_on_campaign_time_changed(RunState.campaign_remaining_seconds())

func register_caster(caster: Node) -> void:
	for ref in casters:
		if ref.get_ref() == caster: return
	casters.append(weakref(caster))
	queue_redraw()
	if is_instance_valid(contact_layer): contact_layer.queue_redraw()

func unregister_caster(caster: Node) -> void:
	for index in range(casters.size()-1,-1,-1):
		if casters[index].get_ref() == caster or casters[index].get_ref() == null: casters.remove_at(index)
	queue_redraw()
	if is_instance_valid(contact_layer): contact_layer.queue_redraw()

func register_emitter(emitter: Node) -> void:
	for ref in emitters:
		if ref.get_ref() == emitter: return
	emitters.append(weakref(emitter))

func unregister_emitter(emitter: Node) -> void:
	for index in range(emitters.size()-1,-1,-1):
		if emitters[index].get_ref() == emitter or emitters[index].get_ref() == null: emitters.remove_at(index)

func set_lighting_enabled(value: bool) -> void:
	lighting_enabled = value
	_apply_ambient()
	for ref in legacy_shadows:
		var shadow = ref.get_ref()
		if shadow != null: shadow.visible = not value
	for ref in emitters:
		var emitter = ref.get_ref()
		if emitter != null: emitter._process(0.0)
	queue_redraw()
	if is_instance_valid(contact_layer): contact_layer.queue_redraw()

func _on_campaign_time_changed(remaining: float) -> void:
	dawn_blend = smoothstep(0.0,1.0,clampf(1.0-remaining/maxf(1.0,profile.dawn_duration),0.0,1.0)) if preview_dawn < 0.0 else preview_dawn
	_apply_ambient()
	queue_redraw()
	if is_instance_valid(contact_layer): contact_layer.queue_redraw()

func _apply_ambient() -> void:
	if is_instance_valid(ambient): ambient.color = profile.night_ambient.lerp(profile.dawn_ambient,dawn_blend) if lighting_enabled else Color.WHITE

func _process(_delta: float) -> void:
	# 只遍历已注册组件；不扫描整棵树、不创建纹理或每帧创建影子节点。
	var active := 0
	for ref in emitters:
		var emitter = ref.get_ref()
		if emitter == null: continue
		emitter.budget_allowed = emitter.is_visible_in_tree() and active < profile.max_local_lights
		if emitter.budget_allowed: active += 1
	queue_redraw()
	contact_layer.queue_redraw()

func _draw() -> void:
	drawn_shadow_count = 0
	if not lighting_enabled or scope == null: return
	var view := get_canvas_transform().affine_inverse()*get_viewport_rect()
	var direction: Vector2 = profile.shadow_direction.normalized()
	var tint: Color = profile.shadow_color
	tint.a = profile.shadow_opacity * lerpf(1.0,0.65,dawn_blend)
	# 直接提交世界坐标；避免为每个可见物体逐帧建立一份局部点数组。
	draw_set_transform_matrix(global_transform.affine_inverse())
	for ref in casters:
		var caster = ref.get_ref()
		if caster == null or not is_instance_valid(caster.source) or not is_instance_valid(caster.anchor): continue
		var source: Sprite2D = caster.source
		if source.texture == null or not source.is_visible_in_tree(): continue
		if caster.is_grounded_actor():
			var contacts: Array[Rect2] = caster.ground_contacts()
			if contacts.is_empty() or not _actor_shadow_rect(caster,contacts,direction).intersects(view): continue
			drawn_shadow_count += 1
			continue
		var world_points: PackedVector2Array = caster.projected_points(direction,profile.shadow_length*caster.length_scale)
		var bounds := Rect2(world_points[0],Vector2.ZERO)
		for point in world_points: bounds = bounds.expand(point)
		if not bounds.intersects(view): continue
		var color_with_alpha := tint
		color_with_alpha.a *= caster.strength * source.modulate.a
		var far_color := color_with_alpha
		far_color.a *= 0.65
		_draw_colors = PackedColorArray([far_color,far_color,color_with_alpha,color_with_alpha])
		draw_polygon(world_points,_draw_colors,caster.texture_uvs(),source.texture)
		drawn_shadow_count += 1

func _actor_shadow_rect(caster: Node,contacts: Array[Rect2],direction: Vector2) -> Rect2:
	var bounds := contacts[0]
	for contact in contacts: bounds = bounds.merge(contact)
	var source: Sprite2D = caster.source
	var body_size := source.get_rect().size*Vector2(source.global_transform.x.length(),source.global_transform.y.length())
	var reach: float = body_size.y*0.30*caster.length_scale
	var center := bounds.get_center()+direction*reach*0.7
	var size := Vector2(maxf(body_size.x*1.05,bounds.size.x+reach),maxf(body_size.y*0.38,bounds.size.y+reach*0.65))
	return Rect2(center-size*0.5,size)

func _draw_ground_shadows(layer: Node2D) -> void:
	if not lighting_enabled or scope == null: return
	var view := get_canvas_transform().affine_inverse()*get_viewport_rect()
	var direction: Vector2 = profile.shadow_direction.normalized()
	layer.draw_set_transform_matrix(layer.global_transform.affine_inverse())
	for ref in casters:
		var caster = ref.get_ref()
		if caster == null or not is_instance_valid(caster.source): continue
		var source: Sprite2D = caster.source
		if source.texture == null or not source.is_visible_in_tree(): continue
		var contacts: Array[Rect2] = caster.ground_contacts()
		if contacts.is_empty(): continue
		var tint: Color = profile.shadow_color
		if caster.is_grounded_actor():
			# 合并足迹形成可辨识的短投影，各脚仍有独立接触核心，保留前后脚透视。
			var footprint := _actor_shadow_rect(caster,contacts,direction)
			if not footprint.intersects(view): continue
			tint.a = profile.actor_shadow_opacity*caster.strength*source.modulate.a*lerpf(1.0,0.8,dawn_blend)
			layer.draw_texture_rect(contact_texture,footprint,false,tint)
		if caster.contact_strength <= 0.0: continue
		tint.a = profile.contact_opacity*caster.strength*caster.contact_strength*source.modulate.a
		for contact in contacts:
			if contact.intersects(view): layer.draw_texture_rect(contact_texture,contact,false,tint)
