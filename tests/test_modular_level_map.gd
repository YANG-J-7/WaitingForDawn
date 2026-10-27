extends Node
## 新运行器必须保持旧关卡的玩法事实，并支持独立实例与组件平移。
var failures := 0

func _ready() -> void:
	var runtime_script = load("res://src/gameplay/map/level_map_runtime.gd")
	check(runtime_script != null, "存在独立关卡运行上下文")
	if runtime_script == null:
		get_tree().quit(failures)
		return
	var first = runtime_script.create_default()
	var second = runtime_script.create_default()
	check(first != second, "两次加载产生不同运行实例")
	check(first.errors.is_empty(), "第一关全部组件与连接校验通过")
	check(first.modules.size() >= 5, "地表、山地、湖、森林边界和标记分别装配")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/dawn_wide_v3/map.json"))
	var nav: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/dawn_wide_v3/mountain-navigation.json"))
	check(first.bounds == Rect2(0,0,7056,2880) and first.grid_size == Vector2i(196,80), "原世界与36单位网格保持")
	check(first.compiled.resourceSites == old.resourceSites, "八个资源ID、位置和类型完整保持")
	check(first.navigation.cells == nav.cells and first.navigation.stairs == nav.stairs, "547个通行格及八梯元数据不变")
	for kind in old.cells:
		check(first.compiled.cells[kind] == old.cells[kind], "地形组件编译保持旧%s格" % kind)
	first.compiled.cells.water.clear()
	check(not second.compiled.cells.water.is_empty(), "运行数据更改不污染另一关实例")
	var source = load("res://src/levels/level_001.tres")
	var scene = source.assembly.instantiate()
	var lake = scene.get_node("Lake")
	var local_water: Array = lake.definition.payload().terrain.water.duplicate(true)
	lake.position += Vector2(-4032,0)
	var shifted = runtime_script.from_assembly(source,scene)
	check(shifted.compiled.cells.water[0] == [old.cells.water[0][0]-112,old.cells.water[0][1]], "湖组件平移后碰撞格跟随移动112格")
	check(lake.definition.payload().terrain.water == local_water, "平移不会改共享组件资源")
	scene.free()
	var invalid = source.assembly.instantiate()
	invalid.get_node("Lake").position.x += 1
	var rejected = runtime_script.from_assembly(source,invalid)
	check(not rejected.errors.is_empty(), "未对齐36格的结构组件拒绝编译")
	invalid.free()
	get_tree().quit(failures)

func check(condition: bool, label: String) -> void:
	if condition: print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
