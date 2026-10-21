extends Node2D
## 岩缘独立遮挡；接近遮挡的单位使岩缘淡化，保证头身可读。
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
var main: Node2D
var pieces: Array[Dictionary] = []
var elapsed := 0.0

func configure(owner_main: Node2D) -> void:
	main = owner_main
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for entry in Definition.visual_data().get("occluders", []):
		var box: Array = entry.sourceRect
		var origin := Definition.source_to_world(Vector2(box[0],box[1]))
		var end := Definition.source_to_world(Vector2(box[2],box[3]))
		pieces.append({"texture":load("res://"+entry.path),"rect":Rect2(origin,end-origin),"alpha":1.0})

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.1: return
	elapsed = 0.0
	var actors: Array = []
	actors.append_array(main.farmer_manager.active_farmers())
	actors.append_array(main.wave_controller.enemies)
	for piece in pieces:
		piece.alpha = 1.0
		for actor in actors:
			if is_instance_valid(actor) and piece.rect.grow(32).has_point(actor.global_position):
				piece.alpha = 0.28
				break
	queue_redraw()

func _draw() -> void:
	if main == null or main.map_camera == null: return
	var visible: Rect2 = main.map_camera.visible_world_rect()
	for piece in pieces:
		# 高Z岩缘不会继承同Z底图的父级裁剪，按实际可玩视口裁切采样区。
		var clipped: Rect2 = piece.rect.intersection(visible)
		if not clipped.has_area(): continue
		var source := Rect2((clipped.position-piece.rect.position)/piece.rect.size*piece.texture.get_size(),clipped.size/piece.rect.size*piece.texture.get_size())
		draw_texture_rect_region(piece.texture,clipped,source,Color(1,1,1,piece.alpha))
