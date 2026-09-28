class_name FarmerAgent
extends Node2D

const ArtVisualScript = preload("res://src/gameplay/art/art_visual.gd")
const GridPathFollowerScript = preload("res://src/gameplay/grid/grid_path_follower.gd")

signal delivery_completed(resource_id: StringName, amount: int)
signal died(farmer: FarmerAgent)

enum WorkState {
	IDLE,
	TO_WORK,
	GATHERING,
	TO_CITY,
	WORKING,
}

@export var move_speed: float = 80.0
@export var gather_seconds: float = 1.0
@export var maximum_health: int = 30

var farmer_index: int = -1
var current_health: int = 30
var city_position: Vector2
var workplace: Node2D
var job_id: StringName = &""
var delivery_resource: StringName = &""
var delivery_amount: int = 0
var carried_amount: int = 0
var carried_resource: StringName = &""
var state: WorkState = WorkState.IDLE
var gather_elapsed: float = 0.0
var path_follower: RefCounted = GridPathFollowerScript.new()


func set_pathfinder(value: RefCounted) -> void:
	path_follower.set_pathfinder(value)


func _ready() -> void:
	var art := ArtVisualScript.new() as ArtVisual
	art.show_behind_parent = true
	add_child(art)
	art.configure("villager", Vector2(12, 18), &"walk")


func configure(index: int, home_position: Vector2) -> void:
	farmer_index = index
	city_position = home_position
	current_health = maximum_health
	global_position = _idle_position()
	state = WorkState.IDLE
	path_follower.invalidate()
	queue_redraw()


func assign_job(
	next_job_id: StringName,
	next_workplace: Node2D,
	resource_id: StringName = &"",
	amount_per_trip: int = 0
) -> void:
	if job_id == next_job_id and workplace == next_workplace:
		return
	job_id = next_job_id
	workplace = next_workplace
	delivery_resource = resource_id
	delivery_amount = amount_per_trip
	gather_elapsed = 0.0
	path_follower.invalidate()
	# 已采集的货物属于本次运输，换岗或建筑毁坏不会将其抹掉。
	state = WorkState.TO_CITY if carried_amount > 0 else (WorkState.TO_WORK if workplace != null else WorkState.IDLE)
	queue_redraw()


func clear_job() -> void:
	assign_job(&"", null)


func is_attackable() -> bool:
	return current_health > 0 and visible


func attackable_radius() -> float:
	return 12.0


func apply_enemy_attack(base_damage: int, _enemy_id: StringName) -> int:
	if not is_attackable() or base_damage <= 0:
		return 0
	var applied: int = mini(current_health, base_damage)
	current_health -= applied
	if current_health == 0:
		carried_amount = 0
		carried_resource = &""
		visible = false
		died.emit(self)
	queue_redraw()
	return applied


func advance(delta: float) -> void:
	# 终局冻结位置、采集进度和携货，防止其他调用入口继续推进运输。
	if RunState.phase in [RunState.Phase.RUN_LOST, RunState.Phase.RUN_WON]:
		return
	if delta <= 0.0 or current_health <= 0:
		return
	match state:
		WorkState.IDLE:
			_move_toward_grid(_idle_position(), 18.0, delta)
		WorkState.TO_WORK:
			if not _workplace_is_valid():
				clear_job()
				return
			if _move_toward_grid(workplace.global_position, 60.0, delta):
				state = WorkState.GATHERING if not delivery_resource.is_empty() else WorkState.WORKING
				gather_elapsed = 0.0
		WorkState.GATHERING:
			if not _workplace_is_valid():
				clear_job()
				return
			gather_elapsed += delta
			if gather_elapsed >= gather_seconds:
				carried_amount = delivery_amount
				carried_resource = delivery_resource
				state = WorkState.TO_CITY
		WorkState.TO_CITY:
			if _move_toward_grid(city_position, 96.0, delta):
				var amount_to_deliver: int = carried_amount
				var resource_to_deliver: StringName = carried_resource
				carried_amount = 0
				carried_resource = &""
				state = WorkState.TO_WORK if _workplace_is_valid() else WorkState.IDLE
				# 入账可能同步触发重新分配；先完成自身状态转换，避免重入覆盖。
				if amount_to_deliver > 0 and not resource_to_deliver.is_empty():
					delivery_completed.emit(resource_to_deliver, amount_to_deliver)
		WorkState.WORKING:
			if not _workplace_is_valid():
				clear_job()
	queue_redraw()


func _move_toward_grid(target: Vector2, stop_distance: float, delta: float) -> bool:
	if path_follower.pathfinder == null:
		global_position = global_position.move_toward(target, move_speed * delta)
		return global_position.distance_to(target) <= maxf(6.0, stop_distance if stop_distance < 24.0 else 8.0)
	var movement: Dictionary = path_follower.advance(global_position, target, stop_distance, move_speed, delta)
	global_position = movement.position
	return bool(movement.arrived)


func _workplace_is_valid() -> bool:
	return is_instance_valid(workplace) and (not workplace.has_method("is_attackable") or bool(workplace.call("is_attackable")))


func _idle_position() -> Vector2:
	var angle: float = float(farmer_index % 8) / 8.0 * TAU
	var ring: float = 108.0 + float(farmer_index / 8) * 18.0
	return city_position + Vector2.from_angle(angle) * ring


func _draw() -> void:
	var job_label: String = str({&"lumber_camp": "木", &"farm": "农", &"gold_mine": "金", &"stone_mine": "石", &"iron_mine": "铁", &"arrow_tower": "箭", &"barracks": "兵"}.get(StringName(String(job_id).get_slice("#", 0)), "闲"))
	draw_string(ThemeDB.fallback_font, Vector2(-24, -13), "%d·%s" % [farmer_index + 1, job_label], HORIZONTAL_ALIGNMENT_CENTER, 48.0, 10, Color.WHITE)
	if carried_amount > 0:
		var resource_label: String = str({&"wood": "木", &"food": "食", &"gold": "金", &"stone": "石", &"iron": "铁"}.get(carried_resource, "货"))
		draw_string(ThemeDB.fallback_font, Vector2(-15, 27), "%s%d" % [resource_label, carried_amount], HORIZONTAL_ALIGNMENT_CENTER, 30.0, 10, Color("ffe083"))
