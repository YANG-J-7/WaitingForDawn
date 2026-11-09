extends Node3D
## 镜像现有实体的美术和位置。生命、资源、路线与占用继续由原节点持有。

const Field = preload("res://tools/moonlake_3d_level/heightfield.gd")
const TOWN_HALL_SCENE = preload("res://assets/buildings/town_hall_3d/town_hall.glb")

var game: Node2D
var field: Field
var grove_mesh: Mesh
var visuals: Dictionary[int, Dictionary] = {}
var visual_epoch := 0


func sync(overview: bool) -> void:
	visual_epoch += 1
	var town: Node2D = game.get_node("TownHallVisual")
	_update_town_hall(town, overview)
	for site: ResourceSite in game.resource_sites:
		if not site.is_occupied():
			_update_visual(site, site.art_visual, _resource_color(site), overview)
	for unit: Node2D in get_tree().get_nodes_in_group(&"map_units"):
		if game.is_ancestor_of(unit) and unit.is_visible_in_tree():
			_update_visual(unit, _find_art(unit), Color("#ef8567") if unit is EnemyActor else Color("#91d7d2"), overview)
	for building: Node2D in game.settlement_builder.placed_buildings():
		_update_visual(building, _find_art(building), Color("#edcf9b"), overview)
	for wall: Node2D in game.wall_manager.active_walls():
		_update_visual(wall, _find_art(wall), Color("#c8a681"), overview)
	for tower: Node2D in game.active_towers():
		_update_visual(tower, _find_art(tower), Color("#f0cf89"), overview)
	for camp: Node2D in game.active_barracks():
		_update_visual(camp, _find_art(camp), Color("#f0cf89"), overview)
	for id in visuals.keys():
		if visuals[id].epoch != visual_epoch:
			visuals[id].anchor.queue_free()
			visuals.erase(id)


func _update_town_hall(source: Node2D, overview: bool) -> void:
	var id := source.get_instance_id()
	if not visuals.has(id):
		visuals[id] = _create_visual(Color("#e7b76e"), false, false)
	var entry: Dictionary = visuals[id]
	entry.epoch = visual_epoch
	var anchor: Node3D = entry.anchor
	anchor.position = field.surface_position(source.global_position)
	if not entry.has("town_model"):
		var created := _create_town_hall_model(anchor)
		entry.town_model = created.model
		entry.town_ground = created.ground
		entry.town_lights = created.lights
	entry.sprite.visible = false
	entry.label.visible = false
	entry.town_model.visible = not overview
	entry.town_ground.visible = true
	var is_selected: bool = game.wave_economy.job_target(game.selected_job_id) == source
	entry.marker.visible = overview or is_selected
	for light: OmniLight3D in entry.town_lights:
		light.visible = not overview and RunState.city_health > 0.0


func _create_town_hall_model(anchor: Node3D) -> Dictionary:
	# GLB 的 Blender -Y 正面转为 Godot +Z，原尺寸先接入，实景复核后再决定比例。
	var model := TOWN_HALL_SCENE.instantiate() as Node3D
	model.name = "TownHall3D"
	anchor.add_child(model)
	var ground := model.find_child("BP_EnvironmentGround", true, false) as Node3D
	if ground == null:
		push_error("主城 GLB 缺少独立地面 BP_EnvironmentGround")
	var lights: Array[OmniLight3D] = []
	for x in [-0.77, 0.77]:
		var light := OmniLight3D.new()
		light.name = "TownHallBrazierLight"
		light.position = Vector3(x, 1.42, 1.80)
		light.light_color = Color("#ffc27d")
		light.light_energy = 0.65
		light.omni_range = 2.2
		light.omni_attenuation = 1.35
		light.shadow_enabled = false
		anchor.add_child(light)
		lights.append(light)
	return {"model": model, "ground": ground, "lights": lights}


func _find_art(source: Node2D) -> Sprite2D:
	for child in source.get_children():
		if child is ArtVisual:
			return child
	return null


func _resource_color(site: ResourceSite) -> Color:
	match site.site_type:
		&"forest": return Color("#9dd288")
		&"iron_deposit": return Color("#e4b889")
		_: return Color("#d6e2e8")


func _update_visual(source: Node2D, art: Sprite2D, tint: Color, overview: bool) -> void:
	var id := source.get_instance_id()
	if not visuals.has(id):
		visuals[id] = _create_visual(tint, source.is_in_group(&"map_units"), source is ResourceSite)
	var entry: Dictionary = visuals[id]
	entry.epoch = visual_epoch
	var anchor: Node3D = entry.anchor
	var sprite: Sprite3D = entry.sprite
	var label: Label3D = entry.label
	anchor.position = field.surface_position(source.global_position)
	var forest_site: bool = source is ResourceSite and source.site_type == &"forest" and source.visual_suppressed
	var model_height := 0.75
	if forest_site:
		if not entry.has("grove"):
			entry.grove = _create_grove(anchor)
		entry.grove.visible = not overview
		model_height = 2.2
	elif is_instance_valid(art) and art.texture != null:
		if sprite.texture != art.texture:
			sprite.texture = art.texture
		sprite.region_enabled = art.region_enabled
		if art.region_enabled:
			sprite.region_rect = art.region_rect
		sprite.flip_h = art.flip_h
		sprite.flip_v = art.flip_v
		sprite.pixel_size = 1.0 / field.cell_size
		sprite.scale = Vector3(absf(art.global_scale.x), absf(art.global_scale.y), 1.0)
		sprite.modulate = art.modulate
		model_height = art.get_rect().size.y * sprite.scale.y / field.cell_size
	sprite.position.y = model_height * 0.5 + 0.025
	sprite.visible = not overview and not forest_site and sprite.texture != null
	var is_selected: bool = game.wave_economy.job_target(game.selected_job_id) == source
	entry.marker.visible = overview or is_selected or (source is ResourceSite and source.highlighted)
	label.position.y = model_height + 0.35
	label.visible = not overview and (source.is_in_group(&"map_units") or (source is ResourceSite and source.highlighted))
	if label.visible:
		label.text = source.display_name if source is ResourceSite else str(source.current_health)


func _create_grove(anchor: Node3D) -> MultiMeshInstance3D:
	# 树根和树冠都收在资源点的保留范围内，建筑占用后随原资源表现隐藏。
	var roots := [Vector2(-0.52, -0.50), Vector2(0.52, -0.53), Vector2.ZERO,
		Vector2(-0.52, 0.47), Vector2(0.51, 0.48)]
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = grove_mesh
	batch.instance_count = roots.size()
	for i in range(roots.size()):
		var point: Vector2 = roots[i]
		var basis := Basis(Vector3.UP, i * 2.39).scaled(Vector3(0.39, 0.52 + 0.03 * i, 0.39))
		batch.set_instance_transform(i, Transform3D(basis, Vector3(point.x, 0.0, point.y)))
	var grove := MultiMeshInstance3D.new()
	grove.multimesh = batch
	anchor.add_child(grove)
	return grove


func _create_visual(tint: Color, unit: bool, resource: bool) -> Dictionary:
	var anchor := Node3D.new()
	add_child(anchor)
	var sprite := Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor.add_child(sprite)
	var icon := CylinderMesh.new()
	icon.top_radius = 0.62 if unit else (1.1 if resource else 1.32)
	icon.bottom_radius = icon.top_radius
	icon.height = 0.035
	icon.radial_segments = 12
	icon.rings = 0
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	icon.material = material
	var marker := MeshInstance3D.new()
	marker.mesh = icon
	marker.position.y = 0.055
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor.add_child(marker)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 18
	label.pixel_size = 0.034
	label.outline_size = 5
	label.modulate = tint
	anchor.add_child(label)
	return {"anchor": anchor, "sprite": sprite, "marker": marker, "label": label, "epoch": 0}
