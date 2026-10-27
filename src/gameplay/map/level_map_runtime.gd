class_name LevelMapRuntime
extends RefCounted
## 关卡上下文实例化、局部坐标编译与兼容数据出口；没有全局可写缓存。
const DEFAULT_LEVEL := "res://src/levels/level_001.tres"
var definition: Resource
var bounds := Rect2()
var grid_size := Vector2i.ZERO
var city_position := Vector2.ZERO
var modules: Array[Dictionary] = []
var compiled: Dictionary = {}
var navigation: Dictionary = {}
var errors: Array[String] = []
var spawn_points: Array[Vector2] = []

static func create_default() -> LevelMapRuntime:
	return from_definition(load(DEFAULT_LEVEL))

static func from_definition(source: Resource) -> LevelMapRuntime:
	var scene = source.assembly.instantiate()
	var result := from_assembly(source,scene)
	scene.free()
	return result

static func from_assembly(source: Resource, scene: Node2D) -> LevelMapRuntime:
	var result := LevelMapRuntime.new()
	result.definition = source
	result.bounds = Rect2(Vector2.ZERO,Vector2(source.world_size))
	result.grid_size = source.world_size / source.cell_size
	result.city_position = source.city_position
	result.compiled = {"worldSize":[float(source.world_size.x),float(source.world_size.y)], "gridSize":[float(result.grid_size.x),float(result.grid_size.y)], "cellSize":source.cell_size, "city":[source.city_position.x,source.city_position.y], "resourceSites":[], "cells":{}, "spawns":[]}
	result.navigation = {"cells":[],"mountainCells":[],"cliffCells":[],"routes":[],"stairs":[]}
	var identities := {}
	for child in scene.get_children():
		if not child is Node2D or child.get("definition") == null: continue
		var component: Resource = child.definition
		var offset_cell := Vector2i(roundi(child.position.x/source.cell_size),roundi(child.position.y/source.cell_size))
		if not child.position.is_equal_approx(Vector2(offset_cell)*source.cell_size) or not child.scale.is_equal_approx(Vector2.ONE) or not is_zero_approx(child.rotation):
			result.errors.append("组件%s必须按格平移，禁止缩放旋转" % child.name)
		if identities.has(child.name): result.errors.append("组件实例ID重复：%s" % child.name)
		identities[child.name] = true
		var payload: Dictionary = component.payload()
		if payload.is_empty() and component.role != "ground": result.errors.append("组件%s缺少数据" % child.name)
		result.modules.append({"instance_id":String(child.name),"module_id":String(component.module_id),"role":component.role,"origin":child.position,"payload":payload,"definition":component})
		for kind in payload.get("terrain",{}):
			var cells: Array = result.compiled.cells.get(kind,[])
			for cell in payload.terrain[kind]: cells.append([float(cell[0])+offset_cell.x,float(cell[1])+offset_cell.y])
			result.compiled.cells[kind] = cells
		for key in ["mountainCells","cliffCells"]:
			for cell in payload.get("navigation",{}).get(key,[]): result.navigation[key].append([float(cell[0])+offset_cell.x,float(cell[1])+offset_cell.y])
		for entry in payload.get("navigation",{}).get("cells",[]):
			var moved: Dictionary = entry.duplicate(true)
			moved.cell = [float(entry.cell[0])+offset_cell.x,float(entry.cell[1])+offset_cell.y]
			result.navigation.cells.append(moved)
		for key in ["routes","stairs"]:
			result.navigation[key].append_array(payload.get("navigation",{}).get(key,[]).duplicate(true))
		for entry in payload.get("resource_sites",[]):
			var moved: Dictionary = entry.duplicate(true)
			moved.position.x += child.position.x
			moved.position.y += child.position.y
			result.compiled.resourceSites.append(moved)
		for point in payload.get("spawn_points",[]):
			var world: Vector2 = Vector2(point[0],point[1])+child.position
			result.spawn_points.append(world)
			result.compiled.spawns.append([world.x,world.y])
	for key in ["cliff","water","forest","boundary","road","ramp"]:
		if not result.compiled.cells.has(key): result.compiled.cells[key] = []
	# 格越界和同类型重复会破坏编译，加载阶段明确拒绝。
	for kind in result.compiled.cells:
		var seen := {}
		for pair in result.compiled.cells[kind]:
			var cell := Vector2i(pair[0],pair[1])
			if cell.x<0 or cell.y<0 or cell.x>=result.grid_size.x or cell.y>=result.grid_size.y: result.errors.append("%s格超出关卡：%s" % [kind,cell])
			if seen.has(cell): result.errors.append("%s格重复：%s" % [kind,cell])
			seen[cell]=true
	return result

func resource_sites() -> Array:
	var sites: Array = compiled.resourceSites.duplicate(true)
	for module in modules:
		for visual in module.payload.get("forest_visuals",[]):
			for site in sites:
				if site.id != visual.id: continue
				site.sprite = visual.path
				var rect: Array = visual.rect
				site.worldRect = [rect[0]+module.origin.x,rect[1]+module.origin.y,rect[2],rect[3]]
	return sites

func is_water_point(point: Vector2) -> bool:
	for module in modules:
		if module.role != "lake": continue
		var local: Vector2 = point-module.origin
		var in_water := false
		for polygon in module.payload.get("water_polygons",[]):
			if Geometry2D.is_point_in_polygon(local,_points(polygon)): in_water = true
		for polygon in module.payload.get("island_polygons",[]):
			if Geometry2D.is_point_in_polygon(local,_points(polygon)): in_water = false
		if in_water: return true
	return false

static func _points(pairs: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for pair in pairs: result.append(Vector2(pair[0],pair[1]))
	return result
