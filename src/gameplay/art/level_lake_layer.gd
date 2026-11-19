extends Node2D
## 第一关湖泊：水域规则和表现读取同一组件；小地图仅渲染静态同源布局。
const WATER=preload("res://assets/map/lake_shore_v1/runtime/water-periodic.png")
var elapsed:=0.0
var layout: Dictionary={}
var water_material: ShaderMaterial
var shore_material: ShaderMaterial
var splashes: Array[Sprite2D]=[]
var overview_only:=false
var control_texture: Texture2D
var beach: Node2D
var beach_layout: Dictionary = {}

func configure(context: RefCounted,overview: bool) -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	overview_only=overview
	var visual_path: String=""
	for component: Dictionary in context.modules:
		if component.role=="lake": visual_path=component.payload.get("visual_layout","")
	if visual_path.is_empty():
		set_process(false)
		return
	layout=JSON.parse_string(FileAccess.get_file_as_string(visual_path))
	if layout.has("beach_layout"):
		beach_layout=JSON.parse_string(FileAccess.get_file_as_string(layout.beach_layout))
	control_texture=load(layout.get("water_control_texture","res://assets/levels/level_001/lake/water-control.png"))
	var water:=Polygon2D.new()
	water.name="LakeWater"
	var bounds: Rect2=context.visual_bounds
	water.polygon=PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
	water_material=ShaderMaterial.new()
	water_material.shader=preload("res://src/gameplay/art/map_lake_water.gdshader")
	water_material.set_shader_parameter("water_texture",WATER)
	water_material.set_shader_parameter("water_control",control_texture)
	water_material.set_shader_parameter("world_size",context.bounds.size)
	if bounds != context.bounds and not beach_layout.is_empty():
		var patch: Dictionary = beach_layout.patches[0]
		var field: Array = patch.rect
		water_material.set_shader_parameter("extend_boundary",true)
		water_material.set_shader_parameter("coast_field",load(patch.field))
		water_material.set_shader_parameter("field_rect",Vector4(field[0],field[1],field[2],field[3]))
		water_material.set_shader_parameter("north_coast_x",float(patch.coast_points[0][0]))
	water_material.set_shader_parameter("animated",not overview)
	water.material=water_material
	add_child(water)
	var shore:=Sprite2D.new()
	shore.name="RockShore"
	shore.centered=false
	shore.position=Vector2(float(layout.shore_origin[0]),float(layout.shore_origin[1]))
	shore.texture=load(layout.get("shore_texture","res://assets/levels/level_001/lake/shore-overlay.png"))
	shore.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shore_material=ShaderMaterial.new()
	shore_material.shader=preload("res://src/gameplay/art/map_lake_shore.gdshader")
	shore_material.set_shader_parameter("water_only",preload("res://assets/levels/level_001/lake/shore-water-only.png"))
	shore_material.set_shader_parameter("ripple_texture",WATER)
	shore_material.set_shader_parameter("animated",not overview)
	if not beach_layout.is_empty():
		shore_material.set_shader_parameter("beach_enabled",true)
		shore_material.set_shader_parameter("beach_cutout",load(beach_layout.rock_cutout))
	shore.material=shore_material
	shore.visible=not beach_layout.get("replace_all_rock_shore",false)
	add_child(shore)
	if not beach_layout.is_empty():
		beach=preload("res://src/gameplay/art/level_beach_layer.gd").new()
		beach.name="Beach"
		add_child(beach)
		beach.configure(layout.beach_layout,overview)
		for material: ShaderMaterial in beach.materials:
			material.set_shader_parameter("render_min",bounds.position)
			material.set_shader_parameter("render_max",bounds.end)
	if not overview:
		_build_splashes()
	set_process(not overview)
	apply_time()

func _build_splashes() -> void:
	for site: Dictionary in layout.splash_sites:
		if site.id in beach_layout.get("disabled_splashes",[]): continue
		var effect:=Sprite2D.new()
		effect.name=site.id
		effect.texture=preload("res://assets/fx/shore_splash_v1/splash-atlas.png")
		var dimensions:=Vector2(float(site.size[0]),float(site.size[1]))
		effect.scale=dimensions/effect.texture.get_size()
		var anchor:=Vector2(float(site.anchor[0]),float(site.anchor[1]))
		effect.position=anchor+Vector2(0,(0.5-190.0/256.0)*dimensions.y)
		effect.set_meta("contact_anchor",anchor)
		var fx:=ShaderMaterial.new()
		fx.shader=preload("res://src/gameplay/art/shore_splash.gdshader")
		fx.set_shader_parameter("splash_texture",effect.texture)
		fx.set_shader_parameter("water_mask_enabled",true)
		fx.set_shader_parameter("world_water_control",control_texture)
		fx.set_shader_parameter("world_size",Vector2(7056,2880))
		fx.set_shader_parameter("water_floor",-1000.0)
		for key in ["cycle","active_duration","phase_offset","intensity"]:
			fx.set_shader_parameter(key,float(site[key]))
		effect.material=fx
		add_child(effect)
		splashes.append(effect)

func _process(delta: float) -> void:
	if overview_only or get_tree().paused: return
	elapsed=fposmod(elapsed+delta,12.0)
	apply_time()

func apply_time() -> void:
	if water_material==null: return
	water_material.set_shader_parameter("elapsed",elapsed)
	shore_material.set_shader_parameter("elapsed",elapsed)
	if beach!=null: beach.apply_time(elapsed)
	for effect: Sprite2D in splashes:
		effect.material.set_shader_parameter("elapsed",elapsed)

func reset() -> void:
	elapsed=0.0
	apply_time()
