extends "res://src/main/main.gd"

const CameraAdapter = preload("res://tools/moonlake_3d_level/map_camera.gd")
const LevelPresentation = preload("res://tools/moonlake_3d_level/presentation.gd")

var presentation: LevelPresentation
var pointer_position := Vector2.INF


func _create_map_camera() -> Camera2D:
	return CameraAdapter.new()


func _ready() -> void:
	super._ready()
	# 只隐藏 CanvasItem 表现，原节点仍可运行、被攻击、提供岗位及占用。
	modulate.a = 0.0
	clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	world_lighting.set_lighting_enabled(false)
	terrain_grid_layer.hide()
	$BorderForest.hide()
	placement_overlay.hide()
	presentation = LevelPresentation.new()
	add_child(presentation)
	presentation.configure(self)
	map_camera.presentation = presentation
	map_camera.reset_view()
	var navigation := $HUD/MapNavigation
	navigation.preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	navigation.preview_texture = presentation.terrain.overview_texture
	navigation.include_suppressed_sites = true
	map_drop_surface.screen_to_world = _drop_world_point


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		pointer_position = event.position


func _drop_world_point(screen: Vector2) -> Vector2:
	return map_camera.screen_to_world(pointer_position if pointer_position.is_finite() else screen)


func _process(delta: float) -> void:
	super._process(delta)
	presentation.advance(delta)
	var card: OpeningCardDefinition = placement_overlay.dragged_card
	var preview := {}
	if card != null and pointer_position.is_finite() and get_viewport().gui_get_hovered_control() == map_drop_surface:
		var hit := presentation.pick_surface(pointer_position)
		if not hit.is_empty():
			preview = placement_preview(card, hit.world)
			preview.valid = preview.valid and hit.top
	presentation.draw_placement(preview)


func placement_preview(card: OpeningCardDefinition, point: Vector2) -> Dictionary:
	var exact_site: ResourceSite
	if not card.required_resource_site.is_empty():
		exact_site = settlement_builder._matching_site(card, point)
	var result := super.placement_preview(card, exact_site.global_position if exact_site != null else point)
	if presentation != null:
		var resource_matches := card.required_resource_site.is_empty() or exact_site != null
		result.valid = result.valid and resource_matches and _surface_accepts_building(point)
		result.valid = result.valid and presentation.flat_footprint(result.position, result.footprint)
	return result


func _surface_accepts_building(point: Vector2) -> bool:
	var cell: Vector2i = grid_map_model.world_to_cell(point)
	if not presentation.field.inside(cell):
		return false
	return presentation.field.kind(cell) not in ["water", "cliff", "ramp", "boundary", "forest", "shore"]


func _on_map_card_dropped(card_index: int, map_position: Vector2) -> void:
	if not _card_play_allowed():
		return
	var card := _card_for_play_ref(card_index)
	if card == null:
		return
	if not map_position.is_finite() or not _surface_accepts_building(map_position):
		_show_notice("请选择可建地表，已保留卡牌与材料。")
		return
	var plan := placement_preview(card, map_position)
	if not presentation.flat_footprint(plan.position, plan.footprint):
		_show_notice("完整占地必须位于同一高度，已保留卡牌与材料。")
		return
	super._on_map_card_dropped(card_index, map_position)
