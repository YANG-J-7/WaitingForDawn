class_name WorldLightingProfile
extends Resource
## 光照风格与地图坐标无关；共享配置只读，运行状态由控制器保存。
@export var night_ambient := Color(0.54, 0.64, 0.82)
@export var dawn_ambient := Color(1.0, 0.97, 0.89)
@export var shadow_direction := Vector2(0.82, 0.57)
@export var night_sky_color := Color(0.52, 0.71, 1.0)
@export var dawn_sky_color := Color(1.0, 0.82, 0.53)
@export_range(0.0, 1.0) var night_sky_energy: float = 0.22
@export_range(0.0, 1.0) var dawn_sky_energy: float = 0.32
## 默认关闭地图上的所有投影和接触影，专项工具可单独启用。
@export var shadows_enabled := false
## 只在总开关启用时控制单位与建筑影。
@export var entity_shadows_enabled := false
@export_range(0.0, 0.5) var terrain_shadow_opacity: float = 0.24
@export_range(0.0, 180.0) var terrain_shadow_reach: float = 96.0
@export_range(0.05, 1.5) var shadow_length: float = 0.58
@export_range(0.0, 1.0) var shadow_opacity: float = 0.48
@export_range(0.0, 1.0) var actor_shadow_opacity: float = 0.82
@export_range(0.0, 1.0) var contact_opacity: float = 0.84
@export var shadow_color := Color(0.012, 0.021, 0.040)
## 普通地面、岩壁、水域的局部光响应，1.0为原生受光强度。
@export var terrain_local_response := Vector3(1.0, 0.72, 0.38)
@export_range(1.0, 900.0) var dawn_duration: float = 300.0
@export_range(0, 32) var max_local_lights: int = 12
