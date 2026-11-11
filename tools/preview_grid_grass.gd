extends Control
## 独立草地样区；只读取候选素材，不启动战斗、不修改正式地图。
const Grid = preload("res://src/gameplay/grid/grid_map_model.gd")
const DATA_PATH := "res://design/levels/grid-grass-preview/map.json"
const DETAIL: Texture2D = preload("res://assets/map/grass_reference_v3/grass.png")
const IDLE_HINT := "   32×20格 · 每格36　|　静态草地贴图 · 滚轮缩放 · 中键拖动"
var data: Dictionary
var grid: RefCounted
var ground: Node2D
var overlay: Node2D
var view: SubViewport
var surface: SubViewportContainer
var status: Label
var zoom_label: Label
var grid_button: CheckButton
var footprint_picker: OptionButton
var center := Vector2.ZERO
var zoom_factor := 1.0
var show_grid := true
var footprint := Vector2i(2, 2)
var hover_cell := Vector2i(-1, -1)
var dragging := false

class GrassLayer extends Node2D:
	var owner_preview: Control
	func _draw() -> void:
		var bounds: Vector2 = Vector2(owner_preview.grid.grid_size) * owner_preview.grid.CELL_SIZE
		draw_rect(Rect2(Vector2.ZERO, bounds), Color.WHITE)

class GridOverlay extends Node2D:
	var owner_preview: Control
	func _draw() -> void:
		var p := owner_preview
		var bounds: Vector2 = Vector2(p.grid.grid_size) * p.grid.CELL_SIZE
		var cell_size: float = p.grid.CELL_SIZE
		var line_width: float = 1.0 / p.zoom_factor
		if p.show_grid:
			for x in range(p.grid.grid_size.x + 1):
				var color := Color(0.60, 0.77, 0.76, 0.25 if x % 4 == 0 else 0.10)
				draw_line(Vector2(x * cell_size, 0), Vector2(x * cell_size, bounds.y), color, line_width)
			for y in range(p.grid.grid_size.y + 1):
				var color := Color(0.60, 0.77, 0.76, 0.25 if y % 4 == 0 else 0.10)
				draw_line(Vector2(0, y * cell_size), Vector2(bounds.x, y * cell_size), color, line_width)
		draw_rect(Rect2(Vector2.ZERO, bounds), Color(0.43, 0.64, 0.67), false, line_width * 2.0)
		if not p.grid.is_inside(p.hover_cell):
			return
		var valid: bool = p.footprint_fits(p.hover_cell)
		var color := Color("e6b75d") if valid else Color("d9545a")
		var rect := Rect2(Vector2(p.hover_cell) * cell_size, Vector2(p.footprint) * cell_size)
		draw_rect(rect, Color(color, 0.12))
		draw_rect(rect, color, false, line_width * 2.0)
		if not valid:
			draw_line(rect.position, rect.end, color, line_width * 2.0)
			draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), color, line_width * 2.0)

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	grid = Grid.new(Vector2i(int(data.columns), int(data.rows)))
	center = Vector2(grid.grid_size) * grid.CELL_SIZE * 0.5
	_build_ui()
	ground = GrassLayer.new()
	ground.owner_preview = self
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var ground_material := ShaderMaterial.new()
	ground_material.shader = preload("res://tools/grid_grass_ground.gdshader")
	ground_material.set_shader_parameter("grass_texture", DETAIL)
	ground.material = ground_material
	view.add_child(ground)
	overlay = GridOverlay.new()
	overlay.owner_preview = self
	view.add_child(overlay)
	surface.resized.connect(_update_camera)
	_update_camera()
	reset_camera.call_deferred()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0b1724")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var title := Label.new()
	title.text = "   草地地图 · 网格样区"
	title.add_theme_font_size_override("font_size", 24)
	title.custom_minimum_size.y = 48
	column.add_child(title)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 18)
	column.add_child(toolbar)
	var margin := Control.new()
	margin.custom_minimum_size.x = 10
	toolbar.add_child(margin)
	grid_button = CheckButton.new()
	grid_button.text = "显示网格 [G]"
	grid_button.button_pressed = show_grid
	grid_button.toggled.connect(func(enabled: bool):
		show_grid = enabled
		overlay.queue_redraw())
	toolbar.add_child(grid_button)
	var hint := Label.new()
	hint.text = "占地预览"
	toolbar.add_child(hint)
	footprint_picker = OptionButton.new()
	for label in ["1×1 · 箭塔 / 城墙", "2×2 · 生产 / 民屋", "4×4 · 主城"]:
		footprint_picker.add_item(label)
	footprint_picker.select(1)
	footprint_picker.item_selected.connect(func(index: int):
		var width: int = [1, 2, 4][index]
		footprint = Vector2i(width, width)
		_refresh_hover())
	toolbar.add_child(footprint_picker)
	var reset := Button.new()
	reset.text = "查看全图 [Home]"
	reset.pressed.connect(reset_camera)
	toolbar.add_child(reset)
	zoom_label = Label.new()
	toolbar.add_child(zoom_label)
	surface = SubViewportContainer.new()
	surface.stretch = true
	surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface.gui_input.connect(_map_input)
	surface.mouse_exited.connect(func():
		dragging = false
		hover_cell = Vector2i(-1, -1)
		overlay.queue_redraw())
	column.add_child(surface)
	view = SubViewport.new()
	view.size = Vector2i(960, 540)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.gui_disable_input = true
	surface.add_child(view)
	status = Label.new()
	status.text = IDLE_HINT
	status.custom_minimum_size.y = 40
	status.add_theme_font_size_override("font_size", 14)
	column.add_child(status)

func footprint_fits(cell: Vector2i) -> bool:
	return grid.is_inside(cell) and grid.is_inside(cell + footprint - Vector2i.ONE)

func minimum_zoom() -> float:
	var bounds: Vector2 = Vector2(grid.grid_size) * grid.CELL_SIZE
	return minf(surface.size.x / bounds.x, surface.size.y / bounds.y)

func reset_camera() -> void:
	center = Vector2(grid.grid_size) * grid.CELL_SIZE * 0.5
	zoom_factor = minimum_zoom()
	_update_camera()

func _update_camera() -> void:
	if overlay == null or surface.size.x <= 0 or surface.size.y <= 0:
		return
	zoom_factor = clampf(zoom_factor, minimum_zoom(), maxf(2.5, minimum_zoom()))
	var bounds: Vector2 = Vector2(grid.grid_size) * grid.CELL_SIZE
	var half := surface.size / (2.0 * zoom_factor)
	for axis in 2:
		center[axis] = bounds[axis] * 0.5 if half[axis] * 2.0 >= bounds[axis] else clampf(center[axis], half[axis], bounds[axis] - half[axis])
	view.canvas_transform = Transform2D(Vector2(zoom_factor, 0), Vector2(0, zoom_factor), surface.size * 0.5 - center * zoom_factor)
	zoom_label.text = "缩放 %.0f%%" % (zoom_factor * 100.0)
	_refresh_hover()

func _refresh_hover() -> void:
	var local := surface.get_local_mouse_position()
	var world := view.canvas_transform.affine_inverse() * local
	hover_cell = grid.world_to_cell(world) if Rect2(Vector2.ZERO, surface.size).has_point(local) else Vector2i(-1, -1)
	if grid.is_inside(hover_cell):
		var result := "可放置（示意）" if footprint_fits(hover_cell) else "超出地图边界 ×"
		status.text = "   格 (%d, %d) · 草地 · 可行走 · 代价 1.0　|　%d×%d 占地：%s" % [hover_cell.x, hover_cell.y, footprint.x, footprint.y, result]
	else:
		status.text = IDLE_HINT
	overlay.queue_redraw()

func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before: Vector2 = view.canvas_transform.affine_inverse() * event.position
			zoom_factor = clampf(zoom_factor * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), minimum_zoom(), maxf(2.5, minimum_zoom()))
			center = before - (event.position - surface.size * 0.5) / zoom_factor
			_update_camera()
	if event is InputEventMouseMotion:
		if dragging:
			center -= event.relative / zoom_factor
			_update_camera()
		_refresh_hover()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			grid_button.button_pressed = not grid_button.button_pressed
		elif event.keycode == KEY_HOME:
			reset_camera()
