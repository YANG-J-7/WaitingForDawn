extends Camera2D

const Layout = preload("res://src/gameplay/buildings/map_layout.gd")
const MOUSE_DRAG_THRESHOLD: float = 6.0
@export var default_zoom: float = 1.0 / 3.0
@export var minimum_zoom: float = 1.0 / 3.0
## 按用户截图中小地图视野框约30%图宽校准：960/(7056×0.30)≈0.45。
@export var maximum_zoom: float = 0.45
@export var defense_zoom: float = 0.24
@export var build_zoom: float = 0.36
@export var detail_zoom: float = 0.45
@export var view_transition_seconds: float = 0.22
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
var return_position := Vector2.ZERO
var return_zoom: float = 0.36
var has_return_view: bool = false
var view_tween: Tween

func _stop_transition() -> void:
	if view_tween != null:
		view_tween.kill()
		view_tween = null

func _process(_delta: float) -> void:
	# 拖牌的屏幕反变换必须稳定，不能让先前的快捷切换继续移动落点。
	if get_viewport().gui_is_dragging(): _stop_transition()

func _move_view(point: Vector2, target_zoom: float, animated: bool) -> void:
	_stop_transition()
	var target := clampf(target_zoom, minimum_zoom, maximum_zoom)
	if not animated or view_transition_seconds <= 0.0:
		_apply_view(point,target)
		return
	var start_position := position
	var start_zoom := zoom.x
	view_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	view_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	view_tween.tween_method(func(weight: float):
		_apply_view(start_position.lerp(point,weight),lerpf(start_zoom,target,weight)),0.0,1.0,view_transition_seconds)

func _apply_view(point: Vector2, scale_value: float) -> void:
	position = point
	zoom = Vector2.ONE * scale_value
	_clamp_position()
	force_update_scroll()

func set_view_level(level: StringName, animated: bool = false) -> void:
	var scales := {&"defense":defense_zoom,&"build":build_zoom,&"detail":detail_zoom}
	if not scales.has(level): return
	var point := return_position if overview and has_return_view else position
	overview = false
	_move_view(point,scales[level],animated)

func active_view_level() -> StringName:
	if overview: return &"overview"
	var scales := {&"defense":defense_zoom,&"build":build_zoom,&"detail":detail_zoom}
	for level in scales:
		var target: float = scales[level]
		if is_equal_approx(zoom.x,clampf(target,minimum_zoom,maximum_zoom)): return level
	return &"custom"

func toggle_overview(animated: bool = false) -> void:
	if not overview:
		show_full_map()
		return
	overview = false
	_move_view(return_position if has_return_view else city_position,return_zoom if has_return_view else build_zoom,animated)

func configure(context: RefCounted) -> void:
	map_bounds = context.bounds
	city_position = context.city_position

func screen_view_rect() -> Rect2:
	return play_rect if play_rect.size.x > 0 and play_rect.size.y > 0 else get_viewport_rect()

func visible_world_rect() -> Rect2:
	return get_canvas_transform().affine_inverse() * screen_view_rect()

func set_play_rect(rect: Rect2) -> void:
	if rect == play_rect: return
	_stop_transition()
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
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_refresh_fit_zoom()
	reset_view()

func reset_view(animated: bool = false) -> void:
	_stop_transition()
	overview = false
	has_return_view = false
	_refresh_fit_zoom()
	touches.clear()
	mouse_panning = false
	mouse_pan_button = MOUSE_BUTTON_NONE
	mouse_pan_distance = 0.0
	last_mouse_pan_distance = 0.0
	_move_view(city_position,build_zoom,animated)

func show_full_map() -> void:
	_stop_transition()
	if not overview:
		return_position = position
		return_zoom = zoom.x
		has_return_view = true
	overview = true
	_refresh_fit_zoom()
	position = map_bounds.get_center()
	zoom = Vector2.ONE * overview_zoom
	_clamp_position()
	force_update_scroll()

func focus_world(point: Vector2) -> void:
	_stop_transition()
	if overview:
		overview = false
		zoom = Vector2.ONE * clampf(build_zoom,minimum_zoom,maximum_zoom)
	position = point
	_clamp_position()
	force_update_scroll()

func screen_to_world(point: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * point

func zoom_at(factor: float, point: Vector2) -> void:
	_stop_transition()
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
	_stop_transition()
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
	_stop_transition()
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
		_stop_transition()
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
		_stop_transition()
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
		_stop_transition()
		touches.clear()
		mouse_panning = false
		mouse_pan_button = MOUSE_BUTTON_NONE
