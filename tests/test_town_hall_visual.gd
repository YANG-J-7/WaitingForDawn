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
	check(main.start_button.is_visible_in_tree() and main.top_bar.is_visible_in_tree(), "启动界面和开始按钮正常加载")
	check(is_instance_valid(city.body) and is_instance_valid(city.flag), "主城完整初始化，无缺失配置中断")
	check(city._shadow_rect({}, false) == Rect2(-100, -10, 290, 70), "旧清单缺少shadows时投影兼容")
	check(city._shadow_rect({}, true) == Rect2(-90, -25, 180, 25), "旧清单缺少shadows时接触影兼容")
	check(city.position == Layout.CITY_POSITION, "主城脚点与权威位置保持")
	check(city.body.texture.get_size() == Vector2(958, 1043), "运行使用独立生成建筑而非概念板切图")
	check((city.body.texture.get_size() * city.body.scale).is_equal_approx(Vector2(180,176)), "建筑180×176显示尺寸保持")
	check(Layout.CITY_FOOTPRINT == Vector2i(4,4), "主城仍占4×4格")
	check(city.grounding.get_parent() == main, "阴影独立于动画主体")
	check(city.grounding.get_index() > main.get_node("BorderForest").get_index() and city.grounding.get_index() < main.get_node("FarmerManager").get_index(), "阴影在地面之上、人物之下")
	check(city.ground_base.texture.get_size() == Vector2(1280, 792), "含左后侧草缘的独立底座完整加载")
	check(city.ground_base.get_parent() == city.grounding and city.ground_base.get_index() < city.grounding.get_node("CastShadow").get_index(), "底座位于主城投影及人物之下")
	check(main.grid_map_model.occupied_cells_for(&"city").size() == 16, "底座装饰没有扩大主城16格占用")
	check(main.grid_map_model.can_place(city.position + Vector2(108,0), Vector2i.ONE), "侧面草缘仍可放置相邻建筑")
	check(main.grid_map_model.can_place(city.position + Vector2(-36,90), Vector2i.ONE), "门前合法草地仍可建造")
	check(not main.grid_map_model.can_place(city.position + Vector2(0,108), Vector2i.ONE), "底座未放开原有南侧树林禁建格")
	var base_transform: Transform2D = city.ground_base.transform
	var base_node: Sprite2D = city.ground_base
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
	check(city.ground_base.transform == base_transform, "底座及草缘不随待机动画漂移")
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
	check(city.ground_base.visible and city.ground_base.transform == base_transform, "重开保持底座且不重复创建")
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
	check(not is_instance_valid(base_node), "场景释放同时清理独立地面底座")
	get_tree().quit(failures)


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
