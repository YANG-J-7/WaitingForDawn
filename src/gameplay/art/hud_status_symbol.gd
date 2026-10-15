extends Control
## 顶栏简洁图形符号，使用固定坐标绘制，避免系统字体的彩色齿轮差异。
const LIGHT := Color("eeeae0")
const DARK := Color("0b1724")
const RED := Color("e53b47")
var kind: String = "settings"
var paused: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	resized.connect(queue_redraw)
	set_process(kind == "pause")
	_update_pause()

func _process(_delta: float) -> void:
	_update_pause()

func _update_pause() -> void:
	if kind != "pause":
		return
	var current: bool = get_tree().paused
	if current != paused:
		paused = current
		queue_redraw()
	get_parent().tooltip_text = "继续对局" if paused else "暂停对局"

func _draw() -> void:
	var extent: float = minf(size.x, size.y)
	draw_set_transform((size - Vector2.ONE * extent) / 2.0, 0.0, Vector2.ONE * extent / 32.0)
	match kind:
		"settings":
			_draw_gear()
		"pause":
			if paused:
				draw_colored_polygon(PackedVector2Array([Vector2(8, 4), Vector2(28, 16), Vector2(8, 28)]), LIGHT)
			else:
				for x in [6.0, 20.0]:
					var bar := StyleBoxFlat.new()
					bar.bg_color = LIGHT
					bar.set_corner_radius_all(2)
					draw_style_box(bar, Rect2(x, 3, 6, 26))
		"city":
			_draw_city()
		"threat":
			_draw_threat()

func _draw_gear() -> void:
	var outline := PackedVector2Array()
	for index in range(40):
		var angle: float = TAU * float(index) / 40.0 - PI / 2.0
		var radius: float = 15.0 if index % 5 in [1, 2, 3] else 11.0
		outline.append(Vector2(16, 16) + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(outline, LIGHT)
	draw_circle(Vector2(16, 16), 6.0, DARK, true, -1.0, true)

func _draw_city() -> void:
	var outline := PackedVector2Array([
		Vector2(4, 1), Vector2(9, 1), Vector2(9, 5), Vector2(13, 5), Vector2(13, 1),
		Vector2(19, 1), Vector2(19, 5), Vector2(23, 5), Vector2(23, 1), Vector2(28, 1),
		Vector2(28, 10), Vector2(23, 10), Vector2(26, 28), Vector2(29, 28), Vector2(29, 31),
		Vector2(3, 31), Vector2(3, 28), Vector2(6, 28), Vector2(9, 10), Vector2(4, 10)
	])
	draw_colored_polygon(outline, LIGHT)
	draw_rect(Rect2(4, 8, 24, 2), Color("b4b5b2"))
	draw_rect(Rect2(12, 13, 8, 6), DARK)
	draw_colored_polygon(PackedVector2Array([Vector2(12, 28), Vector2(12, 23), Vector2(16, 21), Vector2(20, 23), Vector2(20, 28)]), DARK)

func _draw_threat() -> void:
	# 扁平红色角骷髅，与设计图的小尺寸轮廓一致。
	for points in [
		PackedVector2Array([Vector2(9, 11), Vector2(3, 9), Vector2(0, 5), Vector2(1, 0), Vector2(5, 1), Vector2(3, 4), Vector2(5, 7), Vector2(11, 8)]),
		PackedVector2Array([Vector2(23, 11), Vector2(29, 9), Vector2(32, 5), Vector2(31, 0), Vector2(27, 1), Vector2(29, 4), Vector2(27, 7), Vector2(21, 8)])
	]:
		draw_colored_polygon(points, RED)
	draw_colored_polygon(PackedVector2Array([
		Vector2(11, 7), Vector2(21, 7), Vector2(26, 12), Vector2(25, 20), Vector2(22, 23),
		Vector2(21, 29), Vector2(18, 29), Vector2(18, 25), Vector2(14, 25), Vector2(14, 29),
		Vector2(11, 29), Vector2(10, 23), Vector2(7, 20), Vector2(6, 12)
	]), RED)
	draw_circle(Vector2(11, 16), 3.0, DARK)
	draw_circle(Vector2(21, 16), 3.0, DARK)
	draw_colored_polygon(PackedVector2Array([Vector2(16, 18), Vector2(13, 22), Vector2(19, 22)]), DARK)
	for x in [6.0, 12.0, 20.0, 26.0]:
		draw_circle(Vector2(x, 30), 1.5, RED)
