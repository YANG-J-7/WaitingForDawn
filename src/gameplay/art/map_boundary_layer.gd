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
	# 边界由自然景观表达，不把整张地图画成带框的矩形贴片。
	var target: Node2D = main.wave_economy.job_target(main.selected_job_id) as Node2D
	if is_instance_valid(target):
		draw_arc(target.global_position,main._job_target_radius(target)+8,0,TAU,40,Color("f0c767"),3)
