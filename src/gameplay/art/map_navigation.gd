extends Control
## 屏幕层小地图不会缩放HUD；点击只移动地图镜头。
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
const TEXTURE: Texture2D = preload("res://assets/map/dawn_wide_v3/minimap.png")
const MAP_RECT := Rect2(6, 6, 160, 160.0 * 2880.0 / 7056.0)
var main: Node2D
var city_button: Button
var full_button: Button
var preview: SubViewport
var preview_texture: Texture2D

func configure(owner_main: Node2D) -> void:
	main = owner_main
	# 小地图由当前组件组合渲染，不能继续显示旧关卡截图。
	preview = SubViewport.new()
	preview.size = Vector2i(320,131)
	preview.disable_3d = true
	preview.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(preview)
	preview.canvas_transform = Transform2D(0,Vector2.ONE*(320.0/main.map_runtime.bounds.size.x),0,Vector2.ZERO)
	var ground := preload("res://src/gameplay/art/modular_map_layer.gd").new()
	ground.configure(main.grid_map_model,main.map_runtime)
	preview.add_child(ground)
	preview_texture = preview.get_texture()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(172,100)
	size = custom_minimum_size
	tooltip_text = "点击小地图定位；Home回主城，M查看全图"
	city_button = Button.new()
	city_button.text = "回主城"
	city_button.position = Vector2(6,75)
	city_button.size = Vector2(78,23)
	city_button.add_theme_font_size_override("font_size",12)
	city_button.pressed.connect(main.map_camera.reset_view)
	add_child(city_button)
	full_button = Button.new()
	full_button.text = "全图"
	full_button.position = Vector2(88,75)
	full_button.size = Vector2(78,23)
	full_button.add_theme_font_size_override("font_size",12)
	full_button.pressed.connect(main.map_camera.show_full_map)
	add_child(full_button)

func _process(_delta: float) -> void:
	var viewport_rect: Rect2 = main.map_camera.screen_view_rect()
	position = Vector2(viewport_rect.position.x+8, maxf(viewport_rect.position.y+8, viewport_rect.end.y-size.y-8))
	visible = not main.day_setup_panel.visible and not main.bottom_panel.visible and not main.failure_panel.visible
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and MAP_RECT.has_point(event.position):
		focus_minimap(event.position)
		accept_event()

func focus_minimap(point: Vector2) -> void:
	var ratio := ((point-MAP_RECT.position)/MAP_RECT.size).clamp(Vector2.ZERO,Vector2.ONE)
	main.map_camera.zoom = Vector2.ONE * maxf(main.map_camera.zoom.x, 0.72)
	main.map_camera.focus_world(ratio*main.map_runtime.bounds.size)

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_HOME:
		main.map_camera.reset_view()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_M:
		main.map_camera.show_full_map()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if main == null: return
	draw_style_box(_panel_style(),Rect2(Vector2.ZERO,size))
	if preview_texture != null: draw_texture_rect(preview_texture,MAP_RECT,false)
	for site in main.resource_sites:
		var point: Vector2 = MAP_RECT.position + site.position / main.map_runtime.bounds.size * MAP_RECT.size
		if site.site_type == &"forest":
			draw_colored_polygon(PackedVector2Array([point+Vector2(0,-3),point+Vector2(-3,3),point+Vector2(3,3)]),Color("b9d693"))
		else:
			draw_rect(Rect2(point-Vector2(2,2),Vector2(4,4)),Color("ffcd78") if site.site_type == &"iron_deposit" else Color("e5e7e9"))
	var city: Vector2 = MAP_RECT.position + main.map_runtime.city_position / main.map_runtime.bounds.size * MAP_RECT.size
	draw_rect(Rect2(city-Vector2(3,3),Vector2(6,6)),Color("ffd477"),false,1.5)
	var world_rect: Rect2 = main.map_camera.visible_world_rect().intersection(main.map_runtime.bounds)
	draw_rect(Rect2(MAP_RECT.position+world_rect.position/main.map_runtime.bounds.size*MAP_RECT.size,world_rect.size/main.map_runtime.bounds.size*MAP_RECT.size),Color("fff0c6"),false,1.0)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b1825")
	style.border_color = Color("9b7d46")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style
