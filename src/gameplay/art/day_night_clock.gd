extends Control
## 黎明计时胶囊：圆弧按整局有效时间推进，末段由月牙过渡到太阳。
const SHEET: Texture2D = preload("res://assets/ui/day_night_clock_v1/sheet-transparent.png")
const FRAME_COUNT: int = 8
const CELL_SIZE: int = 128
const DAWN_TRANSITION_SECONDS: float = 300.0
const CAPSULE_SIZE := Vector2(142.0, 32.0)
const DRAW_RECT := Rect2(0, -4, 142, 40)

func visual_rect() -> Rect2:
	# 圆弧线条可能比胶囊底边多伸出四分之一像素，视口预留完整范围。
	return get_global_transform() * DRAW_RECT.grow(.5)

var progress: float = 0.0
var transition_progress: float = 0.0
var frame_position: float = 0.0
var current_frame: int = 0
var next_frame: int = 0
var blend: float = 0.0
var remaining_seconds: float = 3600.0
var countdown: Label
var dawn_title: Label


func configure(time_label: Label) -> void:
	name = "DayNightClock"
	custom_minimum_size = CAPSULE_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "守至黎明：圆弧显示本局进度，最后5分钟月牙逐渐转为太阳。"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	countdown = time_label
	countdown.reparent(self)
	countdown.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	# 先更新字体再设尺寸，避免旧大字号的最小宽度留下不可缩回的标签框。
	countdown.add_theme_font_size_override("font_size", 18)
	countdown.position = Vector2(76.0, 3.0)
	countdown.size = Vector2(61.0, 26.0)
	countdown.add_theme_color_override("font_color", Color("ffc65e"))
	countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dawn_title = Label.new()
	dawn_title.text = "黎明"
	dawn_title.position = Vector2(39.0, 7.0)
	dawn_title.size = Vector2(36.0, 19.0)
	dawn_title.add_theme_font_size_override("font_size", 14)
	dawn_title.add_theme_color_override("font_color", Color("f3efdf"))
	dawn_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dawn_title)
	RunState.campaign_time_changed.connect(set_remaining_time)
	set_remaining_time(RunState.campaign_remaining_seconds())
	# Godot延迟更新最小尺寸，待旧字号的高度缓存释放后再收紧标签框。
	call_deferred("_fit_countdown")

func _fit_countdown() -> void:
	countdown.position = Vector2(76.0, 3.0)
	countdown.size = Vector2(61.0, 26.0)


func set_remaining_time(seconds: float) -> void:
	remaining_seconds = clampf(seconds, 0.0, RunState.CAMPAIGN_DURATION_SECONDS)
	progress = 1.0 - remaining_seconds / RunState.CAMPAIGN_DURATION_SECONDS
	transition_progress = clampf(1.0 - remaining_seconds / DAWN_TRANSITION_SECONDS, 0.0, 1.0)
	frame_position = transition_progress * (FRAME_COUNT - 1)
	current_frame = mini(FRAME_COUNT - 1, int(floor(frame_position)))
	next_frame = mini(FRAME_COUNT - 1, current_frame + 1)
	blend = frame_position - current_frame
	queue_redraw()


func _draw() -> void:
	# 胶囊同步压薄，下缘只比顶栏突出4像素。
	var capsule := DRAW_RECT
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color("0b1724")
	rim.border_color = Color("263b4c")
	rim.set_border_width_all(3)
	rim.set_corner_radius_all(20)
	draw_style_box(rim, capsule)
	var inner := StyleBoxFlat.new()
	inner.draw_center = false
	inner.border_color = Color("172a3c")
	inner.set_border_width_all(1)
	inner.set_corner_radius_all(16)
	draw_style_box(inner, capsule.grow(-4.0))
	_draw_progress_arc()
	var source := Rect2((current_frame % 4) * CELL_SIZE, (current_frame / 4) * CELL_SIZE, CELL_SIZE, CELL_SIZE)
	var target := Rect2(3.0, 0.0, 32.0, 32.0)
	# 固定公共画布与统一缩放；相邻帧淡入衔接，保持小尺寸轮廓稳定。
	draw_texture_rect_region(SHEET, target, source, Color(1, 1, 1, 1.0 - blend))
	if blend > 0.0:
		var following := Rect2((next_frame % 4) * CELL_SIZE, (next_frame / 4) * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		draw_texture_rect_region(SHEET, target, following, Color(1, 1, 1, blend))


func _draw_progress_arc() -> void:
	var center := Vector2(20.0, 16.0)
	var radius: float = 19.0
	# 从左侧往下延伸；参考图42:18附近可见约70度绿黄弧。
	var start: float = deg_to_rad(180.0)
	var sweep: float = lerpf(deg_to_rad(12.0), deg_to_rad(246.0), progress)
	var segments: int = maxi(8, int(sweep * 14.0))
	for i in range(segments):
		var fraction: float = float(i) / float(segments)
		var a: float = start - sweep * fraction
		var b: float = start - sweep * float(i + 1) / float(segments)
		var color: Color = Color("67c49a").lerp(Color("f8dc72"), fraction)
		draw_line(center + Vector2(cos(a), sin(a)) * radius, center + Vector2(cos(b), sin(b)) * radius, color, 2.5, true)
