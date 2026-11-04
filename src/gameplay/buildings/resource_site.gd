class_name ResourceSite
extends Node2D

const ArtVisualScript = preload("res://src/gameplay/art/art_visual.gd")

@export var site_type: StringName = &"forest"
@export var display_name: String = "资源点"
@export var radius: float = 32.0
@export var site_color: Color = Color("4f7650")

var occupied_building: ResourceBuilding
var highlighted: bool = false
var art_visual: ArtVisual
var hide_visual_when_occupied: bool = false
var map_data: Dictionary = {}
var grid_model: RefCounted
var forest_cells: Array[Vector2i] = []
var forest_rect := Rect2()
var pending_forest_block := false
var visual_suppressed := false

func configure_map(grid: RefCounted, entry: Dictionary) -> void:
	grid_model = grid
	map_data = entry
	visual_suppressed = bool(entry.get("visual_suppressed",false))


func _ready() -> void:
	art_visual = ArtVisualScript.new() as ArtVisual
	art_visual.show_behind_parent = true
	add_child(art_visual)
	if visual_suppressed:
		# 资源钩子保留供后续树林制作；当前不显示、不产生隐形林区阻挡。
		art_visual.hide()
		return
	if map_data.has("worldRect") or map_data.has("sourceRect"):
		var definition = preload("res://src/gameplay/grid/map_definition.gd")
		var box: Array = map_data.get("sourceRect",[0,0,1,1])
		var origin: Vector2 = definition.source_to_world(Vector2(box[0],box[1]))
		var visual_size: Vector2 = definition.source_to_world(Vector2(box[2],box[3]))-origin
		if map_data.has("worldRect"):
			var world: Array = map_data.worldRect
			origin = Vector2(world[0],world[1])
			visual_size = Vector2(world[2],world[3])
		art_visual.texture = load("res://" + map_data.sprite)
		art_visual.centered = false
		art_visual.position = origin - position
		art_visual.scale = visual_size / art_visual.texture.get_size()
		art_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art_visual.show_behind_parent = false
		hide_visual_when_occupied = true
		# 阻挡的是树簇地面占区，树冠仍由独立图层显示。
		var rect := Rect2(origin, visual_size)
		forest_rect = rect
		# 树簇不再因单位进入宽矩形而整片变透明，单位在独立前景层保持可读。
		z_index = 0
		for y in range(grid_model.grid_size.y):
			for x in range(grid_model.grid_size.x):
				var cell := Vector2i(x,y)
				var point: Vector2 = grid_model.cell_center(cell)
				var normalized := (point-rect.get_center()) / (rect.size * 0.5)
				if normalized.length_squared() <= 1.0 and grid_model.cell_data(cell).terrain_type in [&"grass", &"road"]:
					forest_cells.append(cell)
		_set_forest_blocked(true)
		return
	match site_type:
		&"forest":
			art_visual.configure_path("res://assets/map/resource_sites/forest_resource.png", Vector2(218, 178), &"sway")
			hide_visual_when_occupied = true
		&"stone_deposit":
			art_visual.configure_path("res://assets/map/resource_sites/stone_deposit.png", Vector2(130, 82))
		&"iron_deposit":
			art_visual.configure_path("res://assets/map/resource_sites/iron_deposit.png", Vector2(130, 82))
		&"gold_vein":
			art_visual.configure("mine_entrance", Vector2(52, 42), &"lantern")
		_:
			art_visual.configure("terrain_grass", Vector2(65, 40))


func set_highlighted(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	queue_redraw()


func accepts(card: OpeningCardDefinition) -> bool:
	return (
		card != null
		and card.required_resource_site == site_type
		and not is_occupied()
	)


func is_occupied() -> bool:
	return occupied_building != null and is_instance_valid(occupied_building)


func claim(building: ResourceBuilding) -> bool:
	if building == null or is_occupied():
		return false
	occupied_building = building
	if hide_visual_when_occupied:
		art_visual.visible = false
		_set_forest_blocked(false)
	queue_redraw()
	return true


func release(building: ResourceBuilding) -> void:
	if occupied_building == building:
		occupied_building = null
		art_visual.visible = not visual_suppressed
		art_visual.modulate = Color.WHITE
		_set_forest_blocked(true)
		queue_redraw()


func reset() -> void:
	occupied_building = null
	art_visual.visible = not visual_suppressed
	art_visual.modulate = Color.WHITE
	_set_forest_blocked(true)
	queue_redraw()

func _set_forest_blocked(blocked: bool) -> void:
	# 树林恢复时先让林内单位离开，避免已在合法地面上的单位被新阻挡困住。
	pending_forest_block = blocked and _has_units_inside()
	if pending_forest_block:
		return
	if grid_model != null and not forest_cells.is_empty():
		grid_model.set_terrain_cells(forest_cells, &"forest" if blocked else &"grass", not blocked, not blocked, INF if blocked else 1.0)

func _process(_delta: float) -> void:
	if pending_forest_block and not _has_units_inside():
		_set_forest_blocked(true)

func _has_units_inside() -> bool:
	if grid_model == null or forest_cells.is_empty() or not is_inside_tree():
		return false
	for unit in get_tree().get_nodes_in_group(&"map_units"):
		if unit is Node2D and unit.is_inside_tree() and forest_cells.has(grid_model.world_to_cell(unit.global_position)):
			if not unit.has_method("is_attackable") or unit.is_attackable():
				return true
	return false

func _draw() -> void:
	if highlighted:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 40, Color("ffe083"), 4.0)
		draw_circle(Vector2.ZERO, radius, Color(site_color, 0.24))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, site_color, 2.0)
	if site_type == &"farmland":
		for row in range(-2, 3):
			draw_line(Vector2(-30, row * 9), Vector2(30, row * 9), Color("b8994b"), 3.0)
	if highlighted:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-38, radius + 16),
			display_name if not is_occupied() else "%s·占用" % display_name,
			HORIZONTAL_ALIGNMENT_CENTER,
			76.0,
			13,
			Color("e8e2ca")
		)
