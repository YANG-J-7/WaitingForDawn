extends Node

var failures: int = 0
var playfield: SubViewport
var main: Node


func _ready() -> void:
	playfield = SubViewport.new()
	playfield.size = Vector2i(1024, 768)
	playfield.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(playfield)
	main = preload("res://src/main/main.tscn").instantiate()
	playfield.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_viewport_layout(Vector2(1024, 768), "非16:9")

	main.start_button.pressed.emit()
	for index in [0, 1, 3, 4]:
		main.card_buttons[index].pressed.emit()
	main.ready_button.pressed.emit()
	await get_tree().process_frame
	main._on_battle_shop_button_pressed()
	await get_tree().process_frame
	_check_shop_layout(Vector2(1024, 768), "非16:9")

	playfield.size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_viewport_layout(Vector2(1280, 720), "1280×720")
	_check_shop_layout(Vector2(1280, 720), "1280×720")

	main.queue_free()
	get_tree().quit(failures)


func _check_viewport_layout(viewport_size: Vector2, label: String) -> void:
	var top_rect: Rect2 = main.top_bar.get_global_rect()
	var hand_rect: Rect2 = main.hand_bar.get_global_rect()
	check(is_equal_approx(top_rect.size.x, viewport_size.x), "%s顶栏铺满视口宽度" % label)
	check(is_equal_approx(hand_rect.size.x, viewport_size.x), "%s手牌栏铺满视口宽度" % label)
	check(is_equal_approx(hand_rect.end.y, viewport_size.y), "%s手牌栏贴合视口底部" % label)


func _check_shop_layout(viewport_size: Vector2, label: String) -> void:
	var shop_rect: Rect2 = main.day_setup_panel.get_global_rect()
	var hand_rect: Rect2 = main.hand_bar.get_global_rect()
	check(main.card_grid.columns == 2, "%s商店保持2×3六格布局" % label)
	check(shop_rect.end.x <= viewport_size.x, "%s商店不越过视口右边缘" % label)
	check(shop_rect.end.y <= hand_rect.position.y, "%s商店不覆盖底部手牌" % label)
	check(shop_rect.size.x >= 340.0 and shop_rect.size.x <= 420.0, "%s商店宽度保持可读范围" % label)


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
