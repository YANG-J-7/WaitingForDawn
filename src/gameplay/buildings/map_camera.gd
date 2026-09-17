extends Camera2D

const Layout = preload("res://src/gameplay/buildings/map_layout.gd")
@export var default_zoom: float = 0.48
@export var minimum_zoom: float = 0.35
@export var maximum_zoom: float = 1.6
var touches: Dictionary = {}
var mouse_panning: bool = false
var surface: Control

func _ready() -> void:
	reset_view()

func reset_view() -> void:
	touches.clear()
	mouse_panning = false
	position = Layout.BOUNDS.get_center()
	zoom = Vector2.ONE * default_zoom
	force_update_scroll()

func screen_to_world(point: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * point

func zoom_at(factor: float, point: Vector2) -> void:
	var before := screen_to_world(point)
	zoom = Vector2.ONE * clampf(zoom.x * factor, minimum_zoom, maximum_zoom)
	force_update_scroll()
	position += before - screen_to_world(point)
	_clamp_position()
	force_update_scroll()

func pan_by(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom
	_clamp_position()
	force_update_scroll()

func _clamp_position() -> void:
	# 中心允许移到地图边缘，确保高倍率时边缘建筑仍可移到可操作区域。
	position = position.clamp(Layout.BOUNDS.position, Layout.BOUNDS.end)

func handle_map_input(event: InputEvent) -> void:
	if get_viewport().gui_is_dragging():
		return
	if event is InputEventMouseButton and event.pressed:
		var point: Vector2 = surface.global_position + event.position
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(1.12, point)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(1.0 / 1.12, point)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			mouse_panning = true
	if event is InputEventScreenTouch and event.pressed:
		touches[event.index] = surface.global_position + event.position
	if event is InputEventMagnifyGesture:
		zoom_at(event.factor, surface.global_position + event.position)

func _input(event: InputEvent) -> void:
	if surface == null or not surface.is_visible_in_tree() or get_viewport().gui_is_dragging():
		touches.clear()
		mouse_panning = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		mouse_panning = false
	if event is InputEventMouseMotion and mouse_panning:
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
