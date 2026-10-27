extends Node2D
## 使用世界坐标材质包裹组件几何，画面不读取旧整图像素。
var surface_rect := Rect2()

func _draw() -> void:
	draw_rect(surface_rect,Color.WHITE)
