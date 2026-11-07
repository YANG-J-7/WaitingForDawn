extends Node3D
## 只替换样区表现，地表射线仍命中 P1 原有碰撞体。

const Playable = preload("res://tools/preview_moonlake_3d_playable.gd")
const Layout = preload("res://src/gameplay/buildings/map_layout.gd")
const GROUND = preload("res://tools/moonlake_3d_art/ground.gdshader")
const LAKE = preload("res://tools/moonlake_3d_art/lake.gdshader")
const FOLIAGE = preload("res://tools/moonlake_3d_art/foliage.gdshader")

enum LightMode { DIRECTIONAL, MOVING_POINT }
enum ShadowMode { OFF, ENVIRONMENT, ALL }

var sample: Playable
var terrain: MeshInstance3D
var water: MeshInstance3D
var environment: Environment
var direction := DirectionalLight3D.new()
var moving_point := OmniLight3D.new()
var lake_material := ShaderMaterial.new()
var tree_material := ShaderMaterial.new()
var trees: Array[MeshInstance3D] = []
var entity_shadows: Array[MeshInstance3D] = []
var brazier: Node3D
var flame: MeshInstance3D
var local_lamp: OmniLight3D
var light_mode := LightMode.DIRECTIONAL
var shadow_mode := ShadowMode.OFF
var dawn_blend := 0.0


func configure(playable: Playable) -> void:
	sample = playable
	terrain = sample.graybox.get_node("Terrain")
	var ground_material := ShaderMaterial.new()
	ground_material.shader = GROUND
	terrain.material_override = ground_material
	_build_water()
	_build_trees()
	_add_shore_stones()
	_add_grass_tufts()
	_build_brazier()

	var world_environment: WorldEnvironment = sample.graybox.get_node("WorldEnvironment")
	environment = world_environment.environment.duplicate() as Environment
	world_environment.environment = environment
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var graybox_light: DirectionalLight3D = sample.graybox.get_node("DirectionalLight3D")
	graybox_light.hide()
	add_child(direction)
	direction.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	direction.directional_shadow_max_distance = 55.0
	direction.shadow_bias = 0.06
	direction.shadow_normal_bias = 0.55
	add_child(moving_point)
	moving_point.omni_range = 37.0
	moving_point.omni_attenuation = 0.83
	moving_point.shadow_bias = 0.07

	var proxy := CapsuleMesh.new()
	proxy.radius = 0.19
	proxy.height = 1.05
	_add_entity_shadow(sample.farmer_visual, proxy, proxy.height * 0.5)
	sample.world.building_placed.connect(_on_building_placed)
	set_light_mode(LightMode.DIRECTIONAL)
	set_shadow_mode(ShadowMode.OFF)
	set_time(0.0, 0.0)


func set_light_mode(mode: int) -> void:
	light_mode = mode as LightMode
	direction.visible = light_mode == LightMode.DIRECTIONAL
	moving_point.visible = light_mode == LightMode.MOVING_POINT
	_apply_shadow_mode()


func set_shadow_mode(mode: int) -> void:
	shadow_mode = mode as ShadowMode
	_apply_shadow_mode()


func _apply_shadow_mode() -> void:
	var enabled := shadow_mode != ShadowMode.OFF
	direction.shadow_enabled = enabled and direction.visible
	moving_point.shadow_enabled = enabled and moving_point.visible
	var environment_cast := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain.cast_shadow = environment_cast
	for tree in trees:
		tree.cast_shadow = environment_cast
	for proxy in entity_shadows:
		proxy.visible = shadow_mode == ShadowMode.ALL


func set_time(elapsed: float, motion_seconds: float) -> void:
	var progress := clampf(elapsed / RunState.CAMPAIGN_DURATION_SECONDS, 0.0, 1.0)
	dawn_blend = smoothstep(RunState.CAMPAIGN_DURATION_SECONDS - 300.0, RunState.CAMPAIGN_DURATION_SECONDS, elapsed)
	var light_color := Color("#bbcfee").lerp(Color("#ffe0ad"), dawn_blend)
	environment.ambient_light_color = Color("#a7bfe0").lerp(Color("#f4d4b2"), dawn_blend)
	environment.ambient_light_energy = lerpf(0.57, 0.86, dawn_blend)
	environment.background_color = Color("#101a2a").lerp(Color("#344052"), dawn_blend)
	direction.light_color = light_color
	direction.light_energy = lerpf(0.80, 1.10, dawn_blend)
	direction.rotation_degrees = Vector3(lerpf(-48.0, -26.0, dawn_blend), lerpf(43.0, -49.0, progress), 0)
	moving_point.position = Vector3(lerpf(-4.0, sample.graybox.CROP.size.x + 4.0, progress), 10.5, -3.8)
	moving_point.light_color = light_color
	moving_point.light_energy = lerpf(2.6, 3.50, dawn_blend)
	lake_material.set_shader_parameter("motion_time", motion_seconds)
	tree_material.set_shader_parameter("motion_time", motion_seconds)
	if is_instance_valid(brazier):
		var pulse := sin(motion_seconds * 6.1) * 0.12 + sin(motion_seconds * 11.3) * 0.07
		local_lamp.light_energy = 1.05 + pulse
		flame.scale = Vector3(1.0 - pulse * 0.22, 1.0 + pulse * 0.45, 1.0 - pulse * 0.22)


func set_brazier_visible(enabled: bool) -> void:
	if is_instance_valid(brazier):
		brazier.visible = enabled


func refresh_tree_visibility() -> void:
	for tree in trees:
		var world_point := sample._world_point(tree.position)
		var center := sample.world.grid.snap_footprint_center(world_point, Vector2i.ONE)
		var cell := sample.world.grid.world_to_cell(center)
		var can_build := bool(sample.world.grid.cell_data(cell).buildable)
		var concealed := can_build and not sample.world.grid.can_place(center, Vector2i.ONE)
		for tile in sample.preview_tiles:
			if tile.visible and Vector2(tile.position.x, tile.position.z).distance_to(Vector2(tree.position.x, tree.position.z)) < 1.1:
				concealed = true
				break
		tree.visible = not concealed


func _build_water() -> void:
	var graybox := sample.graybox
	var size := graybox.CROP.size
	var wet_cells := Image.create_empty(size.x, size.y, false, Image.FORMAT_L8)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(size.y):
		for x in range(size.x):
			var cell := graybox.CROP.position + Vector2i(x, z)
			if graybox.kind_at(cell) != "water":
				continue
			wet_cells.set_pixel(x, z, Color.WHITE)
			var a := Vector3(x, graybox.WATER_HEIGHT + 0.008, z)
			for point: Vector3 in [a, a + Vector3.RIGHT, a + Vector3.RIGHT + Vector3.BACK,
					a, a + Vector3.RIGHT + Vector3.BACK, a + Vector3.BACK]:
				surface.set_normal(Vector3.UP)
				surface.add_vertex(point)
	lake_material.shader = LAKE
	lake_material.set_shader_parameter("wet_cells", ImageTexture.create_from_image(wet_cells))
	lake_material.set_shader_parameter("grid_size", Vector2(size))
	surface.set_material(lake_material)
	water = MeshInstance3D.new()
	water.mesh = surface.commit()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _build_trees() -> void:
	tree_material.shader = FOLIAGE
	var pine := create_pine_mesh(tree_material)
	for placeholder: Node3D in sample.graybox.trees_root.get_children():
		var tree := MeshInstance3D.new()
		tree.mesh = pine
		tree.position = placeholder.position
		tree.rotation.y = float(trees.size()) * 2.39
		tree.scale = placeholder.scale
		trees.append(tree)
		add_child(tree)
	sample.graybox.trees_root.hide()


static func create_pine_mesh(material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var bark := Color("#604b3c")
	_add_tier(surface, 0.0, 2.48, 0.11, 0.025, bark, 0.0, 0.0)
	var foliage_colors: Array[Color] = [Color("#254440"), Color("#305751"), Color("#38655a"), Color("#497668")]
	for i in range(foliage_colors.size()):
		var height := 0.71 + float(i) * 0.47
		var radius := 0.71 - float(i) * 0.116
		_add_tier(surface, height, height + 0.96, radius, 0.025, foliage_colors[i], float(i) * 0.37, 0.22)
	surface.generate_normals()
	surface.set_material(material)
	return surface.commit()


static func _add_tier(surface: SurfaceTool, low: float, high: float, base_radius: float, top_radius: float,
		tint: Color, phase: float, irregularity: float) -> void:
	var base := PackedVector3Array()
	var tip := PackedVector3Array()
	const SIDES := 12
	for i in range(SIDES):
		var angle := TAU * float(i) / SIDES + phase
		var radius := base_radius * (1.0 + irregularity * sin(float(i) * 2.1 + phase))
		var floor_y := low + irregularity * 0.42 * cos(float(i) * 2.17 + phase)
		var radial := Vector3(cos(angle), 0, sin(angle))
		base.append(radial * radius + Vector3.UP * floor_y)
		tip.append(radial * top_radius + Vector3.UP * high)
	for i in range(SIDES):
		var next := (i + 1) % SIDES
		var shade := tint.lerp(Color("#8aaa85"), 0.13 + sin(float(i) * 2.4) * 0.095)
		_triangle(surface, base[i], base[next], tip[next], shade)
		_triangle(surface, base[i], tip[next], tip[i], shade)
		_triangle(surface, base[i], Vector3.UP * (low + irregularity * 0.43), base[next], tint.darkened(0.19))


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	surface.set_color(tint)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


func _add_shore_stones() -> void:
	var rock := SphereMesh.new()
	rock.radial_segments = 6
	rock.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#667983")
	material.roughness = 0.94
	rock.material = material
	for cell: Vector2i in [Vector2i(153, 47), Vector2i(155, 45), Vector2i(160, 46),
			Vector2i(162, 48), Vector2i(164, 46), Vector2i(166, 45), Vector2i(168, 48), Vector2i(169, 45)]:
		if sample.graybox.kind_at(cell) not in ["shore", "cliff"]:
			continue
		var stone := MeshInstance3D.new()
		stone.mesh = rock
		stone.position = sample._surface_position(Vector2(cell) + Vector2(0.34, 0.53))
		stone.scale = Vector3(0.36, 0.19, 0.24) * (0.79 + float(posmod(cell.x, 4)) * 0.13)
		stone.rotation.y = float(cell.x) * 1.16
		stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(stone)


func _add_grass_tufts() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	# 岸草落在禁建岸边，山林装饰只放在岩缘，避免穿过占地预览。
	for cell: Vector2i in [Vector2i(153, 47), Vector2i(157, 46), Vector2i(160, 46),
			Vector2i(163, 46), Vector2i(169, 45), Vector2i(163, 40), Vector2i(164, 42)]:
		if sample.graybox.kind_at(cell) not in ["shore", "cliff"]:
			continue
		var root := sample._surface_position(Vector2(cell) + Vector2(0.64, 0.36))
		for blade in range(6):
			var angle := float(cell.x + blade) * 2.39
			var direction := Vector3(cos(angle), 0, sin(angle))
			var side := direction.cross(Vector3.UP) * 0.036
			var foot := root + direction * (0.04 + float(blade) * 0.024)
			var tip := foot + direction * 0.15 + Vector3.UP * (0.23 + float(blade % 3) * 0.075)
			var tint := Color("#53715a").lerp(Color("#8b9a65"), float(blade) / 8.0)
			_triangle(surface, foot - side, foot + side, tip, tint)
	surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.95
	surface.set_material(material)
	var tufts := MeshInstance3D.new()
	tufts.mesh = surface.commit()
	tufts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tufts)


func _build_brazier() -> void:
	brazier = Node3D.new()
	brazier.position = sample._surface_position(Vector2(153.8, 45.3))
	add_child(brazier)
	var bowl := CylinderMesh.new()
	bowl.height = 0.38
	bowl.top_radius = 0.19
	bowl.bottom_radius = 0.10
	bowl.radial_segments = 10
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#64534b")
	bowl.material = iron
	var stand := MeshInstance3D.new()
	stand.mesh = bowl
	stand.position.y = 0.19
	stand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brazier.add_child(stand)

	var ember := SphereMesh.new()
	ember.radius = 0.13
	ember.height = 0.30
	var fire := StandardMaterial3D.new()
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.albedo_color = Color("#ffd185")
	fire.emission_enabled = true
	fire.emission = Color("#ff963f")
	ember.material = fire
	flame = MeshInstance3D.new()
	flame.mesh = ember
	flame.position.y = 0.46
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brazier.add_child(flame)
	local_lamp = OmniLight3D.new()
	local_lamp.position.y = 0.72
	local_lamp.light_color = Color("#ffc27d")
	local_lamp.omni_range = 4.3
	local_lamp.omni_attenuation = 1.25
	brazier.add_child(local_lamp)


func _on_building_placed(card: OpeningCardDefinition, _center: Vector2) -> void:
	var footprint := Layout.footprint_for_card(card.card_id)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(float(footprint.x) * 0.62, 0.72, float(footprint.y) * 0.55)
	_add_entity_shadow(sample.building_visuals.back(), mesh, mesh.size.y * 0.5)


func _add_entity_shadow(anchor: Node3D, mesh: Mesh, height: float) -> void:
	for child in anchor.get_children():
		if child is GeometryInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var proxy := MeshInstance3D.new()
	proxy.mesh = mesh
	proxy.position.y = height
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	proxy.visible = shadow_mode == ShadowMode.ALL
	anchor.add_child(proxy)
	entity_shadows.append(proxy)
