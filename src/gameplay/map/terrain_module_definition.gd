class_name TerrainModuleDefinition
extends Resource
## 组件JSON使用局部坐标，场景节点的平移同时作用于规则与表现。
@export var module_id: StringName
@export var revision: int = 1
@export_enum("ground", "mountain", "lake", "boundary", "markers") var role: String = "ground"
@export_file("*.json") var data_path: String

func payload() -> Dictionary:
	if data_path.is_empty(): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	return parsed if parsed is Dictionary else {}
