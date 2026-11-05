extends Node2D
## 原图林缘编排的独立冷蓝针叶树；不再使用旧树林素材或规则行列。
const ROOT := "res://assets/map_kits/reference_hd_20261102/"
var tree_count := 0
func configure(_runtime: RefCounted) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"forest.json"))
	var textures: Array[Texture2D] = []
	for path in data.sprites: textures.append(load(ROOT+path))
	y_sort_enabled = true
	for entry in data.trees:
		var tree := Sprite2D.new()
		tree.name = entry.id
		tree.texture = textures[int(entry.variant)]
		tree.position = Vector2(entry.position[0],entry.position[1])
		var size := Vector2(entry.size[0],entry.size[1])
		tree.scale = size/tree.texture.get_size()
		# 脚点为排序原点，树冠向上伸展。
		tree.offset = Vector2(0,-tree.texture.get_height()*.5)
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(tree)
		var caster := WorldShadowCaster.attach(tree) as WorldShadowCaster
		# 树根由同一道轮廓影接住，移除按宽树冠尺寸生成的横向接触影。
		caster.contact_strength = 0.0
		caster.directional_projection_width = 0.50
		caster.strength = 1.20
		tree_count += 1
