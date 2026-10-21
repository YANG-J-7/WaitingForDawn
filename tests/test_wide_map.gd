extends Node
## 扩边同时验证旧路线几何、新增平原真实建造与单位交付。
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
const MAIN = preload("res://src/main/main.tscn")
var failures := 0
var delivered := 0

func _ready() -> void:
	var main := MAIN.instantiate()
	add_child(main)
	main._on_start_pressed()
	main.opening_draft.active = false
	main.wave_controller.set_process(false)
	main.farmer_manager.set_process(false)
	RunState.start_current_wave()
	# 本用例跳过选卡界面，显式进入真实战斗手牌布局。
	main.day_setup_panel.hide()
	main.hand_bar.show()
	for resource in RunEconomy.RESOURCE_IDS: RunEconomy.add_resource(resource,10000)
	var grid: RefCounted = main.grid_map_model
	var finder: RefCounted = main.grid_pathfinder
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/dawn_large_v1/map.json"))
	var data := Definition.data()
	check(data.worldSize==[7056.0,2880.0] and data.gridSize==[196.0,80.0],"画幅与196×80权威格同步")
	check(Definition.BOUNDS.size/36==Vector2(grid.grid_size),"36世界像素格没有随画幅拉伸")
	for index in range(old.resourceSites.size()):
		var before: Dictionary = old.resourceSites[index]
		var after: Dictionary = data.resourceSites[index]
		var before_delta := Vector2(before.position.x,before.position.y)-Vector2(old.city[0],old.city[1])
		var after_delta := Vector2(after.position.x,after.position.y)-Definition.CITY_POSITION
		check(before.id==after.id and before_delta==after_delta,"%s与主城的相对距离保持" % before.id)
	for source in [Vector2.ZERO,Vector2(613,201),Vector2(1200,327),Definition.SOURCE_SIZE]:
		check(Definition.world_to_source(Definition.source_to_world(source)).is_equal_approx(source),"扩边坐标双向转换：%s" % source)
	var old_nav: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/dawn_large_v1/mountain-navigation.json"))
	var nav := Definition.navigation_data()
	var preserved: bool = nav.cells.size()==old_nav.cells.size() and nav.routes==old_nav.routes and nav.stairs==old_nav.stairs
	for index in range(old_nav.cells.size()):
		var expected: Dictionary = old_nav.cells[index].duplicate(true)
		expected.cell=[expected.cell[0]+68,expected.cell[1]+8]
		preserved=preserved and expected==nav.cells[index]
	check(preserved,"547个山路/石梯格仅平移，层级、路线及S6几何保持")
	var point := Vector2(1800,1512)
	check(grid.can_place(point,Vector2i(2,2)),"新增西侧平原允许真实双格建造")
	var path: PackedVector2Array = finder.find_path(Definition.CITY_POSITION+Vector2(-108,0),point,60)
	check(not path.is_empty(),"新增平原与主城连通")
	var id: int = main.run_card_inventory.add_card(preload("res://src/data/cards/farm.tres"),1)
	check(main._try_place_map_building_card(id,point),"新增平原实际落成农场并消费卡片")
	var building: Node2D = main.settlement_builder.placed_buildings().back()
	var farmer := FarmerAgent.new()
	main.add_child(farmer)
	farmer.configure(0,Definition.CITY_POSITION)
	farmer.position=Definition.CITY_POSITION+Vector2(-108,0)
	farmer.set_pathfinder(finder)
	farmer.assign_job(&"west_plain",building,&"food",2)
	farmer.delivery_completed.connect(func(_id: StringName,amount: int): delivered+=amount)
	var legal := true
	for step in range(6000):
		farmer.advance(.05)
		legal=legal and not grid.is_solid(grid.world_to_cell(farmer.position))
		if delivered>0: break
	check(delivered==2 and legal,"农民到新增平原采集并合法回城交付")
	farmer.free()
	var boundary := Vector2(5400,144)
	check(grid.is_solid(grid.world_to_cell(boundary)) and not grid.can_place(boundary,Vector2i(2,2)),"新增山体后缘展示带禁行禁建")
	check(finder.find_path(Definition.CITY_POSITION,boundary).is_empty(),"单位不能穿越新增北部展示带")
	check(not grid.interaction_clear(Vector2(5400,324),boundary),"交互射线不能穿越新增北部边界")
	main._update_map_view_rect()
	main.map_camera.show_full_map()
	var rect: Rect2 = main.map_camera.get_canvas_transform()*Definition.BOUNDS
	var play: Rect2 = main.map_view_rect()
	print("METRIC: 默认视口=%s 全图投影=%s 覆盖=%s" % [play,rect,rect.size/play.size])
	check(play.grow(.01).encloses(rect) and rect.size.x/play.size.x>.99 and rect.size.y/play.size.y>.99,"960×540全图完整覆盖中间视口99%以上")
	main._on_reset_pressed()
	check(main.settlement_builder.placed_buildings().is_empty() and main.resource_sites.all(func(s):return not s.is_occupied()),"重开清除新增平原建筑并恢复资源")
	main.queue_free()
	RunState.reset_to_boot()
	get_tree().quit(failures)

func check(condition: bool,label: String) -> void:
	if condition: print("PASS: "+label)
	else:
		failures+=1
		push_error("FAIL: "+label)
