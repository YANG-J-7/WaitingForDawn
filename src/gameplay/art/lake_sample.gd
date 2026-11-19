extends Node2D
## 独立湖岸样区，使用生成原稿与后处理控制图，不修改正式地图或通行。
const SIZE := Vector2(1920,1080)
const ORIGIN := Vector2(-200,150)
const SHORE_SIZE := Vector2(1724,477)
const SHORE_SCALE := 1.35
const PERIOD := 12.0
var elapsed := 0.0
var paused := false
var waves_enabled := true
var foam_enabled := true
var moon_enabled := true
var water_material: ShaderMaterial
var shore_material: ShaderMaterial
var foam_material: ShaderMaterial
var water_root: Node2D
var foam: Sprite2D
var shore: Sprite2D
var layout: Dictionary
var splashes: Array[Sprite2D]=[]
var splash_sites: Array=[]

func _ready() -> void:
	layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/lake_shore_v1/runtime/layout.json"))
	water_material=ShaderMaterial.new()
	water_material.shader=preload("res://src/gameplay/art/lake_water.gdshader")
	water_material.set_shader_parameter("water_texture",preload("res://assets/map/lake_shore_v1/runtime/water-periodic.png"))
	water_material.set_shader_parameter("contact_texture",preload("res://assets/map/lake_shore_v1/runtime/contact.png"))
	water_material.set_shader_parameter("rock_only",preload("res://assets/map/lake_shore_v1/runtime/rock-only.png"))
	water_material.set_shader_parameter("shore_origin",ORIGIN)
	water_material.set_shader_parameter("shore_size",SHORE_SIZE*SHORE_SCALE)
	water_root=Node2D.new()
	add_child(water_root)
	build_water(true)
	var land := Polygon2D.new()
	var points := PackedVector2Array([Vector2(-500,0),Vector2(2500,0),Vector2(2500,ORIGIN.y+(245-35)*SHORE_SCALE)])
	var contact: Array=layout.contact_line
	for i in range(contact.size()-1,-1,-1):
		points.append(ORIGIN+Vector2(float(contact[i][0]),float(contact[i][1])-35.0)*SHORE_SCALE)
	points.append(Vector2(-500,ORIGIN.y+(245-35)*SHORE_SCALE))
	land.polygon=points
	var grass := ShaderMaterial.new()
	grass.shader=preload("res://src/gameplay/art/grass_map.gdshader")
	grass.set_shader_parameter("grass_texture",preload("res://assets/map/grass_variants_v1/grass.png"))
	# 与当前正式地表保持同一草叶密度。
	grass.set_shader_parameter("detail_world_size",Vector2.ONE*360.0)
	land.material=grass
	add_child(land)
	shore=Sprite2D.new()
	shore.centered=false
	shore.position=ORIGIN
	shore.scale=Vector2.ONE*SHORE_SCALE
	shore.texture=preload("res://assets/map/lake_shore_v1/runtime/shore.png")
	shore_material=ShaderMaterial.new()
	shore_material.shader=preload("res://src/gameplay/art/lake_shore.gdshader")
	shore_material.set_shader_parameter("shore_control",preload("res://assets/map/lake_shore_v1/runtime/shore-control.png"))
	shore_material.set_shader_parameter("water_only",preload("res://assets/map/lake_shore_v1/runtime/water-only.png"))
	shore_material.set_shader_parameter("ripple_texture",preload("res://assets/map/lake_shore_v1/runtime/water-periodic.png"))
	shore.material=shore_material
	add_child(shore)
	foam=Sprite2D.new()
	foam.centered=false
	foam.position=ORIGIN
	foam.scale=Vector2.ONE*SHORE_SCALE
	foam.texture=preload("res://assets/map/lake_shore_v1/runtime/foam-source.png")
	foam_material=ShaderMaterial.new()
	foam_material.shader=preload("res://src/gameplay/art/lake_foam.gdshader")
	foam_material.set_shader_parameter("water_only",preload("res://assets/map/lake_shore_v1/runtime/water-only.png"))
	foam_material.set_shader_parameter("rock_only",preload("res://assets/map/lake_shore_v1/runtime/rock-only.png"))
	foam.material=foam_material
	add_child(foam)
	_build_splashes()
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	apply_time()

func _build_splashes() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/fx/shore_splash_v1/sites.json"))
	var playback: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/fx/shore_splash_v1/playback-60fps.json"))
	splash_sites=data.sites
	for site: Dictionary in splash_sites:
		var effect:=Sprite2D.new()
		effect.name=site.id
		effect.texture=preload("res://assets/fx/shore_splash_v1/splash-atlas.png")
		# 一个1024×768图集映射到固定样点四边形，帧寻址由材质完成。
		var dimensions:=Vector2(float(site.size[0]),float(site.size[1]))
		effect.scale=dimensions/effect.texture.get_size()
		var anchor:=Vector2(float(site.anchor[0]),float(site.anchor[1]))
		effect.position=anchor+Vector2(0.0,(0.5-190.0/256.0)*dimensions.y)
		effect.set_meta("contact_anchor",anchor)
		var fx_material:=ShaderMaterial.new()
		fx_material.shader=preload("res://src/gameplay/art/shore_splash.gdshader")
		fx_material.set_shader_parameter("splash_texture",effect.texture)
		fx_material.set_shader_parameter("playback_fps",float(playback.fps))
		effect.set_meta("playback_frames",int(playback.clips[site.id].frame_count))
		for key in ["cycle","active_duration","phase_offset","intensity","water_floor"]:
			fx_material.set_shader_parameter(key,float(site[key]))
		effect.material=fx_material
		add_child(effect)
		splashes.append(effect)

func build_water(split: bool) -> void:
	for child in water_root.get_children():
		water_root.remove_child(child)
		child.queue_free()
	var count := 2 if split else 1
	for row in count:
		for col in count:
			var rect := Rect2(Vector2(col,row)*SIZE/float(count),SIZE/float(count))
			var part := Polygon2D.new()
			part.polygon=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
			part.material=water_material
			water_root.add_child(part)

func _process(delta: float) -> void:
	if not paused:
		elapsed=fposmod(elapsed+delta,PERIOD)
		apply_time()

func apply_time() -> void:
	water_material.set_shader_parameter("elapsed",elapsed)
	water_material.set_shader_parameter("waves_enabled",waves_enabled)
	water_material.set_shader_parameter("moon_enabled",moon_enabled)
	shore_material.set_shader_parameter("foam_enabled",foam_enabled)
	shore_material.set_shader_parameter("elapsed",elapsed)
	shore_material.set_shader_parameter("waves_enabled",waves_enabled)
	foam_material.set_shader_parameter("elapsed",elapsed)
	foam.visible=foam_enabled
	for effect: Sprite2D in splashes:
		effect.visible=foam_enabled
		effect.material.set_shader_parameter("elapsed",elapsed)

func reset() -> void:
	elapsed=0.0
	apply_time()

func set_stage(stage: int) -> void:
	foam_enabled=stage>=1
	waves_enabled=stage>=2
	moon_enabled=stage>=3
	apply_time()
