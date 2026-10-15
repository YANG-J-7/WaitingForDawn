extends Node2D
## 世界边框随缩放保持清楚；不占用玩法格或改变通行。
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
var main: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main == null or main.map_camera == null: return
	var zoom_value: float = maxf(.05, main.map_camera.zoom.x)
	var width := 1.5 / zoom_value
	var rect: Rect2 = Definition.BOUNDS.grow(-width)
	draw_rect(rect,Color("162938"),false,width*3)
	draw_rect(rect,Color("beab72"),false,width)
	var length := 16.0 / zoom_value
	for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		var sx := 1.0 if corner.x == rect.position.x else -1.0
		var sy := 1.0 if corner.y == rect.position.y else -1.0
		draw_line(corner,corner+Vector2(length*sx,0),Color("ebd7a1"),width*1.5)
		draw_line(corner,corner+Vector2(0,length*sy),Color("ebd7a1"),width*1.5)
	var target: Node2D = main.wave_economy.job_target(main.selected_job_id) as Node2D
	if is_instance_valid(target):
		draw_arc(target.global_position,main._job_target_radius(target)+8,0,TAU,40,Color("f0c767"),3)
