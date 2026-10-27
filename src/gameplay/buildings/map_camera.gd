extends Camera2D

const Layout = preload("res://src/gameplay/buildings/map_layout.gd")
const MOUSE_DRAG_THRESHOLD: float = 6.0
@export var default_zoom: float = 1.0 / 3.0
@export var minimum_zoom: float = 1.0 / 3.0
@export var maximum_zoom: float = 1.6
var touches: Dictionary = {}
var mouse_panning: bool = false
var mouse_pan_button: MouseButton = MOUSE_BUTTON_NONE
var mouse_pan_distance: float = 0.0
var last_mouse_pan_distance: float = 0.0
var surface: Control
var play_rect := Rect2()
var map_bounds := Layout.BOUNDS
var city_position := Layout.CITY_POSITION
var overview: bool = false
var overview_zoom: float = 0.1

func configure(context: RefCounted) -> void:
	map_bounds = context.bounds
	city_position = context.city_position

func screen_view_rect() -> Rect2:
	return play_rect if play_rect.size.x > 0 and play_rect.size.y > 0 else get_viewport_rect()

func visible_world_rect() -> Rect2:
	return get_canvas_transform().affine_inverse() * screen_view_rect()

func set_play_rect(rect: Rect2) -> void:
	if rect == play_rect: return
	var was_full := overview
	play_rect = rect
	_refresh_fit_zoom()
	if was_full: zoom = Vector2.ONE * overview_zoom
	_clamp_position()
	force_update_scroll()

func _apply_screen_offset() -> void:
	# 镜头的世界中心映到中间视口中心，而不是整个含HUD窗口的中心。
	offset = (get_viewport_rect().size * 0.5 - screen_view_rect().get_center()) / zoom
	if get_parent() is CanvasItem: get_parent().queue_redraw()

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_refresh_fit_zoom()
	reset_view()

func reset_view() -> void:
	overview = false
	_refresh_fit_zoom()
	touches.clear()
	mouse_panning = false
	mouse_pan_button = MOUSE_BUTTON_NONE
	mouse_pan_distance = 0.0
	last_mouse_pan_distance = 0.0
	position = city_position
	zoom = Vector2.ONE * maxf(minimum_zoom, 0.72)
	_clamp_position()
	force_update_scroll()

func show_full_map() -> void:
	overview = true
	_refresh_fit_zoom()
	position = map_bounds.get_center()
	zoom = Vector2.ONE * overview_zoom
	_clamp_position()
	force_update_scroll()

func focus_world(point: Vector2) -> void:
	if overview:
		overview = false
		zoom = Vector2.ONE * maxf(.72,minimum_zoom)
	position = point
	_clamp_position()
	force_update_scroll()

func screen_to_world(point: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * point

func zoom_at(factor: float, point: Vector2) -> void:
	if overview:
		overview = false
		zoom = Vector2.ONE * minimum_zoom
	var before := screen_to_world(point)
	zoom = Vector2.ONE * clampf(zoom.x * factor, minimum_zoom, maximum_zoom)
	_apply_screen_offset()
	force_update_scroll()
	position += before - screen_to_world(point)
	_clamp_position()
	force_update_scroll()

func pan_by(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom
	_clamp_position()
	force_update_scroll()

func _clamp_position() -> void:
	var viewport_size: Vector2 = screen_view_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or zoom.x <= 0.0:
		return
	var half_visible: Vector2 = viewport_size / (zoom * 2.0)
	if overview:
		position = map_bounds.get_center()
		_apply_screen_offset()
		return
	position.x = _clamp_axis(
		position.x,
		map_bounds.position.x + half_visible.x,
		map_bounds.end.x - half_visible.x,
		map_bounds.get_center().x
	)
	position.y = _clamp_axis(
		position.y,
		map_bounds.position.y + half_visible.y,
		map_bounds.end.y - half_visible.y,
		map_bounds.get_center().y
	)
	_apply_screen_offset()


func _refresh_fit_zoom() -> void:
	var viewport_size: Vector2 = screen_view_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	overview_zoom = minf(
		viewport_size.x / map_bounds.size.x,
		viewport_size.y / map_bounds.size.y
	)
	minimum_zoom = minf(maxf(viewport_size.x/map_bounds.size.x,viewport_size.y/map_bounds.size.y), maximum_zoom)
	default_zoom = minimum_zoom
	if not overview and zoom.x < minimum_zoom:
		zoom = Vector2.ONE * minimum_zoom


func _clamp_axis(value: float, minimum: float, maximum: float, center: float) -> float:
	if minimum > maximum:
		return center
	return clampf(value, minimum, maximum)


func _on_viewport_size_changed() -> void:
	var was_at_full_map: bool = overview
	_refresh_fit_zoom()
	if was_at_full_map:
		zoom = Vector2.ONE * overview_zoom
	_clamp_position()
	force_update_scroll()

func handle_map_input(event: InputEvent) -> void:
	if get_viewport().gui_is_dragging():
		return
	if event is InputEventMouseButton and event.pressed:
		var point: Vector2 = surface.global_position + event.position
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(1.12, point)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(1.0 / 1.12, point)
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			mouse_panning = true
			mouse_pan_button = event.button_index
			mouse_pan_distance = 0.0
			last_mouse_pan_distance = 0.0
	if event is InputEventScreenTouch and event.pressed:
		touches[event.index] = surface.global_position + event.position
	if event is InputEventMagnifyGesture:
		zoom_at(event.factor, surface.global_position + event.position)

func _input(event: InputEvent) -> void:
	if surface == null or not surface.is_visible_in_tree() or get_viewport().gui_is_dragging():
		touches.clear()
		mouse_panning = false
		mouse_pan_button = MOUSE_BUTTON_NONE
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == mouse_pan_button:
		last_mouse_pan_distance = mouse_pan_distance
		mouse_panning = false
		mouse_pan_button = MOUSE_BUTTON_NONE
	if event is InputEventMouseMotion and mouse_panning:
		mouse_pan_distance += event.relative.length()
		pan_by(event.relative)
		get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch and not event.pressed:
		touches.erase(event.index)
	if event is InputEventScreenDrag and event.index in touches:
		if touches.size() == 1:
			pan_by(event.position - Vector2(touches[event.index]))
		else:
			var keys: Array = touches.keys()
			var other: int = int(keys[1] if keys[0] == event.index else keys[0])
			var old_point: Vector2 = touches[event.index]
			var fixed_point: Vector2 = touches[other]
			var old_distance: float = old_point.distance_to(fixed_point)
			if old_distance > 8.0:
				var old_center: Vector2 = (old_point + fixed_point) * 0.5
				zoom_at(event.position.distance_to(fixed_point) / old_distance, old_center)
				pan_by((event.position - old_point) * 0.5)
		touches[event.index] = event.position
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		touches.clear()
		mouse_panning = false
		mouse_pan_button = MOUSE_BUTTON_NONE
