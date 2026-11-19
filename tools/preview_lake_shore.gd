extends Control
## 湖岸分层开发预览：按阶段比较，滚轮缩放、中键平移。
const Sample=preload("res://src/gameplay/art/lake_sample.gd")
var lake: Node2D
var surface: SubViewportContainer
var view: SubViewport
var status: Label
var center := Vector2(960,540)
var zoom_factor := 1.0
var dragging := false

func _ready() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y=42
	column.add_child(bar)
	var title := Label.new()
	title.text=" 湖岸样区 "
	bar.add_child(title)
	var picker := OptionButton.new()
	for label in ["① 静态衔接","② 拍岸水花","③ 湖面波纹","④ 月光碎点"]:
		picker.add_item(label)
	picker.select(3)
	picker.item_selected.connect(func(stage: int): lake.set_stage(stage))
	bar.add_child(picker)
	var pause_button := CheckButton.new()
	pause_button.text="暂停"
	pause_button.toggled.connect(func(value: bool): lake.paused=value)
	bar.add_child(pause_button)
	var reset_button := Button.new()
	reset_button.text="复位"
	reset_button.pressed.connect(func(): lake.reset())
	bar.add_child(reset_button)
	var fit := Button.new()
	fit.text="全图 [Home]"
	fit.pressed.connect(reset_camera)
	bar.add_child(fit)
	surface=SubViewportContainer.new()
	surface.stretch=true
	surface.size_flags_vertical=Control.SIZE_EXPAND_FILL
	surface.gui_input.connect(_map_input)
	column.add_child(surface)
	view=SubViewport.new()
	view.size=Vector2i(960,540)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	view.gui_disable_input=true
	surface.add_child(view)
	lake=Sample.new()
	view.add_child(lake)
	status=Label.new()
	status.text=" 静态岩岸 · 三处拍岸水花 / 波纹 / 月光 | 滚轮缩放 · 中键拖动 | 独立样区"
	status.custom_minimum_size.y=28
	column.add_child(status)
	surface.resized.connect(_update_camera)
	reset_camera.call_deferred()

func reset_camera() -> void:
	center=Sample.SIZE*0.5
	zoom_factor=minf(surface.size.x/Sample.SIZE.x,surface.size.y/Sample.SIZE.y)
	_update_camera()

func _update_camera() -> void:
	view.canvas_transform=Transform2D(Vector2(zoom_factor,0),Vector2(0,zoom_factor),surface.size*0.5-center*zoom_factor)

func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_MIDDLE:
			dragging=event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var before: Vector2=view.canvas_transform.affine_inverse()*event.position
			zoom_factor=clampf(zoom_factor*(1.15 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.15),0.15,2.0)
			center=before-(event.position-surface.size*0.5)/zoom_factor
			_update_camera()
	if event is InputEventMouseMotion and dragging:
		center-=event.relative/zoom_factor
		_update_camera()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_HOME:
		reset_camera()
