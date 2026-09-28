extends Node

const ArtVisualScript = preload("res://src/gameplay/art/art_visual.gd")
const ASSETS := [
	"terrain_grass", "terrain_road", "pine_tree", "boulder", "torch", "bridge",
	"town_hall", "lumberyard", "farm", "arrow_tower", "palisade_wall", "quarry",
	"house", "barracks", "windmill", "mine_entrance", "villager", "guard", "wolf",
]

var failures: int = 0


func _ready() -> void:
	for asset_name in ASSETS:
		var art := ArtVisualScript.new() as ArtVisual
		add_child(art)
		art.configure(asset_name, Vector2(32, 32))
		check(art.texture != null and art.region_rect.size.x > 0.0, "%s 可加载并有有效主体" % asset_name)
		art.queue_free()
	var walker := ArtVisualScript.new() as ArtVisual
	add_child(walker)
	walker.configure("villager", Vector2(12, 18), &"walk")
	walker._process(0.2)
	check(absf(walker.position.y) > 0.01, "村民步行动画改变位置")
	var torch := ArtVisualScript.new() as ArtVisual
	add_child(torch)
	torch.configure("torch", Vector2(9, 22), &"fire")
	torch._process(0.2)
	check(torch.modulate != Color.WHITE, "火把动画改变亮度")
	check(walker.base_scale.x > 0.0 and walker.base_scale.y > 0.0, "缩放依据主体区域")
	if failures > 0:
		push_error("美术素材测试失败：%d" % failures)
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		print("FAIL: " + message)
