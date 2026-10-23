extends Node

const MAIN = preload("res://src/main/main.tscn")
const Layout = preload("res://src/gameplay/buildings/map_layout.gd")
var failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var main := MAIN.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var city: Node2D = main.get_node("TownHallVisual")
	check(city.position == Layout.CITY_POSITION, "主城脚点与权威位置保持")
	check(city.body.texture.get_size() == Vector2(958, 1043), "运行使用独立生成建筑而非概念板切图")
	check((city.body.texture.get_size() * city.body.scale).is_equal_approx(Vector2(180,176)), "建筑180×176显示尺寸保持")
	check(Layout.CITY_FOOTPRINT == Vector2i(4,4), "主城仍占4×4格")
	check(city.grounding.get_parent() == main, "阴影独立于动画主体")
	check(city.grounding.get_index() > main.get_node("BorderForest").get_index() and city.grounding.get_index() < main.get_node("FarmerManager").get_index(), "阴影在地面之上、人物之下")
	var body_transform: Transform2D = city.body.transform
	var shadow_transform: Transform2D = city.grounding.transform
	var cloth_position: Vector2 = city.flag.position
	main._on_start_pressed()
	main.opening_draft.set_countdown_paused(true)
	city.set_process(false)
	var first: Texture2D = city.flag.texture
	city._process(.25)
	check(city.flag.texture != first and city.animation_frame == 1, "旗帜按有效时间进入下一帧")
	check(city.fire_left.texture != city.fire_right.texture, "两侧火焰错相播放")
	check(city.smoke.texture != city.smoke_next.texture, "薄烟使用相邻帧过渡")
	check(city.body.transform == body_transform and city.grounding.transform == shadow_transform and city.flag.position == cloth_position, "建筑、阴影、旗杆附着点均不随动画漂移")
	var time: float = city.animation_time
	get_tree().paused = true
	city._process(1.0)
	await get_tree().process_frame
	check(city.animation_time == time, "暂停冻结所有主城动画")
	get_tree().paused = false
	city._process(.25)
	check(city.animation_time > time, "恢复后继续局部动画")
	main._on_reset_pressed()
	check(city.animation_time == 0.0 and city.animation_frame == 0, "重开复位动画相位")
	check(city.flag.visible and city.fire_left.visible, "重开恢复旗帜与火焰")
	RunState.begin_new_run()
	RunState.start_current_wave()
	RunState.damage_city(999999)
	time = city.animation_time
	city._process(.8)
	check(city.animation_time == time, "失败结算不继续播放")
	check(not city.flag.visible and not city.fire_left.visible and not city.smoke.visible, "主城摧毁不遗留悬浮特效")
	main._on_reset_pressed()
	RunState.begin_new_run()
	RunState.start_current_wave()
	RunState.advance_campaign_time(3600)
	await get_tree().process_frame
	time = city.animation_time
	city._process(.8)
	check(RunState.phase == RunState.Phase.RUN_WON and city.animation_time == time, "胜利结算停止播放")
	main._on_reset_pressed()
	main.queue_free()
	await get_tree().process_frame
	check(not is_instance_valid(city), "场景释放清理主城表现")
	get_tree().quit(failures)


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
