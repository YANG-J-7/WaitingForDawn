extends Control

signal cell_selected(cell: Vector2i)

const Graybox = preload("res://prototypes/moonlake_3d_graybox/moonlake_3d_graybox.gd")

var crop: Rect2i
var terrain_image: ImageTexture
var buildings: Array[Vector2] = []
var farmer_cell := Vector2.ZERO


func configure(terrain: Graybox) -> void:
	crop = terrain.CROP
	var terrain_pixels := Image.create_empty(crop.size.x, crop.size.y, false, Image.FORMAT_RGB8)
	for y in range(crop.size.y):
		for x in range(crop.size.x):
			terrain_pixels.set_pixel(x, y, terrain._cell_color(crop.position + Vector2i(x, y)))
	terrain_image = ImageTexture.create_from_image(terrain_pixels)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	if terrain_image == null:
		return
	var area := _map_area()
	draw_texture_rect(terrain_image, area, false)
	draw_rect(area, Color("#aac0bc"), false)
	for cell in buildings:
		var point := area.position + (cell - Vector2(crop.position)) / Vector2(crop.size) * area.size
		draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), Color("#fff0c7"))
	var farmer_point := area.position + (farmer_cell - Vector2(crop.position)) / Vector2(crop.size) * area.size
	draw_circle(farmer_point, 3.0, Color("#80f4ff"))


func _map_area() -> Rect2:
	var scale_to_fit := minf(size.x / crop.size.x, size.y / crop.size.y)
	var map_size := Vector2(crop.size) * scale_to_fit
	return Rect2((size - map_size) * 0.5, map_size)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var area := _map_area()
		if area.has_point(event.position):
			var local: Vector2 = (event.position - area.position) / area.size * Vector2(crop.size)
			cell_selected.emit(crop.position + Vector2i(local))
			accept_event()
