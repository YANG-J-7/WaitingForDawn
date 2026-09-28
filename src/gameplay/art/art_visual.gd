class_name ArtVisual
extends Sprite2D

# 候选图保留原文件；显示时只裁去透明留白并按地图逻辑尺寸缩放。
const ROOT := "res://assets/art_candidates/night_set_v1/"
static var used_regions: Dictionary = {}

var base_scale: Vector2 = Vector2.ONE
var animation_kind: StringName = &"still"
var elapsed: float = 0.0
var phase_offset: float = 0.0


func configure(asset_name: String, display_size: Vector2, kind: StringName = &"still") -> void:
	configure_path(ROOT + asset_name + ".png", display_size, kind, asset_name)


func configure_path(path: String, display_size: Vector2, kind: StringName = &"still", cache_key: String = "") -> void:
	var loaded: Resource = load(path)
	if not loaded is Texture2D:
		push_warning("美术素材无法加载：%s" % path)
		return
	texture = loaded as Texture2D
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var key := cache_key if not cache_key.is_empty() else path
	if not used_regions.has(key):
		var detected: Rect2i = _visible_region(texture.get_image())
		if detected.size.x <= 0 or detected.size.y <= 0:
			detected = Rect2i(Vector2i.ZERO, Vector2i(texture.get_size()))
		used_regions[key] = detected
	var used: Rect2i = used_regions[key]
	region_enabled = true
	region_rect = Rect2(Vector2(used.position), Vector2(used.size))
	offset = Vector2(0.0, -float(used.size.y) * 0.5)
	base_scale = display_size / Vector2(used.size)
	scale = base_scale
	animation_kind = kind
	phase_offset = float(get_instance_id() % 13) * 0.37
	set_process(kind != &"still")


static func _visible_region(image: Image) -> Rect2i:
	# 排除生成图边缘的低 alpha 光晕，按实际主体计算地图尺寸。
	var left: int = image.get_width()
	var top: int = image.get_height()
	var right: int = -1
	var bottom: int = -1
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			if image.get_pixel(x, y).a < 0.5:
				continue
			left = mini(left, x)
			top = mini(top, y)
			right = maxi(right, x)
			bottom = maxi(bottom, y)
	if right < left or bottom < top:
		return image.get_used_rect()
	return Rect2i(
		Vector2i(maxi(0, left - 4), maxi(0, top - 4)),
		Vector2i(mini(image.get_width(), right + 8) - maxi(0, left - 4), mini(image.get_height(), bottom + 8) - maxi(0, top - 4))
	)


func _process(delta: float) -> void:
	elapsed += delta
	var wave: float = sin(elapsed * 3.0 + phase_offset)
	match animation_kind:
		&"sway":
			rotation = wave * 0.025
		&"walk":
			position.y = sin(elapsed * 10.0 + phase_offset) * 1.5
			rotation = sin(elapsed * 5.0 + phase_offset) * 0.035
		&"wolf":
			position.y = sin(elapsed * 12.0 + phase_offset) * 1.2
			scale = base_scale * Vector2(1.0 + wave * 0.025, 1.0 - wave * 0.025)
		&"fire":
			modulate = Color(1.0, 0.93 + 0.07 * wave, 0.78 + 0.18 * wave, 1.0)
		&"lantern":
			modulate = Color(1.0, 0.97 + 0.03 * wave, 0.92 + 0.05 * wave, 1.0)
