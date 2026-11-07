extends Node3D
## 镜像现有实体的美术和位置。生命、资源、路线与占用继续由原节点持有。

const FOREST_ART = preload("res://assets/map/resource_sites/forest_resource.png")
const Field = preload("res://tools/moonlake_3d_level/heightfield.gd")

var game: Node2D
var field: Field
var visuals: Dictionary[int, Dictionary] = {}
var visual_epoch := 0


func sync(overview: bool) -> void:
	visual_epoch += 1
	var town: Node2D = game.get_node("TownHallVisual")
	_update_visual(town, town.body, Color("#e7b76e"), overview)
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
		sprite.texture = FOREST_ART
		sprite.region_enabled = false
		sprite.pixel_size = 4.5 / FOREST_ART.get_height()
		sprite.scale = Vector3.ONE
		model_height = 4.5
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
	sprite.visible = not overview and sprite.texture != null
	var is_selected: bool = game.wave_economy.job_target(game.selected_job_id) == source
	entry.marker.visible = overview or is_selected or (source is ResourceSite and source.highlighted)
	label.position.y = model_height + 0.35
	label.visible = not overview and (source.is_in_group(&"map_units") or (source is ResourceSite and source.highlighted))
	if label.visible:
		label.text = source.display_name if source is ResourceSite else str(source.current_health)


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
