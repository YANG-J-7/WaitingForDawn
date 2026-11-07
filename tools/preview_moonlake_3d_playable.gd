extends Node3D

const Graybox = preload("res://prototypes/moonlake_3d_graybox/moonlake_3d_graybox.gd")
const SampleWorld = preload("res://tools/moonlake_3d_sample_world.gd")
const SampleMinimap = preload("res://tools/moonlake_3d_sample_minimap.gd")
const Art = preload("res://src/gameplay/art/art_visual.gd")
const Layout = preload("res://src/gameplay/buildings/map_layout.gd")
const STARTING_CARDS: Array[OpeningCardDefinition] = [
	preload("res://src/data/cards/farm.tres"),
	preload("res://src/data/cards/house.tres"),
	preload("res://src/data/cards/wall.tres"),
	preload("res://src/data/cards/lumber_camp.tres"),
]
const BUILDING_ART := {&"farm": "farm", &"house": "house", &"wall": "palisade_wall"}

@onready var graybox: Graybox = $Graybox
@onready var inventory: RunCardInventory = $Inventory
@onready var drop_surface: MapDropSurface = $HUD/MapDropSurface
@onready var hand: VBoxContainer = $HUD/HandPanel/Hand
@onready var status: Label = $HUD/StatusPanel/Status
@onready var resources: Label = $HUD/Controls/Rows/Resources
@onready var route_status: Label = $HUD/Controls/Rows/RouteStatus
@onready var minimap: SampleMinimap = $HUD/MinimapPanel/Rows/Minimap

var world: SampleWorld
var farmer_visual: Node3D
var building_visuals: Array[Node3D] = []
var preview_tiles: Array[MeshInstance3D] = []
var preview_material := StandardMaterial3D.new()
var pending_drop: Dictionary = {}
var pointer_position := Vector2.ZERO
var simulation_paused := false
var last_message := "拖动卡牌建造 · 绿框可建 · 红框为无效落点"


func _ready() -> void:
	$Graybox/HUD/Panel/Text/Title.text = "月湖山谷 · S6 可玩样区"
	RunEconomy.resources_changed.connect(_update_resources)
	RunEconomy.begin_run()
	world = SampleWorld.new()
	add_child(world)
	world.configure(graybox)
	world.building_placed.connect(_add_building_visual)
	world.route_status_changed.connect(_show_route_status)
	# 松手与预览共用视口事件坐标，物理帧内统一投射到 3D 地表。
	drop_surface.screen_to_world = func(_point: Vector2) -> Vector2: return pointer_position
	drop_surface.card_dropped.connect(_queue_drop)
	$HUD/Controls/Rows/RoundTrip.pressed.connect(world.start_round_trip)
	minimap.configure(graybox)
	minimap.cell_selected.connect(_focus_cell)
	for card in STARTING_CARDS:
		var instance_id := inventory.add_card(card, 0)
		var slot := HandCardSlot.new()
		hand.add_child(slot)
		slot.configure(instance_id, card)
		slot.set_interaction_enabled(true)

	farmer_visual = Node3D.new()
	add_child(farmer_visual)
	_add_sprite(farmer_visual, "villager", 1.28)
	_add_farmer_marker()
	_update_farmer_visual()
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		pointer_position = event.position


func _physics_process(delta: float) -> void:
	if not pending_drop.is_empty():
		_drop_at(pending_drop.id, pending_drop.screen)
		pending_drop.clear()
	if not simulation_paused:
		world.advance(delta)
	_update_farmer_visual()
	_update_drag_preview()


func _queue_drop(instance_id: int, screen: Vector2) -> void:
	pending_drop = {"id": instance_id, "screen": screen}


func _pick_surface(screen: Vector2) -> Dictionary:
	var camera := graybox.camera
	var origin := camera.project_ray_origin(screen)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen) * camera.far)
	return get_world_3d().direct_space_state.intersect_ray(ray)


func _world_point(hit_position: Vector3) -> Vector2:
	return (Vector2(hit_position.x, hit_position.z) + Vector2(graybox.CROP.position)) * GridMapModel.CELL_SIZE


func _drop_at(instance_id: int, screen: Vector2) -> void:
	var card := inventory.card_for(instance_id)
	if card == null:
		return
	var hit := _pick_surface(screen)
	if hit.is_empty() or hit.normal.y < 0.8:
		_show_status("请选择可建地表，已保留卡牌与材料")
		return
	if not world.build(card, _world_point(hit.position)):
		_show_status("%s，已保留卡牌与材料" % world.last_error)
		return
	inventory.consume(instance_id)
	var slot := hand.get_node("HandCard_%d" % instance_id)
	slot.hide()
	slot.queue_free()
	var message := "%s已建成" % card.display_name
	if card.card_id == &"farm":
		message += "，已安排农民采集并运输"
	_show_status(message)


func _update_drag_preview() -> void:
	for tile in preview_tiles:
		tile.hide()
	status.text = last_message
	var payload: Variant = get_viewport().gui_get_drag_data()
	if get_viewport().gui_get_hovered_control() != drop_surface or not drop_surface.accepts_card_data(payload):
		return
	var card := inventory.card_for(int(payload.card_instance_id))
	if card == null:
		return
	var hit := _pick_surface(pointer_position)
	if hit.is_empty() or hit.normal.y < 0.8:
		status.text = "不可建 · 请选择可建地表"
		return
	var plan := world.placement(card, _world_point(hit.position))
	var valid: bool = plan.reason.is_empty()
	status.text = "%s · %s" % [card.display_name, "可建" if valid else plan.reason]
	preview_material.albedo_color = Color(0.3, 1.0, 0.58, 0.56) if valid else Color(1.0, 0.28, 0.29, 0.6)
	for i in range(plan.cells.size()):
		var cell: Vector2i = plan.cells[i]
		if graybox.CROP.has_point(cell):
			var tile := _preview_tile(i)
			tile.position = _surface_position(Vector2(cell) + Vector2(0.5, 0.5)) + Vector3.UP * 0.026
			tile.show()


func _preview_tile(index: int) -> MeshInstance3D:
	while preview_tiles.size() <= index:
		var tile := _box(Vector3(0.94, 0.018, 0.94), preview_material)
		add_child(tile)
		preview_tiles.append(tile)
	return preview_tiles[index]


func _surface_position(cell_point: Vector2) -> Vector3:
	var local := cell_point - Vector2(graybox.CROP.position)
	var cell := Vector2i(floori(cell_point.x), floori(cell_point.y))
	return Vector3(local.x, graybox.height_at(cell), local.y)


func _update_farmer_visual() -> void:
	var cell_point := world.farmer.global_position / GridMapModel.CELL_SIZE
	farmer_visual.position = _surface_position(cell_point)
	if minimap.farmer_cell != cell_point:
		minimap.farmer_cell = cell_point
		minimap.queue_redraw()


func _add_building_visual(card: OpeningCardDefinition, center: Vector2) -> void:
	var anchor := Node3D.new()
	var cell_point := center / GridMapModel.CELL_SIZE
	add_child(anchor)
	anchor.position = _surface_position(cell_point)
	building_visuals.append(anchor)
	var footprint := Layout.footprint_for_card(card.card_id)
	var material := StandardMaterial3D.new()
	material.albedo_color = card.building_color
	var base := _box(Vector3(footprint.x - 0.08, 0.065, footprint.y - 0.08), material)
	base.position.y = 0.0325
	anchor.add_child(base)
	_add_sprite(anchor, BUILDING_ART[card.card_id], 1.0 if card.card_id == &"wall" else 1.8, 0.065)
	minimap.buildings.append(cell_point)
	minimap.queue_redraw()


func _add_sprite(anchor: Node3D, asset: String, height: float, base_height: float = 0.0) -> void:
	var source: Texture2D = load("res://assets/art_candidates/night_set_v1/%s.png" % asset)
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = Art._visible_region(source.get_image())
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = height / texture.region.size.y
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.position.y = base_height + height * 0.5
	anchor.add_child(sprite)


func _add_farmer_marker() -> void:
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.21
	marker_mesh.bottom_radius = 0.21
	marker_mesh.height = 0.018
	marker_mesh.radial_segments = 16
	marker_mesh.rings = 0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#81d4d8")
	marker_mesh.material = material
	var marker := MeshInstance3D.new()
	marker.mesh = marker_mesh
	marker.position.y = 0.015
	farmer_visual.add_child(marker)


func _box(dimensions: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _focus_cell(cell: Vector2i) -> void:
	graybox.set_view(2, _surface_position(Vector2(cell) + Vector2(0.5, 0.5)))


func _update_resources(balances: Dictionary, _population: int, _capacity: int) -> void:
	resources.text = "木 %d   石 %d   食 %d" % [balances[&"wood"], balances[&"stone"], balances[&"food"]]


func _show_status(message: String) -> void:
	last_message = message
	status.text = message


func _show_route_status(message: String) -> void:
	route_status.text = message
