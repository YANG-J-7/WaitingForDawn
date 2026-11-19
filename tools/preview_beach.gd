extends Control
var sample: Node2D
func _ready() -> void:
	var column:=VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	var bar:=HBoxContainer.new()
	column.add_child(bar)
	var title:=Label.new()
	title.text=" 沙滩与连续浪花 · 独立预览 "
	bar.add_child(title)
	var pause:=CheckButton.new()
	pause.text="暂停"
	pause.toggled.connect(func(value: bool): sample.paused=value)
	bar.add_child(pause)
	var reset:=Button.new()
	reset.text="复位"
	reset.pressed.connect(func(): sample.reset())
	bar.add_child(reset)
	var container:=SubViewportContainer.new()
	container.stretch=true
	container.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(container)
	var view:=SubViewport.new()
	view.size=Vector2i(1920,720)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	container.add_child(view)
	sample=preload("res://src/gameplay/art/beach_sample.gd").new()
	view.add_child(sample)
	container.resized.connect(func(): view.canvas_transform=Transform2D(0.0,Vector2.ZERO).scaled(Vector2.ONE*minf(container.size.x/1920.0,container.size.y/720.0)))
