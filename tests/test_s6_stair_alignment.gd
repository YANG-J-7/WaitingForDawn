extends Node
## 对照可见石梯的踏面、平台与侧墙校核S6，避免仅验证自定义格数据。
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
const MAIN = preload("res://src/main/main.tscn")
const LOWER_FLIGHT := Rect2(1133,434,37,30)
const UPPER_FLIGHT := Rect2(1198,382,30,35)
const LANDING := Rect2(1171,418,28,18)
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
	var grid: RefCounted = main.grid_map_model
	var finder: RefCounted = main.grid_pathfinder
	var low: Vector2 = grid.cell_center(grid.world_to_cell(Definition.source_to_world(Vector2(1105,485))))
	var high: Vector2 = grid.cell_center(grid.world_to_cell(Definition.source_to_world(Vector2(1200,327))))
	for point in [Vector2(1168,386),Vector2(1176,402),Vector2(1237,405)]:
		var world: Vector2 = Definition.source_to_world(point)
		var cell: Vector2i = grid.world_to_cell(world)
		check(grid.is_solid(cell) and grid.cell_data(cell).terrain_type==&"cliff" and not grid.can_place(grid.cell_center(cell),Vector2i.ONE),"S6旧斜穿通路及两侧岩壁禁行禁建：%s" % point)
	var upward: PackedVector2Array = finder.find_path(low,high)
	var downward: PackedVector2Array = finder.find_path(high,low)
	check(_visits(upward,LOWER_FLIGHT) and _visits(upward,LANDING) and _visits(upward,UPPER_FLIGHT),"S6上山依次经过下段踏面、中间平台及上段踏面")
	check(_visits(downward,UPPER_FLIGHT) and _visits(downward,LANDING) and _visits(downward,LOWER_FLIGHT),"S6下山经过两段石梯及平台")
	_check_follower(grid,finder,low,high,"上山")
	_check_follower(grid,finder,high,low,"下山")
	for upper in [false,true]:
		var gate: Array[Vector2i] = []
		for entry in Definition.navigation_data().cells:
			if int(entry.stair)!=6: continue
			var cell := Vector2i(entry.cell[0],entry.cell[1])
			var source: Vector2 = _source(grid.cell_center(cell))
			if (upper and source.y>=391 and source.y<=406 and source.x>1190) or (not upper and source.y>=436 and source.y<=452 and source.x<1180): gate.append(cell)
		check(not gate.is_empty(),"S6%s段有实际踏面封闭格" % ("上" if upper else "下"))
		grid.set_terrain_cells(gate,&"cliff",false,false,INF)
		var alternate: PackedVector2Array = finder.find_path(low,high)
		var uses_s6 := false
		for point in alternate: uses_s6 = uses_s6 or grid.navigation_data(grid.world_to_cell(point)).stair==6
		check(not alternate.is_empty() and not uses_s6 and _length(low,alternate)>_length(low,upward)+250,"封闭S6任一段后走其他石梯绕行，不从侧墙穿过")
		grid.set_terrain_cells(gate,&"ramp",true,false,1)
		var restored: PackedVector2Array = finder.find_path(low,high)
		check(_visits(restored,LOWER_FLIGHT) and _visits(restored,UPPER_FLIGHT) and is_equal_approx(_length(low,restored),_length(low,upward)),"S6解除封闭后恢复原双段路线及缓存")
	_check_units(main,grid,finder,low,high)
	print("METRIC: S6上山点=%d 下山点=%d 距离=%.2f/%.2f世界像素" % [upward.size(),downward.size(),_length(low,upward),_length(high,downward)])
	main.queue_free()
	RunState.reset_to_boot()
	get_tree().quit(failures)

func _source(point: Vector2) -> Vector2:
	return point/Definition.BOUNDS.size*Definition.SOURCE_SIZE

func _visits(path: PackedVector2Array,zone: Rect2) -> bool:
	for point in path:
		if zone.has_point(_source(point)): return true
	return false

func _length(start: Vector2,path: PackedVector2Array) -> float:
	var total := 0.0
	for point in path:
		total+=start.distance_to(point)
		start=point
	return total

func _check_follower(grid: RefCounted,finder: RefCounted,start: Vector2,target: Vector2,label: String) -> void:
	var follower = preload("res://src/gameplay/grid/grid_path_follower.gd").new()
	follower.set_pathfinder(finder)
	var current := start
	var trace := PackedVector2Array([start])
	var legal := true
	var arrived := false
	for step in range(1800):
		var previous: Vector2i = grid.world_to_cell(current)
		var movement: Dictionary = follower.advance(current,target,0,80,.02)
		current=movement.position
		trace.append(current)
		var cell: Vector2i = grid.world_to_cell(current)
		legal=legal and not grid.is_solid(cell) and (cell==previous or grid.can_step(previous,cell))
		for polygon in Definition.navigation_data().hardCliffs:
			legal=legal and not Geometry2D.is_point_in_polygon(current,Definition.polygon_world(polygon))
		if movement.arrived:
			arrived=true
			break
	check(arrived and legal,"S6%s连续脚点均不进入可见岩壁、侧墙或非法跨层" % label)
	check(_visits(trace,LOWER_FLIGHT) and _visits(trace,LANDING) and _visits(trace,UPPER_FLIGHT),"S6%s连续移动经过两段踏面和转弯平台" % label)

func _check_units(main: Node,grid: RefCounted,finder: RefCounted,low: Vector2,high: Vector2) -> void:
	var workplace := Node2D.new()
	main.add_child(workplace)
	workplace.position=high
	var farmer := FarmerAgent.new()
	main.add_child(farmer)
	farmer.configure(0,low)
	farmer.set_pathfinder(finder)
	farmer.position=low
	farmer.assign_job(&"s6",workplace,&"food",2)
	farmer.delivery_completed.connect(func(_id: StringName,amount: int): delivered+=amount)
	var trace := PackedVector2Array()
	var legal := true
	for step in range(4000):
		farmer.advance(.02)
		trace.append(farmer.position)
		legal=legal and not grid.is_solid(grid.world_to_cell(farmer.position))
		if delivered>0: break
	check(delivered==2 and legal and _visits(trace,LOWER_FLIGHT) and _visits(trace,UPPER_FLIGHT),"真实农民通过S6两段石梯完成采集往返交付")
	farmer.free()
	workplace.free()
	var enemy := preload("res://src/gameplay/enemies/enemy.tscn").instantiate() as EnemyActor
	main.add_child(enemy)
	enemy.configure(preload("res://src/data/enemies/wolf.tres"),high,low)
	enemy.set_pathfinder(finder)
	enemy.set_physics_process(false)
	trace.clear()
	for step in range(3000):
		enemy._physics_process(.02)
		trace.append(enemy.position)
		if enemy.has_reached_target: break
	check(enemy.has_reached_target and _visits(trace,LOWER_FLIGHT) and _visits(trace,UPPER_FLIGHT),"真实野狼下山经过S6上下两段阶梯")
	enemy.position=low
	var guard := preload("res://src/gameplay/defenses/barracks_guard.tscn").instantiate() as BarracksGuard
	main.add_child(guard)
	guard.configure(preload("res://src/data/defenses/barracks_guard.tres"),0)
	guard.position=high
	guard.set_pathfinder(finder)
	guard.set_process(false)
	guard.engage_enemy(enemy)
	trace.clear()
	for step in range(3000):
		guard._process(.02)
		trace.append(guard.position)
		if guard.position.distance_to(enemy.position)<=guard.definition.attack_range_pixels: break
	check(guard.position.distance_to(enemy.position)<=guard.definition.attack_range_pixels and _visits(trace,LOWER_FLIGHT) and _visits(trace,UPPER_FLIGHT),"真实守卫追敌经过S6上下两段阶梯")
	guard.free()
	enemy.free()

func check(condition: bool,label: String) -> void:
	if condition: print("PASS: "+label)
	else:
		failures+=1
		push_error("FAIL: "+label)
