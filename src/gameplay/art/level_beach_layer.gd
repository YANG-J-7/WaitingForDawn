extends Node2D
## 全岸复用已生成沙/泡沫，时间由父湖层统一管理。
var layout: Dictionary = {}
var materials: Array[ShaderMaterial] = []
var overview_only := false
var impacts: Array[Sprite2D] = []

func bind_rocks(material: ShaderMaterial) -> void:
	material.set_shader_parameter("rock_clip_enabled", true)
	material.set_shader_parameter("rock_texture", preload("res://assets/levels/level_001/mountain/mountain.png"))
	material.set_shader_parameter("rock_rect", Vector4(3528,-108,3548,1774))

func configure(path: String, overview: bool) -> void:
	overview_only = overview
	layout = JSON.parse_string(FileAccess.get_file_as_string(path))
	for patch: Dictionary in layout.patches:
		var rect := Rect2(float(patch.rect[0]), float(patch.rect[1]), float(patch.rect[2]), float(patch.rect[3]))
		var surface := Polygon2D.new()
		surface.name = patch.id
		surface.polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		var material := ShaderMaterial.new()
		material.shader = preload("res://src/gameplay/art/map_beach.gdshader")
		bind_rocks(material)
		material.set_shader_parameter("coast_field", load(patch.field))
		material.set_shader_parameter("field_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
		material.set_shader_parameter("coast_length", float(patch.length))
		material.set_shader_parameter("end_fade", float(patch.end_fade))
		material.set_shader_parameter("width_scale", float(patch.width_scale))
		material.set_shader_parameter("mountain_sand_extension", float(layout.get("mountain_sand_extension", 0.0)))
		material.set_shader_parameter("world_size", Vector2(float(layout.world_size[0]), float(layout.world_size[1])))
		material.set_shader_parameter("sand_texture", preload("res://assets/map/beach_v1/sand.png"))
		material.set_shader_parameter("foam_texture", preload("res://assets/map/beach_v1/foam.png"))
		material.set_shader_parameter("grass_contact", preload("res://assets/map/beach_v1/grass-contact.png"))
		material.set_shader_parameter("grass_detail", preload("res://assets/map/grass_variants_v1/grass.png"))
		material.set_shader_parameter("animated", not overview)
		surface.material = material
		materials.append(material)
		add_child(surface)
	if not overview:
		build_impacts()
	apply_time(0.0)

func build_impacts() -> void:
	if not layout.get("reverse_waves_enabled", false):
		return
	var sites: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/fx/reverse_wave_v1/contact-sites.json"))
	for site: Dictionary in sites.sites:
		var effect := Sprite2D.new()
		effect.name = site.id
		effect.texture = preload("res://assets/fx/reverse_wave_v1/sheet-transparent.png")
		var dimensions := Vector2(site.size[0],site.size[1])
		var anchor := Vector2(site.anchor[0],site.anchor[1])
		effect.rotation = deg_to_rad(float(site.angle))
		effect.scale = dimensions / effect.texture.get_size()
		# 原画接触点锁在原格(.26,.70)，旋转与缩放都围绕该固定世界落点。
		effect.position = anchor + ((Vector2(.5,.5)-Vector2(.26,.70))*dimensions).rotated(effect.rotation)
		effect.set_meta("contact_anchor",anchor)
		effect.set_meta("site_index",int(site.source_image))
		effect.z_index = 1
		var fx := ShaderMaterial.new()
		fx.shader = preload("res://src/gameplay/art/shore_splash.gdshader")
		fx.set_shader_parameter("splash_texture", effect.texture)
		fx.set_shader_parameter("atlas_grid", Vector2(4,2))
		fx.set_shader_parameter("frame_count", 8.0)
		fx.set_shader_parameter("water_floor", -1000.0)
		fx.set_shader_parameter("cycle", 4.0)
		fx.set_shader_parameter("active_duration", 3.2)
		fx.set_shader_parameter("phase_offset", float(site.phase))
		fx.set_shader_parameter("intensity", .8)
		bind_rocks(fx)
		effect.material = fx
		add_child(effect)
		impacts.append(effect)

func apply_time(seconds: float) -> void:
	for material in materials:
		material.set_shader_parameter("elapsed", 0.0 if overview_only else seconds)
	for effect: Sprite2D in impacts:
		effect.material.set_shader_parameter("elapsed", seconds)
