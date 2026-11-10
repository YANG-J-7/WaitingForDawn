extends "res://src/gameplay/buildings/map_camera.gd"

const TILT := Vector3(0, 80, 72)
const TILT_SINE := 0.743294146
const Border = preload("res://tools/moonlake_3d_level/border.gd")
var presentation: Node3D


func _init() -> void:
	maximum_zoom = 1.5
	detail_zoom = maximum_zoom


func screen_to_world(point: Vector2) -> Vector2:
	if presentation == null:
		return super.screen_to_world(point)
	var hit: Dictionary = presentation.pick_surface(point)
	return hit.world if hit.get("top", false) else Vector2.INF


func world_to_screen(point: Vector2) -> Vector2:
	if presentation == null:
		return super.world_to_screen(point)
	return presentation.project_world(point)


func visible_world_rect() -> Rect2:
	if presentation == null or overview:
		return super.visible_world_rect()
	var extent := screen_view_rect().size / (Vector2(1.0, TILT_SINE) * zoom)
	return Rect2(position - extent * 0.5, extent)


func pan_by(screen_delta: Vector2) -> void:
	super.pan_by(screen_delta / Vector2(1.0, TILT_SINE if not overview else 1.0))


func zoom_at(factor: float, point: Vector2) -> void:
	if presentation == null:
		super.zoom_at(factor, point)
		return
	_stop_transition()
	var anchor := screen_to_world(point)
	if overview:
		overview = false
		zoom = Vector2.ONE * minimum_zoom
	zoom = Vector2.ONE * clampf(zoom.x * factor, minimum_zoom, maximum_zoom)
	_clamp_position()
	if anchor.is_finite():
		for i in range(3):
			var correction := world_to_screen(anchor) - point
			if correction.length_squared() < 0.04:
				break
			position += correction / (Vector2(1.0, TILT_SINE) * zoom)
			_clamp_position()
	force_update_scroll()


func _clamp_position() -> void:
	if overview or presentation == null:
		super._clamp_position()
		return
	var half_extent := visible_world_rect().size * 0.5
	var render_bounds := map_bounds.grow((Border.REACH - Border.VIEW_MARGIN) * MapDefinition.CELL_SIZE)
	var minimum := map_bounds.position.max(render_bounds.position + half_extent)
	var maximum := map_bounds.end.min(render_bounds.end - half_extent)
	position.x = _clamp_axis(position.x, minimum.x, maximum.x, map_bounds.get_center().x)
	position.y = _clamp_axis(position.y, minimum.y, maximum.y, map_bounds.get_center().y)
	_apply_screen_offset()


func _refresh_fit_zoom() -> void:
	super._refresh_fit_zoom()
	var play := screen_view_rect().size
	minimum_zoom = minf(maxf(minimum_zoom, play.y / (map_bounds.size.y * TILT_SINE)), maximum_zoom)
	default_zoom = minimum_zoom
	if not overview and zoom.x < minimum_zoom:
		zoom = Vector2.ONE * minimum_zoom
