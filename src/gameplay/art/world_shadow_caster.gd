class_name WorldShadowCaster
extends Node
## 挂在任意世界Sprite2D下；不读取怪种、建筑类型或地图固定位置。
var source: Sprite2D
var anchor: Node2D
var strength: float = 1.0
var length_scale: float = 1.0
var contact_strength: float = 1.0
## 非零时在光线的横向轴上调整轮廓宽度，投影以地面锚点为原点。
var directional_projection_width: float = 0.0
static var contact_profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/data/ground_contacts.json"))
var _contact_cache: Array[Rect2] = []
var _contact_transform := Transform2D()
var _contact_rect := Rect2()
var _contact_flip := Vector2i(-1,-1)
var _contact_texture: Texture2D
var _contact_region := Rect2()

func is_grounded_actor() -> bool:
	return source.get("animation_kind") in [&"walk", &"wolf"]

func ground_contacts() -> Array[Rect2]:
	if source.texture == null: return []
	var flip := Vector2i(int(source.flip_h),int(source.flip_v))
	var region := source.region_rect if source.region_enabled else Rect2(Vector2.ZERO,source.texture.get_size())
	var frame_size := region.size/Vector2(source.hframes,source.vframes)
	region = Rect2(region.position+Vector2(source.frame_coords)*frame_size,frame_size)
	if not _contact_cache.is_empty() and _contact_transform == source.global_transform and _contact_rect == source.get_rect() and _contact_flip == flip and _contact_texture == source.texture and _contact_region == region:
		return _contact_cache
	_contact_transform = source.global_transform
	_contact_rect = source.get_rect()
	_contact_flip = flip
	_contact_texture = source.texture
	_contact_region = region
	var result: Array[Rect2] = []
	_contact_cache = result
	var rect := source.get_rect()
	var hints: Array = contact_profiles.get(source.texture.resource_path.get_file().get_basename(),[])
	var scale_x := source.global_transform.x.length()
	var scale_y := source.global_transform.y.length()
	if hints.is_empty():
		var center := source.to_global(Vector2(rect.get_center().x,rect.end.y-1.0))
		var size := Vector2(maxf(8.0,rect.size.x*scale_x*0.42),maxf(3.0,rect.size.y*scale_y*0.025))
		result.append(Rect2(center-size*0.5,size))
		return result
	for hint in hints:
		# 绑点是素材内的鞋底/爪底，不是地图坐标；按当前区域、镜像和变换换算。
		var uv := (Vector2(hint[0],hint[1])-region.position)/region.size
		if source.flip_h: uv.x = 1.0-uv.x
		if source.flip_v: uv.y = 1.0-uv.y
		var center := source.to_global(rect.position+uv*rect.size)
		var size := Vector2(maxf(8.0,float(hint[2])*scale_x*1.15),maxf(6.0,float(hint[3])*scale_y*2.0))
		# 核心与鞋底重叠，羽化部分向地面露出，避免整个暗部藏在鞋内。
		center.y += size.y*0.22
		result.append(Rect2(center-size*0.5,size))
	return result
var system: Node2D
var legacy_shadows: Array[CanvasItem] = []
var _cached_points := PackedVector2Array()
var _last_transform := Transform2D()
var _last_foot := Vector2(INF,INF)
var _last_direction := Vector2(INF,INF)
var _last_length: float = -1.0
var _last_projection_width: float = -1.0
var _last_rect := Rect2()
var _cached_uvs := PackedVector2Array()
var _last_region := Rect2()
var _last_flip := Vector2i(-1,-1)
var _last_texture_size := Vector2.ZERO

static func attach(sprite: Sprite2D, ground_anchor: Node2D = null) -> Node:
	if sprite.has_node("WorldShadowCaster"):
		return sprite.get_node("WorldShadowCaster")
	var caster := WorldShadowCaster.new()
	caster.name = "WorldShadowCaster"
	caster.source = sprite
	caster.anchor = ground_anchor if ground_anchor != null else sprite
	sprite.add_child(caster)
	return caster

func _ready() -> void:
	# 延后到整棵场景树就绪，兼容先创建物体、后创建控制器的装配顺序。
	_register.call_deferred()

func _register() -> void:
	if not is_inside_tree(): return
	for candidate in get_tree().get_nodes_in_group(&"world_lighting_systems"):
		if candidate.scope != null and candidate.scope.is_ancestor_of(self) and source.get_canvas() == candidate.get_canvas() and source.get_viewport() == candidate.get_viewport():
			system = candidate
			system.register_caster(self)
			for shadow in legacy_shadows:
				if is_instance_valid(shadow): system.register_legacy_shadow(shadow)
			return

func _exit_tree() -> void:
	if is_instance_valid(system): system.unregister_caster(self)

func projected_points(direction: Vector2, length_ratio: float) -> PackedVector2Array:
	var rect := source.get_rect()
	var foot := anchor.global_position
	var transform := source.global_transform
	if _cached_points.size() == 4 and transform == _last_transform and foot == _last_foot and direction == _last_direction and length_ratio == _last_length and rect == _last_rect and directional_projection_width == _last_projection_width:
		return _cached_points
	_last_transform = transform
	_last_foot = foot
	_last_direction = direction
	_last_length = length_ratio
	_last_projection_width = directional_projection_width
	_last_rect = rect
	_cached_points = PackedVector2Array()
	var across := Vector2(direction.y,-direction.x).normalized()*directional_projection_width
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var world: Vector2 = source.to_global(corner)
		var height := maxf(0.0, foot.y - world.y)
		if not across.is_zero_approx():
			# 轮廓在地面上沿主光方向展开，根部保持在锚点。
			_cached_points.append(foot + across*(world.x-foot.x) + direction*height*length_ratio)
			continue
		# 脚点不漂移；保留少量纵深，防止宽矮物件的影子退化成一条线。
		_cached_points.append(Vector2(world.x, foot.y + (world.y-foot.y)*0.12) + direction*height*length_ratio)
	return _cached_points

func texture_uvs() -> PackedVector2Array:
	var region := source.region_rect if source.region_enabled else Rect2(Vector2.ZERO, source.texture.get_size())
	var frame_size := region.size / Vector2(source.hframes,source.vframes)
	region = Rect2(region.position + Vector2(source.frame_coords)*frame_size,frame_size)
	var flip := Vector2i(int(source.flip_h),int(source.flip_v))
	if _cached_uvs.size() == 4 and region == _last_region and flip == _last_flip and source.texture.get_size() == _last_texture_size: return _cached_uvs
	_last_region = region
	_last_flip = flip
	_last_texture_size = source.texture.get_size()
	var low := region.position / source.texture.get_size()
	var high := region.end / source.texture.get_size()
	if source.flip_h:
		var old := low.x
		low.x = high.x
		high.x = old
	if source.flip_v:
		var old := low.y
		low.y = high.y
		high.y = old
	_cached_uvs = PackedVector2Array([low, Vector2(high.x,low.y), high, Vector2(low.x,high.y)])
	return _cached_uvs
