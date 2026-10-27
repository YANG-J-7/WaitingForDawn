class_name LevelDefinition
extends Resource
## 只读关卡源配置；占用、单位和编译缓存属于各自运行实例。
@export var level_id: StringName = &"level_001"
@export var revision: int = 1
@export var display_name: String = "月湖山谷"
@export var world_size := Vector2i(7056,2880)
@export var cell_size: int = 36
@export var city_position := Vector2(4176,1908)
@export var assembly: PackedScene
@export var source_size := Vector2(1672,941)
@export var source_world_size := Vector2(4608,2592)
@export var source_world_origin := Vector2(2448,288)
