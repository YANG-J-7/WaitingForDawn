extends Node2D
## 独立沙滩样区，原地图草地同坐标采样；不改正式岩岸。
const SIZE=Vector2(1920,720)
var elapsed:=0.0
var paused:=false
var animated:=true
var grass: Polygon2D
var materials: Array[ShaderMaterial]=[]
var layers: Array[Polygon2D]=[]
func _ready() -> void:
	grass=_quad("Grass",null)
	var ground:=ShaderMaterial.new()
	ground.shader=preload("res://src/gameplay/art/grass_map.gdshader")
	ground.set_shader_parameter("grass_texture",preload("res://assets/map/grass_variants_v1/grass.png"))
	ground.set_shader_parameter("detail_world_size",Vector2.ONE*360.0)
	grass.material=ground
	for kind in ["water","sand","foam"]:
		var material:=ShaderMaterial.new()
		material.shader=load("res://src/gameplay/art/beach_"+kind+".gdshader")
		if kind=="water": material.set_shader_parameter("water_texture",preload("res://assets/map/lake_shore_v1/runtime/water-periodic.png"))
		if kind=="sand":
			material.set_shader_parameter("sand_texture",preload("res://assets/map/beach_v1/sand.png"))
			material.set_shader_parameter("grass_contact",preload("res://assets/map/beach_v1/grass-contact.png"))
			material.set_shader_parameter("grass_detail",preload("res://assets/map/grass_variants_v1/grass.png"))
		if kind=="foam": material.set_shader_parameter("foam_texture",preload("res://assets/map/beach_v1/foam.png"))
		materials.append(material)
		layers.append(_quad(kind,material))
	apply_time()
func _quad(label: String,material: Material) -> Polygon2D:
	var quad:=Polygon2D.new()
	quad.name=label
	quad.polygon=PackedVector2Array([Vector2.ZERO,Vector2(SIZE.x,0),SIZE,Vector2(0,SIZE.y)])
	quad.material=material
	add_child(quad)
	return quad
func _process(delta: float) -> void:
	if not paused:
		elapsed=fposmod(elapsed+delta,12.0)
		apply_time()
func apply_time() -> void:
	for material in materials:
		material.set_shader_parameter("elapsed",elapsed)
		material.set_shader_parameter("animated",animated)
func reset() -> void:
	elapsed=0.0
	apply_time()
