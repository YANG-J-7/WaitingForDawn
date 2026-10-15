extends Node
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
	for resource in RunEconomy.RESOURCE_IDS: RunEconomy.add_resource(resource,10000)
	var grid: RefCounted = main.grid_map_model
	var finder: RefCounted = main.grid_pathfinder
	var start: Vector2 = Definition.CITY_POSITION+Vector2(108,0)
	check(grid.grid_size == Vector2i(128,72),"4608×2592地图共9216格，36像素格保持")
	check(main.wave_controller.playable_bounds == Definition.BOUNDS,"世界边界共用地图定义")
	check(main.resource_sites.size()==8,"四林两石两铁保持")
	check(Definition.data().qc.initialCompositeMaxChannelDifference==0,"原始v1分层候选合成像素差为0，高清v2不沿用此指标")
	check(main.terrain_grid_layer.chunks.size()==12,"地形分成12片并按视口裁绘")
	var terrain_only := preload("res://src/gameplay/grid/grid_map_model.gd").new()
	preload("res://src/gameplay/grid/terrain_map_data.gd").apply_to(terrain_only)
	for entry in Definition.resource_sites():
		var point := Vector2(entry.position.x,entry.position.y)
		check(terrain_only.can_place(point,Vector2i(2,2)),"%s资源标注原本位于完整草台，不覆盖裸岩或水" % entry.id)
	check(main.map_camera.position == Definition.CITY_POSITION and is_equal_approx(main.map_camera.zoom.x,.72),"开局主城近景，单位尺寸不缩小")
	var cards := {&"forest":preload("res://src/data/cards/lumber_camp.tres"),&"stone_deposit":preload("res://src/data/cards/stone_mine.tres"),&"iron_deposit":preload("res://src/data/cards/iron_mine.tres")}
	for site in main.resource_sites:
		var card = cards[site.site_type]
		var id: int = main.run_card_inventory.add_card(card,1)
		check(main.placement_preview(card,site.position).valid,"%s资源点吸附合法" % site.name)
		check(main._try_place_map_building_card(id,site.position),"%s真实资源建筑建造成功" % site.name)
		if not site.is_occupied(): continue
		if site.site_type == &"forest":
			check(not site.art_visual.visible,"%s占用隐藏整簇树林" % site.name)
			check(grid.cells_of_type(&"forest").size()>0,"固定边界树林仍有阻挡")
		var outward: PackedVector2Array = finder.find_path(start,site.position,60)
		check(not outward.is_empty() and outward[-1].distance_to(site.position)<=60,"%s采集入口可达" % site.name)
		if outward.is_empty(): continue
		check(_legal(grid,start,outward),"%s去程不穿岩/水/斜角" % site.name)
		var home: PackedVector2Array = finder.find_path(outward[-1],Definition.CITY_POSITION,96)
		check(not home.is_empty() and _legal(grid,outward[-1],home),"%s回城合法" % site.name)
		var farmer := FarmerAgent.new()
		add_child(farmer)
		farmer.configure(0,Definition.CITY_POSITION)
		farmer.position = start
		farmer.set_pathfinder(finder)
		farmer.assign_job(StringName(site.name),site.occupied_building,&"wood",2)
		delivered = 0
		farmer.delivery_completed.connect(func(_resource: StringName,amount: int): delivered+=amount)
		var stayed_open := true
		for step in range(8000):
			farmer.advance(.05)
			stayed_open = stayed_open and not grid.is_solid(grid.world_to_cell(farmer.position))
			if delivered>0:
				print("METRIC: %s往返=%.2fs 路径长度=%.1f" % [site.name,(step+1)*.05,_length(start,outward)+_length(outward[-1],home)])
				break
		check(delivered==2 and stayed_open,"%s真实农民完整交付且未穿阻挡" % site.name)
		farmer.free()
		if site.site_type==&"forest":
			site.occupied_building.apply_enemy_attack(99999,&"wolf")
			check(site.art_visual.visible and not site.is_occupied(),"%s销毁后恢复树林及空闲点" % site.name)
	for stair in Definition.navigation_data().stairs:
		var points: Array = stair.points
		var a: Vector2 = Definition.source_to_world(Vector2(points[0][0],points[0][1]))
		var b: Vector2 = Definition.source_to_world(Vector2(points[-1][0],points[-1][1]))
		var path: PackedVector2Array = finder.find_path(a,b)
		check(not path.is_empty() and _legal(grid,grid.cell_center(grid.world_to_cell(path[0])),path),"石阶上下通行：%s" % [points])
		var has_ramp := false
		for p in path: has_ramp = has_ramp or grid.navigation_data(grid.world_to_cell(p)).stair == int(stair.id)
		check(has_ramp,"路径实际经过对应石阶格")
	for terrain in [&"cliff",&"water",&"ramp"]:
		var cells: Array[Vector2i] = grid.cells_of_type(terrain)
		check(not cells.is_empty(),"地图存在%s" % terrain)
		var policy := true
		for cell in cells:
			var data: Dictionary = grid.cell_data(cell)
			policy = policy and not data.buildable and data.walkable == (terrain==&"ramp")
		check(policy,"%s通行/建造规则正确" % terrain)
	for sample in [[500,250],[905,54],[1320,210]]:
		var point: Vector2 = grid.snap_footprint_center(Definition.source_to_world(Vector2(sample[0],sample[1])),Vector2i(2,2))
		var card = preload("res://src/data/cards/farm.tres")
		var id: int = main.run_card_inventory.add_card(card,1)
		check(main._try_place_map_building_card(id,point),"平原/山台实际建造：%s" % [sample])
	for terrain in [&"cliff",&"water",&"ramp"]:
		var point: Vector2 = grid.cell_center(grid.cells_of_type(terrain)[0])
		var card = preload("res://src/data/cards/farm.tres")
		var id: int = main.run_card_inventory.add_card(card,1)
		var wood: int = RunEconomy.amount(&"wood")
		check(not main._try_place_map_building_card(id,point) and main.run_card_inventory.has_card(id) and RunEconomy.amount(&"wood")==wood,"%s失败保卡保材料" % terrain)
	var navigation: Control = main.get_node("HUD/MapNavigation")
	main.map_camera.show_full_map()
	var fit: float = minf(main.map_view_rect().size.x/Definition.BOUNDS.size.x,main.map_view_rect().size.y/Definition.BOUNDS.size.y)
	check(is_equal_approx(main.map_camera.zoom.x,fit),"全图倍率按上下栏之间的可用视口适配")
	navigation.focus_minimap(Vector2(115,30))
	check(main.map_camera.position.distance_to(Definition.CITY_POSITION)>100 and is_equal_approx(main.map_camera.zoom.x,.72),"点击小地图定位并进入可操作近景")
	main.map_camera.reset_view()
	var screen := Vector2(420,250)
	var before: Vector2 = main.map_camera.screen_to_world(screen)
	main.map_camera.zoom_at(1.2,screen)
	check(main.map_camera.screen_to_world(screen).distance_to(before)<.01,"大地图缩放锚点保持世界落点")
	var began := Time.get_ticks_usec()
	var pressure_ok := true
	for index in range(50):
		var path: PackedVector2Array = finder.find_path(start,grid.resource_site_center(&"iron_01"),60)
		pressure_ok = pressure_ok and not path.is_empty()
	print("METRIC: 50次暖缓存寻路=%.2fms" % ((Time.get_ticks_usec()-began)/1000.0))
	check(pressure_ok,"50单位共享寻路请求全部成功")
	for spawn in Definition.SPAWN_POINTS:
		var resolved: Vector2 = finder.spawn_position(spawn)
		check(not grid.is_solid(grid.world_to_cell(resolved)) and not finder.find_path(resolved,Definition.CITY_POSITION,96).is_empty(),"出生入口合法脚点到主城可达：%s" % spawn)
	main._on_reset_pressed()
	check(main.resource_sites.all(func(site):return not site.is_occupied() and site.art_visual.visible),"重开释放8资源并恢复树林")
	check(is_equal_approx(main.map_camera.zoom.x,.72),"重开恢复主城近景")
	main.queue_free()
	get_tree().quit(failures)

func _legal(grid: RefCounted,start: Vector2,path: PackedVector2Array) -> bool:
	var last: Vector2i = grid.world_to_cell(start)
	for point in path:
		var cell: Vector2i = grid.world_to_cell(point)
		if grid.is_solid(cell): return false
		if cell != last and not grid.can_step(last,cell): return false
		last=cell
	return true

func _length(start: Vector2,path: PackedVector2Array) -> float:
	var length := 0.0
	for point in path:
		length+=start.distance_to(point)
		start=point
	return length

func check(condition: bool,label: String) -> void:
	if condition: print("PASS: "+label)
	else:
		failures+=1
		print("FAIL: "+label)
