extends Node2D

const ArtVisualScript = preload("res://src/gameplay/art/art_visual.gd")

const ITEMS := [
	["terrain_grass", "草地", &"still"],
	["terrain_road", "道路", &"still"],
	["pine_tree", "针叶树", &"sway"],
	["boulder", "岩石", &"still"],
	["torch", "火把", &"fire"],
	["bridge", "木桥", &"still"],
	["town_hall", "主城", &"lantern"],
	["lumberyard", "伐木场", &"lantern"],
	["farm", "农场", &"lantern"],
	["arrow_tower", "箭塔", &"lantern"],
	["palisade_wall", "木城墙", &"still"],
	["quarry", "采石场", &"lantern"],
	["house", "民屋", &"lantern"],
	["barracks", "兵营", &"lantern"],
	["windmill", "风车", &"sway"],
	["mine_entrance", "矿洞", &"lantern"],
	["villager", "村民", &"walk"],
	["guard", "守卫", &"walk"],
	["wolf", "野狼", &"wolf"],
]


func _ready() -> void:
	for index in range(ITEMS.size()):
		var item: Array = ITEMS[index]
		var column: int = index % 7
		var row: int = floori(float(index) / 7.0)
		var center := Vector2(72 + column * 136, 137 + row * 132)
		var art := ArtVisualScript.new() as ArtVisual
		art.position = center
		art.configure(str(item[0]), Vector2(72, 77), item[2])
		add_child(art)
		var label := Label.new()
		label.text = str(item[1])
		label.position = center + Vector2(-59, 5)
		label.size = Vector2(118, 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color("101827"))
	for row in range(3):
		for column in range(7):
			draw_rect(Rect2(5 + column * 136, 18 + row * 132, 132, 126), Color("203242"))
