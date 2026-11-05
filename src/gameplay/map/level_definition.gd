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
@export var terrain_tiles: PackedScene
@export var show_resource_forests: bool = true
@export var lighting_profile: Resource = preload("res://src/gameplay/art/world_lighting_profile.gd").new()
## 可选的全图受光遮罩，红色为岩壁、绿色为水域，空缺时从关卡地形格生成。
@export var terrain_light_mask: Texture2D
@export var source_size := Vector2(1672,941)
@export var source_world_size := Vector2(4608,2592)
@export var source_world_origin := Vector2(2448,288)
