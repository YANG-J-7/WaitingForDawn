extends Node3D

const Field = preload("res://tools/moonlake_3d_level/heightfield.gd")
const Terrain = preload("res://tools/moonlake_3d_level/terrain.gd")
const Entities = preload("res://tools/moonlake_3d_level/entities.gd")
const View = preload("res://tools/moonlake_3d_level/map_camera.gd")

var game: Node2D
var field := Field.new()
var terrain := Terrain.new()
var entities := Entities.new()
var camera := Camera3D.new()
var direction := DirectionalLight3D.new()
var environment := Environment.new()
var city_lights: Array[OmniLight3D] = []
var motion_seconds := 0.0
var camera_key: Array = []
var preview_material := StandardMaterial3D.new()
var preview_tiles: Array[MeshInstance3D] = []


func configure(owner_game: Node2D) -> void:
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	field.configure(game.map_runtime, game.grid_map_model)
	add_child(terrain)
	terrain.configure(field)
	terrain.terrain_material.set_shader_parameter("town_center", game.map_runtime.city_position / field.cell_size)
	add_child(entities)
	entities.game = game
	entities.field = field
	entities.grove_mesh = terrain.forest.multimesh.mesh
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 400.0
	camera.make_current()
	var world_environment := WorldEnvironment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.environment = environment
	add_child(world_environment)
	direction.shadow_enabled = true
	direction.directional_shadow_max_distance = 185.0
	add_child(direction)
	for offset in [Vector2(-73.0, 28.0), Vector2(73.0, 28.0)]:
		var light := OmniLight3D.new()
		light.position = field.surface_position(game.map_runtime.city_position + offset) + Vector3.UP * 1.1
		light.light_color = Color("#ffc27d")
		light.omni_range = 5.2
		light.omni_attenuation = 1.25
		add_child(light)
		city_lights.append(light)
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_update_lighting(RunState.campaign_remaining_seconds())
	RunState.campaign_time_changed.connect(_update_lighting)
	sync_camera()
	entities.sync(false)


func _process(_delta: float) -> void:
	if get_tree().paused:
		sync_camera()
		entities.sync(game.map_camera.overview)


func advance(delta: float) -> void:
	motion_seconds += delta
	terrain.lake_material.set_shader_parameter("motion_time", motion_seconds)
	terrain.tree_material.set_shader_parameter("motion_time", motion_seconds)
	for i in range(city_lights.size()):
		city_lights[i].visible = RunState.city_health > 0
		city_lights[i].light_energy = 1.05 + sin(motion_seconds * 6.0 + float(i) * 1.8) * 0.12
	sync_camera()
	entities.sync(game.map_camera.overview)


func _update_lighting(remaining: float) -> void:
	if remaining >= RunState.CAMPAIGN_DURATION_SECONDS:
		motion_seconds = 0.0
	var dawn := smoothstep(0.0, 1.0, clampf(1.0 - remaining / 300.0, 0.0, 1.0))
	var progress := 1.0 - remaining / RunState.CAMPAIGN_DURATION_SECONDS
	environment.ambient_light_color = Color("#a7bfe0").lerp(Color("#f4d4b2"), dawn)
	environment.ambient_light_energy = lerpf(0.57, 0.86, dawn)
	environment.background_color = Color("#101a2a").lerp(Color("#344052"), dawn)
	direction.light_color = Color("#bbcfee").lerp(Color("#ffe0ad"), dawn)
	direction.light_energy = lerpf(0.80, 1.10, dawn)
	direction.rotation_degrees = Vector3(lerpf(-48.0, -26.0, dawn), lerpf(43.0, -49.0, progress), 0)


func sync_camera() -> void:
	var view: Camera2D = game.map_camera
	var viewport_size := get_viewport().get_visible_rect().size
	var play: Rect2 = view.screen_view_rect()
	var key := [view.position, view.zoom.x, view.overview, viewport_size, play]
	if key == camera_key:
		return
	camera_key = key
	terrain.lake_material.set_shader_parameter("detail_strength", 0.0 if view.overview else 1.0)
	var focus := field.surface_position(view.position)
	if view.overview:
		focus.y = 0.0
	camera.position = focus + (Vector3(0, 80, 0) if view.overview else View.TILT)
	camera.look_at(focus, Vector3.FORWARD if view.overview else Vector3.UP)
	var pixels_per_unit := view.zoom.x * field.cell_size
	camera.size = viewport_size.y / pixels_per_unit
	camera.h_offset = (viewport_size.x * 0.5 - play.get_center().x) / pixels_per_unit
	camera.v_offset = (play.get_center().y - viewport_size.y * 0.5) / pixels_per_unit


func project_world(point: Vector2) -> Vector2:
	sync_camera()
	return camera.unproject_position(field.surface_position(point))


func pick_surface(screen: Vector2) -> Dictionary:
	if not game.map_camera.screen_view_rect().has_point(screen):
		return {}
	sync_camera()
	var origin := camera.project_ray_origin(screen)
	var ray := camera.project_ray_normal(screen)
	# 固定无偏航的正交镜头只穿过同一列。按可见面顺序走格，先遇到的竖面拦截后面的可建地面。
	var x := floori(origin.x)
	if x < 0 or x >= field.size.x:
		return {}
	if absf(ray.z) < 0.00001:
		var cell := Vector2i(x, floori(origin.z))
		return _hit(origin.x, origin.z, cell, true) if field.inside(cell) else {}
	var entry := maxf(0.0, (float(field.size.y) - origin.z) / ray.z)
	var row := mini(field.size.y - 1, floori(origin.z + ray.z * entry - 0.00001))
	for z in range(row, -1, -1):
		var cell := Vector2i(x, z)
		var exit := (float(z) - origin.z) / ray.z
		var altitude := field.height(cell)
		var at_top := (altitude - origin.y) / ray.y
		if at_top >= entry - 0.00001 and at_top <= exit + 0.00001:
			return _hit(origin.x, origin.z + ray.z * at_top, cell, true)
		var entering_y := origin.y + ray.y * entry
		if entering_y < altitude and entering_y >= field.height(cell + Vector2i.DOWN):
			return _hit(origin.x, origin.z + ray.z * entry, cell, false)
		entry = exit
	return {}


func _hit(x: float, z: float, cell: Vector2i, top: bool) -> Dictionary:
	var inside_cell := Vector2(x, clampf(z, float(cell.y) + 0.00001, float(cell.y + 1) - 0.00001))
	return {"world": inside_cell * field.cell_size, "cell": cell, "top": top}


func flat_footprint(center: Vector2, footprint: Vector2i) -> bool:
	var cells: Array[Vector2i] = game.grid_map_model.footprint_cells(center, footprint)
	var height := field.height(cells.front())
	for cell in cells:
		if not field.inside(cell) or not is_equal_approx(field.height(cell), height):
			return false
	return true


func draw_placement(preview: Dictionary) -> void:
	for tile in preview_tiles:
		tile.hide()
	if preview.is_empty():
		return
	var cells: Array[Vector2i] = game.grid_map_model.footprint_cells(preview.position, preview.footprint)
	preview_material.albedo_color = Color(0.30, 1.0, 0.58, 0.59) if preview.valid else Color(1.0, 0.28, 0.29, 0.63)
	for i in range(cells.size()):
		if not field.inside(cells[i]):
			continue
		while preview_tiles.size() <= i:
			var plane := PlaneMesh.new()
			plane.size = Vector2(0.94, 0.94)
			plane.material = preview_material
			var tile := MeshInstance3D.new()
			tile.mesh = plane
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			preview_tiles.append(tile)
			add_child(tile)
		var cell := cells[i]
		preview_tiles[i].position = Vector3(cell.x + 0.5, field.height(cell) + 0.025, cell.y + 0.5)
		preview_tiles[i].show()
