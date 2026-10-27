@tool
extends Node2D
## 每个零件独立场景；运行渲染器通过定义读取局部数据，不访问Main路径。
@export var definition: Resource
