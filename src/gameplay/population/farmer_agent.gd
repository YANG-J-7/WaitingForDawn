class_name FarmerAgent
extends Node2D

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
var state: WorkState = WorkState.IDLE
var gather_elapsed: float = 0.0


func configure(index: int, home_position: Vector2) -> void:
	farmer_index = index
	city_position = home_position
	current_health = maximum_health
	global_position = _idle_position()
	state = WorkState.IDLE
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
	carried_amount = 0
	gather_elapsed = 0.0
	state = WorkState.TO_WORK if workplace != null else WorkState.IDLE
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
		visible = false
		died.emit(self)
	queue_redraw()
	return applied


func advance(delta: float) -> void:
	if delta <= 0.0 or current_health <= 0:
		return
	match state:
		WorkState.IDLE:
			global_position = global_position.move_toward(_idle_position(), move_speed * delta)
		WorkState.TO_WORK:
			if not is_instance_valid(workplace):
				clear_job()
				return
			global_position = global_position.move_toward(workplace.global_position, move_speed * delta)
			if global_position.distance_to(workplace.global_position) <= 6.0:
				state = WorkState.GATHERING if not delivery_resource.is_empty() else WorkState.WORKING
				gather_elapsed = 0.0
		WorkState.GATHERING:
			if not is_instance_valid(workplace):
				clear_job()
				return
			gather_elapsed += delta
			if gather_elapsed >= gather_seconds:
				carried_amount = delivery_amount
				state = WorkState.TO_CITY
		WorkState.TO_CITY:
			global_position = global_position.move_toward(city_position, move_speed * delta)
			if global_position.distance_to(city_position) <= 8.0:
				if carried_amount > 0 and not delivery_resource.is_empty():
					delivery_completed.emit(delivery_resource, carried_amount)
				carried_amount = 0
				state = WorkState.TO_WORK if is_instance_valid(workplace) else WorkState.IDLE
		WorkState.WORKING:
			if not is_instance_valid(workplace):
				clear_job()
	queue_redraw()


func _idle_position() -> Vector2:
	var angle: float = float(farmer_index % 8) / 8.0 * TAU
	var ring: float = 66.0 + float(farmer_index / 8) * 18.0
	return city_position + Vector2.from_angle(angle) * ring


func _draw() -> void:
	var body_color := Color("d6b66a") if carried_amount == 0 else Color("f0cf59")
	draw_circle(Vector2.ZERO, 8.0, body_color)
	draw_rect(Rect2(-5, 6, 10, 9), Color("6f5438"))
	draw_string(ThemeDB.fallback_font, Vector2(-12, -13), str(farmer_index + 1), HORIZONTAL_ALIGNMENT_CENTER, 24.0, 10, Color.WHITE)
	if carried_amount > 0:
		draw_string(ThemeDB.fallback_font, Vector2(-15, 27), "%s%d" % [String(delivery_resource).left(1), carried_amount], HORIZONTAL_ALIGNMENT_CENTER, 30.0, 10, Color("ffe083"))
