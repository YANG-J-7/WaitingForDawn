extends Node2D
## 已确认山体作为地表层绘制；主图与小地图共用组件位置及统一尺度。
var layouts: Array[Dictionary] = []
var dawn_materials: Array[ShaderMaterial] = []

func configure(context: RefCounted, overview_only: bool = false) -> void:
	for component: Dictionary in context.modules:
		if component.role != "mountain": continue
		var path: String = component.payload.get("visual_layout", "")
		if path.is_empty(): continue
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		layouts.append(layout)
		var sprite := Sprite2D.new()
		sprite.name = component.instance_id
		sprite.texture = load(layout.texture)
		sprite.centered = false
		sprite.position = component.origin + Vector2(layout.origin[0], layout.origin[1])
		sprite.scale = Vector2.ONE * float(layout.scale)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var mask_path: String = layout.get("dawn_arrival_mask", "")
		if not overview_only and not mask_path.is_empty():
			var dawn_material := ShaderMaterial.new()
			dawn_material.shader = preload("res://src/gameplay/art/mountain_dawn.gdshader")
			dawn_material.set_shader_parameter("arrival_mask", load(mask_path))
			sprite.material = dawn_material
			dawn_materials.append(dawn_material)
		add_child(sprite)

func set_dawn_progress(progress: float) -> void:
	for dawn_material in dawn_materials:
		dawn_material.set_shader_parameter("dawn_progress", progress)
