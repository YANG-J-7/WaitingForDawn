extends Node
## 用独立Dijkstra距离核对分叉选路，而非检查一条预先指定的整圈路线。
const Definition = preload("res://src/gameplay/grid/map_definition.gd")
const Grid = preload("res://src/gameplay/grid/grid_map_model.gd")
const Finder = preload("res://src/gameplay/grid/grid_pathfinder.gd")
var failures := 0

func _ready() -> void:
	var main := preload("res://src/main/main.tscn").instantiate()
	add_child(main)
	main._on_start_pressed()
	main.opening_draft.active = false
	main.wave_controller.set_process(false)
	main.farmer_manager.set_process(false)
	var grid: RefCounted = main.grid_map_model
	var finder: RefCounted = main.grid_pathfinder
	var junction: Array = Definition.navigation_data().junctions[0].point
	var start: Vector2 = grid.cell_center(grid.world_to_cell(Definition.source_to_world(Vector2(junction[0],junction[1]))))
	check(grid.is_walkable(grid.world_to_cell(start)) and grid.navigation_data(grid.world_to_cell(start)).level == 1,"红圈分叉为同层可通行路口")
	var distances := _distances(grid,grid.world_to_cell(start))
	var goals := [
		["北侧高台",Definition.source_to_world(Vector2(1120,31)),0.0,2,4],
		["东南侧石矿",grid.resource_site_center(&"stone_02"),60.0,-1,2],
		["东南山路",Definition.source_to_world(Vector2(1200,327)),0.0,-1,2],
		["西侧铁矿",grid.resource_site_center(&"iron_02"),60.0,-1,2],
	]
	for goal in goals:
		var route: PackedVector2Array = finder.find_path(start,goal[1],goal[2])
		check(not route.is_empty(),"分叉可达目的地："+goal[0])
		if route.is_empty(): continue
		check(_legal(grid,start,route),"分叉选路不穿岩壁或跨层："+goal[0])
		var optimum := _best_distance(grid,distances,goal[1],goal[2])
		var actual := _cost(grid,start,route)
		check(absf(actual-optimum)<.01,"根据目的地选择最短合法行走路线："+goal[0])
		check((goal[3]<0 or _uses_stair(grid,route,goal[3])) and not _uses_stair(grid,route,goal[4]),"选择对应支路，避免无关石梯绕圈："+goal[0])
		print("METRIC: 分叉到%s 实际代价=%.2f 最短代价=%.2f" % [goal[0],actual,optimum])
	var north: Vector2 = Definition.source_to_world(Vector2(1120,31))
	var before: PackedVector2Array = finder.find_path(start,north)
	var before_cost := _cost(grid,start,before)
	var stairs: Array[Vector2i] = []
	for entry in Definition.navigation_data().cells:
		if int(entry.stair)==2: stairs.append(Vector2i(entry.cell[0],entry.cell[1]))
	grid.set_terrain_cells(stairs,&"cliff",false,false,INF)
	var detour: PackedVector2Array = finder.find_path(start,north)
	check(not detour.is_empty() and _uses_stair(grid,detour,4) and not _uses_stair(grid,detour,2),"北侧近路封闭后改走东南支路，经其他石梯绕行")
	check(not detour.is_empty() and _cost(grid,start,detour)>before_cost,"封路后的绕行长度大于原近路")
	grid.set_terrain_cells(stairs,&"ramp",true,false,1)
	var reopened: PackedVector2Array = finder.find_path(start,north)
	check(_uses_stair(grid,reopened,2) and not _uses_stair(grid,reopened,4),"近路恢复后清除旧路径缓存，重新选择北侧支路")
	_test_interaction_distance()
	main.queue_free()
	get_tree().quit(failures)

func _test_interaction_distance() -> void:
	var grid = Grid.new()
	grid.set_terrain_rect(Definition.BOUNDS,&"mountain_grass",false,true,INF)
	var open: Array[Vector2i] = []
	for i in range(3):
		for dx in range(2):
			for dy in range(2):
				var cell := Vector2i(4+i+dx,4+i+dy)
				if cell not in open: open.append(cell)
	for x in range(4,9):
		var cell := Vector2i(x,4)
		if cell not in open: open.append(cell)
	grid.set_terrain_cells(open,&"road",true,true,1)
	var finder = Finder.new(grid)
	var start: Vector2 = grid.cell_center(Vector2i(4,4))
	var target: Vector2 = grid.cell_center(Vector2i(12,9))
	var route: PackedVector2Array = finder.find_path(start,target,232)
	check(not route.is_empty(),"多外围入口夹具存在合法路线")
	var optimum := _best_distance(grid,_distances(grid,Vector2i(4,4)),target,232)
	check(not route.is_empty() and absf(_cost(grid,start,route)-optimum)<.01,"外围入口按实际步行距离选取，不能因点数或目标中心偏好走远路")
	check(not route.is_empty() and route[-1]!=grid.cell_center(Vector2i(7,7)),"拒绝原先偏好更靠近目标中心但行走更远的入口")

func _distances(grid: RefCounted,start: Vector2i) -> Dictionary:
	var result := {start:0.0}
	var heap: Array = [[0.0,start]]
	while not heap.is_empty():
		var item := _pop(heap)
		var cell: Vector2i = item[1]
		if item[0]>float(result[cell])+.001: continue
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
			var next: Vector2i = cell+offset
			if not grid.can_step(cell,next): continue
			var cost: float = item[0]+Vector2(offset).length()*36*maxf(1,float(grid.cell_data(next).movement_cost))
			if cost<float(result.get(next,INF)):
				result[next]=cost
				_push(heap,[cost,next])
	return result

func _push(heap: Array,item: Array) -> void:
	heap.append(item)
	var i := heap.size()-1
	while i>0:
		var parent := (i-1)/2
		if heap[parent][0]<=heap[i][0]: break
		var hold: Array = heap[parent]
		heap[parent]=heap[i]; heap[i]=hold
		i=parent

func _pop(heap: Array) -> Array:
	var result: Array = heap[0]
	var tail: Array = heap.pop_back()
	if heap.is_empty(): return result
	heap[0]=tail
	var i := 0
	while i*2+1<heap.size():
		var child := i*2+1
		if child+1<heap.size() and heap[child+1][0]<heap[child][0]: child+=1
		if heap[i][0]<=heap[child][0]: break
		var hold: Array = heap[i]
		heap[i]=heap[child]; heap[child]=hold
		i=child
	return result

func _best_distance(grid: RefCounted,distances: Dictionary,target: Vector2,radius: float) -> float:
	if radius<=0: return float(distances.get(grid.world_to_cell(target),INF))
	var result := INF
	for cell: Vector2i in distances:
		var point: Vector2 = grid.cell_center(cell)
		if point.distance_to(target)<=radius and grid.interaction_clear(point,target): result=minf(result,float(distances[cell]))
	return result

func _cost(grid: RefCounted,start: Vector2,path: PackedVector2Array) -> float:
	var result := 0.0
	for point in path:
		result+=start.distance_to(point)*maxf(1,float(grid.cell_data(grid.world_to_cell(point)).movement_cost))
		start=point
	return result

func _uses_stair(grid: RefCounted,path: PackedVector2Array,id: int) -> bool:
	for point in path:
		if grid.navigation_data(grid.world_to_cell(point)).stair==id: return true
	return false

func _legal(grid: RefCounted,start: Vector2,path: PackedVector2Array) -> bool:
	var last: Vector2i = grid.world_to_cell(start)
	for point in path:
		var cell: Vector2i = grid.world_to_cell(point)
		if grid.is_solid(cell) or (last!=cell and not grid.can_step(last,cell)): return false
		last=cell
	return true

func check(condition: bool,label: String) -> void:
	if condition: print("PASS: "+label)
	else:
		failures+=1
		push_error("FAIL: "+label)
