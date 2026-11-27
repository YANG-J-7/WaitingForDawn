class_name TownHallAppearance
extends Resource
## 主城原画、受光遮罩及以原画像素为单位的接影与高度数据。

@export var display_name: String
@export var body: Texture2D
@export var face_mask: Texture2D
@export var hearth_mask: Texture2D
@export var width: float
@export var origin: Vector2
@export var footprints: Array[PackedVector2Array]
@export var solids: Array[PackedVector3Array]
@export var shadow_slope := Vector3(0.70, 0.32, 0.54)
